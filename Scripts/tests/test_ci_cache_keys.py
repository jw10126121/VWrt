#!/usr/bin/env python3
"""验证缓存兼容性边界，直接运行真实键生成脚本。"""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "ci_cache_keys.py"


class CacheKeysTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / ".config").write_text('CONFIG_TARGET_BOARD="qualcommax"\nCONFIG_GCC_VERSION="14.3.0"\n')
        self.env = {
            **os.environ,
            "OPENWRT_PATH": str(self.root),
            "RUNNER_OS": "Linux",
            "RUNNER_ARCH": "X64",
            "ImageOS": "ubuntu24",
            "ImageVersion": "20261001.1.0",
            "WRT_REPO_URL": "https://github.com/VIKINGYFY/immortalwrt",
            "WRT_REPO_BRANCH": "main",
            "REPO_GIT_HASH": "a" * 40,
            "DEVICE_TARGET": "qualcommax",
            "DEVICE_SUBTARGET": "ipq60xx",
            "CACHE_SCRIPTS_HASH": "b" * 64,
        }

    def keys(self, **changes):
        result = subprocess.run(
            [sys.executable, str(SCRIPT)], env={**self.env, **changes},
            check=True, text=True, capture_output=True,
        )
        return dict(line.split("=", 1) for line in result.stdout.splitlines())

    def test_keys_are_deterministic_and_versioned(self):
        first = self.keys()
        self.assertEqual(first, self.keys())
        self.assertTrue(first["TOOLCHAIN_CACHE_KEY"].startswith("toolchain-v2-"))
        self.assertTrue(first["CCACHE_CACHE_PREFIX"].startswith("ccache-v2-"))

    def test_new_commit_invalidates_toolchain_but_allows_ccache_reuse(self):
        first = self.keys()
        # 完整 SHA 的尾部变化也必须使工具链失效。
        changed = self.keys(REPO_GIT_HASH="a" * 39 + "c")
        self.assertNotEqual(first["TOOLCHAIN_CACHE_KEY"], changed["TOOLCHAIN_CACHE_KEY"])
        self.assertEqual(first["CCACHE_CACHE_PREFIX"], changed["CCACHE_CACHE_PREFIX"])

    def test_config_and_script_changes_invalidate_toolchain(self):
        first = self.keys()
        (self.root / ".config").write_text('CONFIG_GCC_VERSION="15.2.0"\n')
        self.assertNotEqual(first["TOOLCHAIN_CACHE_KEY"], self.keys()["TOOLCHAIN_CACHE_KEY"])
        self.assertNotEqual(self.keys()["TOOLCHAIN_CACHE_KEY"], self.keys(CACHE_SCRIPTS_HASH="c" * 64)["TOOLCHAIN_CACHE_KEY"])

    def test_repo_branch_target_and_host_are_isolated(self):
        first = self.keys()
        for change in (
            {"WRT_REPO_URL": "https://github.com/immortalwrt/immortalwrt"},
            {"WRT_REPO_BRANCH": "master"},
            {"DEVICE_TARGET": "other"},
            {"DEVICE_SUBTARGET": "ipq807x"},
            {"RUNNER_ARCH": "ARM64"},
            {"ImageOS": "ubuntu26"},
            {"ImageVersion": "20261007.1.0"},
        ):
            with self.subTest(change=change):
                changed = self.keys(**change)
                self.assertNotEqual(first["TOOLCHAIN_CACHE_KEY"], changed["TOOLCHAIN_CACHE_KEY"])
                self.assertNotEqual(first["CCACHE_CACHE_PREFIX"], changed["CCACHE_CACHE_PREFIX"])

    def test_missing_metadata_fails_instead_of_using_broad_key(self):
        for name in ("REPO_GIT_HASH", "DEVICE_TARGET", "DEVICE_SUBTARGET", "CACHE_SCRIPTS_HASH"):
            with self.subTest(name=name):
                result = subprocess.run(
                    [sys.executable, str(SCRIPT)], env={**self.env, name: ""},
                    text=True, capture_output=True,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")
                self.assertIn(name, result.stderr)


if __name__ == "__main__":
    unittest.main()
