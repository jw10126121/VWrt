# Device FW4 Config Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the existing IPQ60xx-family device configs into independent `FW3` / `FW4` main files, add `JD-AX6600-WIFI`, and expose every configured manual-build device through `DEFAULT.yml` and `CACHE-BENCH.yml`.

**Architecture:** Keep `Scripts/export_config.sh` unchanged and rely on its existing direct-`-FW4.txt` precedence. Add test coverage first for the new device export, split-device `FW4` package intent, and manual workflow device options; then migrate the configs, delete empty `FW4` overlays, and add a regression test that locks in direct `FW4` resolution.

**Tech Stack:** OpenWrt `.config` fragments, GitHub Actions YAML, POSIX shell tests, repository README maintenance

---

### Task 1: Add A Red Test For Manual Device Options

**Files:**
- Create: `Scripts/tests/test_workflow_manual_device_options.sh`

- [ ] **Step 1: Write the failing manual workflow options test**

```bash
#!/bin/bash

set -eu

default_workflow=".github/workflows/DEFAULT.yml"
cache_bench_workflow=".github/workflows/CACHE-BENCH.yml"

assert_contains() {
	local file_path="$1"
	local pattern="$2"
	local message="$3"

	if ! grep -Fq "$pattern" "$file_path"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		exit 1
	fi
}

for device in \
	CMIOT-AX18-NOWIFI \
	CMIOT-AX18-NOWIFI-MINI \
	IPQ60XX-NOWIFI \
	IPQ60XX-NOWIFI-MINI \
	JD-AX1800PRO-WIFI \
	JD-AX1800PRO-NOWIFI \
	JD-AX6600-WIFI \
	GL-MT6000-WIFI \
	GL-MT6000-WIFI-MINI \
	MIR3G-WIFI-MINI
do
	assert_contains "$default_workflow" "$device" "DEFAULT should expose ${device} in manual choices"
	assert_contains "$cache_bench_workflow" "$device" "CACHE-BENCH should expose ${device} in manual choices"
done

echo "test_workflow_manual_device_options: ok"
```

- [ ] **Step 2: Run the new workflow-options test to verify it fails**

Run:

```bash
rtk bash Scripts/tests/test_workflow_manual_device_options.sh
```

Expected: FAIL, because `DEFAULT.yml` and `CACHE-BENCH.yml` do not yet list `IPQ60XX-*`, `JD-AX1800PRO-NOWIFI`, or `JD-AX6600-WIFI`.

- [ ] **Step 3: Commit the red test**

```bash
git add Scripts/tests/test_workflow_manual_device_options.sh
git commit -m "test: add workflow manual device options coverage"
```

### Task 2: Add `JD-AX6600-WIFI` Export Coverage First

**Files:**
- Create: `Scripts/tests/test_jd_ax6600_wifi_export.sh`

- [ ] **Step 1: Write the failing `JD-AX6600-WIFI` export test**

```bash
#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

FW3_OUT="$TMPDIR/jd-ax6600-fw3.txt"
FW4_OUT="$TMPDIR/jd-ax6600-fw4.txt"

bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "JD-AX6600-WIFI" \
	--fw "fw3" \
	--output "$FW3_OUT" >/dev/null

bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "JD-AX6600-WIFI" \
	--fw "fw4" \
	--output "$FW4_OUT" >/dev/null

grep -n '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02=y'
grep -n '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=n'
grep -n '^CONFIG_PACKAGE_kmod-ath11k=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_kmod-ath11k=y'
grep -n '^CONFIG_PACKAGE_ath11k-firmware-ipq6018=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_ath11k-firmware-ipq6018=y'
grep -n '^CONFIG_PACKAGE_wpad-openssl=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wpad-openssl=y'

grep -n '^CONFIG_PACKAGE_firewall4=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_firewall4=y'
grep -n '^CONFIG_PACKAGE_firewall=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_firewall=n'
grep -n '^CONFIG_PACKAGE_luci-app-homeproxy=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-homeproxy=y'
grep -n '^CONFIG_PACKAGE_luci-app-ssr-plus=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-ssr-plus=n'

if grep -n '^CONFIG_PACKAGE_ipq-wifi-jdcloud_re-cs-02=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_ipq-wifi-jdcloud_re-cs-02=y'; then
	:
else
	echo "JD-AX6600-WIFI should enable the jdcloud_re-cs-02 board data package" >&2
	exit 1
fi

echo "test_jd_ax6600_wifi_export: ok"
```

