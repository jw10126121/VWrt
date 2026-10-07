#!/usr/bin/env python3
"""生成 Actions 缓存键；stdout 可直接追加到 GITHUB_ENV。"""

import hashlib
import json
import os
from pathlib import Path


def required(name):
    value = os.environ.get(name, "")
    if not value.strip():
        raise SystemExit(f"缓存键缺少必要元数据：{name}")
    return value


def fingerprint(values):
    return hashlib.sha256(json.dumps(values, sort_keys=True).encode()).hexdigest()


def main():
    # 镜像版本也参与隔离，避免升级 host 编译器/运行库后复用旧工具。
    scope = {
        name: required(name)
        for name in (
            "RUNNER_OS", "RUNNER_ARCH", "ImageOS", "ImageVersion",
            "WRT_REPO_URL", "WRT_REPO_BRANCH", "DEVICE_TARGET", "DEVICE_SUBTARGET",
        )
    }
    source_hash = required("REPO_GIT_HASH")
    scripts_hash = required("CACHE_SCRIPTS_HASH")
    config = Path(required("OPENWRT_PATH")) / ".config"
    config_hash = hashlib.sha256(config.read_bytes()).hexdigest()
    compatibility_hash = fingerprint({
        **scope,
        "source": source_hash,
        "config": config_hash,
        "scripts": scripts_hash,
    })
    print(f"TOOLCHAIN_CACHE_KEY=toolchain-v2-{compatibility_hash}")
    # ccache 自行验证编译器、源码和参数，可在同一 scope 内跨提交复用。
    print(f"CCACHE_CACHE_PREFIX=ccache-v2-{fingerprint(scope)}")


if __name__ == "__main__":
    main()
