# ruff: noqa: PT027
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("scope", ROOT / "scripts/plan_scope.py")
assert spec is not None
assert spec.loader is not None
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ScopeTests(unittest.TestCase):
    def test_owned_http_loadbalancer_passes(self):
        module.validate(
            {
                "resource_changes": [
                    {
                        "address": "xcsh_http_loadbalancer.canada[0]",
                        "change": {"actions": ["create"]},
                    }
                ]
            },
            "build",
        )

    def test_foreign_root_rejected(self):
        with self.assertRaisesRegex(ValueError, "foreign resource"):
            module.validate(
                {
                    "resource_changes": [
                        {
                            "address": "aws_instance.ce",
                            "change": {"actions": ["create"]},
                        }
                    ]
                },
                "build",
            )

    def test_destroy_rejects_update(self):
        with self.assertRaisesRegex(ValueError, "non-deletion"):
            module.validate(
                {
                    "resource_changes": [
                        {
                            "address": "module.ce_node_ca.azurerm_network_interface.mgmt",
                            "change": {"actions": ["update"]},
                        }
                    ]
                },
                "destroy",
            )

    def test_zero_requires_output_noop(self):
        with self.assertRaisesRegex(ValueError, "output changes"):
            module.validate(
                {
                    "resource_changes": [],
                    "output_changes": {"domain": {"actions": ["update"]}},
                },
                "zero",
            )

    def test_owned_deletions_pass(self):
        module.validate(
            {
                "resource_changes": [
                    {
                        "address": "module.ce_vm_ca.azurerm_linux_virtual_machine.this",
                        "change": {"actions": ["delete"]},
                    }
                ]
            },
            "destroy",
        )

    def test_application_cutover_rejects_infrastructure_replacement(self):
        for address in [
            "module.ce_vm_ca.azurerm_linux_virtual_machine.this",
            "module.showcase_origin_ca.azurerm_linux_virtual_machine.this",
            "module.azure_frr_ca.azurerm_linux_virtual_machine.this",
            "xcsh_public_ip_binding.canada[0]",
        ]:
            with self.assertRaises(ValueError):
                module.validate(
                    {
                        "resource_changes": [
                            {
                                "address": address,
                                "change": {"actions": ["delete", "create"]},
                            }
                        ]
                    },
                    "application",
                )

    def test_application_cutover_rejects_infrastructure_update(self):
        with self.assertRaises(ValueError):
            module.validate(
                {
                    "resource_changes": [
                        {
                            "address": "xcsh_public_ip_binding.canada[0]",
                            "change": {
                                "actions": ["update"],
                                "before": {"expected_ip": "192.0.2.1"},
                                "after": {"expected_ip": "192.0.2.2"},
                            },
                        }
                    ]
                },
                "application",
            )


if __name__ == "__main__":
    unittest.main()


class NamespaceMigrationTests(unittest.TestCase):
    def test_namespace_and_application_migration(self):
        for address, before, after in [
            ("xcsh_namespace.canada", {"name": "canada-topology"}, {"name": "canada"}),
            (
                "xcsh_http_loadbalancer.canada[0]",
                {"namespace": "canada-topology"},
                {"namespace": "canada"},
            ),
        ]:
            module.validate(
                {
                    "resource_changes": [
                        {
                            "address": address,
                            "change": {
                                "actions": ["delete", "create"],
                                "before": before,
                                "after": after,
                            },
                        }
                    ]
                },
                "namespace",
            )

    def test_ce_and_token_replacement_rejected(self):
        for address in [
            "xcsh_token.ce[0]",
            'module.ce_vm_ca["one"].azurerm_linux_virtual_machine.this',
        ]:
            with self.assertRaises(ValueError):
                module.validate(
                    {
                        "resource_changes": [
                            {
                                "address": address,
                                "change": {
                                    "actions": ["delete", "create"],
                                    "before": {},
                                    "after": {},
                                },
                            }
                        ]
                    },
                    "namespace",
                )


class CeReadbackNormalizationTests(unittest.TestCase):
    def test_false_flags_equal_omitted_flags(self):
        assert module.normalize_ce_readback(
            {"is_primary": False, "mac": "synthetic"}
        ) == {"mac": "synthetic"}
        assert module.normalize_ce_readback({"is_primary": True}) == {
            "is_primary": True
        }
