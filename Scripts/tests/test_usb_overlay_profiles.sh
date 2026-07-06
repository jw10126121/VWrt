#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

assert_has_line() {
    local pattern=$1
    local file=$2

    grep -Eq "^${pattern}([[:space:]]+#.*)?$" "$file"
}

assert_lacks_line() {
    local pattern=$1
    local file=$2

    if grep -q "^${pattern}$" "$file"; then
        echo "unexpected line in $(basename "$file"): $pattern" >&2
        exit 1
    fi
}

IWRT_DEFAULT_OUT="$TMPDIR/iwrt-default.txt"
IWRT_NOUSB_OUT="$TMPDIR/iwrt-nousb.txt"
IWRT_USB_OUT="$TMPDIR/iwrt-usb.txt"
LEAN_NOUSB_OUT="$TMPDIR/lean-nousb.txt"
LEAN_USB_OUT="$TMPDIR/lean-usb.txt"

SOURCE_TYPE=vwrt bash "$EXPORT_SCRIPT" \
    --device cmiot-ax18-wifi \
    --fw fw4 \
    --output "$IWRT_DEFAULT_OUT" >/dev/null

assert_has_line 'CONFIG_PACKAGE_kmod-usb-xhci-hcd=y' "$IWRT_DEFAULT_OUT"
assert_has_line 'CONFIG_PACKAGE_usb-modeswitch=y' "$IWRT_DEFAULT_OUT"
assert_lacks_line 'CONFIG_PACKAGE_kmod-usb-xhci=y' "$IWRT_DEFAULT_OUT"
assert_lacks_line 'CONFIG_PACKAGE_kmod-usb-modeswitch=y' "$IWRT_DEFAULT_OUT"

SOURCE_TYPE=vwrt bash "$EXPORT_SCRIPT" \
    --device cmiot-ax18-wifi \
    --fw fw4 \
    --overlay nousb \
    --output "$IWRT_NOUSB_OUT" >/dev/null

for pkg in \
    kmod-usb-core \
    kmod-usb2 \
    kmod-usb3 \
    kmod-usb-xhci-hcd \
    kmod-usb-ohci \
    kmod-usb-uhci \
    kmod-usb-dwc3 \
    kmod-usb-storage \
    kmod-usb-storage-extras \
    kmod-usb-storage-uas \
    kmod-usb-net \
    kmod-usb-net-cdc-ether \
    kmod-usb-net-qmi-wwan \
    kmod-usb-audio \
    usb-modeswitch \
    usbutils \
    libimobiledevice \
    usbmuxd \
    luci-app-usb-printer \
    luci-i18n-usb-printer-zh-cn; do
    assert_has_line "CONFIG_PACKAGE_${pkg}=n" "$IWRT_NOUSB_OUT"
done

assert_lacks_line 'CONFIG_PACKAGE_kmod-usb-core=y' "$IWRT_NOUSB_OUT"
assert_lacks_line 'CONFIG_PACKAGE_kmod-usb-xhci-hcd=y' "$IWRT_NOUSB_OUT"
assert_lacks_line 'CONFIG_PACKAGE_usb-modeswitch=y' "$IWRT_NOUSB_OUT"

SOURCE_TYPE=vwrt bash "$EXPORT_SCRIPT" \
    --device cmiot-ax18-wifi \
    --fw fw4 \
    --overlay usb \
    --output "$IWRT_USB_OUT" >/dev/null

for pkg in \
    kmod-usb-core \
    kmod-usb2 \
    kmod-usb3 \
    kmod-usb-xhci-hcd \
    kmod-usb-ohci \
    kmod-usb-uhci \
    kmod-usb-dwc3 \
    kmod-usb-storage \
    kmod-usb-storage-extras \
    kmod-usb-storage-uas \
    kmod-usb-net \
    kmod-usb-net-cdc-ether \
    kmod-usb-net-qmi-wwan \
    kmod-usb-audio \
    usb-modeswitch \
    usbutils \
    libimobiledevice \
    usbmuxd; do
    assert_has_line "CONFIG_PACKAGE_${pkg}=y" "$IWRT_USB_OUT"
done

assert_has_line 'CONFIG_PACKAGE_luci-app-usb-printer=m' "$IWRT_USB_OUT"
assert_has_line 'CONFIG_PACKAGE_luci-i18n-usb-printer-zh-cn=m' "$IWRT_USB_OUT"

SOURCE_TYPE=lean bash "$EXPORT_SCRIPT" \
    --device cmiot-ax18-wifi \
    --fw fw3 \
    --overlay nousb \
    --output "$LEAN_NOUSB_OUT" >/dev/null

for pkg in \
    kmod-usb-core \
    kmod-usb2 \
    kmod-usb3 \
    kmod-usb-dwc3 \
    kmod-usb-ehci \
    kmod-usb-ohci \
    kmod-usb-uhci \
    kmod-usb-storage \
    kmod-usb-storage-extras \
    kmod-usb-storage-uas \
    kmod-usb-net \
    kmod-usb-acm \
    kmod-usb-serial-option \
    usb-modeswitch \
    usbutils \
    luci-app-usb-printer \
    luci-i18n-usb-printer-zh-cn; do
    assert_has_line "CONFIG_PACKAGE_${pkg}=n" "$LEAN_NOUSB_OUT"
done

SOURCE_TYPE=lean bash "$EXPORT_SCRIPT" \
    --device cmiot-ax18-wifi \
    --fw fw3 \
    --overlay usb \
    --output "$LEAN_USB_OUT" >/dev/null

for pkg in \
    kmod-usb-core \
    kmod-usb2 \
    kmod-usb3 \
    kmod-usb-dwc3 \
    kmod-usb-ehci \
    kmod-usb-ohci \
    kmod-usb-uhci \
    kmod-usb-storage \
    kmod-usb-storage-extras \
    kmod-usb-storage-uas \
    kmod-usb-net \
    kmod-usb-acm \
    kmod-usb-serial-option \
    usb-modeswitch \
    usbutils; do
    assert_has_line "CONFIG_PACKAGE_${pkg}=y" "$LEAN_USB_OUT"
done

assert_has_line 'CONFIG_PACKAGE_luci-app-usb-printer=m' "$LEAN_USB_OUT"
assert_has_line 'CONFIG_PACKAGE_luci-i18n-usb-printer-zh-cn=m' "$LEAN_USB_OUT"

echo "test_usb_overlay_profiles: ok"
