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


if __name__ == "__main__":
    unittest.main()
