#!/bin/sh

# SOURCE_TYPE describes the selected upstream flavor; config family describes
# which config set should be applied by this repository.

normalize_source_type() {
	local source_type=${1:-auto}

	case "$source_type" in
		lean|lede|lwrt)
			printf '%s\n' 'lean'
			;;
		iwrt|vwrt|immortalwrt|vikingyfy)
			printf '%s\n' 'vwrt'
			;;
		libwrt)
			printf '%s\n' 'libwrt'
			;;
		auto|'')
			printf '%s\n' 'auto'
			;;
		*)
			printf '%s\n' "$source_type"
			;;
	esac
}

source_config_family() {
	local source_type
	source_type=$(normalize_source_type "${1:-auto}")

	case "$source_type" in
		lean)
			printf '%s\n' 'lean'
			;;
		*)
			printf '%s\n' 'iwrt'
			;;
	esac
}

detect_source_type_from_tree() {
	local source_root=${1:-.}

	if [ -f "$source_root/package/lean/default-settings/files/zzz-default-settings" ] || \
		[ -f "$source_root/package/lean/default-settings/Makefile" ]; then
		printf '%s\n' 'lean'
	else
		printf '%s\n' 'vwrt'
	fi
}

resolve_source_type() {
	local requested_type
	local source_root=${2:-.}
	requested_type=$(normalize_source_type "${1:-auto}")

	if [ "$requested_type" = "auto" ]; then
		detect_source_type_from_tree "$source_root"
	else
		printf '%s\n' "$requested_type"
	fi
}
