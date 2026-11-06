"""Safety guarantees of the integration scripts — all offline (no network, no real credentials used)."""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKILLS = ROOT / ".github" / "skills"
SECRET = "sentinel-secret-value-do-not-print"


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def clean_env(**extra) -> dict:
    keep = {k: v for k, v in os.environ.items() if k in ("PATH", "HOME", "TMPDIR", "LANG")}
    return {**keep, **extra}


class PostgresReadOnlyScreen(unittest.TestCase):
    pg = load("pg_query", SKILLS / "postgres-query" / "scripts" / "pg_query.py")

    def test_reads_pass(self):
        for sql in ["select 1", "with x as (select 1) select * from x", "explain select * from t",
                    "select 'delete from t' as s", "select 1 -- drop table t", "show search_path"]:
            with self.subTest(sql=sql):
                self.assertEqual(self.pg.write_reasons(sql), [])

    def test_writes_refused(self):
        for sql in ["delete from t", "update t set a=1", "insert into t values (1)", "drop table t",
                    "select 1; delete from t", "truncate t", "with d as (delete from t returning *) select * from d",
                    "\\! rm -rf /", "alter table t add c int", "grant all on t to x"]:
            with self.subTest(sql=sql):
                self.assertNotEqual(self.pg.write_reasons(sql), [])

    def test_prod_write_refused_before_connecting(self):
        env = clean_env(**{f"DB_LICENCE_PROD_{f}": v for f, v in
                           {"HOST": "127.0.0.1", "PORT": "1", "NAME": "x", "USER": "x", "PASSWORD": SECRET}.items()})
        r = subprocess.run([sys.executable, str(SKILLS / "postgres-query" / "scripts" / "pg_query.py"), "query",
                            "--db", "licence", "--env", "prod", "--sql", "delete from t", "--write"],
                           capture_output=True, text=True, env=env, timeout=30)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("read-only", r.stderr.lower() + r.stdout.lower())
        self.assertNotIn(SECRET, r.stdout + r.stderr)


class AwsWriteGuard(unittest.TestCase):
    script = SKILLS / "aws-access" / "scripts" / "aws_ro.sh"

    def run_ro(self, *args):
        return subprocess.run(["bash", str(self.script), *args], capture_output=True, text=True,
                              env=clean_env(), timeout=30)

    def test_write_refused_without_flag(self):
        r = self.run_ro("--env", "staging", "--", "ecs", "update-service", "--cluster", "c", "--service", "s")
        self.assertEqual(r.returncode, 1)
        self.assertIn("refused", r.stderr)

    def test_sensitive_refused_without_flag(self):
        r = self.run_ro("--env", "prod", "--", "secretsmanager", "get-secret-value", "--secret-id", "x")
        self.assertEqual(r.returncode, 1)
        self.assertIn("refused", r.stderr)

    def test_prod_write_needs_double_confirmation(self):
        r = self.run_ro("--env", "prod", "--write", "--", "ecs", "update-service", "--cluster", "c")
        self.assertEqual(r.returncode, 1)
        self.assertIn("confirm twice", r.stderr)

    def test_classify(self):
        cases = {("ecs", "describe-services"): "read", ("logs", "start-query"): "read",
                 ("ssm", "get-parameter", "--with-decryption"): "sensitive", ("ssm", "get-parameter"): "read",
                 ("lambda", "invoke"): "sensitive", ("ecs", "update-service"): "write", ("s3", "rm"): "sensitive"}
        lib = SKILLS / "aws-access" / "scripts" / "_lib.sh"
        for args, want in cases.items():
            with self.subTest(args=args):
                r = subprocess.run(["bash", "-c", f'source "{lib}"; classify "$@"', "_", *args],
                                   capture_output=True, text=True, timeout=10)
                self.assertEqual(r.stdout.strip(), want)


class IntegrationHealthNoLeak(unittest.TestCase):
    script = SKILLS / "integration-health" / "scripts" / "health.py"

    def test_offline_never_prints_values(self):
        env = clean_env(JIRA_EMAIL=SECRET, JIRA_TOKEN=SECRET, JIRA_BASE_URL=SECRET, GITLAB_TOKEN=SECRET,
                        FIGMA_TOKEN=SECRET, OPENSEARCH_URL_NONPROD=SECRET, OPENSEARCH_URL_PROD=SECRET,
                        APEX_LOG_TOKEN_STAGING=SECRET, SLACK_TOKEN=SECRET)
        outputs = []
        for args in ([], ["--json"]):
            r = subprocess.run([sys.executable, str(self.script), *args],
                               capture_output=True, text=True, env=env, timeout=60)
            self.assertNotIn(SECRET, r.stdout + r.stderr)
            outputs.append(r.stdout)
        rows = {x["name"]: x for x in json.loads(outputs[1])["integrations"]}
        self.assertTrue(rows["jira"]["configured"])
        self.assertTrue(rows["slack"]["optional"])

    def test_unknown_integration_rejected(self):
        r = subprocess.run([sys.executable, str(self.script), "--only", "bogus"],
                           capture_output=True, text=True, timeout=30)
        self.assertEqual(r.returncode, 1)


class TimelineInputs(unittest.TestCase):
    tl = load("timeline", SKILLS / "change-timeline" / "scripts" / "timeline.py")
    now = datetime(2026, 11, 6, 6, 0, tzinfo=timezone.utc)

    def test_relative_and_absolute_times(self):
        self.assertEqual(self.tl.parse_time("6h", self.now), self.now - timedelta(hours=6))
        self.assertEqual(self.tl.parse_time("2d", self.now), self.now - timedelta(days=2))
        naive_sgt = self.tl.parse_time("2026-11-06 14:00", self.now)
        self.assertEqual(naive_sgt.astimezone(timezone.utc), self.now)

    def test_bad_input_exits(self):
        script = SKILLS / "change-timeline" / "scripts" / "timeline.py"
        for args in (["--env", "uat"], ["--env", "stg", "--since", "1h", "--until", "2h"],
                     ["--env", "stg", "--since", "yesterday"]):
            with self.subTest(args=args):
                r = subprocess.run([sys.executable, str(script), *args], capture_output=True, text=True,
                                   env=clean_env(), timeout=30)
                self.assertEqual(r.returncode, 1)
                self.assertIn("ERROR", r.stderr)


class JiraScriptsNoArgvSecrets(unittest.TestCase):
    def test_scripts_use_curl_config_not_argv(self):
        for sh in (SKILLS / "jira-ticket" / "scripts").glob("*.sh"):
            text = sh.read_text()
            with self.subTest(script=sh.name):
                self.assertNotRegex(text, r"-u\s+\"?\$JIRA_EMAIL")
                self.assertNotRegex(text, r"-H\s+\"Authorization")

    def test_search_requires_query(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = clean_env(JIRA_BASE_URL="https://example.invalid", JIRA_EMAIL="x", JIRA_TOKEN=SECRET, TMPDIR=tmp)
            for script in ("search-issues.sh", "search-pages.sh"):
                r = subprocess.run(["bash", str(SKILLS / "jira-ticket" / "scripts" / script)],
                                   capture_output=True, text=True, env=env, timeout=30)
                with self.subTest(script=script):
                    self.assertEqual(r.returncode, 1)
                    self.assertNotIn(SECRET, r.stdout + r.stderr)


if __name__ == "__main__":
    unittest.main()
