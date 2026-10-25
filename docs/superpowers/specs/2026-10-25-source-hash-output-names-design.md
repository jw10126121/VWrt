# 编译产物文件名加入源码短 hash

## 目标

让编译后整理出的配置、说明、固件、Packages 目录及压缩包，以及 GitHub Actions 的 Artifact 和 Release 名称，都能直接标识本次使用的源码提交。

## 命名规则

现有输出前缀为：

```text
<源码风味>_<设备>_<防火墙>_<包管理器>_<FRP角色>_<开始时间>
```

调整为：

```text
<源码风味>_<源码短hash>_<设备>_<防火墙>_<包管理器>_<FRP角色>_<开始时间>
```

例如：

```text
lean_a1b2c3d_cmiot_ax18_fw4_ipk_frpc_D261025_T120000
```

短 hash 使用源码检出步骤产生的 Git 默认短 hash（`git log --pretty=%h`）。如果该变量未传入最终元数据脚本，则从完整 hash 取前 7 位；两者都为空时使用 `unknown`，保证前缀仍然可生成。

## 实现范围

- 在 `Scripts/ci_collect_final_metadata.sh` 集中生成带 hash 的 `OUTPUT_NAME_PREFIX`。
- 保持 `Scripts/ci_organize_outputs.sh`、Artifact 上传和 Release 发布继续复用该前缀，避免多处拼接。
- 更新已有元数据和产物整理测试的期望文件名，并增加完整 hash 兜底覆盖。

## 验证

- 元数据测试验证短 hash 位于源码风味之后。
- 元数据测试验证只有完整 hash 时仍能生成前缀。
- 产物整理测试验证配置、README、固件、Packages 目录和 ZIP 都继承带 hash 的前缀。
