"""Claude PreToolUse guard: blocks leaks/bypasses, and never blocks a command our own skills tell agents to run."""
import json
import re
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GUARD = ROOT / ".claude" / "hooks" / "guard_bash.py"
sys.path.insert(0, str(GUARD.parent))
import guard_bash  # noqa: E402

DENY = {
    "token-argv": [
        'curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" https://sgts.gitlab-dedicated.com/api/v4/user',
        "curl --header 'Authorization: Bearer ${SLACK_TOKEN}' https://slack.com/api/auth.test",
        'curl -u "$JIRA_EMAIL:$JIRA_TOKEN" https://x.atlassian.net/rest/api/3/myself',
    ],
    "token-echo": [
        'echo "$GITLAB_TOKEN"',
        "echo token=${FIGMA_TOKEN}",
        'echo $DB_LICENCE_PROD_PASSWORD',
    ],
    "aws-prod-raw": [
        "aws ecs list-clusters --profile prod-elevated",
        "aws --profile=production s3 ls",
        "AWS_PROFILE=prod-elevated aws sts get-caller-identity",
    ],
    "psql-prod-raw": ['psql -h "$DB_LICENCE_PROD_HOST" -U "$DB_LICENCE_PROD_USER"'],
    "pg-prod-write": ['python3 pg_query.py query --db licence --env prod --sql "delete from x" --write'],
    "os-prod-write": [
        'curl -X DELETE "$OPENSEARCH_URL_PROD/prod-ap-backend.2026.10"',
        "curl --request PUT https://opensearch.molbproject.io/_cluster/settings -d '{}'",
    ],
}
ALLOW = [
    "curl -K <(printf 'header = \"PRIVATE-TOKEN: %s\"\\n' \"$GITLAB_TOKEN\") https://sgts.gitlab-dedicated.com/api/v4/user",
    '[ -n "$GITLAB_TOKEN" ] && echo OK || echo MISSING',
    'echo "GL: $([ -n "$GITLAB_TOKEN" ] && echo OK || echo MISSING) | GH: $([ -n "$GITHUB_TOKEN" ] && echo OK || echo MISSING)"',
    "aws sso login --profile staging",
    "bash .github/skills/aws-access/scripts/aws_ro.sh --env prod -- ecs list-clusters",
    "aws ecs list-clusters --profile staging",
    'python3 pg_query.py query --db licence --env prod --sql "select 1"',
    'python3 pg_query.py query --db licence --env stg --sql "update x set y=1" --write --rollback',
    'curl -X POST "$OPENSEARCH_URL_PROD/prod-ap-backend*/_search" -d "{}"',
    'curl -X POST "$OPENSEARCH_URL_NONPROD/staging-x/_doc" -d "{}"',
    "git status",
]


def documented_commands(md: Path) -> list[str]:
    text = md.read_text()
    blocks = re.findall(r"```(?:bash|sh)\n(.*?)```", text, flags=re.S)
    inline = re.findall(r"`((?:bash|python3|curl|aws|psql) [^`]+)`", text)
    return [b.replace("\\\n", " ") for b in blocks] + inline


class GuardRules(unittest.TestCase):
    def test_denies(self):
        for rule, cmds in DENY.items():
            for cmd in cmds:
                with self.subTest(cmd=cmd):
                    hit = guard_bash.decide(cmd)
                    self.assertIsNotNone(hit, "should be denied")
                    self.assertEqual(hit[0], rule)

    def test_allows(self):
        for cmd in ALLOW:
            with self.subTest(cmd=cmd):
                self.assertIsNone(guard_bash.decide(cmd))

    def test_skill_and_agent_snippets_are_not_blocked(self):
        docs = list((ROOT / ".github").rglob("*.md"))
        self.assertTrue(docs)
        for md in docs:
            for cmd in documented_commands(md):
                with self.subTest(file=str(md.relative_to(ROOT)), cmd=cmd[:80]):
                    self.assertIsNone(guard_bash.decide(cmd), "documented command would be denied by the hook")


class GuardProtocol(unittest.TestCase):
    def run_hook(self, payload: str) -> subprocess.CompletedProcess:
        return subprocess.run([sys.executable, str(GUARD)], input=payload, capture_output=True, text=True, timeout=10)

    def test_deny_json_shape(self):
        r = self.run_hook(json.dumps({"tool_name": "Bash", "tool_input": {"command": 'echo "$JIRA_TOKEN"'}}))
        self.assertEqual(r.returncode, 0)
        out = json.loads(r.stdout)["hookSpecificOutput"]
        self.assertEqual(out["hookEventName"], "PreToolUse")
        self.assertEqual(out["permissionDecision"], "deny")
        self.assertIn("[guard:token-echo]", out["permissionDecisionReason"])

    def test_allow_is_silent(self):
        r = self.run_hook(json.dumps({"tool_name": "Bash", "tool_input": {"command": "ls"}}))
        self.assertEqual((r.returncode, r.stdout), (0, ""))

    def test_garbage_input_is_silent(self):
        r = self.run_hook("not json")
        self.assertEqual((r.returncode, r.stdout), (0, ""))

    def test_internal_error_fails_closed(self):
        import io
        from unittest import mock
        with mock.patch.object(guard_bash, "decide", side_effect=RuntimeError("boom")), \
                mock.patch("sys.stdin", io.StringIO(json.dumps({"tool_input": {"command": "ls"}}))), \
                mock.patch("sys.stdout", new_callable=io.StringIO) as out:
            guard_bash.main()
        decision = json.loads(out.getvalue())["hookSpecificOutput"]
        self.assertEqual(decision["permissionDecision"], "deny")
        self.assertIn("[guard:error]", decision["permissionDecisionReason"])


class HookSettings(unittest.TestCase):
    def test_new_scripts_run_on_system_python(self):
        """macOS /usr/bin/python3 is 3.9 — hooks/skills may run under it; a crash would make the guard fail open."""
        sys_py = Path("/usr/bin/python3")
        if not sys_py.exists():
            self.skipTest("no /usr/bin/python3")
        skills = ROOT / ".github" / "skills"
        for script in (skills / "change-timeline/scripts/timeline.py", skills / "docs-folder/scripts/validate_docs.py",
                       skills / "integration-health/scripts/health.py"):
            with self.subTest(script=script.name):
                r = subprocess.run([str(sys_py), "-B", str(script), "--help"], capture_output=True, text=True, timeout=30)
                self.assertEqual(r.returncode, 0, r.stderr[-300:])
        r = subprocess.run([str(sys_py), "-B", str(GUARD)], capture_output=True, text=True, timeout=10,
                           input=json.dumps({"tool_input": {"command": 'echo "$JIRA_TOKEN"'}}))
        self.assertEqual(json.loads(r.stdout)["hookSpecificOutput"]["permissionDecision"], "deny", r.stderr[-300:])

    def test_settings_reference_existing_hooks(self):
        for base in (ROOT / ".claude", ROOT / "general" / ".claude", ROOT / "monorepo" / ".claude"):
            with self.subTest(base=str(base.relative_to(ROOT))):
                cfg = json.loads((base / "settings.json").read_text())
                cmds = [h["command"] for groups in cfg["hooks"].values() for g in groups for h in g["hooks"]]
                for cmd in cmds:
                    rel = re.search(r"\.claude/hooks/[\w.]+", cmd).group(0)
                    self.assertTrue((base.parent / rel).exists(), f"{rel} missing under {base}")


if __name__ == "__main__":
    unittest.main()