- [ ] **Step 2: Run the `JD-AX6600-WIFI` export test and confirm it fails**

Run:

```bash
rtk bash Scripts/tests/test_jd_ax6600_wifi_export.sh
```

Expected: FAIL, because `Config/JD-AX6600-WIFI-FW3.txt` and `Config/JD-AX6600-WIFI-FW4.txt` do not exist yet.

- [ ] **Step 3: Commit the new export test**

```bash
git add Scripts/tests/test_jd_ax6600_wifi_export.sh
git commit -m "test: add jd ax6600 export coverage"
```

### Task 3: Add A Red Regression Test For Split-Device `FW4` Exports

**Files:**
- Create: `Scripts/tests/test_split_device_fw4_exports.sh`

- [ ] **Step 1: Write the split-device `FW4` regression test**

```bash
#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

assert_fw4_core() {
	local device="$1"
	local out_file="$TMPDIR/${device}.txt"

	bash "$EXPORT_SCRIPT" \
		--config-dir "$SCRIPT_DIR/../Config" \
		--device "$device" \
		--fw "fw4" \
		--output "$out_file" >/dev/null

	grep -n '^CONFIG_PACKAGE_firewall4=' "$out_file" | tail -n 1 | grep -q 'CONFIG_PACKAGE_firewall4=y'
	grep -n '^CONFIG_PACKAGE_firewall=' "$out_file" | tail -n 1 | grep -q 'CONFIG_PACKAGE_firewall=n'
	grep -n '^CONFIG_PACKAGE_iptables=' "$out_file" | tail -n 1 | grep -q 'CONFIG_PACKAGE_iptables=n'
	grep -n '^CONFIG_PACKAGE_nftables=' "$out_file" | tail -n 1 | grep -q 'CONFIG_PACKAGE_nftables=y'
	grep -n '^CONFIG_PACKAGE_luci-app-homeproxy=' "$out_file" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-homeproxy=y'
	grep -n '^CONFIG_PACKAGE_luci-app-turboacc=' "$out_file" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-turboacc=n'
	grep -n '^CONFIG_PACKAGE_luci-app-ssr-plus=' "$out_file" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-ssr-plus=n'
}

for device in \
	CMIOT-AX18-NOWIFI \
	CMIOT-AX18-NOWIFI-MINI \
	IPQ60XX-NOWIFI \
	IPQ60XX-NOWIFI-MINI \
	JD-AX1800PRO-WIFI \
	JD-AX1800PRO-NOWIFI
do
	assert_fw4_core "$device"
done

echo "test_split_device_fw4_exports: ok"
```

- [ ] **Step 2: Run the new split-device regression test and confirm it fails**

Run:

```bash
rtk bash Scripts/tests/test_split_device_fw4_exports.sh
```

Expected: FAIL, because the six split-device `-FW4.txt` files do not exist yet and `FW4` exports still come from embedded blocks.

- [ ] **Step 3: Re-run the existing `CMIOT-AX18` `FW4` package test and confirm it is red**

Run:

```bash
rtk bash Scripts/tests/test_cmiot_ax18_fw4_packages.sh
```

Expected: FAIL, because `CMIOT-AX18-NOWIFI` still exports `luci-app-ssr-plus=m` in `FW4`.

- [ ] **Step 4: Commit the new red regression test**

```bash
git add Scripts/tests/test_split_device_fw4_exports.sh
git commit -m "test: add split device fw4 export regression"
```

### Task 4: Add `JD-AX6600-WIFI` Configs

**Files:**
- Create: `Config/JD-AX6600-WIFI-FW3.txt`
- Create: `Config/JD-AX6600-WIFI-FW4.txt`

- [ ] **Step 1: Create `Config/JD-AX6600-WIFI-FW3.txt` from the AX1800 Pro Wi-Fi template**

Start from `Config/JD-AX1800PRO-WIFI-FW3.txt`, then replace the device-selection and board-data block with:

