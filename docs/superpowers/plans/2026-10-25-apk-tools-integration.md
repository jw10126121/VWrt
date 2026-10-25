# apk-tools 补丁集成实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将 `apk-tools.sh` 集成到 VWrt，使 APK 构建自动生成允许未受信任包的 apk-tools 补丁，同时保留脚本的手动复用能力。

**架构：** 新增自包含的 POSIX shell 脚本，使用 `OPENWRT_PATH` 或默认 `${GITHUB_WORKSPACE}/wrt` 定位源码，并幂等写入固定补丁文件。`CORE-ALL.yml` 在源码克隆和包管理器解析完成后，仅对 APK 模式调用脚本；IPK 模式明确跳过。测试通过临时源码目录验证脚本输出和幂等性，并静态检查 workflow 接入。

**技术栈：** POSIX `sh`、GitHub Actions YAML、现有 shell 测试约定。

---

### 任务 1：为 apk-tools 脚本编写失败测试

**文件：**
- 创建：`Scripts/tests/test_apk_tools.sh`
- 参考：`Scripts/tests/test_diy_config_apk_index_patch.sh`

- [x] **步骤 1：编写测试脚本**

测试应创建临时 `OPENWRT_PATH/package/system/apk`，执行 `Scripts/apk-tools.sh`，断言 `patches/0101-allow-untrusted-by-default.patch` 存在，包含 `ac->trust.allow_untrusted = 1;` 且不包含原来的条件判断；复制结果后再次执行并用 `cmp` 断言幂等。测试还应运行 `bash -n Scripts/apk-tools.sh`。

- [x] **步骤 2：运行测试确认失败**

运行：`bash Scripts/tests/test_apk_tools.sh`

预期：FAIL，报错 `Scripts/apk-tools.sh: No such file or directory`。

### 任务 2：实现可复用的 apk-tools 补丁脚本

**文件：**
- 创建：`Scripts/apk-tools.sh`

- [x] **步骤 1：实现最少脚本**

脚本内容应使用 `#!/bin/sh` 和 `set -e`，解析 `OPENWRT_PATH`，为空时使用 `${GITHUB_WORKSPACE}/wrt`；定义 `PATCH_DIR` 与 `PATCH_FILE`，执行 `mkdir -p "$PATCH_DIR"`，通过单引号 heredoc 覆盖写入参考补丁，最后输出补丁路径。补丁上下文必须保持：

```diff
-	if (ac->flags & APK_ALLOW_UNTRUSTED) ac->trust.allow_untrusted = 1;
+	ac->trust.allow_untrusted = 1;
```

- [x] **步骤 2：运行脚本测试确认通过**

运行：`bash Scripts/tests/test_apk_tools.sh`

预期：输出 `test_apk_tools: ok`。

- [x] **步骤 3：提交脚本与测试**

运行：

```bash
git add Scripts/apk-tools.sh Scripts/tests/test_apk_tools.sh
git commit -m "feat: 集成 apk-tools 信任补丁"
```

### 任务 3：接入 APK workflow 并回归验证

**文件：**
- 修改：`.github/workflows/CORE-ALL.yml`（源码克隆步骤完成包管理器解析后）
- 创建：`Scripts/tests/test_workflow_apk_tools.sh`

- [x] **步骤 1：编写 workflow 静态测试**

测试读取 `CORE-ALL.yml`，断言存在 `WRT_PACKAGE_MANAGER` 为 `apk` 时调用 `Scripts/apk-tools.sh`，且脚本调用位于 `DIY Feeds (自定义 Feeds)` 步骤之前；同时断言 IPK 分支包含跳过日志，避免无条件应用补丁。

- [x] **步骤 2：运行测试确认失败**

运行：`bash Scripts/tests/test_workflow_apk_tools.sh`

预期：FAIL，因为 workflow 尚未包含 apk-tools 步骤。

- [x] **步骤 3：增加条件调用步骤**

在 `CORE-ALL.yml` 克隆源码步骤结束后增加独立步骤：

```yaml
- name: Apply apk-tools Patch (应用 apk-tools 补丁)
  if: env.WRT_PACKAGE_MANAGER == 'apk'
  run: bash "$GITHUB_WORKSPACE/$WRT_DIR_SCRIPTS/apk-tools.sh"
```

同时增加一个 shell 分支日志，确保脚本只在 APK 模式运行；脚本通过 `OPENWRT_PATH` 环境变量定位刚克隆的源码。

- [x] **步骤 4：运行 workflow 静态测试与相关回归测试**

运行：

```bash
bash Scripts/tests/test_workflow_apk_tools.sh
bash Scripts/tests/test_diy_config_package_manager.sh
bash Scripts/tests/test_diy_config_apk_index_patch.sh
git diff --check
```

预期：所有测试输出 `ok`，`git diff --check` 无输出且退出码为 0。

- [x] **步骤 5：提交 workflow 接入**

运行：

```bash
git add .github/workflows/CORE-ALL.yml Scripts/tests/test_workflow_apk_tools.sh
git commit -m "ci: 在 APK 构建中应用 apk-tools 补丁"
```

