# 配置参数化重构设计

## 背景

当前仓库的配置组织方式仍然带有明显的“最终文件名驱动”特征，例如：

- `IPQ60XX-NOWIFI-FW3.txt`
- `IPQ60XX-NOWIFI-FW4.txt`
- `GL-MT6000-WIFI-FW3.txt`
- `GL-MT6000-WIFI-FW4.txt`

这类文件同时承载了多个维度的信息：

1. 设备类型
2. 防火墙栈类型
3. 服务默认项
4. 部分包管理器或特殊功能差异

随着 `GENERAL.txt`、`GENERAL-SERVICE.txt`、`GENERAL-FW3.txt`、`GENERAL-FW4.txt` 的引入，机型配置文件里开始出现大量与基础层完全相同的重复项。虽然这些重复项可以靠人工注释清理，但根本问题不是“文件里有重复”，而是“文件职责切分仍然不清晰”。

本次重构的目标，是将配置组织方式改成“参数驱动的多层组合”，直接去掉旧的 `设备-FW` 组合文件。

## 目标

- 固定保留两层基础通用配置：`GENERAL.txt`、`GENERAL-SERVICE.txt`
- 将 FW3 / FW4 基础配置保留为可选的防火墙层
- 将设备配置改成纯设备差异层，不再带 `FW3/FW4` 后缀
- 将 `FRPS`、`APK`、`IPK` 等可选差异改成 overlay 层
- 通过脚本参数组合生成最终配置，而不是直接选最终文件名
- 允许同时叠加多个 overlay
- 明确 `APK` 和 `IPK` 为互斥 overlay，冲突时直接报错

## 非目标

- 保留旧的 `设备-FW3/FW4.txt` 文件结构做长期兼容
- 把所有已有配置文件一次性抽象成任意维度的通用模板系统
- 重写 OpenWrt 编译逻辑本身

## 目标目录结构

重构后建议的配置结构如下：

### 基础层

- `Config/GENERAL.txt`
- `Config/GENERAL-SERVICE.txt`

### 防火墙层

- `Config/GENERAL-FW3.txt`
- `Config/GENERAL-FW4.txt`

### 设备层

- `Config/devices/IPQ60XX-NOWIFI.txt`
- `Config/devices/GL-MT6000-WIFI.txt`
- 后续其他设备也统一放在 `Config/devices/`

### 自动设备叠加层

- `Config/device-overlays/IPQ60XX-NOWIFI-FW3.txt`
- `Config/device-overlays/IPQ60XX-NOWIFI-FW4.txt`
- `Config/device-overlays/GL-MT6000-WIFI-FW3.txt`
- `Config/device-overlays/GL-MT6000-WIFI-FW4.txt`

这一层不是用户手动选择的 overlay，而是在 `device + fw` 已确定后由脚本自动叠加的“设备栈差异层”。它用于承接某些同一设备在 `fw3/fw4` 下仍有差异、但又不适合放进 `GENERAL-FW3/FW4` 的配置。

### 覆盖层

- `Config/overlays/FRPS.txt`
- `Config/overlays/APK.txt`
- `Config/overlays/IPK.txt`

overlay 文件只表达“在已有组合基础上追加或覆盖的差异”，不再重复设备层和基础层配置。

## 组合规则

最终配置生成顺序固定为：

1. `GENERAL.txt`
2. `GENERAL-SERVICE.txt`
3. `GENERAL-FW3.txt` 或 `GENERAL-FW4.txt`
4. `devices/<device>.txt`
5. `device-overlays/<device>-<FW>.txt`，如果存在则自动叠加
6. `overlays/<name>.txt`，按参数顺序依次叠加

后面的层允许覆盖前面的层，因此 overlay 适合作为用户显式开启的可选差异。

## 脚本接口设计

导出脚本和 workflow 都改成参数驱动，不再直接接受最终配置文件名。

推荐接口：

```bash
bash Scripts/export_config.sh \
  --device IPQ60XX-NOWIFI \
  --fw fw3 \
  --overlay frps,apk \
  --output /tmp/IPQ60XX-NOWIFI-fw3-frps-apk.txt
```

