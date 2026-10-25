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
            "WRT_CONFIG_LABEL": "gl-mt6000-fw4",
            "WRT_REPO_URL": "https://github.com/VIKINGYFY/immortalwrt",
            "WRT_REPO_BRANCH": "main",
            "REPO_GIT_HASH": "a" * 40,
            "DEVICE_TARGET": "qualcommax",
            "DEVICE_SUBTARGET": "ipq60xx",
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
        self.assertTrue(first["TOOLCHAIN_CACHE_KEY"].startswith("toolchain-v4-"))
        self.assertTrue(first["TOOLCHAIN_CACHE_RESTORE_KEY"].startswith("toolchain-v4-"))
        self.assertTrue(first["CCACHE_CACHE_PREFIX"].startswith("ccache-v4-"))
        self.assertTrue(first["CCACHE_CACHE_KEY"].startswith(first["CCACHE_CACHE_PREFIX"] + "-"))

    def test_new_commit_changes_exact_toolchain_key_but_keeps_restore_scope(self):
        first = self.keys()
        # 完整 SHA 的尾部变化也必须使工具链失效。
        changed = self.keys(REPO_GIT_HASH="a" * 39 + "c")
        self.assertNotEqual(first["TOOLCHAIN_CACHE_KEY"], changed["TOOLCHAIN_CACHE_KEY"])
        self.assertEqual(first["TOOLCHAIN_CACHE_RESTORE_KEY"], changed["TOOLCHAIN_CACHE_RESTORE_KEY"])
        self.assertEqual(first["CCACHE_CACHE_PREFIX"], changed["CCACHE_CACHE_PREFIX"])
        self.assertEqual(first["CCACHE_CACHE_KEY"], changed["CCACHE_CACHE_KEY"])

    def test_config_changes_invalidate_toolchain_and_restore_scope(self):
        first = self.keys()
        (self.root / ".config").write_text('CONFIG_GCC_VERSION="15.2.0"\n')
        self.assertNotEqual(first["TOOLCHAIN_CACHE_KEY"], self.keys()["TOOLCHAIN_CACHE_KEY"])
        self.assertNotEqual(first["TOOLCHAIN_CACHE_RESTORE_KEY"], self.keys()["TOOLCHAIN_CACHE_RESTORE_KEY"])

    def test_package_only_config_changes_reuse_toolchain(self):
        config = self.root / ".config"
        config.write_text(
            '# Wi-Fi 软件包\n'
            'CONFIG_TARGET_BOARD="qualcommax"\n'
            'CONFIG_GCC_VERSION="14.3.0"\n'
            'CONFIG_PACKAGE_kmod-mt7915e=y\n'
            '# CONFIG_PACKAGE_wpad-openssl is not set\n'
            'CONFIG_DEFAULT_kmod-mt76=y\n'
            'CONFIG_TARGET_DEVICE_PACKAGES_qualcommax_device="kmod-mt7915e"\n'
        )
        first = self.keys()

        config.write_text(
            '# OVERLAY_GROUP=nowifi\n'
            'CONFIG_TARGET_DEVICE_PACKAGES_qualcommax_device="-kmod-mt7915e"\n'
            '# CONFIG_DEFAULT_kmod-mt76 is not set\n'
            'CONFIG_PACKAGE_wpad-openssl=y\n'
            '# CONFIG_PACKAGE_kmod-mt7915e is not set\n'
            'CONFIG_GCC_VERSION="14.3.0"\n'
            'CONFIG_TARGET_BOARD="qualcommax"\n'
        )
        changed = self.keys()

        self.assertEqual(first["TOOLCHAIN_CACHE_KEY"], changed["TOOLCHAIN_CACHE_KEY"])
        self.assertEqual(first["CCACHE_CACHE_PREFIX"], changed["CCACHE_CACHE_PREFIX"])

    def test_repo_branch_target_and_host_are_isolated(self):
        first = self.keys()
        for change in (
            {"WRT_REPO_URL": "https://github.com/immortalwrt/immortalwrt"},
            {"WRT_REPO_BRANCH": "master"},
            {"DEVICE_TARGET": "other"},
            {"DEVICE_SUBTARGET": "ipq807x"},
            {"RUNNER_ARCH": "ARM64"},
        ):
            with self.subTest(change=change):
                changed = self.keys(**change)
                self.assertNotEqual(first["TOOLCHAIN_CACHE_KEY"], changed["TOOLCHAIN_CACHE_KEY"])
                self.assertNotEqual(first["TOOLCHAIN_CACHE_RESTORE_KEY"], changed["TOOLCHAIN_CACHE_RESTORE_KEY"])
                self.assertNotEqual(first["CCACHE_CACHE_PREFIX"], changed["CCACHE_CACHE_PREFIX"])
                self.assertNotEqual(first["CCACHE_CACHE_KEY"], changed["CCACHE_CACHE_KEY"])

        image_changed = self.keys(ImageOS="ubuntu26")
        self.assertNotEqual(first["TOOLCHAIN_CACHE_KEY"], image_changed["TOOLCHAIN_CACHE_KEY"])
        self.assertNotEqual(first["TOOLCHAIN_CACHE_RESTORE_KEY"], image_changed["TOOLCHAIN_CACHE_RESTORE_KEY"])
        self.assertEqual(first["CCACHE_CACHE_PREFIX"], image_changed["CCACHE_CACHE_PREFIX"])
        self.assertEqual(first["CCACHE_CACHE_KEY"], image_changed["CCACHE_CACHE_KEY"])

    def test_image_version_isolates_toolchain_but_not_ccache(self):
        first = self.keys()
        changed = self.keys(ImageVersion="20261007.1.0")
        self.assertNotEqual(first["TOOLCHAIN_CACHE_KEY"], changed["TOOLCHAIN_CACHE_KEY"])
        self.assertNotEqual(first["TOOLCHAIN_CACHE_RESTORE_KEY"], changed["TOOLCHAIN_CACHE_RESTORE_KEY"])
        self.assertEqual(first["CCACHE_CACHE_PREFIX"], changed["CCACHE_CACHE_PREFIX"])
        self.assertEqual(first["CCACHE_CACHE_KEY"], changed["CCACHE_CACHE_KEY"])

    def test_config_label_only_changes_exact_ccache_key(self):
        first = self.keys()
        changed = self.keys(WRT_CONFIG_LABEL="jd-ax6600-fw4")
        self.assertEqual(first["TOOLCHAIN_CACHE_KEY"], changed["TOOLCHAIN_CACHE_KEY"])
        self.assertEqual(first["TOOLCHAIN_CACHE_RESTORE_KEY"], changed["TOOLCHAIN_CACHE_RESTORE_KEY"])
        self.assertEqual(first["CCACHE_CACHE_PREFIX"], changed["CCACHE_CACHE_PREFIX"])
        self.assertNotEqual(first["CCACHE_CACHE_KEY"], changed["CCACHE_CACHE_KEY"])

    def test_missing_metadata_fails_instead_of_using_broad_key(self):
        for name in ("REPO_GIT_HASH", "WRT_CONFIG_LABEL", "DEVICE_TARGET", "DEVICE_SUBTARGET"):
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
