"""Run with: python3 -m unittest discover -s .github/tests -v."""

import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest


REPOSITORY = Path(__file__).resolve().parents[2]
SCRIPT = REPOSITORY / ".github/scripts/detect-upstream.sh"
QQ_CONFIG = "https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/linuxConfig.js"
QQ_BACKUP = "https://qqdl.gtimg.cn/qqfile/QQNT/9.9.33/release/c97651b2/QQ_3.2.32_260730_{}_01.deb"
ARCHES = ("amd64", "arm64")


class DetectUpstreamTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.packages_dir = tempfile.TemporaryDirectory(prefix="wechat-ci-packages-")
        cls.addClassCleanup(cls.packages_dir.cleanup)
        cls.packages = {}
        for name, version in (("wechat", "4.1.13.23"), ("qq", "3.2.32-51802"), ("qq", "3.2.34-60000")):
            for arch in ARCHES:
                root = Path(cls.packages_dir.name) / f"{name}-{version}-{arch}"
                (root / "DEBIAN").mkdir(parents=True)
                (root / "DEBIAN/control").write_text(
                    f"Package: {name}\nVersion: {version}\nArchitecture: {arch}\n"
                    "Maintainer: CI Tests <ci@example.invalid>\nDescription: Test package\n"
                )
                (root / "payload").write_text(f"{name} {version} {arch}\n")
                package = root.parent / (root.name + ".deb")
                subprocess.run(["dpkg-deb", "--build", str(root), str(package)], check=True, capture_output=True)
                cls.packages[name, version, arch] = package

    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix="wechat-ci-test-")
        self.addCleanup(directory.cleanup)
        self.directory = Path(directory.name)
        self.state_path = self.directory / "upstream.env"
        self.output_path = self.directory / "output"
        self.rules_path = self.directory / "curl-rules.json"
        self.requests_path = self.directory / "requests.jsonl"
        self.bin_path = self.directory / "bin"
        self.bin_path.mkdir()
        fake_curl = self.bin_path / "curl"
        fake_curl.write_text("""#!/usr/bin/env python3
import json, os, pathlib, shutil, sys
args = sys.argv[1:]
url = args[-1]
with open(os.environ['FAKE_CURL_REQUESTS'], 'a') as requests:
    requests.write(json.dumps(url) + '\\n')
rules = json.loads(pathlib.Path(os.environ['FAKE_CURL_RULES']).read_text())
rule = rules.get(url, {'code': 22})
if rule.get('code', 0):
    print('curl: simulated failure for ' + url, file=sys.stderr)
    sys.exit(rule['code'])
if '-o' in args:
    shutil.copyfile(rule['path'], args[args.index('-o') + 1])
else:
    print(rule['body'])
""")
        fake_curl.chmod(0o755)
        self.rules = {}
        self.state = {}
        for name, version in (("wechat", "4.1.13.23"), ("qq", "3.2.32-51802")):
            for arch in ARCHES:
                url = f"https://packages.example.invalid/{name}-{arch}.deb"
                self.track_package(name, arch, url, version)
                self.rules[url] = {"path": str(self.packages[name, version, arch])}
            self.state[f"{name.upper()}_LAST_CHECKED_AT"] = "2026-01-01T00:00:00Z"
        for arch in ARCHES:
            self.rules[QQ_BACKUP.format(arch)] = {"path": str(self.packages["qq", "3.2.32-51802", arch])}
        self.configure_latest("3.2.34-60000")
        self.write_state()

    def track_package(self, name, arch, url, version):
        prefix = f"{name.upper()}_{arch.upper()}"
        self.state[prefix + "_URL"] = url
        self.state[prefix + "_VERSION"] = version
        self.state[prefix + "_SHA256"] = hashlib.sha256(self.packages[name, version, arch].read_bytes()).hexdigest()

    def configure_latest(self, version, failure=None):
        config = {}
        self.latest_urls = {}
        for arch, field in (("amd64", "x64DownloadUrl"), ("arm64", "armDownloadUrl")):
            url = f"https://packages.example.invalid/latest-{arch}_01.deb"
            self.latest_urls[arch] = url
            config[field] = {"deb": url}
            self.rules[url] = {"code": failure} if failure else {"path": str(self.packages["qq", version, arch])}
        self.rules[QQ_CONFIG] = {"body": ";(function(){var params=" + json.dumps(config) + ";})()"}

    def write_state(self):
        lines = ["# Upstream package state tracked by automation.", ""]
        for name in ("WECHAT", "QQ"):
            for field in ("URL", "VERSION", "SHA256"):
                for arch in ("AMD64", "ARM64"):
                    key = f"{name}_{arch}_{field}"
                    lines.append(f'{key}="{self.state[key]}"')
                lines.append("")
            key = f"{name}_LAST_CHECKED_AT"
            lines.extend([f'{key}="{self.state[key]}"', ""])
        self.state_path.write_text("\n".join(lines))

    def run_detection(self, overrides=None):
        self.rules_path.write_text(json.dumps(self.rules))
        self.output_path.write_text("")
        self.requests_path.write_text("")
        env = {key: value for key, value in os.environ.items() if not key.startswith(("WECHAT_", "QQ_", "GITHUB_"))}
        env.update({
            "PATH": str(self.bin_path) + os.pathsep + env["PATH"],
            "STATE_FILE": str(self.state_path),
            "GITHUB_OUTPUT": str(self.output_path),
            "GITHUB_STEP_SUMMARY": str(self.directory / "summary"),
            "FAKE_CURL_RULES": str(self.rules_path),
            "FAKE_CURL_REQUESTS": str(self.requests_path),
        })
        env.update(overrides or {})
        self.result = subprocess.run(["bash", str(SCRIPT)], env=env, capture_output=True, text=True, timeout=15)
        self.requests = [json.loads(line) for line in self.requests_path.read_text().splitlines()]
        return self.result

    def read_state(self):
        return {
            key: shlex.split(value)[0]
            for line in self.state_path.read_text().splitlines()
            if line and not line.startswith("#")
            for key, value in [line.split("=", 1)]
        }

    def assert_success(self, changed):
        self.assertEqual(self.result.returncode, 0, self.result.stdout + self.result.stderr)
        self.assertIn(f"changed={str(changed).lower()}\n", self.output_path.read_text())

    def assert_qq_package(self, arch, url, version):
        state = self.read_state()
        prefix = "QQ_" + arch.upper()
        self.assertEqual(state[prefix + "_URL"], url)
        self.assertEqual(state[prefix + "_VERSION"], version)
        self.assertEqual(state[prefix + "_SHA256"], hashlib.sha256(self.packages["qq", version, arch].read_bytes()).hexdigest())

    def test_blocked_latest_preserves_known_good_state(self):
        self.configure_latest("3.2.34-60000", failure=22)
        before = self.state_path.read_bytes()
        before_mtime = self.state_path.stat().st_mtime_ns
        self.run_detection()
        self.assert_success(changed=False)
        self.assertEqual(self.state_path.read_bytes(), before)
        self.assertEqual(self.state_path.stat().st_mtime_ns, before_mtime)
        self.assertIn("Using fallback package", self.result.stderr)
        for arch in ARCHES:
            self.assertNotIn(QQ_BACKUP.format(arch), self.requests)

    def test_repairs_mismatched_urls_and_remains_stable(self):
        self.configure_latest("3.2.34-60000", failure=22)
        for arch in ARCHES:
            self.state[f"QQ_{arch.upper()}_URL"] = self.latest_urls[arch]
        self.write_state()
        self.run_detection()
        self.assert_success(changed=True)
        for arch in ARCHES:
            self.assert_qq_package(arch, QQ_BACKUP.format(arch), "3.2.32-51802")
            self.assertEqual(self.requests.count(self.latest_urls[arch]), 1)
        repaired = self.state_path.read_bytes()
        self.run_detection()
        self.assert_success(changed=False)
        self.assertEqual(self.state_path.read_bytes(), repaired)

    def test_uses_previous_package_before_older_backup(self):
        self.configure_latest("3.2.34-60000", failure=28)
        for arch in ARCHES:
            url = self.state[f"QQ_{arch.upper()}_URL"]
            self.track_package("qq", arch, url, "3.2.34-60000")
            self.rules[url] = {"path": str(self.packages["qq", "3.2.34-60000", arch])}
        self.write_state()
        self.run_detection()
        self.assert_success(changed=False)
        for arch in ARCHES:
            self.assert_qq_package(arch, self.state[f"QQ_{arch.upper()}_URL"], "3.2.34-60000")
            self.assertNotIn(QQ_BACKUP.format(arch), self.requests)

    def test_records_available_latest_package(self):
        self.run_detection()
        self.assert_success(changed=True)
        for arch in ARCHES:
            self.assert_qq_package(arch, self.latest_urls[arch], "3.2.34-60000")

    def test_url_change_detected_when_package_is_identical(self):
        self.configure_latest("3.2.32-51802")
        self.run_detection()
        self.assert_success(changed=True)
        for arch in ARCHES:
            self.assert_qq_package(arch, self.latest_urls[arch], "3.2.32-51802")

    def test_failed_downloads_do_not_overwrite_state(self):
        self.configure_latest("3.2.34-60000", failure=28)
        for arch in ARCHES:
            self.rules[self.state[f"QQ_{arch.upper()}_URL"]] = {"code": 28}
            self.rules[QQ_BACKUP.format(arch)] = {"code": 28}
        before = self.state_path.read_bytes()
        self.run_detection()
        self.assertNotEqual(self.result.returncode, 0)
        self.assertEqual(self.state_path.read_bytes(), before)
        self.assertEqual(self.output_path.read_text(), "")
        self.assertIn("::error::Failed to download a valid package", self.result.stderr)

    def test_invalid_package_falls_back_to_valid_package(self):
        invalid = self.directory / "invalid.deb"
        invalid.write_text("<html>download unavailable</html>")
        for arch in ARCHES:
            self.rules[self.latest_urls[arch]] = {"path": str(invalid)}
        self.run_detection()
        self.assert_success(changed=False)
        self.assertIn("Invalid Debian package", self.result.stderr)

    def test_explicit_urls_skip_discovery(self):
        self.run_detection({"QQ_AMD64_URL": self.latest_urls["amd64"], "QQ_ARM64_URL": self.latest_urls["arm64"]})
        self.assert_success(changed=True)
        self.assertNotIn(QQ_CONFIG, self.requests)

    def test_config_failure_uses_tracked_urls(self):
        self.rules[QQ_CONFIG] = {"code": 28}
        before = self.state_path.read_bytes()
        self.run_detection()
        self.assert_success(changed=False)
        self.assertEqual(self.state_path.read_bytes(), before)
        self.assertIn("Failed to fetch the official QQ configuration", self.result.stderr)


if __name__ == "__main__":
    unittest.main()
