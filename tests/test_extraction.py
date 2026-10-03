import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class ExtractionTests(unittest.TestCase):
    def test_independent_canadian_graph(self):
        terraform = ROOT / "terraform"
        source = "\n".join(p.read_text() for p in terraform.glob("*.tf"))
        self.assertIn('resource "xcsh_namespace" "canada"', source)
        self.assertIn('backend "local"', source)
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
        backend = (ROOT / "terraform/backend.tf").read_text()
        self.assertIn('backend "local"', backend)
        self.assertFalse((ROOT / "terraform/bootstrap").exists())
        lifecycle = (ROOT / "scripts/lifecycle.py").read_text()
        self.assertIn(
            "local state must be absolute and outside the checkout", lifecycle
        )
        self.assertIn("local state directory must have mode 0700", lifecycle)
        self.assertIn("fcntl.LOCK_EX", lifecycle)
        self.assertIn("validate(data, mode)", lifecycle)
        self.assertIn('inventory["app_objects"]', lifecycle)


if __name__ == "__main__":
    unittest.main()
