# 源码风味解耦实现计划

> **给执行型 agent 的要求：** 必须使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 按任务逐项执行。所有步骤都使用 `- [ ]` 复选框格式追踪。

**目标：** 让 `LjwOpenWrt` 以 `WRT_REPO_URL` 为唯一来源解析 `source_flavor=lean|VIKINGYFY|generic`，并将 `diy_config.sh`、`Packages.sh`、workflow 与 README 从 `lean` 目录特征耦合中解开。

**架构：** 先新增共享的源码风味解析 helper，再用它重构 shell 脚本与 workflow。`diy_config.sh` 采用 `common/lean/VIKINGYFY/generic` 四层结构，`Packages.sh` 则保留通用包操作函数，只把源码专属覆盖清单拆分出去。最后补齐结构测试、风味解析测试与文档说明。

**技术栈：** Bash、GitHub Actions YAML、GNU/bsd `sed`、`grep`、现有 shell 测试脚本

---

### 任务 1：新增共享源码风味解析 helper

**文件：**
- 新建：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/lib/source_flavor.sh`
- 新建：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/test_source_flavor.sh`

- [ ] **步骤 1：先写失败测试**

```bash
#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/source_flavor.sh"

[ "$(resolve_source_flavor "https://github.com/coolsnowwolf/lede")" = "lean" ]
[ "$(resolve_source_flavor "https://github.com/VIKINGYFY/immortalwrt")" = "VIKINGYFY" ]
[ "$(resolve_source_flavor "https://github.com/openwrt/openwrt")" = "generic" ]

echo "test_source_flavor: ok"
```

- [ ] **步骤 2：运行测试并确认失败**

运行：`bash Scripts/test_source_flavor.sh`

预期：失败，提示 `Scripts/lib/source_flavor.sh` 不存在或 `resolve_source_flavor` 未定义。

- [ ] **步骤 3：补最小实现**

```bash
#!/bin/bash

resolve_source_flavor() {
    local repo_url=${1:-}
    local repo_url_lc

    repo_url_lc=$(printf '%s' "$repo_url" | tr '[:upper:]' '[:lower:]')

    case "$repo_url_lc" in
        *coolsnowwolf/lede*)
            printf '%s\n' 'lean'
            ;;
        *vikingyfy/immortalwrt*)
            printf '%s\n' 'VIKINGYFY'
            ;;
        *)
            printf '%s\n' 'generic'
            ;;
    esac
}
```

- [ ] **步骤 4：运行测试并确认通过**

运行：`bash Scripts/test_source_flavor.sh`

预期：输出 `test_source_flavor: ok`

- [ ] **步骤 5：提交**

```bash
git add Scripts/lib/source_flavor.sh Scripts/test_source_flavor.sh
git commit -m "test: add source flavor resolver"
```

### 任务 2：重构 `diy_config.sh` 的源码风味边界

**文件：**
- 修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/diy_config.sh`
- 修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/test_diy_config_structure.sh`
- 复用：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/lib/source_flavor.sh`

- [ ] **步骤 1：先更新结构测试，要求新边界函数存在**

```bash
required_functions='
resolve_source_flavor_from_input
configure_common_system_defaults
apply_lean_runtime_customizations
apply_VIKINGYFY_runtime_customizations
apply_generic_runtime_defaults
main
'
```

- [ ] **步骤 2：运行结构测试并确认失败**

运行：`bash Scripts/test_diy_config_structure.sh`

预期：失败，提示缺少 `resolve_source_flavor_from_input`、`configure_common_system_defaults` 或 `apply_VIKINGYFY_runtime_customizations`。

- [ ] **步骤 3：在 `diy_config.sh` 里接入共享 helper 与显式源码风味解析**

```bash
source_repo_url="${WRT_REPO_URL:-}"
source_flavor='generic'

