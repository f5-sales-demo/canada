"""Reject unclassified, mismatched and spoofable country acceptance receipts."""

# ruff: noqa: PT027
import copy
import importlib.util
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location(
    "country",
    Path(__file__).resolve().parents[1] / "scripts/verify-country-receipts.py",
)
assert SPEC is not None
assert SPEC.loader is not None
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)


class CountryTests(unittest.TestCase):
    def setUp(self):
        self.receipt = {
            "domain": "canada.f5-sales-demo.ca",
            "source_commit": "a" * 40,
            "dns_matches_allocation": True,
            "canadian": {
                "samples": 120,
                "failures": 0,
                "country": "CA",
                "observed_egress": "192.0.2.1",
                "xc_source_ip": "192.0.2.1",
                "exact_origin": True,
            },
            "negative": [
                {
                    "country": "US",
                    "observed_egress": "192.0.2.2",
                    "xc_source_ip": "192.0.2.2",
                    "requests": [
                        {"variant": variant, "status": 403, "xc_policy_denial": True}
                        for variant in [
                            "plain",
                            "x-forwarded-for",
                            "forwarded",
                            "x-real-ip",
                        ]
                    ],
                }
            ],
        }

    def test_complete_receipt_passes(self):
        module.validate(self.receipt)

    def test_insufficient_or_unclassified_evidence_fails(self):
        mutations = [
            lambda value: value["canadian"].update(samples=119),
            lambda value: value["canadian"].update(country="US"),
            lambda value: value["canadian"].update(xc_source_ip="192.0.2.3"),
            lambda value: value.update(dns_matches_allocation=False),
            lambda value: value["negative"][0].update(country=""),
            lambda value: value["negative"][0].update(xc_source_ip="192.0.2.3"),
            lambda value: value["negative"][0]["requests"].pop(),
            lambda value: value["negative"][0]["requests"][0].update(status=200),
            lambda value: value["negative"][0]["requests"][0].update(
                xc_policy_denial=False
            ),
        ]
        for mutation in mutations:
            receipt = copy.deepcopy(self.receipt)
            mutation(receipt)
            with self.assertRaises(ValueError):
                module.validate(receipt)
