#!/bin/bash

# 说明：
# 1. 按手工维护的 PACKAGE_OVERRIDES 维度整理编译产出的 ipk/apk。
# 2. 不再根据 .config 或外部生成规则自动补齐插件/主题分组。
# 3. 输入目录会被直接复制与清理，适合在打包阶段使用。

### --- 取参 --- ###

ACTION_DIR=${1:-}
CONFIG_PATH=${2:-}
GENERATED_OVERRIDES_PATH=${3:-}

[ -z "$ACTION_DIR" ] && echo "【Lin】错误：未指定操作目录" && exit 1;
[ -z "$CONFIG_PATH" ] && [ -f "./.config" ] && CONFIG_PATH="./.config"

### --- 方法 --- ###

resolve_config_anchor() {

	local package_list=$1

	printf '%s\n' "$package_list" | tr ' ' '\n' | sed 's/_$//' | grep -E '^(luci-app|luci-theme)-' | head -n1
}

package_group_enabled() {

	local package_list=$1
	local anchor_package

	[ -f "$CONFIG_PATH" ] || return 0

	anchor_package=$(resolve_config_anchor "$package_list")
	[ -n "$anchor_package" ] || return 0

	grep -Eq "^CONFIG_PACKAGE_${anchor_package}=(y|m)$" "$CONFIG_PATH"
}

# 整理依赖包列表
UPDATE_PACKAGE_LIST() {

	local ACTION_DIR=$1
	local PACKAGE_PRE_LIST=$2
	PACKAGE_NAME=$3

	# 若未显式指定目录名，则优先从依赖列表里猜一个 luci-app / luci-theme 作为目标目录名。
	if [ -z "${PACKAGE_NAME}" ]; then
		PACKAGE_NAME=$(echo "$PACKAGE_PRE_LIST" | grep -o 'luci-(app|theme)-[[:alnum:]-]*_\?' | sed 's/_$//' | head -n1)	
		# PACKAGE_NAME=$(echo "$PACKAGE_PRE_LIST" | tr ' ' '\n' | grep -E '^luci-(app|theme)-' | sed 's/_$//' | head -n1)
		# 如果没有包名，就取第一个作为包名
		if [ -z "${PACKAGE_NAME}" ]; then
			PACKAGE_NAME=$(echo "$PACKAGE_PRE_LIST" | awk '{print $1}' | sed 's/_$//')
		fi
	fi

	echo "【Lin】操作目录：${ACTION_DIR}，整理${PACKAGE_NAME}的安装包"

	PACKAGE_DIRNAME="$ACTION_DIR/$PACKAGE_NAME"
	mkdir -p "$PACKAGE_DIRNAME"
	# 将同一功能需要的 ipk/apk 聚合到一个目录，便于上传与安装。
	# ipk 用 _ 做版本分隔符，apk 用 -，用 [-_] 兼容两种命名。
	for pkg in $PACKAGE_PRE_LIST; do
	    local find_name
	    find_name=$(echo "$pkg" | sed 's/_$//')
	    for ext in ipk apk; do
	    	find "$ACTION_DIR" -name "${find_name}[-_]*.${ext}" 2>/dev/null -exec cp -r {} "$PACKAGE_DIRNAME" \;
	    done
	done

}

# 删除依赖包列表
DELETE_PACKAGE_LIST() {

 	local ACTION_DIR=$1
	local PACKAGE_PRE_LIST=$2

	for pkg in $PACKAGE_PRE_LIST; do
	    local find_name
	    find_name=$(echo "$pkg" | sed 's/_$//')
	    for ext in ipk apk; do
	    	find "$ACTION_DIR" -maxdepth 1 -name "${find_name}[-_]*.$ext" 2>/dev/null -exec rm -rf {} \;
	    done
	done

}

