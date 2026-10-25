# apk-tools 补丁集成设计

## 目标

将参考项目 `OpenWrt-Actions/Scripts/apk-tools.sh` 集成到 VWrt，使 APK 构建生成的固件默认允许安装未受信任的 APK，同时保留脚本的独立复用能力。该补丁只影响 APK 模式，不改变 IPK 构建。

## 方案

新增 `Scripts/apk-tools.sh`，使用 `GITHUB_WORKSPACE/wrt` 作为默认源码路径，并支持 `OPENWRT_PATH` 覆盖。脚本在 `package/system/apk/patches` 创建 `0101-allow-untrusted-by-default.patch`，目录和文件均使用 `mkdir -p`/覆盖写入，重复运行结果一致。补丁将 apk-tools `apk_ctx_prepare` 中的条件信任设置改为无条件启用 `trust.allow_untrusted`。

在 `.github/workflows/CORE-ALL.yml` 的源码克隆和包管理器解析完成后增加一个步骤：仅当 `WRT_PACKAGE_MANAGER=apk` 时调用该脚本；IPK 模式记录跳过日志。放在 DIY Feeds、Update Feeds 之前，确保后续源码包编译使用补丁。

## 错误处理与兼容性

脚本使用 `set -e`，无法创建目录或补丁时立即失败，避免构建继续使用未修补的 apk-tools。目标源码目录不存在时由 `mkdir -p` 创建补丁目录；源码包在后续构建阶段决定是否实际消费该补丁。脚本不执行网络访问、不修改 `.config`，不依赖 Bash 专属语法。

## 验证

新增 `Scripts/tests/test_apk_tools.sh`，在临时 `OPENWRT_PATH` 下执行脚本并验证：补丁路径、关键补丁行、重复执行幂等性，以及非 APK workflow 分支不会调用脚本。运行该测试和现有与包管理器相关的回归测试，并用 `bash -n` 检查新增脚本。

## 范围边界

现有 `test_diy_config_apk_index_patch.sh` 涉及的空 feed 索引逻辑与 apk-tools 信任补丁独立，本次不实现该测试对应的缺失函数。