```text
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq60xx=y
CONFIG_TARGET_MULTI_PROFILE=y

CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_cmiot_ax18=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_glinet_gl-ax1800=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_glinet_gl-axt1800=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02=y
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-07=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_linksys_mr7350=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_qihoo_360v6=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_redmi_ax5-jdcloud=n
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_xiaomi_rm1800=n

CONFIG_PACKAGE_kmod-ath11k=y
CONFIG_PACKAGE_kmod-ath11k-ahb=y
CONFIG_PACKAGE_kmod-ath11k-pci=n
CONFIG_PACKAGE_ath11k-firmware-ipq6018=y
CONFIG_PACKAGE_ath11k-firmware-qcn9074=n
CONFIG_PACKAGE_wpad-openssl=y
CONFIG_PACKAGE_hostapd-common=y
CONFIG_PACKAGE_ipq-wifi-jdcloud_re-cs-02=y
```

- [ ] **Step 2: Create `Config/JD-AX6600-WIFI-FW4.txt`**

Copy `Config/JD-AX6600-WIFI-FW3.txt`, then replace the firewall/accelerator/proxy block with:

```text
CONFIG_PACKAGE_firewall4=y
CONFIG_PACKAGE_firewall=n
CONFIG_PACKAGE_iptables=n
CONFIG_PACKAGE_ip6tables=n
CONFIG_PACKAGE_ip6tables-extra=n
CONFIG_PACKAGE_ip6tables-mod-nat=n
CONFIG_PACKAGE_kmod-ipt-fullconenat=n
CONFIG_PACKAGE_iptables-mod-fullconenat=n
CONFIG_PACKAGE_kmod-nf-conntrack=y
CONFIG_PACKAGE_kmod-nf-conntrack-netlink=y
CONFIG_PACKAGE_kmod-nf-conntrack6=y
CONFIG_PACKAGE_nftables=y
CONFIG_PACKAGE_kmod-nft-core=y
CONFIG_PACKAGE_kmod-nft-nat=y
CONFIG_PACKAGE_kmod-nft-offload=y
CONFIG_PACKAGE_kmod-nft-fullcone=y
CONFIG_PACKAGE_luci-app-turboacc=n
CONFIG_PACKAGE_luci-i18n-turboacc-zh-cn=n
CONFIG_PACKAGE_luci-app-adguardhome=n
CONFIG_PACKAGE_luci-i18n-adguardhome-zh-cn=n
CONFIG_PACKAGE_luci-app-adguardhome_INCLUDE_binary=n
CONFIG_PACKAGE_luci-app-homeproxy=y
CONFIG_PACKAGE_luci-app-ssr-plus=n
CONFIG_PACKAGE_luci-i18n-ssr-plus-zh-cn=n
```

- [ ] **Step 3: Run the new `JD-AX6600-WIFI` export test**

Run:

```bash
rtk bash Scripts/tests/test_jd_ax6600_wifi_export.sh
```

Expected: PASS with `test_jd_ax6600_wifi_export: ok`

- [ ] **Step 4: Commit the new `JD-AX6600-WIFI` configs**

```bash
git add Config/JD-AX6600-WIFI-FW3.txt Config/JD-AX6600-WIFI-FW4.txt
git commit -m "feat: add jd ax6600 wifi configs"
```

### Task 5: Split The Six Existing Devices Into Independent `FW4` Main Files

**Files:**
- Modify: `Config/CMIOT-AX18-NOWIFI-FW3.txt`
- Create: `Config/CMIOT-AX18-NOWIFI-FW4.txt`
- Modify: `Config/CMIOT-AX18-NOWIFI-MINI-FW3.txt`
- Create: `Config/CMIOT-AX18-NOWIFI-MINI-FW4.txt`
- Modify: `Config/IPQ60XX-NOWIFI-FW3.txt`
- Create: `Config/IPQ60XX-NOWIFI-FW4.txt`
- Modify: `Config/IPQ60XX-NOWIFI-MINI-FW3.txt`
- Create: `Config/IPQ60XX-NOWIFI-MINI-FW4.txt`
- Modify: `Config/JD-AX1800PRO-WIFI-FW3.txt`
- Create: `Config/JD-AX1800PRO-WIFI-FW4.txt`
- Modify: `Config/JD-AX1800PRO-NOWIFI-FW3.txt`
- Create: `Config/JD-AX1800PRO-NOWIFI-FW4.txt`
- Delete: `Config/device-overlays/CMIOT-AX18-NOWIFI-FW4.txt`
- Delete: `Config/device-overlays/IPQ60XX-NOWIFI-MINI-FW4.txt`

