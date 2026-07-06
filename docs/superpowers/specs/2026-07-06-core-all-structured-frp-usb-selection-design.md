# CORE-ALL 结构化 FRP 与 USB 选择设计

## 目标

把 `frp/usb` 从 `DEFAULT.yml` 里的 overlay 拼接逻辑中拆出来，改成和 `apk/ipk` 一样的结构化参数传递方式：

- `DEFAULT.yml` 负责解析 `auto` 与透传结构化输入
- `CORE-ALL.yml` 负责根据 FRP、USB、设备自动规则与手动 overlay 生成最终 `.config`
- `WRT_OVERLAYS` 保留为高级兜底输入，但不再承载常规的 `frp/usb` 选择

## 背景

当前链路里，`DEFAULT.yml` 会先把：

- `WRT_FRP_MODE`
- `WRT_USB_MODE`
- `WRT_OVERLAYS`

合成为一个 `WRT_OVERLAYS`，再传给 `CORE-ALL.yml`。而 `CORE-ALL.yml` 又会继续叠加设备自动 overlay，例如 `nowifi-ipq60xx`。

这带来两个问题：

1. 常规选择项和高级兜底输入混在一起，阅读 workflow 时很难看出谁在决定最终配置。
2. `DEFAULT.yml` 和 `CORE-ALL.yml` 都在参与“最终 overlay 组合”，责任边界不清晰，后续扩展时容易重复或遗漏。

## 范围

### 修改

- `.github/workflows/DEFAULT.yml`
- `.github/workflows/CORE-ALL.yml`
- `Scripts/local_menuconfig.sh`
- 相关 workflow / shell 测试

### 保持不变

- `Scripts/export_config.sh` 继续接收最终 `--overlay` CSV，并按现有方式叠加配置文件
- `Config/overlays/*.txt` 目录结构暂不迁移
- `WRT_OVERLAYS` 继续保留为高级手动追加入口

## 设计

### 1. DEFAULT 只解析，不合成 `frp/usb`

`DEFAULT.yml` 保留以下输入：

- `WRT_FRP_MODE`
  - `frpc` / `frps` / `frp` / `none`
- `WRT_USB_MODE`
  - `default` / `usb` / `nousb`
- `WRT_PACKAGE_MANAGER`
  - `auto` / `apk` / `ipk`
- `WRT_OVERLAYS`
  - 字符串，高级手动 overlay 兜底

`resolve` job 的职责调整为：

- 把 `WRT_FIREWALL=auto` 解析成最终 `fw3/fw4`
- 把 `WRT_PACKAGE_MANAGER=auto` 解析成最终 `apk/ipk`
- 输出用于 job name 的简洁 label
- 直接把 `WRT_FRP_MODE`、`WRT_USB_MODE`、`WRT_OVERLAYS` 透传给 `CORE-ALL.yml`

`DEFAULT.yml` 不再生成：

- `structured_overlays`
- `overlays`
- 由 `frp/usb` 推导出的 `overlay_label`

### 2. CORE-ALL 成为唯一的 overlay 组合器

`CORE-ALL.yml` 新增并消费结构化输入：

- `WRT_FRP_MODE`
- `WRT_USB_MODE`

在 `Check Config Values` 阶段统一生成“最终 overlay CSV”，生成顺序固定为：

1. 设备自动 overlay
   - 例如 `*-nowifi` 自动补全 `nowifi-ipq60xx`
2. FRP 结构化选择
   - `frpc` -> `frpc`
   - `frps` -> `frps`
   - `frp` -> `frp`
   - `none` -> 不追加
3. USB 结构化选择
   - `usb` -> `usb`
   - `nousb` -> `nousb`
   - `default` -> 不追加
4. 手动 `WRT_OVERLAYS`

然后：

- 用 `overlay_utils.sh` 统一做归一化与互斥组去重
- 把最终结果写回 `WRT_OVERLAYS`
- 仅把这个最终值传给 `export_config.sh`

这样 `CORE-ALL.yml` 成为唯一了解“本次编译最终用了哪些 overlay”的地方。

### 3. 包管理器继续独立处理

`apk/ipk` 仍然保留为独立的结构化输入，不再依赖 overlay 参与组合。

具体原则：

- `DEFAULT.yml` 继续把 `auto` 解析成真实包管理器，用于 job name 与传参
- `CORE-ALL.yml` 继续把 `WRT_PACKAGE_MANAGER` 作为独立变量传给 `diy_config.sh`
- overlay 组合逻辑不再关注 `apk/ipk`

