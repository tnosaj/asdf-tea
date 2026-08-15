#!/usr/bin/env bash

set -euo pipefail

TOOL_REPO="https://gitea.com/gitea/tea"
GITEA_API="https://gitea.com/api/v1/repos/gitea/tea"
TOOL_NAME="tea"
TOOL_TEST="tea --version"

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

curl_opts=(-fsSL)

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

get_platform() {
	local os arch
	os=$(uname -s | tr '[:upper:]' '[:lower:]')
	arch=$(uname -m)
	case "$arch" in
	x86_64) arch="amd64" ;;
	aarch64 | arm64) arch="arm64" ;;
	armv7l) arch="arm-7" ;;
	armv6l) arch="arm-6" ;;
	armv5*) arch="arm-5" ;;
	*) fail "Unsupported architecture: $arch" ;;
	esac
	echo "${os}-${arch}"
}

list_gitea_releases() {
	local page=1
	while true; do
		local response tags
		response=$(curl "${curl_opts[@]}" "${GITEA_API}/releases?limit=50&page=${page}")
		tags=$(echo "$response" | grep -o '"tag_name": *"[^"]*"' | sed 's/"tag_name": *"//;s/^v//;s/"//' || true)
		[ -z "$tags" ] && break
		echo "$tags"
		page=$((page + 1))
	done
}

list_all_versions() {
	list_gitea_releases
}

download_release() {
	local version filename url platform
	version="$1"
	filename="$2"
	platform=$(get_platform)

	url="${TOOL_REPO}/releases/download/v${version}/tea-${version}-${platform}"

	echo "* Downloading $TOOL_NAME release $version..."
	curl "${curl_opts[@]}" -o "$filename" "$url" || fail "Could not download $url"
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}/bin"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		mkdir -p "$install_path"
		cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"

		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}