ORGANIZE_USB_PACKAGES() {

	local ACTION_DIR=$1
	local USB_DIRNAME="$ACTION_DIR/usb"
	local found_any=false
	local pkg_pattern ext

	for pkg_pattern in 'kmod-usb-*' 'kmod-usb2_*' 'kmod-usb3_*' 'usbutils_*'; do
		local find_name
		find_name=$(echo "$pkg_pattern" | sed 's/_$//')
		for ext in ipk apk; do
			if find "$ACTION_DIR" -maxdepth 1 -name "${find_name}[-_]*.${ext}" | grep -q .; then
				found_any=true
				break
			fi
		done
	done

	[ "$found_any" = true ] || return 0

	echo "【Lin】操作目录：${ACTION_DIR}，整理usb的安装包"
	mkdir -p "$USB_DIRNAME"
	for pkg_pattern in 'kmod-usb-*' 'kmod-usb2_*' 'kmod-usb3_*' 'usbutils_*'; do
		local find_name
		find_name=$(echo "$pkg_pattern" | sed 's/_$//')
		for ext in ipk apk; do
			find "$ACTION_DIR" -maxdepth 1 -name "${find_name}[-_]*.${ext}" 2>/dev/null -exec mv -f {} "$USB_DIRNAME" \;
		done
	done
}

### --- 执行 --- ###

# netspeedtest需要下载librespeed-go，但编译后，未发现librespeed-go，所以需要下载
# https://mirrors.tencent.com/lede/releases/24.10.2/packages/aarch64_cortex-a53/packages/librespeed-go_1.1.5-r5_aarch64_cortex-a53.ipk