resolve_source_flavor_from_input() {
    if [ -n "${source_repo_url}" ]; then
        source_flavor=$(resolve_source_flavor "${source_repo_url}")
    else
        source_flavor='generic'
    fi

    echo "【Lin】源码风味：${source_flavor}"
}
```

- [ ] **步骤 4：把通用系统逻辑聚合到新函数名下**

```bash
configure_common_system_defaults() {
    configure_default_system
    configure_theme
    clear_passwords
    adjust_luci_menu_positions
    configure_openvpn_defaults
    configure_base_package_options
    patch_apk_empty_feed_indexing
}
```

- [ ] **步骤 5：把主流程改成按 `source_flavor` 调度**

```bash
main() {
    WRT_TARGET="${config_name}"
    resolve_source_flavor_from_input

    configure_common_system_defaults
    update_build_revision

    case "${source_flavor}" in
        lean)
            apply_lean_runtime_customizations
            configure_nss_usage_display
            ;;
        VIKINGYFY)
            apply_VIKINGYFY_runtime_customizations
            apply_ipq_optimizations
            apply_ipq_init_tuning
            ;;
        *)
            apply_generic_runtime_defaults
            apply_ipq_optimizations
            apply_ipq_init_tuning
            ;;
    esac
}
```

- [ ] **步骤 6：给 `VIKINGYFY` 先建空边界函数**

```bash
apply_VIKINGYFY_runtime_customizations() {
    echo "【Lin】当前源码风味为 VIKINGYFY，暂未追加专属运行时修补"
}
```

- [ ] **步骤 7：运行结构与包管理器测试确认通过**

运行：

```bash
bash Scripts/test_diy_config_structure.sh
bash Scripts/test_diy_config_package_manager.sh
bash Scripts/test_diy_config_apk_index_patch.sh
```

预期：

- `test_diy_config_structure: ok`
- `test_diy_config_package_manager: ok`
- `test_diy_config_apk_index_patch: ok`

- [ ] **步骤 8：提交**

```bash
git add Scripts/diy_config.sh Scripts/test_diy_config_structure.sh
git commit -m "refactor: split diy config by source flavor"
```

### 任务 3：重构 `Packages.sh` 的源码风味入口

**文件：**
- 修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/Packages.sh`
- 新建：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/test_packages_source_flavor.sh`
- 复用：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/lib/source_flavor.sh`

- [ ] **步骤 1：先补 `Packages.sh` 的风味解析测试**

```bash
#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/Packages.sh"

for fn in resolve_packages_source_flavor apply_lean_package_overrides apply_VIKINGYFY_package_overrides apply_generic_package_overrides; do
    grep -q "^${fn}() {" "$TARGET_SCRIPT"
done

echo "test_packages_source_flavor: ok"
```

- [ ] **步骤 2：运行测试并确认失败**

运行：`bash Scripts/test_packages_source_flavor.sh`

预期：失败，提示缺少新的风味函数。

- [ ] **步骤 3：让 `Packages.sh` 接入共享 helper**

```bash
source_repo_url="${WRT_REPO_URL:-}"
source_flavor='generic'

resolve_packages_source_flavor() {
    source_flavor=$(resolve_source_flavor "${source_repo_url}")
    echo "【Lin】Packages 源码风味：${source_flavor}"
}
```

- [ ] **步骤 4：把当前源码专属包清单拆成三个入口函数**

```bash
apply_lean_package_overrides() {
    :
}

apply_VIKINGYFY_package_overrides() {
    update_package_list "luci-app-timewol" "VIKINGYFY/packages" "main"
}

apply_generic_package_overrides() {
    :
}
```

- [ ] **步骤 5：在主流程里按风味调用对应入口**

```bash
resolve_packages_source_flavor

case "${source_flavor}" in
    lean)
        apply_lean_package_overrides
        ;;
    VIKINGYFY)
        apply_VIKINGYFY_package_overrides
        ;;
    *)
        apply_generic_package_overrides
        ;;
esac
```

- [ ] **步骤 6：运行风味测试确认通过**

运行：`bash Scripts/test_packages_source_flavor.sh`

预期：输出 `test_packages_source_flavor: ok`

- [ ] **步骤 7：提交**

```bash
git add Scripts/Packages.sh Scripts/test_packages_source_flavor.sh
git commit -m "refactor: split packages by source flavor"
```

### 任务 4：让 workflow 输出并传递 `SOURCE_FLAVOR`

**文件：**
- 修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/.github/workflows/CORE-ALL.yml`
- 修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/ci_collect_source_metadata.sh`
- 可选修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/.github/workflows/DEFAULT.yml`
- 可选修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/.github/workflows/CUSTOM.yml`
- 复用：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/lib/source_flavor.sh`

- [ ] **步骤 1：先补元数据测试，要求支持 `SOURCE_FLAVOR`**

```bash
WRT_REPO_URL="https://github.com/VIKINGYFY/immortalwrt" \
WRT_REPO_BRANCH="main" \
SOURCE_FLAVOR="VIKINGYFY" \
OPENWRT_PATH="$TMPDIR/openwrt" \
bash "$SCRIPT_DIR/ci_collect_source_metadata.sh" > "$TMPDIR/meta.env"

grep -q '^SOURCE_FLAVOR=VIKINGYFY$' "$TMPDIR/meta.env"
```

- [ ] **步骤 2：运行元数据测试并确认失败**

运行：`bash Scripts/test_export_config.sh` 或新增独立元数据测试

预期：失败，因为输出里还没有 `SOURCE_FLAVOR`。

- [ ] **步骤 3：在 `CORE-ALL.yml` 里统一解析 `SOURCE_FLAVOR`**

```bash
. "$GITHUB_WORKSPACE/Scripts/lib/source_flavor.sh"
SOURCE_FLAVOR=$(resolve_source_flavor "$WRT_REPO_URL")
echo "SOURCE_FLAVOR=${SOURCE_FLAVOR}" >> "$GITHUB_ENV"

