# 编译产物文件名加入源码短 hash 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将源码短 hash 放在输出前缀的源码风味之后，使所有编译产物、Packages、Artifact 和 Release 名称都能标识源码提交。

**架构：** 在 `Scripts/ci_collect_final_metadata.sh` 集中解析源码短 hash，并把它写入现有 `OUTPUT_NAME_PREFIX`。后续工作流和 `Scripts/ci_organize_outputs.sh` 继续复用该前缀，不新增分散的命名拼接逻辑。

**技术栈：** Bash、GitHub Actions、Shell 回归测试。

---

## 文件清单

- 修改：`Scripts/ci_collect_final_metadata.sh`：读取短 hash，按优先级生成安全的 hash 标签并拼入输出前缀。
- 修改：`Scripts/tests/test_ci_collect_metadata_version_priority.sh`：验证短 hash 拼接及完整 hash 兜底。
- 修改：`Scripts/tests/test_ci_organize_outputs_naming.sh`：验证整理后的文件、Packages 目录和 ZIP 继承带 hash 的前缀。

### 任务 1：先更新元数据测试

**文件：**
- 修改：`Scripts/tests/test_ci_collect_metadata_version_priority.sh`

- [ ] **步骤 1：让测试输入明确包含短 hash**

在 `run_case` 的环境变量中加入 `REPO_GIT_hash_simple="abc1234"`，并把现有 `OUTPUT_NAME_PREFIX` 断言统一改为 `源码风味_abc1234_设备...`。

- [ ] **步骤 2：增加完整 hash 兜底用例**

让测试辅助函数支持单独传入短 hash 和完整 hash；新增一个短 hash 为空、完整 hash 为 `123456789abcdef` 的用例，断言输出前缀使用 `1234567`。

- [ ] **步骤 3：运行测试确认当前实现失败**

运行：`bash Scripts/tests/test_ci_collect_metadata_version_priority.sh`

预期：失败，当前 `OUTPUT_NAME_PREFIX` 尚未包含 `abc1234` 或完整 hash 截取值。

### 任务 2：实现源码 hash 前缀

**文件：**
- 修改：`Scripts/ci_collect_final_metadata.sh`：在现有 `repo_git_hash` 读取处增加短 hash 解析，并修改 `output_name_prefix`。

- [ ] **步骤 1：读取短 hash 并提供兜底**

使用 `REPO_GIT_hash_simple` 作为首选；为空时从 `REPO_GIT_HASH` 取前 7 位；两者为空时使用 `unknown`。保持完整 hash 继续用于 README 和通知正文。

- [ ] **步骤 2：拼接统一输出前缀**

将前缀构造改为 `${source_flavor_tag}_${repo_git_hash_simple}_${device_name_alias}_...`，保留现有字段顺序和默认值。

- [ ] **步骤 3：运行元数据测试确认通过**

运行：`bash Scripts/tests/test_ci_collect_metadata_version_priority.sh`

预期：输出 `test_ci_collect_metadata_version_priority: ok`，且短 hash 与完整 hash 兜底断言均通过。

### 任务 3：更新并验证产物整理测试

**文件：**
- 修改：`Scripts/tests/test_ci_organize_outputs_naming.sh`：将测试前缀改为 `lean_abc1234_cmiot_ax18_...`，并同步所有文件断言和 ZIP 目录断言。

- [ ] **步骤 1：更新测试前缀**

把测试传入的 `OUTPUT_NAME_PREFIX` 和所有期望路径统一改为带 `abc1234` 的前缀，确保配置、README、Packages 目录、Packages ZIP 和固件文件都覆盖到。

- [ ] **步骤 2：运行产物整理测试**

运行：`bash Scripts/tests/test_ci_organize_outputs_naming.sh`

预期：输出 `test_ci_organize_outputs_naming: ok`。

### 任务 4：完整回归与提交

**文件：**
- 检查：`Scripts/ci_collect_final_metadata.sh`
- 检查：`Scripts/ci_organize_outputs.sh`
- 检查：`.github/workflows/CORE-ALL.yml`

- [ ] **步骤 1：检查工作流复用关系**

确认 Artifact、Packages Artifact、Release 名称和上传路径仍全部引用 `OUTPUT_NAME_PREFIX`，不需要额外修改工作流。

- [ ] **步骤 2：运行相关回归测试和 shell 语法检查**

运行：

```bash
bash -n Scripts/ci_collect_final_metadata.sh Scripts/ci_organize_outputs.sh Scripts/tests/test_ci_collect_metadata_version_priority.sh Scripts/tests/test_ci_organize_outputs_naming.sh
bash Scripts/tests/test_ci_collect_metadata_version_priority.sh
bash Scripts/tests/test_ci_organize_outputs_naming.sh
git diff --check
```

预期：所有命令退出码为 0，两个测试分别输出 `ok`，且 `git diff --check` 无输出。

- [ ] **步骤 3：提交实现**

```bash
git add Scripts/ci_collect_final_metadata.sh Scripts/tests/test_ci_collect_metadata_version_priority.sh Scripts/tests/test_ci_organize_outputs_naming.sh
git commit -m "feat: 在产物文件名中加入源码短 hash"
```
