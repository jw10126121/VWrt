# 软件包变体共享 Toolchain Cache 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让同一源码和 target/subtarget 下仅软件包选择不同的构建生成同一个 toolchain cache key，同时继续隔离真实工具链配置差异。

**架构：** 在缓存键脚本中把最终 `.config` 规范化为“非软件包配置”集合，忽略 `CONFIG_PACKAGE_*`、`CONFIG_DEFAULT_*` 和 `CONFIG_TARGET_DEVICE_PACKAGES_*` 的启用、赋值及未启用形式。toolchain key 升级到 v3；workflow restore/save 结构与 ccache 策略保持不变。

**技术栈：** Python 3 标准库、`unittest`、Bash、GitHub Actions YAML

---

## 文件结构

- 修改：`Scripts/ci_cache_keys.py`——解析 `.config`、生成规范化工具链配置哈希，并输出 v3 toolchain key。
- 修改：`Scripts/tests/test_ci_cache_keys.py`——锁定软件包差异共享、非软件包差异隔离和 key 版本行为。
- 验证：`Scripts/tests/test_workflow_cache_keys.sh`——确认 workflow 的精确 restore/save 与 ccache 行为没有回归。

### 任务 1：忽略纯软件包配置差异

**文件：**

- 修改：`Scripts/tests/test_ci_cache_keys.py`
- 修改：`Scripts/ci_cache_keys.py`

- [ ] **步骤 1：编写软件包差异共享缓存的失败测试**

在 `CacheKeysTest` 中添加：

```python
    def test_package_only_config_changes_reuse_toolchain(self):
        config = self.root / ".config"
        config.write_text(
            'CONFIG_TARGET_BOARD="qualcommax"\n'
            'CONFIG_GCC_VERSION="14.3.0"\n'
            'CONFIG_PACKAGE_kmod-mt7915e=y\n'
            '# CONFIG_PACKAGE_wpad-openssl is not set\n'
            'CONFIG_DEFAULT_kmod-mt76=y\n'
            'CONFIG_TARGET_DEVICE_PACKAGES_qualcommax_device="kmod-mt7915e"\n'
        )
        first = self.keys()

        config.write_text(
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
```

该测试同时覆盖：

- `CONFIG_PACKAGE_*` 的启用和 `is not set` 形式
- `CONFIG_DEFAULT_*` 的启用和 `is not set` 形式
- `CONFIG_TARGET_DEVICE_PACKAGES_*` 的正向及负向软件包列表
- 配置行顺序变化

- [ ] **步骤 2：运行测试并确认正确失败**

运行：

```bash
python3 -m unittest Scripts/tests/test_ci_cache_keys.py -v
```

预期：新增测试 FAIL；当前完整 `.config` 哈希会令两次 `TOOLCHAIN_CACHE_KEY` 不相等。其余已有测试通过。

- [ ] **步骤 3：实现最小配置规范化逻辑**

在 `Scripts/ci_cache_keys.py` 的 import 之后增加忽略前缀：

```python
PACKAGE_ONLY_CONFIG_PREFIXES = (
    "CONFIG_PACKAGE_",
    "CONFIG_DEFAULT_",
    "CONFIG_TARGET_DEVICE_PACKAGES_",
)
```

在 `fingerprint()` 后增加：

```python
def config_symbol(line):
    if line.startswith("# ") and line.endswith(" is not set"):
        return line[2:-len(" is not set")]
    if line.startswith("#"):
        return ""
    return line.split("=", 1)[0]


def toolchain_config_hash(path):
    normalized = []
    for raw_line in path.read_text().splitlines():
        line = raw_line.strip()
        if not line:
            continue
        symbol = config_symbol(line)
        if not symbol or symbol.startswith(PACKAGE_ONLY_CONFIG_PREFIXES):
            continue
        normalized.append(line)
    content = "\n".join(sorted(normalized)) + "\n"
    return hashlib.sha256(content.encode()).hexdigest()
```

将 `main()` 中：

```python
    config_hash = hashlib.sha256(config.read_bytes()).hexdigest()
```

替换为：