- [ ] **Step 1: For each existing `-FW3.txt`, create a sibling `-FW4.txt` and delete the embedded `FW4` block from the `FW3` file**

Use this migration rule for each pair:

```text
1. Copy the existing <DEVICE>-FW3.txt to <DEVICE>-FW4.txt
2. In <DEVICE>-FW4.txt, keep all service/target/hardware sections intact
3. In <DEVICE>-FW4.txt, replace the old embedded FW3 firewall block with the former uncommented FW4 values
4. In <DEVICE>-FW4.txt, normalize SSR Plus to:
   CONFIG_PACKAGE_luci-app-ssr-plus=n
   CONFIG_PACKAGE_luci-i18n-ssr-plus-zh-cn=n
5. In <DEVICE>-FW3.txt, delete the full "# >>> FW4-BEGIN" ... "# <<< FW4-END" block
```

- [ ] **Step 2: Keep the `JD-AX1800PRO-WIFI` / `JD-AX1800PRO-NOWIFI` hardware blocks unchanged between `FW3` and `FW4`**

The Wi-Fi / NOWIFI tail blocks should remain identical to today, for example the Wi-Fi profile tail must still include:

```text
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=y
CONFIG_PACKAGE_kmod-ath11k=y
CONFIG_PACKAGE_kmod-ath11k-ahb=y
CONFIG_PACKAGE_ath11k-firmware-ipq6018=y
CONFIG_PACKAGE_wpad-openssl=y
CONFIG_PACKAGE_hostapd-common=y
CONFIG_PACKAGE_ipq-wifi-jdcloud_ax1800pro=y
```

and the NOWIFI tail must still include:

```text
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=y
CONFIG_PACKAGE_kmod-ath11k=n
CONFIG_PACKAGE_kmod-ath11k-ahb=n
CONFIG_PACKAGE_ath11k-firmware-ipq6018=n
CONFIG_PACKAGE_wpad-openssl=n
CONFIG_PACKAGE_hostapd-common=n
```

- [ ] **Step 3: Delete the empty `FW4` device overlay placeholders**

Delete:

```text
Config/device-overlays/CMIOT-AX18-NOWIFI-FW4.txt
Config/device-overlays/IPQ60XX-NOWIFI-MINI-FW4.txt
```

- [ ] **Step 4: Re-run the split-device `FW4` regression test**

Run:

```bash
rtk bash Scripts/tests/test_split_device_fw4_exports.sh
```

Expected: PASS with `test_split_device_fw4_exports: ok`

- [ ] **Step 5: Re-run the existing `CMIOT-AX18` `FW4` package test**

Run:

```bash
rtk bash Scripts/tests/test_cmiot_ax18_fw4_packages.sh
```

Expected: PASS with `test_cmiot_ax18_fw4_packages: ok`

- [ ] **Step 6: Re-run the `JD-AX1800PRO-WIFI` export test**

Run:

```bash
rtk bash Scripts/tests/test_ipq60xx_ax1800pro_wifi_overlay.sh
```

Expected: PASS with `test_jd_ax1800pro_wifi_export: ok`

- [ ] **Step 7: Commit the config split**

```bash
git add \
	Config/CMIOT-AX18-NOWIFI-FW3.txt \
	Config/CMIOT-AX18-NOWIFI-FW4.txt \
	Config/CMIOT-AX18-NOWIFI-MINI-FW3.txt \
	Config/CMIOT-AX18-NOWIFI-MINI-FW4.txt \
	Config/IPQ60XX-NOWIFI-FW3.txt \
	Config/IPQ60XX-NOWIFI-FW4.txt \
	Config/IPQ60XX-NOWIFI-MINI-FW3.txt \
	Config/IPQ60XX-NOWIFI-MINI-FW4.txt \
	Config/JD-AX1800PRO-WIFI-FW3.txt \
	Config/JD-AX1800PRO-WIFI-FW4.txt \
	Config/JD-AX1800PRO-NOWIFI-FW3.txt \
	Config/JD-AX1800PRO-NOWIFI-FW4.txt \
	Config/device-overlays/CMIOT-AX18-NOWIFI-FW4.txt \
	Config/device-overlays/IPQ60XX-NOWIFI-MINI-FW4.txt
git commit -m "refactor: split device fw4 configs into dedicated files"
```