if [ "${SOURCE_FLAVOR}" = "lean" ]; then
  echo "WRT_IS_LEAN=true" >> "$GITHUB_ENV"
else
  echo "WRT_IS_LEAN=false" >> "$GITHUB_ENV"
fi
```

- [ ] **步骤 4：在源码元数据采集脚本里输出 `SOURCE_FLAVOR`**

```bash
source_flavor="${SOURCE_FLAVOR:-generic}"

cat <<EOF
WRT_VER=${wrt_ver}
SOURCE_REPO=${source_repo}
SOURCE_FLAVOR=${source_flavor}
DEVICE_TARGET=${device_target}
DEVICE_SUBTARGET=${device_subtarget}
DEVICE_PROFILE=${device_profile}
DEVICE_NAME_LIST=${device_name_list_joined}
DEVICE_NAME_LIST_LIAN=${device_name_list_lian}
VERSION_KERNEL=${version_kernel}
EOF
```

- [ ] **步骤 5：运行相关测试确认通过**

运行：

```bash
bash Scripts/test_source_flavor.sh
bash Scripts/test_resolve_general_configs.sh
```

预期：

- `test_source_flavor: ok`
- `test_resolve_general_configs: ok`

- [ ] **步骤 6：提交**

```bash
git add .github/workflows/CORE-ALL.yml Scripts/ci_collect_source_metadata.sh
git commit -m "ci: pass source flavor through workflows"
```

### 任务 5：更新 README 与中文文档说明

**文件：**
- 修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/README.md`
- 修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/docs/superpowers/specs/2026-04-19-source-flavor-decoupling-design.md`
- 修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/docs/superpowers/plans/2026-04-19-source-flavor-decoupling.md`

- [ ] **步骤 1：把 README 中“FW3/FW4 决定源码”的暗示改掉**

```markdown
### GitHub Actions 源码与配置层说明

- `WRT_REPO_URL`：决定使用哪个上游源码
- `FW3` / `FW4`：决定功能配置层，不再隐含绑定特定源码
- `WRT_GENERAL_CONFIG`：决定基础配置组合，留空时按主配置文件自动解析
```

- [ ] **步骤 2：补一句 `source_flavor` 的说明**

```markdown
脚本内部会根据 `WRT_REPO_URL` 自动解析 `source_flavor=lean|VIKINGYFY|generic`，用于选择源码差异逻辑。
```

- [ ] **步骤 3：人工检查中文文档与注释语气保持一致**

运行：`sed -n '1,220p' README.md`

预期：源码选择说明与配置层说明不再互相混淆，新增说明为中文。

- [ ] **步骤 4：提交**

```bash
git add README.md docs/superpowers/specs/2026-04-19-source-flavor-decoupling-design.md docs/superpowers/plans/2026-04-19-source-flavor-decoupling.md
git commit -m "docs: clarify source flavor behavior"
```

### 任务 6：跑回归测试并整理结果

**文件：**
- 不新增文件
- 复核：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/*.sh`

- [ ] **步骤 1：执行与本次改动直接相关的测试**

运行：

```bash
bash Scripts/test_source_flavor.sh
bash Scripts/test_diy_config_structure.sh
bash Scripts/test_diy_config_package_manager.sh
bash Scripts/test_diy_config_apk_index_patch.sh
bash Scripts/test_packages_source_flavor.sh
bash Scripts/test_resolve_general_configs.sh
```

预期：全部输出 `ok`，且没有新的 shell 报错。

- [ ] **步骤 2：检查工作区状态**

运行：`git status --short`

预期：只剩本次改动文件，且不存在意外未跟踪输出文件。

- [ ] **步骤 3：整理验证摘要**

```text
- source_flavor 解析测试通过
- diy_config 结构边界测试通过
- apk/ipk 包管理器兼容测试通过
- Packages 风味入口测试通过
- 基础配置解析测试通过
```

- [ ] **步骤 4：最终提交**

```bash
git add Scripts .github/workflows README.md
git commit -m "refactor: decouple source flavor from config layers"
```

## 自检结果

- 规格覆盖：helper、`diy_config.sh`、`Packages.sh`、workflow、README、测试都已映射到任务。
- 文案检查：计划里没有后补说明、待办标记或延后实现这类描述。
- 命名一致性：统一使用 `source_flavor=lean|VIKINGYFY|generic`、`resolve_source_flavor`、`apply_VIKINGYFY_*`。
