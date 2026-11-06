"""docs-folder validator: enforces Jira-keyed folders and descriptive investigation names."""
import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "validate_docs", ROOT / ".github" / "skills" / "docs-folder" / "scripts" / "validate_docs.py")
vd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vd)


class Topic(unittest.TestCase):
    def test_good_topics(self):
        for t in ["nparks-validation-403", "status-push-draft-approved", "apex-526-errors", "spf-plus2c-526-20261106"]:
            with self.subTest(t=t):
                self.assertIsNone(vd.topic_problem(t))

    def test_bad_topics(self):
        for t in ["2b8be96a", "a0a2e96a", "526", "apex-4dceb96af3c5d699aa53d56b", "x" * 70 + "-abc", "errors"]:
            with self.subTest(t=t):
                self.assertIsNotNone(vd.topic_problem(t))


class Tree(unittest.TestCase):
    def build(self, tmp: Path, dirs: list[str], files: list[str] = ()) -> Path:
        root = tmp / ".docs"
        root.mkdir()
        for d in dirs:
            (root / d).mkdir(parents=True, exist_ok=True)
        for f in files:
            (root / f).parent.mkdir(parents=True, exist_ok=True)
            (root / f).write_text("x")
        return root

    def rules(self, root: Path, profile: str, only=None) -> list[str]:
        return sorted(i["rule"] for i in vd.validate(root, profile, only))

    def test_clean_gobiz_tree(self):
        with tempfile.TemporaryDirectory() as t:
            root = self.build(Path(t), ["MOLBLT-1-foo-bar/investigation-foo-timeout", "archive/old", ".claude/x"],
                              ["MOLBLT-1-foo-bar/plan.md", "MOLBLT-1-foo-bar/fixes/fix-20261106-101010-null-check.md",
                               "KNOWN-ISSUES.md", ".DS_Store"])
            self.assertEqual(self.rules(root, "gobiz"), [])

    def test_gobiz_violations(self):
        with tempfile.TemporaryDirectory() as t:
            root = self.build(Path(t), ["MOLBLT-7645", "no-key-folder", "investigation-526",
                                        "MOLBLT-2-ok/investigation-2b8be96a"],
                              ["notes.md", "MOLBLT-2-ok/fixes/random.md"])
            self.assertEqual(self.rules(root, "gobiz"),
                             ["fix-name", "folder-name", "folder-name", "investigation-name", "root-artefact",
                              "root-file"])

    def test_general_profile_accepts_plain_kebab(self):
        with tempfile.TemporaryDirectory() as t:
            root = self.build(Path(t), ["create-form/investigation-form-save-error"])
            self.assertEqual(self.rules(root, "general"), [])

    def test_folder_filter(self):
        with tempfile.TemporaryDirectory() as t:
            root = self.build(Path(t), ["bad", "MOLBLT-3-ok/investigation-a0a2e96a"])
            self.assertEqual(self.rules(root, "gobiz", "MOLBLT-3-ok"), ["investigation-name"])

    def test_profile_line_present_in_every_variant(self):
        for variant in ("", "general/", "monorepo/"):
            for host in (".github", ".claude"):
                md = ROOT / f"{variant}{host}/skills/docs-folder/SKILL.md"
                with self.subTest(md=str(md.relative_to(ROOT))):
                    self.assertRegex(md.read_text(), r"\*\*PROFILE: (gobiz|general)\*\*")


if __name__ == "__main__":
    unittest.main()