```python
    config_hash = toolchain_config_hash(config)
```

- [ ] **步骤 4：运行测试并确认通过**

运行：

```bash
python3 -m unittest Scripts/tests/test_ci_cache_keys.py -v
```

预期：全部测试 PASS。现有 `test_config_and_script_changes_invalidate_toolchain` 证明 GCC 等非软件包配置仍会改变 key。

- [ ] **步骤 5：提交规范化行为**

```bash
git add Scripts/ci_cache_keys.py Scripts/tests/test_ci_cache_keys.py
git commit -m "feat: 共享软件包变体的工具链缓存"
```

### 任务 2：升级 Toolchain Cache Key 版本

**文件：**

- 修改：`Scripts/tests/test_ci_cache_keys.py`
- 修改：`Scripts/ci_cache_keys.py`

- [ ] **步骤 1：先把版本断言改为 v3**

在 `test_keys_are_deterministic_and_versioned` 中将：

```python
        self.assertTrue(first["TOOLCHAIN_CACHE_KEY"].startswith("toolchain-v2-"))
```

改为：

```python
        self.assertTrue(first["TOOLCHAIN_CACHE_KEY"].startswith("toolchain-v3-"))
```

- [ ] **步骤 2：运行测试并确认版本测试失败**

运行：

```bash
python3 -m unittest Scripts/tests/test_ci_cache_keys.py -v
```

预期：只有 `test_keys_are_deterministic_and_versioned` FAIL，实际输出仍以 `toolchain-v2-` 开头。

- [ ] **步骤 3：把生产 key 前缀升级为 v3**

在 `main()` 中将：

```python
    print(f"TOOLCHAIN_CACHE_KEY=toolchain-v2-{compatibility_hash}")
```

改为：

```python
    print(f"TOOLCHAIN_CACHE_KEY=toolchain-v3-{compatibility_hash}")
```

保持 `CCACHE_CACHE_PREFIX=ccache-v2-...` 不变。

- [ ] **步骤 4：运行缓存键和 workflow 回归测试**

运行：

```bash
python3 -m unittest Scripts/tests/test_ci_cache_keys.py -v
bash Scripts/tests/test_workflow_cache_keys.sh
bash Scripts/tests/test_gl_mt6000_nowifi_overlay.sh
```

预期：

- Python 测试全部 PASS。
- workflow 测试输出 `test_workflow_cache_keys: ok`。
- MT6000 overlay 测试输出 `test_gl_mt6000_nowifi_overlay: ok`。

- [ ] **步骤 5：确认变更范围并提交版本升级**

运行：

```bash
git diff --check
git status --short
```

预期：没有空白错误；仅两个缓存键相关文件有预期修改。

提交：

```bash
git add Scripts/ci_cache_keys.py Scripts/tests/test_ci_cache_keys.py
git commit -m "chore: 升级工具链缓存键版本"
```

### 任务 3：最终验收

**文件：**

- 验证：`Scripts/ci_cache_keys.py`
- 验证：`Scripts/tests/test_ci_cache_keys.py`
- 验证：`.github/workflows/CORE-ALL.yml`

- [ ] **步骤 1：重新运行完整相关测试集**

```bash
python3 -m unittest Scripts/tests/test_ci_cache_keys.py -v
bash Scripts/tests/test_workflow_cache_keys.sh
bash Scripts/tests/test_gl_mt6000_nowifi_overlay.sh
```

预期：全部命令退出码为 0，没有测试失败。

- [ ] **步骤 2：核对兼容边界**

检查测试输出与测试用例，确认：

- 软件包选择和行顺序变化不改变 toolchain key。
- GCC、源码 commit、脚本哈希、target/subtarget、runner 等变化仍改变 toolchain key。
- ccache 前缀仍为 v2，且行为没有改变。
- workflow 的 toolchain restore/save 仍使用相同精确 key，且没有 `restore-keys`。

- [ ] **步骤 3：检查最终提交与工作区**

```bash
git log -3 --oneline
git status --short
```

预期：存在规范化和 v3 key 两个实现提交，工作区干净。