### --- 包列表定义 --- ###
PACKAGE_OVERRIDES=$(cat <<'EOF'
openclash|luci-app-openclash_ kmod-inet-diag_ coreutils-nohup_ libcap-bin_ libgmp10_ libruby libyaml_ ruby_ ruby-bigdecimal_ ruby-date_ ruby-digest_ ruby-enc_ ruby-forwardable_ ruby-pstore_ ruby-psych_ ruby-stringio_ ruby-strscan_ ruby-yaml_ bash_ curl_ ca-bundle_ ip-full_ kmod-tun_ unzip_ kmod-nft-tproxy_
accesscontrol|luci-app-accesscontrol_ luci-i18n-accesscontrol-zh-cn_
advancedplus|luci-app-advancedplus_ luci-i18n-advancedplus-zh-cn_ luci-compat_ curl_
advancedsetting|luci-app-advancedsetting_ luci-i18n-advancedsetting-zh-cn_
athena-led|luci-app-athena-led_ luci-i18n-athena-led-zh-cn_ athena-led_ zoneinfo-core_ zoneinfo-asia_
attendedsysupgrade|luci-app-attendedsysupgrade_ luci-i18n-attendedsysupgrade-zh-cn_ attendedsysupgrade-common_ cgi-io_
autoreboot|luci-app-autoreboot_ luci-i18n-autoreboot-zh-cn_
ssrplus|luci-app-ssr-plus_ luci-i18n-ssr-plus-zh-cn_ libustream-openssl20201210_ dnsmasq-full_ jq_ ip-full_ curl_ libpcap1_ libudns_ libuci-lua_ nping_ resolveip_ lua-neturl_ libev_ libpcre2_ libsodium_ dns2socks_ dns2tcp_ ipt2socks_ chinadns-ng_ mosdns_ microsocks_ shadowsocks-libev-ss-local_ shadowsocks-libev-ss-redir_ shadowsocks-libev-ss-server_ shadowsocks-rust-sslocal_ shadowsocks-rust-ssserver_ shadowsocksr-libev-ssr-check_ shadowsocksr-libev-ssr-local_ shadowsocksr-libev-ssr-redir_ shadowsocksr-libev-ssr-server_ simple-obfs-client_ tcping_ xray-core_ coreutils_ coreutils-base64_ ca-bundle_ libopenssl3_ libubox20240329_ lyaml_ xz-utils_ libyaml_ unzip_
sqm|luci-app-sqm_ luci-i18n-sqm-zh-cn_ sqm-scripts_ kmod-ipt-ipopt_ kmod-ifb_ kmod-sched-cake_ kmod-sched-core_ iptables-mod-ipopt_ tc-tiny_ kmod-qca-nss-drv-igs_ kmod-qca-nss-drv-qdisc_
openvpnserver|luci-app-openvpn-server_ luci-i18n-openvpn-server-zh-cn_ liblzo_ openvpn-easy-rsa_ openvpn-openssl_
adguardhome|luci-app-adguardhome_ luci-i18n-adguardhome-zh-cn_ adguardhome_ ca-certs_ curl_ wget-ssl_ ca-bundle_ libcurl_ libgnutls_ libmbedtls_ libopenssl_ libwolfssl_ kmod-crypto-hw-padlock_ kmod-crypto-user_ kmod-cryptodev_ libatomic_ libgcc_
samba4|luci-app-samba4_ luci-i18n-samba4-zh-cn_ libattr_ libgnutls_ libavahi-client_ libavahi-dbus-support_ libdaemon_ libdbus_ libexpat_ libgmp_ libnettle_ libtasn1_ libtirpc_ liburing_ avahi-dbus-daemon_ wsdd2_ samba4-libs_ samba4-server_ attr_ dbus_
mwan3|luci-app-mwan3_ luci-i18n-mwan3-zh-cn_ pdnsd-alt_ mwan3_ ip_ ipset_ iptables_ iptables-mod-conntrack-extra_ iptables-mod-ipopt_ rpcd_ rpcd-mod-ucode_ jshn_
alist|luci-app-alist_ luci-i18n-alist-zh-cn_ alist_ libfuse_ fuse-utils_
openlist|luci-app-openlist_ luci-i18n-openlist-zh-cn_ openlist_ libfuse_ fuse-utils_
wrtbwmon|luci-app-wrtbwmon_ luci-i18n-wrtbwmon-zh-cn_ wrtbwmon_
netdata|luci-app-netdata_ luci-i18n-netdata-zh-cn_ netdata_ coreutils-timeout_
rclone|luci-app-rclone_ luci-i18n-rclone-zh-cn_ rclone_ rclone-config_ rclone-ng_ rclone-webui-react_ fuse-utils_
frps|luci-app-frps_ luci-i18n-frps-zh-cn_ frps_ libc_ zoneinfo-asia_
frpc|luci-app-frpc_ luci-i18n-frpc-zh-cn_ frpc_ libc_ zoneinfo-asia_
filetransfer|luci-app-filetransfer_ luci-i18n-filetransfer-zh-cn_ luci-lib-fs_
filebrowser|luci-app-filebrowser_ luci-i18n-filebrowser-zh-cn_ filebrowser_
3cat|luci-app-3cat_ luci-i18n-3cat-zh-cn_ 3proxy_ 3proxy-mod-tcppm_ 3proxy-mod-udppm_
socat|luci-app-socat_ luci-i18n-socat-zh-cn_ socat_
diskman|luci-app-diskman_ luci-i18n-diskman-zh-cn_ libparted_ parted_ smartmontools_ blkid_ e2fsprogs_
nlbwmon|luci-app-nlbwmon_ nlbwmon_ luci-i18n-nlbwmon-zh-cn_ kmod-nf-conntrack-netlink_
arpbind|luci-app-arpbind_ luci-i18n-arpbind-zh-cn_
wifischedule|luci-app-wifischedule_ wifischedule_ luci-i18n-wifischedule-zh-cn_
usbprinter|luci-app-usb-printer_ kmod-usb-printer_ p910nd_ luci-i18n-usb-printer-zh-cn_
pushbot|luci-app-pushbot_ iputils-arping_ jq_ curl_ luci-i18n-pushbot-zh-cn_
wechatpush|luci-app-wechatpush_ luci-i18n-wechatpush-zh-cn_ iputils-arping_ jq_ curl_ bash_
oaf|luci-app-oaf_ luci-i18n-oaf-zh-cn_ appfilter_ kmod-oaf_
easytier|luci-app-easytier_ luci-i18n-easytier-zh-cn_ easytier_ easytier-noweb_ kmod-tun_
bandix|luci-app-bandix_ bandix_ luci-i18n-bandix-zh-cn_
mosdns|luci-app-mosdns_ luci-i18n-mosdns-zh-cn_ curl_ mosdns_ v2dat_ v2ray-geoip_ v2ray-geosite_ libcurl_ ca-bundle_ libgnutls_ libmbedtls_ libopenssl_ libwolfssl_ kmod-crypto-hw-padlock_ kmod-crypto-user_ kmod-cryptodev_ libatomic_ libgcc_
argon|luci-theme-argon_ luci-i18n-argon-zh-cn_ curl_ jsonfilter_
argonconfig|luci-app-argon-config_ luci-i18n-argon-config-zh-cn_
onliner|luci-app-onliner_ luci-i18n-onliner-zh-cn_ arp-scan_ libpcap_
wolplus|luci-app-wolplus_ luci-i18n-wolplus-zh-cn_ etherwake_
versync|luci-app-verysync_ verysync_
vlmcsd|luci-app-vlmcsd_ luci-i18n-vlmcsd-zh-cn_ vlmcsd_
netspeedtest|luci-app-netspeedtest_ luci-i18n-netspeedtest-zh-cn_ speedtest-cli_ ookla-speedtest_ homebox_ python3_ python3-light_ python3-pkg-resources_ python3-xml_ python3-email_ python3-urllib_ python3-codecs_ python3-openssl_ iperf3_ iperf3-ssl_ curl_ jsonfilter_ taskset_
homeproxy|luci-app-homeproxy_ luci-i18n-homeproxy-zh-cn_ firewall4_ kmod-lib-crc32c_ kmod-nf-flow_ kmod-nft-core_ kmod-nft-fib_ kmod-nft-nat_ kmod-nft-offload_ kmod-nft-tproxy_ kmod-netlink-diag_ jansson_ libnftnl_ nftables-json_ chinadns-ng_ sing-box_ ip-full_ kmod-tun_ curl_ flock_ unzip_ ucode-mod-digest_
tailscale|luci-app-tailscale_ luci-i18n-tailscale-zh-cn_ tailscale_
nftqos|luci-app-nft-qos_ luci-i18n-nft-qos-zh-cn_ nft-qos_
hdidle|luci-app-hd-idle_ luci-i18n-hd-idle-zh-cn_ hd-idle_ lsblk_
airplay2|luci-app-airplay2_ luci-i18n-airplay2-zh-cn_ alsa-utils_ shairport-sync-openssl_
turboacc|luci-app-turboacc_ luci-i18n-turboacc-zh-cn_ kmod-fast-classifier_ kmod-ipt-offload_ kmod-shortcut-fe-cm_ kmod-tcp-bbr_
vsftpd|luci-app-vsftpd_ luci-i18n-vsftpd-zh-cn_ vsftpd_ vsftpd-alt_
lucky|luci-app-lucky_ luci-i18n-lucky-zh-cn_ lucky_
sqmcontroller|luci-app-sqm-controller_ luci-i18n-sqm-controller-zh-cn_ python3_ python3-light_ kmod-sched-connmark_ kmod-sched-ctinfo_
clientstatus|luci-app-clientstatus_ luci-i18n-clientstatus-zh-cn_ clientstatus_ luci-compat_
cpufreq|luci-app-cpufreq_ luci-i18n-cpufreq-zh-cn_ cpufreq_
ddns|luci-app-ddns_ luci-i18n-ddns-zh-cn_ ddns-scripts_ ddns-scripts-aliyun_ resolveip_ ip_
ddns-go|luci-app-ddns-go_ luci-i18n-ddns-go-zh-cn_ ddns-go_ ca-bundle_
docker|luci-app-docker_ luci-i18n-docker-zh-cn_ luci-compat_ docker_ dockerd_ e2fsprogs_ fdisk_
dockerman|luci-app-dockerman_ luci-i18n-dockerman-zh-cn_ luci-base_ docker_ ttyd_ dockerd_ docker-compose_ ucode-mod-socket_
easymesh|luci-app-easymesh_ luci-i18n-easymesh-zh-cn_ kmod-cfg80211_ batctl-default_ kmod-batman-adv_ wpad-mesh-openssl_ dawn_
guest-wifi|luci-app-guest-wifi_ luci-i18n-guest-wifi-zh-cn_
minidiskmanager|luci-app-mini-diskmanager_ luci-i18n-mini-diskmanager-zh-cn_ block-mount_ fdisk_ parted_ lsblk_
mwan3helper|luci-app-mwan3helper_ luci-i18n-mwan3helper-zh-cn_ luci-app-mwan3_ pdnsd-alt_ dnsmasq-full_ ipset_
nfs|luci-app-nfs_ luci-i18n-nfs-zh-cn_ luci-compat_ nfs-utils_ nfs-kernel-server_ nfs-kernel-server-utils_ mount-utils_
ninjaconnector2|luci-app-ninjaconnector2_ luci-i18n-ninjaconnector2-zh-cn_ luci-base_ luci-compat_ luci-app-openclash_ curl_ ca-bundle_ jsonfilter_
openvpn|luci-app-openvpn_ luci-i18n-openvpn-zh-cn_ luci-base_ luci-compat_ openvpn-openssl_ kmod-tun_
partexp|luci-app-partexp_ luci-i18n-partexp-zh-cn_ fdisk_ block-mount_ bc_ blkid_ parted_ btrfs-progs_ losetup_ resize2fs_ e2fsprogs_ f2fs-tools_ kmod-loop_
ramfree|luci-app-ramfree_ luci-i18n-ramfree-zh-cn_
smartdns|luci-app-smartdns_ luci-i18n-smartdns-zh-cn_ smartdns_ smartdns-ui_ libopenssl3_
syncdial|luci-app-syncdial_ luci-i18n-syncdial-zh-cn_ luci-compat_ kmod-macvlan_ luci-app-mwan3_
timewol|luci-app-timewol_ luci-i18n-timewol-zh-cn_ luci-compat_
ttyd|luci-app-ttyd_ luci-i18n-ttyd-zh-cn_ luci-base_ ttyd_
uhttpd|luci-app-uhttpd_ luci-i18n-uhttpd-zh-cn_ luci-base_ uhttpd_
upnp|luci-app-upnp_ luci-i18n-upnp-zh-cn_ luci-base_ miniupnpd-nftables_ rpcd-mod-ucode_
watchcat|luci-app-watchcat_ luci-i18n-watchcat-zh-cn_ luci-base_ watchcat_
webadmin|luci-app-webadmin_ luci-i18n-webadmin-zh-cn_ uhttpd_
wol|luci-app-wol_ luci-i18n-wol-zh-cn_ luci-base_ etherwake_
zerotier|luci-app-zerotier_ luci-i18n-zerotier-zh-cn_ zerotier_ libpthread_ libstdcpp6_ kmod-tun_ ip_ libminiupnpc_ libnatpmp_ libatomic_
nikki|luci-app-nikki_ luci-i18n-nikki-zh-cn_ nikki_ mihomo_ ca-bundle_ curl_ yq_ firewall4_ ip-full_ kmod-inet-diag_ kmod-nft-socket_ kmod-nft-tproxy_ kmod-tun_ kmod-dummy_
subconverter|luci-app-subconverter_ luci-i18n-subconverter-zh-cn_ subconverter_
fluent|luci-theme-fluent_ luci-i18n-fluent-zh-cn_
miaomiaowu|luci-app-miaomiaowu_ miaomiaowu_
aurora|luci-theme-aurora_ luci-app-aurora-config_ luci-i18n-aurora-config-zh-cn_
EOF
)

# 兼容保留旧入参，当前版本只消费手工 PACKAGE_OVERRIDES。
PACKAGES="$PACKAGE_OVERRIDES"

### --- 执行 --- ###
# 先更新所有包
while IFS='|' read -r pkg_name package_list; do
	[ -z "$pkg_name" ] && continue
	if package_group_enabled "$package_list"; then
		UPDATE_PACKAGE_LIST "$ACTION_DIR" "$package_list"
	fi
done <<EOF
$PACKAGES
EOF

ORGANIZE_USB_PACKAGES "$ACTION_DIR"

#UPDATE_PACKAGE_LIST "$ACTION_DIR" "luci-app-netspeedtest_ luci-i18n-netspeedtest-zh-cn_ librespeed-go_ iperf3_ python3-speedtest-cli_ ca-certificates_" "luci-app-netspeedtest_muink"

# 再删除所有包
while IFS='|' read -r pkg_name package_list; do
	[ -z "$pkg_name" ] && continue
	DELETE_PACKAGE_LIST "$ACTION_DIR" "$package_list"
done <<EOF
$PACKAGES
EOF
