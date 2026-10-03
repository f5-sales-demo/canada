import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class ExtractionTests(unittest.TestCase):
    def test_independent_canadian_graph(self):
        terraform = ROOT / "terraform"
        source = "\n".join(p.read_text() for p in terraform.glob("*.tf"))
        self.assertIn('resource "xcsh_namespace" "canada"', source)
        self.assertIn('backend "azurerm"', source)
        self.assertIn("f5-sales-demo/canada-topology", source)
        self.assertNotIn("f5-sales-demo/multi-cloud-networking", source)
        self.assertNotIn('provider "aws"', source)
        self.assertNotIn('data "terraform_remote_state"', source)
        self.assertIn("allow_ssh         = false", source)
        self.assertIn("data.xcsh_network_cdn.origin", source)
        self.assertIn("data.xcsh_network_regional_edges.origin", source)
        self.assertIn("canadacentral", source)
        self.assertIn("canadaeast", source)
        self.assertIn("ves-io-", source)

    def test_module_closure_is_local(self):
        import re

        sources = [
            s
            for p in (ROOT / "terraform").rglob("*.tf")
            for s in re.findall(r'source\s*=\s*"([^"]+)"', p.read_text())
            if s.startswith((".", "git", "http"))
        ]
        self.assertTrue(sources)
        self.assertTrue(all(s.startswith(("./modules/", "../")) for s in sources))

    def test_backend_security_and_teardown_boundary(self):
        bootstrap = ROOT / "terraform/bootstrap/state-backend/main.tf"
        text = bootstrap.read_text()
        for contract in [
            'location = "canadacentral"',
            "shared_access_key_enabled = false",
            "allow_nested_items_to_be_public = false",
            "versioning_enabled = true",
            "days = 30",
            'container_access_type = "private"',
            "Storage Blob Data Contributor",
            'default_action = "Deny"',
        ]:
            import re

            assert re.sub(r"\s+", " ", contract) in re.sub(r"\s+", " ", text)
        lifecycle = (ROOT / "scripts/lifecycle.py").read_text()
        self.assertNotIn("terraform/bootstrap", lifecycle)
        self.assertIn("fcntl.LOCK_EX", lifecycle)
        self.assertIn("validate(data, mode)", lifecycle)


if __name__ == "__main__":
    unittest.main()
