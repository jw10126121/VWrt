# 多仓库架构设计

## 背景

当前 VWrt 项目在单仓库中编译多个设备的固件，GitHub Actions 缓存限制为每仓库 10GB。多设备共用缓存导致互相挤占，编译效率低下。

## 目标

1. 每个设备编译拥有独立的 10GB 缓存
2. 编译逻辑和设备配置分离，改一处即可
3. 新增设备只需创建新仓库，无需修改核心代码

## 架构

### 仓库结构

```
Linjw/ (GitHub Organization)
├── VWrt-Core/                          # 核心仓库
│   ├── Scripts/                        # 所有编译脚本（不变）
│   ├── Config/                         # 通用配置
│   │   ├── GENERAL.txt                 # lean 基线
│   │   └── GENERAL-VWRT.txt            # vwrt 基线（含 fw4）
│   └── .github/workflows/
│       └── build-core.yml              # 可复用编译工作流
│
├── CMIOT-AX18-NOWIFI/                  # 设备仓库
│   ├── Config/                         # 设备专属配置
│   │   ├── CMIOT-AX18-NOWIFI-FW3.txt  # lean fw3
│   │   └── CMIOT-AX18-NOWIFI-FW4-VWRT.txt  # vwrt fw4
│   └── .github/workflows/
│       └── build.yml                   # 触发编译
│
├── GL-MT6000-WIFI/
│   ├── Config/
│   │   ├── GL-MT6000-WIFI-FW3.txt
│   │   └── GL-MT6000-WIFI-FW4-VWRT.txt
│   └── .github/workflows/
│       └── build.yml
│
├── JD-AX1800PRO-WIFI/
│   ├── Config/
│   │   ├── JD-AX1800PRO-WIFI-FW3.txt
│   │   └── JD-AX1800PRO-WIFI-FW4-VWRT.txt
│   └── .github/workflows/
│       └── build.yml
│
└── JD-AX6600-WIFI/
    ├── Config/
    │   ├── JD-AX6600-WIFI-FW3.txt
    │   └── JD-AX6600-WIFI-FW4-VWRT.txt
    └── .github/workflows/
        └── build.yml
```

### 职责划分

| 仓库 | 内容 | 维护频率 |
|------|------|---------|
| VWrt-Core | 编译脚本、通用配置、工作流模板 | 编译逻辑变更时 |
| 设备仓库 | 设备配置、触发工作流 | 设备配置变更时 |

### 核心仓库 build-core.yml

可复用工作流，接受设备名和其他参数：

```yaml
on:
  workflow_call:
    inputs:
      WRT_DEVICE:
        required: true
        type: string
      SOURCE_TYPE:
        type: string
        default: 'auto'
      WRT_FIREWALL:
        type: string
        default: 'auto'
      WRT_USE_APK:
        type: string
        default: 'auto'
      WRT_OVERLAYS:
        type: string
        default: ''
      WRT_DEFAULT_LANIP:
        type: string
        default: '192.168.0.1'
      WRT_RELEASE_FIRMWARE:
        type: boolean
        default: true
```

### 设备仓库 build.yml

极简触发文件：

```yaml
name: Build
on:
  workflow_dispatch:
    inputs:
      WRT_DEVICE:
        description: '设备型号'
        type: choice
        options:
          - CMIOT-AX18-NOWIFI
        default: 'CMIOT-AX18-NOWIFI'
      WRT_SOURCE_HASH_INFO:
        description: '源码 commit hash'
        type: string
        default: ''
  schedule:
    - cron: '0 3 1 * *'

jobs:
  build:
    uses: Linjw/VWrt-Core/.github/workflows/build-core.yml@main
    with:
      WRT_DEVICE: ${{ inputs.WRT_DEVICE || 'CMIOT-AX18-NOWIFI' }}
      WRT_SOURCE_HASH_INFO: ${{ inputs.WRT_SOURCE_HASH_INFO || '' }}
    secrets: inherit
```

### 配置加载流程

```
1. 设备仓库 workflow 调用核心仓库 build-core.yml
2. build-core.yml checkout 核心仓库代码（Scripts/ + Config/G*.txt）
3. build-core.yml checkout 设备仓库代码到子目录（device-repo/Config/DEVICE-*.txt）
4. 构建步骤中将设备仓库的 Config/*.txt 复制到核心仓库的 Config/ 目录
5. export_config.sh 从合并后的 Config/ 查找配置（通用 + 设备）
6. 编译脚本正常执行
```

具体实现：build-core.yml 的编译步骤中，在运行 export_config.sh 之前，将设备仓库 checkout 到临时目录，并将其 Config/ 下的文件复制到工作目录的 Config/ 下。这样 export_config.sh 无需修改，直接在合并后的 Config/ 中查找。

### 缓存策略

每个设备仓库独立拥有 10GB 缓存：
- `CMIOT-AX18-NOWIFI` 仓库：CMIOT 设备的 toolchain + ccache
- `GL-MT6000-WIFI` 仓库：GL-MT6000 设备的 toolchain + ccache
- 互不干扰

### 新增设备流程

1. 在 Organization 下创建新仓库（如 `NEW-DEVICE-WIFI`）
2. 复制任意现有设备仓库的 `Config/` 和 `.github/workflows/build.yml`
3. 修改 `Config/` 中的设备配置文件
4. 修改 `build.yml` 中的设备名选项

无需修改核心仓库。

### 改编译逻辑流程

1. 只修改 VWrt-Core 仓库的 `Scripts/` 或 `Config/G*.txt`
2. 所有设备仓库下次编译自动使用新逻辑

无需修改设备仓库。

## 实施步骤

1. 创建 VWrt-Core 仓库，迁移 Scripts/ 和通用 Config/
2. 为每个设备创建独立仓库，迁移设备配置
3. 在核心仓库创建 build-core.yml 可复用工作流
4. 在设备仓库创建 build.yml 触发文件
5. 测试单个设备编译
6. 迁移剩余设备
7. 归档旧的 VWrt 仓库

## 风险和缓解

| 风险 | 缓解 |
|------|------|
| 核心仓库 breaking change 影响所有设备 | 设备仓库可 pin 到特定 tag |
| 跨仓库 checkout 增加编译时间 | 影响很小（几秒） |
| Secrets 管理分散 | 使用 Organization 级 secrets |
