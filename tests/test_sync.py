"""broadcast-sync invariant: every destination equals root after the documented transforms (no drift)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BROADCAST = (ROOT / ".github" / "agents" / "broadcast-sync.agent.md").read_text()


def listed(label: str) -> set[str]:
    m = re.search(rf"\*\*{label}\*\*:(.*)", BROADCAST)
    assert m, f"'{label}' line missing in broadcast-sync.agent.md"
    return set(re.findall(r"`([^`]+)`", m.group(1)))


EX_AGENTS = listed("Integration Agents")
EX_SKILLS = listed("Integration Skills")
AGENTS = {p.name[: -len(".agent.md")]: p for p in (ROOT / ".github" / "agents").glob("*.agent.md")}
SKILLS = {p.name: p for p in (ROOT / ".github" / "skills").iterdir() if p.is_dir()}


def skill_files(d: Path) -> dict[str, bytes]:
    return {str(f.relative_to(d)): f.read_bytes() for f in d.rglob("*") if f.is_file() and f.name != ".DS_Store" and "__pycache__" not in f.parts}


def docs_general(b: bytes) -> bytes:
    t = b.decode().replace("**PROFILE: gobiz**", "**PROFILE: general**")
    return "".join(line for line in t.splitlines(True) if "env-chope/" not in line).encode()


class Sync(unittest.TestCase):
    def test_exclusions_name_real_sources(self):
        self.assertLessEqual(EX_AGENTS, set(AGENTS))
        self.assertLessEqual(EX_SKILLS, set(SKILLS))

    def test_agents(self):
        for name, src in AGENTS.items():
            dests = [ROOT / ".claude/commands" / f"{name}.md", ROOT / "monorepo/.github/agents" / src.name,
                     ROOT / "monorepo/.claude/commands" / f"{name}.md"]
            if name not in EX_AGENTS:
                dests += [ROOT / "general/.github/agents" / src.name, ROOT / "general/.claude/commands" / f"{name}.md"]
            for d in dests:
                with self.subTest(dest=str(d.relative_to(ROOT))):
                    self.assertTrue(d.exists(), "missing")
                    self.assertEqual(d.read_bytes(), src.read_bytes(), "drifted from root")

    def test_skills(self):
        for name, src in SKILLS.items():
            want = skill_files(src)
            dests = [".claude/skills", "monorepo/.github/skills", "monorepo/.claude/skills"]
            if name not in EX_SKILLS:
                dests += ["general/.github/skills", "general/.claude/skills"]
            for d in dests:
                got_dir = ROOT / d / name
                with self.subTest(dest=f"{d}/{name}"):
                    self.assertTrue(got_dir.is_dir(), "missing")
                    expected = want
                    if d.startswith("general") and name == "docs-folder":
                        expected = {k: docs_general(v) if k == "SKILL.md" else v for k, v in want.items()}
                    self.assertEqual(skill_files(got_dir), expected, "drifted from root")

    def test_general_has_no_integration_items(self):
        for host, sub in ((".github", "agents"), (".claude", "commands")):
            names = {p.name.split(".")[0] for p in (ROOT / "general" / host / sub).glob("*.md")}
            self.assertFalse(names & EX_AGENTS, f"general/{host}/{sub} contains integration agents")
        for host in (".github", ".claude"):
            names = {p.name for p in (ROOT / "general" / host / "skills").iterdir() if p.is_dir()}
            self.assertFalse(names & EX_SKILLS, f"general/{host}/skills contains integration skills")

    def test_no_orphan_skills_or_agents(self):
        for d in (".claude/skills", "monorepo/.github/skills", "monorepo/.claude/skills",
                  "general/.github/skills", "general/.claude/skills"):
            for p in (ROOT / d).iterdir():
                if p.is_dir():
                    with self.subTest(orphan=f"{d}/{p.name}"):
                        self.assertIn(p.name, SKILLS)
        for d in (".claude/commands", "monorepo/.claude/commands", "general/.claude/commands"):
            for p in (ROOT / d).glob("*.md"):
                with self.subTest(orphan=f"{d}/{p.name}"):
                    self.assertIn(p.stem, AGENTS)

    def test_claude_hooks(self):
        files = [ROOT / ".claude/settings.json", *(ROOT / ".claude/hooks").iterdir()]
        for variant in ("general", "monorepo"):
            for f in files:
                d = ROOT / variant / f.relative_to(ROOT)
                with self.subTest(dest=str(d.relative_to(ROOT))):
                    self.assertTrue(d.exists(), "missing")
                    self.assertEqual(d.read_bytes(), f.read_bytes())


if __name__ == "__main__":
    unittest.main()