这样 FRP、USB、包管理器各自职责清晰：

- FRP、USB：决定额外配置叠加
- 包管理器：决定构建与系统设置行为

### 4. local_menuconfig 同步对齐

`Scripts/local_menuconfig.sh` 需要与 CI 保持同一套参数语义，避免“本地可复现、CI 不一致”。

调整方向：

- 新增或启用：
  - `WRT_FRP_MODE`
  - `WRT_USB_MODE`
  - `WRT_PACKAGE_MANAGER`
- `WRT_OVERLAYS` 只保留为高级手动 overlay
- 本地入口按与 `CORE-ALL.yml` 相同的顺序合成最终 overlay CSV，再调用 `export_config.sh`

这样本地 menuconfig 和 GitHub Actions 对同一组参数会生成一致的 `.config`。

## 数据流

### DEFAULT -> CORE-ALL

`DEFAULT.yml` 传递：

- `WRT_DEVICE`
- 解析后的 `WRT_FIREWALL`
- 解析后的 `WRT_PACKAGE_MANAGER`
- 原始 `WRT_FRP_MODE`
- 原始 `WRT_USB_MODE`
- 原始 `WRT_OVERLAYS`

### CORE-ALL -> export_config.sh

`CORE-ALL.yml` 内部生成：

- `AUTO_OVERLAYS`
- `FRP_OVERLAYS`
- `USB_OVERLAYS`
- `FINAL_WRT_OVERLAYS`

最终只调用一次：

```bash
bash "$GITHUB_WORKSPACE/$WRT_DIR_SCRIPTS/export_config.sh" \
  --config-dir "$GITHUB_WORKSPACE/$WRT_DIR_CONFIGS" \
  --device "$WRT_DEVICE" \
  --fw "$WRT_FIREWALL" \
  --output ".config" \
  --overlay "$WRT_OVERLAYS"
```

`export_config.sh` 只负责消费最终结果，不参与结构化业务规则判断。

## 风险与约束

### 风险 1：旧测试仍假设 DEFAULT 负责 overlay 合成

现有测试里已经有断言要求 `DEFAULT.yml` 暴露 `overlays` 输出并将其传给 `CORE-ALL.yml`。这些测试需要改为：

- `DEFAULT.yml` 暴露并透传结构化 FRP/USB 输入
- `CORE-ALL.yml` 负责最终 overlay 合成

### 风险 2：本地入口与 CI 行为分叉

如果只改 workflow，不改 `local_menuconfig.sh`，本地还是会沿用旧规则，把 `frp/usb` 直接塞进 `WRT_OVERLAYS`。这会让“同样参数”的 `.config` 在两端不一致，因此必须同步。

### 风险 3：job name 与真实编译条件不同步

`DEFAULT.yml` 过去把 `WRT_OVERLAYS` 作为展示字段的一部分。调整后，job 名应优先展示结构化值：

- `frpc/frps/frp/none`
- `usb/nousb/default`
- `apk/ipk`

而不是继续依赖合成后的 overlay 字符串。

## 测试建议

至少覆盖以下场景：

1. `DEFAULT.yml`
   - 不再拼接 `structured_overlays`
   - 直接把 `WRT_FRP_MODE`、`WRT_USB_MODE` 传给 `CORE-ALL.yml`
   - 仍保留 `WRT_OVERLAYS` 作为高级输入

2. `CORE-ALL.yml`
   - `nowifi + frpc + usb + 手动 overlays` 能按固定顺序合成最终 overlay CSV
   - `none + default + 空手动 overlays` 时只保留设备自动 overlay
   - `frp`、`frps`、`nousb` 等分支都能进入最终结果

3. `local_menuconfig.sh`
   - 与 `CORE-ALL.yml` 使用同一组结构化参数
   - 不再通过 `apk` overlay 决定包管理器

4. `export_config.sh`
   - 现有 overlay 顺序和上下文导出测试继续通过

## 预期结果

- `DEFAULT.yml` 更轻，只负责输入解析和透传
- `CORE-ALL.yml` 成为唯一的配置组合入口
- `frp/usb` 不再伪装成“用户手写 overlay”
- `WRT_OVERLAYS` 回到“高级兜底输入”的本意
- 本地 menuconfig 与 CI 的 `.config` 生成规则保持一致
