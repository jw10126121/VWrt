# GENERAL 配置分层设计

## 目标

将当前共享的 OpenWrt 基础配置拆成分层文件，形成下面的结构：

- `Config/GENERAL.txt`：只保留真正的全局基础层
- `Config/GENERAL-SERVICE.txt`：承载不强绑定 FW3/FW4 的共享服务与页面默认项
- `Config/GENERAL-FW3.txt`：承载纯 FW3 / iptables 栈与明确绑定 FW3 的默认项
- `Config/GENERAL-FW4.txt`：承载纯 FW4 / nftables 栈与明确绑定 FW4 的默认项
- 各机型配置：只关注目标平台、硬件差异和机型级覆盖项

同时修改 GitHub Actions workflow，使其能够按顺序合并多个基础配置文件，最后再拼接机型配置文件。

## 范围

本次改动包括：

- 收敛 `Config/GENERAL.txt`
- 新增 `Config/GENERAL-SERVICE.txt`
- 新增 `Config/GENERAL-FW3.txt`
- 新增 `Config/GENERAL-FW4.txt`
- 修改 workflow 输入与合并逻辑，使其支持多个基础配置文件
- 补一个最小化验证脚本或测试，验证多基础配置的合并顺序

本次改动不包括：

- 继续拆出 `GENERAL-USB.txt`、`GENERAL-SERVICE.txt` 等更多层
- 为了分层而大规模重写所有机型配置
- 修改 `diy_config.sh` 的包管理器切换逻辑

## 文件职责

### `Config/GENERAL.txt`

只保留真正适合作为全仓库基础层的内容：

- 构建行为与镜像生成相关开关
- 风险较低的通用工具与运行时依赖
- 少量 LuCI / 运行时基础支持包
- 与具体机型无关、但整体系统普遍需要的基础依赖

不再保留：

- FW3 策略与服务组合
- 明显属于某一类设备的硬件支持包
- 只是被上层功能顺带用到、但不属于“基础层”的包

补充说明：

- 默认情况下，USB / 外设扩展能力原本不建议放进 `GENERAL.txt`
- 但如果仓库维护者明确希望“所有常用固件都默认带 USB / 4G 外设支持”，则允许把整组 USB 能力保留在 `GENERAL.txt`，前提是用独立分组和清晰注释标明这是“运维与外设扩展基线”
- 同理，如果仓库主力目标长期集中在现代多网口路由器，也允许把 `kmod-dsa` 一类交换机 / 网口架构支持保留在 `GENERAL.txt`，但应单独分组说明原因
- `mmc-utils`、`nand-utils` 这类存储维护工具也可以保留在 `GENERAL.txt`，前提是明确标注其用途属于“维护基线”，而不是系统运行必需依赖
- `kmod-mtd-rw` 不建议放进 `GENERAL.txt`：它更像高风险维护能力，是否启用主要取决于维护策略，而不是机型共性
- `cpufreq` 不建议仅凭“看起来常用”就放进 `GENERAL.txt`：优先由 `luci-app-cpufreq` 等上层功能带出，只有在明确平台支持且需要显式固定时再考虑上提

### `Config/GENERAL-SERVICE.txt`

承载不强绑定 FW3/FW4 的共享服务与页面默认项，例如：

- 主题与界面默认项
- `ttyd`、`filetransfer`、`upnp`、`ddns`、`ddns-go`
- `frpc/frps`
- `watchcat`
- `onliner`、`ramfree`
- `sqm`、`socat`

### `Config/GENERAL-FW3.txt`

只承载 FW3 / iptables 栈与明确绑定 FW3 的默认项，包括：

- `firewall4=n`、`firewall=y`、`iptables*`
- FullCone 相关包
- 明确在 FW3 侧启用或关闭的代理默认项，例如 `homeproxy`、`ssr-plus`

### `Config/GENERAL-FW4.txt`

只承载 FW4 / nftables 栈与明确绑定 FW4 的默认项，包括：

- `firewall4=y`、`firewall=n`、关闭 `iptables*`
- `kmod-nf-*`、`kmod-nft-*`、`nftables` 等 FW4 栈核心模块
- 明确在 FW4 侧启用或关闭的代理默认项，例如 `homeproxy`、`ssr-plus`

补充说明：

- `openclash` 虽然在 FW3 与 FW4 配置里都常见，但它不属于防火墙栈本身
- 由于 FW3 / FW4 配置中对 `openclash` 的默认构建形式不同，当前更适合继续留在机型配置层决定 `y` / `m`

如果某个机型仍然需要把某个共享项从 `y` 改成 `m` 或反过来，仍然允许在机型配置里覆盖。原因是 OpenWrt 配置是后写覆盖前写，机型配置依然最后拼接。

### 机型配置

各机型配置主要负责：

- target / subtarget / device 选择
- Wi-Fi 开关与硬件固件
- 机型特有的软件包选择
- 对共享 FW3 默认项的明确覆盖

## Workflow 设计

### 输入格式

继续使用 `WRT_GENERAL_CONFIG`，但允许它传入一个或多个配置文件名，文件名之间用空格分隔。

示例：

- `GENERAL.txt`
- `GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW3.txt`
- `GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW4.txt`

不引入逗号或其他新语法，这样现有单文件调用方式仍然兼容。

### 合并顺序

workflow 组装 `.config` 时采用以下顺序：

1. 按 `WRT_GENERAL_CONFIG` 中列出的顺序，从左到右依次拼接基础配置
2. 最后拼接机型配置 `WRT_CONFIG`

这样可以保持现有覆盖逻辑不变：

- 前面的基础层提供默认值
- 后面的基础层进一步细化共享策略
- 机型配置始终最后生效

### Workflow 改动点

更新 workflow 入口和共享 workflow，使其满足：

- 输入说明明确写出支持多基础配置文件，并支持留空自动选择
- 自动按 `WRT_CONFIG` 是否为 `-V` 选择 FW3 或 FW4 的基础配置组合
- 合并步骤改成遍历文件名，而不是只拼一个 `WRT_GENERAL_CONFIG`

涉及文件：

- `.github/workflows/main.yml`
- `.github/workflows/DEFAULT.yml`
- `.github/workflows/CUSTOM.yml`
- `.github/workflows/CORE-ALL.yml`

## 验证方案

增加一个最小化 shell 测试，验证：

- 多个基础配置文件会按声明顺序读取
- 后面的基础配置可以覆盖前面的基础配置
- 机型配置可以覆盖前面所有基础层

验证应保持轻量，只做仓库级合并逻辑校验，不做完整 workflow 集成测试。

## 风险

- 如果 `WRT_GENERAL_CONFIG` 里出现异常空白字符，shell 分词可能产生意外行为。实现时应使用简单的 `for` 循环按空格分隔文件名，并在 `cat` 时对路径加引号。
- 如果把太多包搬进 `GENERAL-FW3.txt`，可能掩盖掉真实存在的机型差异，因此只上提高置信度的共享项。
- 如果把不完全同值的共享服务强行塞进 `GENERAL-SERVICE.txt`，可能丢失不同栈或不同机型对 `y/m` 的差异控制。
- 有些包虽然在多个机型里重复出现，但 `y/m` 不一致，这类项要允许机型层覆盖，不能在共享层里强行定死。

## 建议实施顺序

1. 收敛 `Config/GENERAL.txt`
2. 新增 `Config/GENERAL-FW3.txt`
3. 修改 workflow 默认值与合并逻辑
4. 增加合并验证脚本或测试
5. 回归检查单文件输入仍然兼容