### Task 6: Add A Direct-`FW4` Resolution Regression Test After The Split

**Files:**
- Create: `Scripts/tests/test_export_config_prefers_direct_fw4_file.sh`

- [ ] **Step 1: Add the direct-`FW4` regression test**

```bash
#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$TMPDIR/device-overlays"

cat > "$TMPDIR/GENERAL.txt" <<'EOF'
CONFIG_GENERAL_MARKER=y
EOF

cat > "$TMPDIR/DEVICE-A-FW3.txt" <<'EOF'
CONFIG_FROM_FW3=y
# >>> FW3-BEGIN
CONFIG_STACK=fw3
# <<< FW3-END
# >>> FW4-BEGIN
# CONFIG_STACK=fw4-from-embedded
# <<< FW4-END
EOF

cat > "$TMPDIR/DEVICE-A-FW4.txt" <<'EOF'
CONFIG_FROM_FW4_FILE=y
CONFIG_STACK=fw4-from-direct-file
EOF

OUT_FILE="$TMPDIR/fw4.txt"

bash "$EXPORT_SCRIPT" \
	--config-dir "$TMPDIR" \
	--device "DEVICE-A" \
	--fw "fw4" \
	--output "$OUT_FILE" >/dev/null

grep -q '^CONFIG_GENERAL_MARKER=y$' "$OUT_FILE"
grep -q '^CONFIG_FROM_FW4_FILE=y$' "$OUT_FILE"
grep -q '^CONFIG_STACK=fw4-from-direct-file$' "$OUT_FILE"

if grep -q '^CONFIG_FROM_FW3=y$' "$OUT_FILE"; then
	echo "fw4 export should prefer DEVICE-A-FW4.txt over DEVICE-A-FW3.txt" >&2
	exit 1
fi

if grep -q '^CONFIG_STACK=fw4-from-embedded$' "$OUT_FILE"; then
	echo "fw4 export should not fall back to the embedded FW4 block when DEVICE-A-FW4.txt exists" >&2
	exit 1
fi

echo "test_export_config_prefers_direct_fw4_file: ok"
```

- [ ] **Step 2: Run the direct-`FW4` regression test**

Run:

```bash
rtk bash Scripts/tests/test_export_config_prefers_direct_fw4_file.sh
```

Expected: PASS with `test_export_config_prefers_direct_fw4_file: ok`

- [ ] **Step 3: Commit the direct-`FW4` regression test**

```bash
git add Scripts/tests/test_export_config_prefers_direct_fw4_file.sh
git commit -m "test: lock direct fw4 config resolution"
```

### Task 7: Expose All Manual-Build Devices Through `DEFAULT`, `CACHE-BENCH`, And `README`

**Files:**
- Modify: `.github/workflows/DEFAULT.yml`
- Modify: `.github/workflows/CACHE-BENCH.yml`
- Modify: `README.md`

- [ ] **Step 1: Expand `DEFAULT.yml` manual `WRT_DEVICE` choices**

Replace the `options:` block under `workflow_dispatch.inputs.WRT_DEVICE` with:

```yaml
        options:
          - CMIOT-AX18-NOWIFI
          - CMIOT-AX18-NOWIFI-MINI
          - IPQ60XX-NOWIFI
          - IPQ60XX-NOWIFI-MINI
          - JD-AX1800PRO-WIFI
          - JD-AX1800PRO-NOWIFI
          - JD-AX6600-WIFI
          - GL-MT6000-WIFI
          - GL-MT6000-WIFI-MINI
          - MIR3G-WIFI-MINI
```

- [ ] **Step 2: Expand `CACHE-BENCH.yml` manual `WRT_DEVICE` choices to the same set**

Use the exact same list under `workflow_dispatch.inputs.WRT_DEVICE.options`.