参数语义：

- `--device`：设备名，映射到 `Config/devices/<device>.txt`
- `--fw`：`fw3` 或 `fw4`
- `--overlay`：逗号分隔 overlay 列表，可为空
- `--output`：输出路径

### overlay 规则

- 支持多个 overlay 同时叠加
- overlay 按传入顺序叠加
- `apk` 与 `ipk` 互斥
- 如果同时传入 `apk,ipk` 或 `ipk,apk`，脚本必须直接报错并停止

## 设备配置文件职责

设备文件只保留真正的设备差异：

- 目标平台 / 设备列表
- 无线驱动开关
- 某设备特有的包选择
- 与设备硬件能力直接相关的开关

设备文件中不应再重复以下几类内容：

- `GENERAL.txt` 已明确提供的通用基础项
- `GENERAL-SERVICE.txt` 已明确提供的服务默认项
- `GENERAL-FW3/FW4.txt` 已明确提供的防火墙栈项
- 仅属于用户可选功能的 overlay 项

如果某项差异只在“同一设备 + 不同 fw”之间出现，但并不适合放入通用 `GENERAL-FW3/FW4.txt`，则应放入自动设备叠加层，而不是重新塞回设备主文件。

## overlay 职责

overlay 只承担“显式可选差异”：

- `FRPS`：把普通默认的 `frpc=y / frps=m` 调整为 `frpc=m / frps=y` 或其它明确差异
- `APK`：将包管理器能力切换到 APK
- `IPK`：显式恢复 / 固化为 IPK

overlay 不应承担设备默认职责，也不应包含和设备无关的大量服务默认项。

## workflow 设计

workflow 输入应从当前的 `WRT_CONFIG` 转成独立参数：

- `WRT_DEVICE`
- `WRT_FIREWALL`
- `WRT_OVERLAYS`

示例：

- `WRT_DEVICE=IPQ60XX-NOWIFI`
- `WRT_FIREWALL=fw3`
- `WRT_OVERLAYS=frps,apk`

workflow 在生成 `.config` 时统一调用新的参数化导出脚本，不再把设备与防火墙绑进一个文件名里。

## 旧文件迁移策略

这次重构按“直接迁移、不保留旧文件兼容”处理：

- 删除旧的 `IPQ60XX-NOWIFI-FW3.txt` / `FW4.txt`
- 删除旧的 `GL-MT6000-WIFI-FW3.txt` / `FW4.txt`
- 设备差异迁移到 `Config/devices/`
- 可选差异迁移到 `Config/overlays/`

迁移完成后，所有脚本和 workflow 都不再依赖旧文件名模式。

## 测试计划

至少补齐以下验证：

1. 参数化导出脚本能正确生成：
   - `device + fw`
   - `device + fw + 单 overlay`
   - `device + fw + 多 overlay`
2. `apk` / `ipk` 同时出现时，脚本必须报错
3. 输出文件中的关键覆盖项顺序正确，后置 overlay 能覆盖前值
4. 设备层不再包含基础层完全相同的重复项

## 风险与控制

- 风险：直接删除旧文件会影响现有 workflow
  控制：同一批提交里一起改脚本与 workflow，避免出现中间态

- 风险：overlay 顺序导致结果不符合预期
  控制：固定左到右顺序并补顺序测试

- 风险：设备层迁移时遗漏某些原本写在 `FW3/FW4` 文件里的设备专属配置
  控制：迁移前先对旧文件做差异归类，再逐项落到设备层或 overlay 层

## 预期结果

重构完成后，配置组合将从“直接选择最终文件名”变成“传参数生成最终配置”：

- 通用基础总是加载
- FW 层按 `fw3/fw4` 选择
- 设备层按设备名选择
- overlay 按需叠加

这样可以从结构上解决当前设备文件中大量重复配置的问题，也为后续继续扩展 `FRPS/APK/IPK` 等可选差异提供稳定边界。
