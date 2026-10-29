#!/usr/bin/env sh
set -eu
# 发布时替换仓库标记；本地验证可通过环境变量指定分发仓库或下载地址。
repository=${STATIONOS_CLI_REPO:-StationPC-Technology/stationospro-cli}
version=${STATIONOS_CLI_VERSION:-latest}
install_dir=${STATIONOS_CLI_INSTALL_DIR:-"$HOME/.local/bin"}
skill_client=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --with-skill) [ "$#" -ge 2 ] || { echo "--with-skill requires a client" >&2; exit 1; }; skill_client=$2; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done
case "$skill_client" in ""|cursor|claude|codex) ;; *) echo "Unsupported skill client" >&2; exit 1 ;; esac
case "$repository" in */*) ;; *) echo "Set STATIONOS_CLI_REPO to owner/repository" >&2; exit 1 ;; esac
if [ "$repository" = StationPC-Technology/stationospro-cli ]; then echo "This installer has not been configured for a distribution repository" >&2; exit 1; fi
case "$(uname -s)" in Linux) target_os=linux ;; Darwin) target_os=darwin ;; *) echo "Unsupported OS; use install.ps1 on Windows" >&2; exit 1 ;; esac
case "$(uname -m)" in x86_64|amd64) target_arch=amd64 ;; aarch64|arm64) target_arch=arm64 ;; *) echo "Unsupported architecture" >&2; exit 1 ;; esac
command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
if [ "$version" = latest ]; then
  # 从 GitHub 重定向解析发布标签，不依赖 jq 或 Node.js。
  release_url=$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/$repository/releases/latest")
  tag=${release_url##*/}
else
  tag=v${version#v}
fi
version=${tag#v}
case "$version" in *[!0-9.]*|"") echo "Invalid release version: $version" >&2; exit 1 ;; esac
name="stationos-cli-${version}-${target_os}-${target_arch}"
base_url=${STATIONOS_CLI_DOWNLOAD_BASE:-"https://github.com/$repository/releases/download/$tag"}
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM
curl -fsSL "$base_url/$name" -o "$temp_dir/$name"
curl -fsSL "$base_url/checksums.txt" -o "$temp_dir/checksums.txt"
expected=$(awk -v file="$name" '$2 == file {print $1}' "$temp_dir/checksums.txt")
[ -n "$expected" ] || { echo "Asset missing from checksums.txt" >&2; exit 1; }
if command -v sha256sum >/dev/null 2>&1; then actual=$(sha256sum "$temp_dir/$name" | awk '{print $1}');
elif command -v shasum >/dev/null 2>&1; then actual=$(shasum -a 256 "$temp_dir/$name" | awk '{print $1}');
else echo "sha256sum or shasum is required" >&2; exit 1; fi
[ "$actual" = "$expected" ] || { echo "Checksum mismatch; existing CLI was not changed" >&2; exit 1; }
mkdir -p "$install_dir"
# 在目标目录中准备文件，再替换可执行文件，失败时保留原安装。
install_temp=$(mktemp "$install_dir/.stationos-cli-XXXXXX")
trap 'rm -rf "$temp_dir"; rm -f "$install_temp"' EXIT HUP INT TERM
cp "$temp_dir/$name" "$install_temp"
chmod 755 "$install_temp"
mv -f "$install_temp" "$install_dir/stationos-cli"
printf 'Installed stationos-cli %s to %s\n' "$version" "$install_dir"
case ":$PATH:" in *":$install_dir:"*) ;; *) printf 'Add this directory to PATH: %s\n' "$install_dir" ;; esac
if [ -n "$skill_client" ]; then "$install_dir/stationos-cli" skills install --client "$skill_client"; fi
