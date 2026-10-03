"""Canadian public RE isolation acceptance regression tests."""

# pylint: disable=invalid-name,missing-class-docstring,missing-function-docstring
# ruff: noqa: PT009, PT027
import copy
import importlib.util
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location(
    "canadian_re",
    Path(__file__).resolve().parents[1] / "scripts/verify-canadian-public-re.py",
)
assert SPEC is not None
assert SPEC.loader is not None
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)


class CanadianRETests(unittest.TestCase):
    def setUp(self):
        self.config = {
            "allocation": {
                "name": "ip-example",
                "namespace": "shared",
                "ip": "192.0.2.55",
            },
            "virtual_site": "canada",
            "re_namespace": "shared",
            "ce_virtual_site": "canada-ce",
            "namespace": "demo",
            "ce_sites": ["ca1", "ca2", "ca3"],
            "domain": "canada.f5-sales-demo.ca",
            "pool": "canada-pool",
            "loadbalancer": "canada-lb",
            "service_policy": "canada-only",
            "internal_loadbalancer": "canada-internal",
            "origin_ip": "192.0.2.30",
        }
        self.objects = {
            "service_policy": {
                "spec": {
                    "any_server": {},
                    "allow_list": {
                        "country_list": ["COUNTRY_CA"],
                        "default_action_deny": {},
                    },
                }
            },
            "public_ip": {
                "spec": {
                    "ip": "192.0.2.55",
                    "virtual_sites": [{"name": "canada", "namespace": "shared"}],
                }
            },
            "virtual_site": {
                "spec": {
                    "site_type": "REGIONAL_EDGE",
                    "site_selector": {"expressions": module.SELECTOR},
                }
            },
            "selectees": {"items": [{"name": name} for name in module.ALLOWED_RE]},
            "ce_selectees": {
                "items": [{"name": name} for name in self.config["ce_sites"]]
            },
            "loadbalancer": {
                "spec": {
                    "domains": ["canada.f5-sales-demo.ca"],
                    "add_location": True,
                    "disable_trust_client_ip_headers": {},
                    "active_service_policies": {
                        "policies": [{"name": "canada-only", "namespace": "demo"}]
                    },
                    "advertise_custom": {
                        "advertise_where": [
                            {
                                "advertise_on_public": {
                                    "public_ip": {
                                        "name": "ip-example",
                                        "namespace": "shared",
                                    }
                                }
                            },
                        ]
                    },
                    "default_route_pools": [
                        {"pool": {"name": "canada-pool", "namespace": "demo"}}
                    ],
                }
            },
            "pool": {
                "spec": {
                    "endpoint_selection": "DISTRIBUTED",
                    "origin_servers": [
                        {
                            "private_ip": {
                                "ip": "192.0.2.30",
                                "site_locator": {
                                    "virtual_site": {
                                        "name": "canada-ce",
                                        "namespace": "demo",
                                    }
                                },
                            }
                        }
                    ],
                }
            },
        }

        self.objects["internal_loadbalancer"] = {
            "spec": {
                "domains": ["internal.canada.f5-sales-demo.ca"],
                "http": {"dns_volterra_managed": False},
                "advertise_custom": {
                    "advertise_where": [
                        {"site": {"site": {"name": site}}}
                        for site in self.config["ce_sites"]
                    ]
                },
                "default_route_pools": [
                    {"pool": {"name": "canada-pool", "namespace": "demo"}}
                ],
            }
        }

    def test_reads_regional_selectees_in_allocation_namespace(self):
        routes = []

        def get(namespace, kind, name, suffix=""):
            routes.append((namespace, kind, name, suffix))
            return {}

        module.collect_configuration(self.config, get)
        self.assertIn(("shared", "virtual_sites", "canada", "/selectees"), routes)
        self.assertIn(("demo", "virtual_sites", "canada-ce", "/selectees"), routes)
        self.assertIn(
            ("demo", "http_loadbalancers", self.config["loadbalancer"], ""), routes
        )

    def test_exact_configuration_passes(self):
        module.validate_configuration(self.config, self.objects)

    def test_foreign_binding_listener_pool_and_origin_are_rejected(self):
        mutations = [
            lambda value: value["public_ip"]["spec"]["virtual_sites"].append(
                {"name": "all"}
            ),
            lambda value: value["selectees"]["items"].append({"name": "us-edge"}),
            lambda value: value["ce_selectees"]["items"].append({"name": "us-ce"}),
            lambda value: value["loadbalancer"]["spec"]["advertise_custom"][
                "advertise_where"
            ].append({"site": {"site": {"name": "ca1"}}}),
            lambda value: value["loadbalancer"]["spec"].update(
                domains=["old.f5-sales-demo.ca"]
            ),
            lambda value: value["loadbalancer"]["spec"].update(
                service_policies_from_namespace={}
            ),
            lambda value: value["loadbalancer"]["spec"].update(
                disable_trust_client_ip_headers=None
            ),
            lambda value: value["loadbalancer"]["spec"]["active_service_policies"][
                "policies"
            ].append({"name": "exceptions"}),
            lambda value: value["service_policy"]["spec"]["allow_list"][
                "country_list"
            ].append("COUNTRY_US"),
            lambda value: value["service_policy"]["spec"]["allow_list"][
                "country_list"
            ].append("COUNTRY_NONE"),
            lambda value: value["service_policy"]["spec"]["allow_list"].update(
                default_action_allow={}
            ),
            lambda value: value["service_policy"]["spec"]["allow_list"].update(
                prefix_list={"prefixes": ["192.0.2.1/32"]}
            ),
            lambda value: value["service_policy"]["spec"]["allow_list"].update(
                asn_list={"as_numbers": [64512]}
            ),
            lambda value: value["service_policy"]["spec"].update(disable=True),
            lambda value: value["loadbalancer"]["spec"]["default_route_pools"][0][
                "pool"
            ].update(name="us-pool"),
            lambda value: value["pool"]["spec"]["origin_servers"][0][
                "private_ip"
            ].update(ip="192.0.2.31"),
            lambda value: value["pool"]["spec"].update(endpoint_selection="LOCAL_ONLY"),
        ]
        mutations.extend(
            [
                lambda value: value["internal_loadbalancer"]["spec"]["http"].update(
                    dns_volterra_managed=True
                ),
                lambda value: value["internal_loadbalancer"]["spec"][
                    "advertise_custom"
                ]["advertise_where"].append({"advertise_on_public": {}}),
                lambda value: value["internal_loadbalancer"]["spec"][
                    "default_route_pools"
                ][0]["pool"].update(name="foreign"),
            ]
        )
        for mutation in mutations:
            value = copy.deepcopy(self.objects)
            mutation(value)
            with self.assertRaises(ValueError):
                module.validate_configuration(self.config, value)

    def test_response_requires_canadian_marker_and_location(self):
        for edge in module.ALLOWED_RE:
            self.assertEqual(
                module.validate_response(
                    b"mcn-showcase-canada-origin",
                    f"X-Volterra-Location: {edge}",
                    "mcn-showcase-canada-origin",
                ),
                edge,
            )
        for body, headers in [
            (b"mcn-showcase-origin", "X-Volterra-Location: tr2-tor"),
            (b"mcn-showcase-canada-origin", "X-Volterra-Location: us-edge"),
            (b"mcn-showcase-canada-origin", ""),
        ]:
            with self.assertRaises(ValueError):
                module.validate_response(body, headers, "mcn-showcase-canada-origin")