- [ ] **Step 3: Update `README.md` support targets and examples**

Update the support list to include:

```markdown
- `IPQ60XX-NOWIFI`
- `IPQ60XX-NOWIFI-MINI`
- `JD-AX1800PRO-NOWIFI`
- `JD-AX6600-WIFI`
- `MIR3G-WIFI-MINI`
```

Update the preset examples to include:

```markdown
- `京东云雅典娜 AX6600 带 Wi-Fi`：`WRT_DEVICE=JD-AX6600-WIFI`
- `京东云亚瑟 AX1800 Pro 无 Wi-Fi`：`WRT_DEVICE=JD-AX1800PRO-NOWIFI`
```

Update the “主维护文件” section to point each device at its `-FW3.txt` main file, including:

```markdown
- `IPQ60XX-NOWIFI`：`Config/IPQ60XX-NOWIFI-FW3.txt`
- `IPQ60XX-NOWIFI-MINI`：`Config/IPQ60XX-NOWIFI-MINI-FW3.txt`
- `JD-AX1800PRO-NOWIFI`：`Config/JD-AX1800PRO-NOWIFI-FW3.txt`
- `JD-AX6600-WIFI`：`Config/JD-AX6600-WIFI-FW3.txt`
- `MIR3G-WIFI-MINI`：`Config/MIR3G-WIFI-MINI-FW3.txt`
```

- [ ] **Step 4: Run the manual workflow-options test**

Run:

```bash
rtk bash Scripts/tests/test_workflow_manual_device_options.sh
```

Expected: PASS with `test_workflow_manual_device_options: ok`

- [ ] **Step 5: Commit the workflow and README updates**

```bash
git add .github/workflows/DEFAULT.yml .github/workflows/CACHE-BENCH.yml README.md
git commit -m "chore: expose manual workflow device entries"
```

### Task 8: Final Verification

**Files:**
- Test: `Scripts/tests/test_export_config.sh`
- Test: `Scripts/tests/test_export_config_prefers_direct_fw4_file.sh`
- Test: `Scripts/tests/test_cmiot_ax18_fw4_packages.sh`
- Test: `Scripts/tests/test_ipq60xx_ax1800pro_wifi_overlay.sh`
- Test: `Scripts/tests/test_jd_ax6600_wifi_export.sh`
- Test: `Scripts/tests/test_split_device_fw4_exports.sh`
- Test: `Scripts/tests/test_workflow_manual_device_options.sh`

- [ ] **Step 1: Run the full targeted verification set**

Run:

```bash
rtk bash Scripts/tests/test_export_config.sh
rtk bash Scripts/tests/test_export_config_prefers_direct_fw4_file.sh
rtk bash Scripts/tests/test_cmiot_ax18_fw4_packages.sh
rtk bash Scripts/tests/test_ipq60xx_ax1800pro_wifi_overlay.sh
rtk bash Scripts/tests/test_jd_ax6600_wifi_export.sh
rtk bash Scripts/tests/test_split_device_fw4_exports.sh
rtk bash Scripts/tests/test_workflow_manual_device_options.sh
```

Expected:

```text
test_export_config: ok
test_export_config_prefers_direct_fw4_file: ok
test_cmiot_ax18_fw4_packages: ok
test_jd_ax1800pro_wifi_export: ok
test_jd_ax6600_wifi_export: ok
test_split_device_fw4_exports: ok
test_workflow_manual_device_options: ok
```

- [ ] **Step 2: Run syntax checks on touched workflows and shell scripts**

Run:

```bash
rtk bash -n Scripts/export_config.sh
rtk bash -n Scripts/tests/test_export_config_prefers_direct_fw4_file.sh
rtk bash -n Scripts/tests/test_jd_ax6600_wifi_export.sh
rtk bash -n Scripts/tests/test_split_device_fw4_exports.sh
rtk bash -n Scripts/tests/test_workflow_manual_device_options.sh
```

Expected: no output and zero exit status for each command

- [ ] **Step 3: Commit any final fixups**

```bash
git add Scripts/tests .github/workflows/DEFAULT.yml .github/workflows/CACHE-BENCH.yml README.md Config
git commit -m "test: finalize fw4 split verification"
```
