#!/bin/sh
# Install the forked QoSmate backend and LuCI package from a GitHub checkout.
# Public release repository:
#   https://github.com/bbkien2312/Iprange-QoSmate_speedtest_ipk-apk_openwrt_release
#   wget -qO- https://raw.githubusercontent.com/bbkien2312/Iprange-QoSmate_speedtest_ipk-apk_openwrt_release/main/install_from_git.sh | sh
# Update an existing installation with shaping kept off:
#   QOSMATE_ENABLE=0 sh -c "$(wget -qO- https://raw.githubusercontent.com/bbkien2312/Iprange-QoSmate_speedtest_ipk-apk_openwrt_release/main/install_from_git.sh)"
# Optional: QOSMATE_REPO_URL=https://github.com/me/qosmate QOSMATE_REF=main sh install_from_git.sh
# Optional debug: QOSMATE_KEEP_STAGE=1 keeps /tmp/qosmate-fork after a successful install.

set -eu

repo_url="${QOSMATE_REPO_URL:-https://github.com/bbkien2312/Iprange-QoSmate_speedtest_ipk-apk_openwrt_release}"
ref="${QOSMATE_REF:-main}"
version="${QOSMATE_VERSION:-0.5.48-speedtest}"
luci_version="${QOSMATE_LUCI_VERSION:-1.0.14-speedtest}"
apk_luci_version="${QOSMATE_APK_LUCI_VERSION:-0.1.0}"
stage="/tmp/qosmate-fork"

fetch() {
    url="$1"; output="$2"
    if command -v uclient-fetch >/dev/null 2>&1; then
        uclient-fetch -q -O "$output" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$output" "$url"
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$output" "$url"
    else
        echo "uclient-fetch, wget or curl is required" >&2
        return 1
    fi
}

fetch_artifact() {
    filename="$1"; directory="$2"; output="$3"
    # Release-only repositories may keep artifacts at the repository root;
    # the full source repository keeps them under dist/dist-standard.
    if fetch "$repo_url/raw/$ref/$directory/$filename" "$output"; then
        return 0
    fi
    fetch "$repo_url/raw/$ref/$filename" "$output"
}

manager=''
command -v opkg >/dev/null 2>&1 && manager=opkg
if [ -z "$manager" ] && command -v apk >/dev/null 2>&1; then
    manager=apk
fi
[ -n "$manager" ] || { echo "OpenWrt opkg/apk was not found" >&2; exit 1; }

mkdir -p "$stage"
if [ "$manager" = opkg ]; then
    base="$repo_url/raw/$ref/dist-standard"
    backend="$stage/qosmate_${version}_all.ipk"
    frontend="$stage/luci-app-qosmate_${luci_version}_all.ipk"
    fetch_artifact "qosmate_${version}_all.ipk" "dist-standard" "$backend"
    fetch_artifact "luci-app-qosmate_${luci_version}_all.ipk" "dist-standard" "$frontend"
    opkg update
    opkg install --force-reinstall "$backend" "$frontend"
else
    # The dependency-free APK artifacts are produced by tools/build_packages.py.
    base="$repo_url/raw/$ref/dist"
    backend="$stage/qosmate-${version}.apk"
    frontend="$stage/luci-app-qosmate-speedtest-${apk_luci_version}.apk"
    fetch_artifact "qosmate-${version}.apk" "dist" "$backend"
    fetch_artifact "luci-app-qosmate-speedtest-${apk_luci_version}.apk" "dist" "$frontend"
    apk update
    apk add --allow-untrusted --force-broken-world "$backend" "$frontend"
fi

# Do not overwrite UCI settings or enable shaping implicitly.  Restart only
# the RPC/UI daemons so the new menu and health actions become available.
/etc/init.d/rpcd restart 2>/dev/null || true
/etc/init.d/uhttpd restart 2>/dev/null || true

if [ "${QOSMATE_ENABLE:-0}" = "1" ]; then
    /etc/init.d/qosmate enable
    /etc/init.d/qosmate restart
fi

if [ "${QOSMATE_KEEP_STAGE:-0}" = "1" ]; then
    echo "Keeping $stage because QOSMATE_KEEP_STAGE=1."
else
    # Packages are already installed; remove only this installer-owned staging
    # directory.  On an earlier install failure set -e exits before this point,
    # leaving the files available for troubleshooting.
    rm -rf "$stage"
fi

echo "QoSmate fork installed. Temporary staging cleanup completed."
echo "Set QOSMATE_ENABLE=1 only when you want the QoSmate service enabled at boot."
