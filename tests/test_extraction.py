import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class ExtractionTests(unittest.TestCase):
    def test_independent_canadian_graph(self):
        terraform = ROOT / "terraform"
        source = "\n".join(p.read_text() for p in terraform.glob("*.tf"))
        assert 'resource "xcsh_namespace" "canada"' in source
        assert 'backend "local"' in source
        assert "f5-sales-demo/canada-topology" in source
        assert "f5-sales-demo/multi-cloud-networking" not in source
        assert 'provider "aws"' not in source
        assert 'data "terraform_remote_state"' not in source
        assert "allow_ssh         = false" in source
        assert "data.xcsh_network_cdn.origin" in source
        assert "data.xcsh_network_regional_edges.origin" in source
        assert "canadacentral" in source
        assert "canadaeast" in source
        assert "ves-io-" in source

    def test_module_closure_is_local(self):

        sources = [
            s
            for p in (ROOT / "terraform").rglob("*.tf")
            for s in re.findall(r'source\s*=\s*"([^"]+)"', p.read_text())
            if s.startswith((".", "git", "http"))
        ]
        assert sources
        assert all(s.startswith(("./modules/", "../")) for s in sources)

    def test_backend_security_and_teardown_boundary(self):
        backend = (ROOT / "terraform/backend.tf").read_text()
        assert 'backend "local"' in backend
        assert not (ROOT / "terraform/bootstrap").exists()
        lifecycle = (ROOT / "scripts/lifecycle.py").read_text()
        assert "local state must be absolute and outside the checkout" in lifecycle
        assert "local state directory must have mode 0700" in lifecycle
        assert "fcntl.LOCK_EX" in lifecycle
        assert "validate(data, mode)" in lifecycle
        assert 'inventory["app_objects"]' in lifecycle


if __name__ == "__main__":
    unittest.main()
