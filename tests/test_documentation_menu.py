"""Guard the short English titles and four stage landings."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "docs" / "en"
ROUTES = {
    "index",
    "design",
    "use-case",
    "architecture",
    "deploy",
    "deployment",
    "terraform",
    "verify",
    "presentation",
    "verification",
    "operate",
    "troubleshooting",
    "failover",
    "teardown",
}
STAGES = {
    "design": ("use-case", "architecture", "deploy"),
    "deploy": ("deployment", "terraform", "verify"),
    "verify": ("presentation", "verification", "operate"),
    "operate": ("troubleshooting", "failover", "teardown", "design"),
}


class DocumentationMenuTest(unittest.TestCase):
    def test_all_english_pages_have_short_titles(self):
        pages = {path.stem: path for path in ROOT.glob("*.mdx")}
        assert set(pages) == ROUTES
        for route, path in pages.items():
            with self.subTest(route=route):
                title = re.search(r"^title: (.+)$", path.read_text(), re.MULTILINE)
                assert title is not None
                assert len(title.group(1).split()) <= 3

    def test_each_overview_links_to_its_pages_and_next_stage(self):
        for stage, destinations in STAGES.items():
            text = (ROOT / f"{stage}.mdx").read_text()
            with self.subTest(stage=stage):
                for route in destinations:
                    assert f"(../{route}/)" in text


if __name__ == "__main__":
    unittest.main()
