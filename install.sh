#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly INSTALL_BASE="$HOME/.local/share/dsh-kylin"
readonly RELEASES_DIR="$INSTALL_BASE/releases"
readonly USER_BIN="$HOME/.local/bin"
readonly DESKTOP_DIR="$HOME/.local/share/applications"
readonly STATE_DIR="$HOME/.local/state/dsh-kylin"
readonly DSH_VERSION="0.1.0-rc.7"
readonly NODE_VERSION="22.23.2"
readonly MINIFORGE_SHA256="2c113a69297e612b01ca0f320c22a3107a11f2ab9b573d79ac868a175945ce29"
readonly MINIFORGE_INSTALLER="$SCRIPT_DIR/Miniforge3-Linux-aarch64.sh"
readonly CONDA_DIR="$SCRIPT_DIR/conda-pkgs"
readonly CONDA_HASHES="$SCRIPT_DIR/metadata/conda-package-sha256s.txt"
readonly BUNDLE_HASHES="$SCRIPT_DIR/metadata/sha256sums.txt"
readonly DEB_DIR="$SCRIPT_DIR/payload/compat/debs"
readonly DEB_HASHES="$DEB_DIR/SHA256SUMS"
readonly COMPAT_PAYLOAD="$SCRIPT_DIR/payload/compat/root"
readonly NPM_CACHE="$SCRIPT_DIR/npm-cache"
readonly PATCH_SCRIPT="$SCRIPT_DIR/scripts/patch-elf-tree.sh"

RELEASE_DIR=""
EXPLICIT_FILE=""
LOCK_DIR=""
OLD_CURRENT=""
SWITCHED=0
INSTALL_OK=0

log() { printf '[dsh-kylin] %s\n' "$*"; }
die() { printf '[dsh-kylin] ERROR: %s\n' "$*" >&2; exit 1; }

safe_remove_failed_release() {
  [[ -n "$RELEASE_DIR" && -d "$RELEASE_DIR" ]] || return 0
  case "$RELEASE_DIR" in
    "$RELEASES_DIR"/*) rm -rf -- "$RELEASE_DIR" ;;
    *) printf '[dsh-kylin] Refusing unsafe cleanup path: %s\n' "$RELEASE_DIR" >&2 ;;
  esac
}

finish() {
  status=$?
  trap - EXIT
  [[ -z "$EXPLICIT_FILE" || ! -f "$EXPLICIT_FILE" ]] || rm -f -- "$EXPLICIT_FILE"
  if (( status != 0 || INSTALL_OK == 0 )); then
    if (( SWITCHED == 1 )); then
      rm -f -- "$INSTALL_BASE/current"
      [[ -z "$OLD_CURRENT" ]] || ln -s -- "$OLD_CURRENT" "$INSTALL_BASE/current"
      printf '[dsh-kylin] Previous release restored.\n' >&2
    fi
    safe_remove_failed_release
  fi
  [[ -z "$LOCK_DIR" || ! -d "$LOCK_DIR" ]] || rmdir "$LOCK_DIR" 2>/dev/null || true
  exit "$status"
}
trap finish EXIT
trap 'printf "[dsh-kylin] ERROR: failed at line %s\n" "$LINENO" >&2' ERR

[[ "${EUID:-$(id -u)}" -ne 0 ]] || die "请以普通用户运行，不要使用 sudo。"
[[ "$(uname -s)" == Linux ]] || die "此安装包只支持 Linux。"
[[ "$(uname -m)" == aarch64 ]] || die "需要 aarch64，当前为 $(uname -m)。"
[[ "$HOME" == /* && "$HOME" != / ]] || die "HOME 必须是有效的绝对路径。"

glibc_line="$(getconf GNU_LIBC_VERSION 2>/dev/null || true)"
[[ "$glibc_line" =~ ([0-9]+)\.([0-9]+) ]] || die "无法识别系统 glibc：$glibc_line"
host_glibc_major="${BASH_REMATCH[1]}"
host_glibc_minor="${BASH_REMATCH[2]}"
if (( host_glibc_major < 2 || (host_glibc_major == 2 && host_glibc_minor < 17) )); then
  die "系统 glibc $host_glibc_major.$host_glibc_minor 太旧；Miniforge 至少需要 glibc 2.17。"
fi

kernel_release="$(uname -r)"
kernel_major="${kernel_release%%.*}"
kernel_tail="${kernel_release#*.}"
kernel_minor="${kernel_tail%%.*}"
if [[ "$kernel_major" =~ ^[0-9]+$ && "$kernel_minor" =~ ^[0-9]+$ ]]; then
  if (( kernel_major < 4 || (kernel_major == 4 && kernel_minor < 4) )); then
    die "内核 $kernel_release 低于本包验证下限 4.4。"
  fi
fi
log "目标检查通过：$(uname -m)，kernel $kernel_release，system glibc $host_glibc_major.$host_glibc_minor。"
if (( host_glibc_major < 2 || (host_glibc_major == 2 && host_glibc_minor < 28) )); then
  log "系统 glibc 低于 Node 22 所需版本；自动启用 bundled glibc 2.28 compatibility mode。"
else
  log "使用 bundled compatibility runtime，以保持 DSH 与系统程序完全隔离。"
fi

for command_name in bash sha256sum md5sum awk sed find od tr df; do
  command -v "$command_name" >/dev/null 2>&1 || die "缺少基础命令：$command_name"
done
[[ -f "$MINIFORGE_INSTALLER" ]] || die "缺少 Miniforge 安装器。"
[[ -f "$CONDA_HASHES" && -d "$CONDA_DIR" ]] || die "Conda 离线载荷不完整。"
[[ -f "$BUNDLE_HASHES" ]] || die "离线包完整性清单缺失。"
[[ -f "$DEB_HASHES" && -x "$COMPAT_PAYLOAD/usr/bin/patchelf" ]] || die "私有 glibc/patchelf 载荷不完整。"
[[ -d "$NPM_CACHE/_cacache" ]] || die "npm 离线缓存不完整。"
[[ -x "$PATCH_SCRIPT" ]] || die "缺少 ELF 修补脚本。"

available_kib="$(df -Pk "$HOME" | awk 'NR==2 {print $4}')"
[[ "$available_kib" =~ ^[0-9]+$ ]] || die "无法确认 HOME 可用空间。"
(( available_kib >= 4194304 )) || die "HOME 至少需要 4 GiB 可用空间。"
if (( available_kib < 6291456 )); then
  log "警告：可用空间少于建议的 6 GiB。"
fi

actual_miniforge_sha="$(sha256sum "$MINIFORGE_INSTALLER" | awk '{print $1}')"
[[ "$actual_miniforge_sha" == "$MINIFORGE_SHA256" ]] || die "Miniforge SHA256 不匹配。"

log "校验完整离线包内容。"
(cd "$SCRIPT_DIR" && sha256sum --quiet -c metadata/sha256sums.txt)

log "校验 45 个 Conda 包。"
package_count=0
while read -r expected name; do
  [[ -n "${expected:-}" && -n "${name:-}" ]] || continue
  [[ -f "$CONDA_DIR/$name" ]] || die "缺少 Conda 包：$name"
  [[ "$(sha256sum "$CONDA_DIR/$name" | awk '{print $1}')" == "$expected" ]] || die "Conda 包校验失败：$name"
  package_count=$((package_count + 1))
done < "$CONDA_HASHES"
[[ "$package_count" -eq 45 ]] || die "Conda 包数量异常：$package_count"

log "校验私有 glibc 2.28、libgcc、libstdc++ 与 patchelf。"
(cd "$DEB_DIR" && sha256sum -c SHA256SUMS)

mkdir -p "$RELEASES_DIR" "$USER_BIN" "$DESKTOP_DIR" "$STATE_DIR" "$INSTALL_BASE/bin"
chmod 700 "$INSTALL_BASE" "$RELEASES_DIR" "$STATE_DIR"
LOCK_DIR="$INSTALL_BASE/.install.lock"
mkdir "$LOCK_DIR" 2>/dev/null || die "另一个安装过程可能仍在运行：$LOCK_DIR"

release_name="dsh-$DSH_VERSION-node-$NODE_VERSION-$(date +%Y%m%d-%H%M%S)-$$"
RELEASE_DIR="$RELEASES_DIR/$release_name"
mkdir -m 700 "$RELEASE_DIR"
printf 'DSH_VERSION=%s\nNODE_VERSION=%s\nCREATED_AT=%s\n' \
  "$DSH_VERSION" "$NODE_VERSION" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$RELEASE_DIR/.dsh-kylin-release"

log "复制私有 glibc 2.28 运行时。"
mkdir "$RELEASE_DIR/compat"
cp -a "$COMPAT_PAYLOAD"/. "$RELEASE_DIR/compat"/

miniforge="$RELEASE_DIR/miniforge"
env_prefix="$RELEASE_DIR/env"
log "在版本目录中安装 Miniforge（不会修改 shell 配置）。"
bash "$MINIFORGE_INSTALLER" -b -p "$miniforge"
# shellcheck disable=SC1091
source "$miniforge/etc/profile.d/conda.sh"

EXPLICIT_FILE="$(mktemp "${TMPDIR:-/tmp}/dsh-conda-explicit.XXXXXX")"
printf '@EXPLICIT\n' > "$EXPLICIT_FILE"
while read -r package_sha package_name; do
  [[ -n "${package_sha:-}" && -n "${package_name:-}" ]] || continue
  package_uri="$("$miniforge/bin/python" -c \
    'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' \
    "$CONDA_DIR/$package_name")"
  printf '%s#%s\n' "$package_uri" "$package_sha" >> "$EXPLICIT_FILE"
done < "$CONDA_HASHES"

log "从 45 个本地包创建 Node 22/Python/C++ 环境。"
conda create --yes --offline --prefix "$env_prefix" --file "$EXPLICIT_FILE"

log "为环境中的动态 ELF 写入私有解释器和运行库路径。"
"$PATCH_SCRIPT" "$env_prefix" "$env_prefix" "$RELEASE_DIR/compat"

node="$env_prefix/bin/node"
npm="$env_prefix/bin/npm"
[[ "$($node --version)" == "v$NODE_VERSION" ]] || die "Node 版本不符合锁定值。"

export PATH="$env_prefix/bin:$PATH"
export CC="$env_prefix/bin/gcc"
export CXX="$env_prefix/bin/g++"
export PYTHON="$env_prefix/bin/python"
export npm_config_python="$PYTHON"
export npm_config_nodedir="$env_prefix"
export npm_config_cache="$NPM_CACHE"
export npm_config_platform=linux
export npm_config_arch=arm64
export npm_config_libc=glibc
export npm_config_offline=true
export npm_config_update_notifier=false

toolchain_dir="$(mktemp -d "$RELEASE_DIR/cxx17.XXXXXX")"
printf '#include <iostream>\nint main(){std::cout << "C++17 OK";return 0;}\n' > "$toolchain_dir/test.cpp"
"$CXX" -std=c++17 "$toolchain_dir/test.cpp" -o "$toolchain_dir/test"
"$PATCH_SCRIPT" "$toolchain_dir" "$env_prefix" "$RELEASE_DIR/compat"
[[ "$($toolchain_dir/test)" == "C++17 OK" ]] || die "C++17 编译/执行测试失败。"
rm -rf -- "$toolchain_dir"

log "验证 npm 内容缓存并严格离线安装 @deepseek-ai/dsh@$DSH_VERSION。"
"$npm" cache verify --cache "$NPM_CACHE"
"$npm" install --global --prefix "$env_prefix" --offline --include=optional \
  --os=linux --cpu=arm64 --libc=glibc --foreground-scripts --no-audit --no-fund \
  --cache "$NPM_CACHE" "@deepseek-ai/dsh@$DSH_VERSION"

log "修补 npm 新增的全部 Linux ARM64 动态 ELF。"
"$PATCH_SCRIPT" "$env_prefix" "$env_prefix" "$RELEASE_DIR/compat"

dsh_root="$env_prefix/lib/node_modules/@deepseek-ai/dsh"
pty_binary="$(find "$dsh_root" -type f -path '*/node-pty/prebuilds/linux-arm64/pty.node' -print -quit)"
[[ -f "$pty_binary" ]] || die "node-pty Linux ARM64 预编译模块缺失。"
"$node" -e "require(process.argv[1]); console.log('node-pty ARM64 load OK')" "${pty_binary%/prebuilds/linux-arm64/pty.node}"
for native_package in sharp koffi; do
  native_manifest="$(find "$dsh_root" -type f -path "*/node_modules/$native_package/package.json" -print -quit)"
  [[ -n "$native_manifest" ]] || die "native package 缺失：$native_package"
  "$node" -e "require(process.argv[1]); console.log(process.argv[2] + ' ARM64 load OK')" \
    "${native_manifest%/package.json}" "$native_package"
done
"$node" "$env_prefix/bin/dsh" --version
"$node" "$env_prefix/bin/dsh" --help >/dev/null

mkdir "$RELEASE_DIR/support"
cp "$SCRIPT_DIR/scripts/node-smoke.mjs" "$SCRIPT_DIR/scripts/child-smoke.mjs" \
  "$SCRIPT_DIR/diagnose.sh" "$RELEASE_DIR/support/"
chmod 755 "$RELEASE_DIR/support/diagnose.sh"

if [[ -L "$INSTALL_BASE/current" ]]; then
  OLD_CURRENT="$(readlink "$INSTALL_BASE/current")"
elif [[ -e "$INSTALL_BASE/current" ]]; then
  die "$INSTALL_BASE/current 已存在但不是符号链接。"
fi
new_link="$INSTALL_BASE/.current.$$.new"
ln -s -- "$RELEASE_DIR" "$new_link"
mv -Tf -- "$new_link" "$INSTALL_BASE/current"
SWITCHED=1

ln -sfn ../current/env/bin/node "$INSTALL_BASE/bin/node"

write_launcher() {
  destination="$1"
  body="$2"
  tmp="$destination.$$.new"
  printf '%s\n' '#!/usr/bin/env bash' '# dsh-kylin-managed' 'set -Eeuo pipefail' "$body" > "$tmp"
  chmod 755 "$tmp"
  mv -f -- "$tmp" "$destination"
}

write_launcher "$USER_BIN/dsh" 'base="$HOME/.local/share/dsh-kylin"; exec "$base/current/env/bin/node" "$base/current/env/bin/dsh" "$@"'
write_launcher "$USER_BIN/dsh-web" 'exec "$HOME/.local/share/dsh-kylin/current/support/diagnose.sh" --start-web "$@"'
write_launcher "$USER_BIN/dsh-diagnose" 'exec "$HOME/.local/share/dsh-kylin/current/support/diagnose.sh" "$@"'
write_launcher "$USER_BIN/dsh-configure-key" 'exec bash "$HOME/.local/share/dsh-kylin/tools/configure-api-key.sh" "$@"'
write_launcher "$USER_BIN/dsh-rollback" 'exec bash "$HOME/.local/share/dsh-kylin/tools/rollback.sh" "$@"'

mkdir -p "$INSTALL_BASE/tools"
cp "$SCRIPT_DIR/configure-api-key.sh" "$SCRIPT_DIR/rollback.sh" "$SCRIPT_DIR/uninstall.sh" "$INSTALL_BASE/tools/"
chmod 700 "$INSTALL_BASE/tools/"*.sh

desktop_tmp="$DESKTOP_DIR/.deepseek-harness.desktop.$$.new"
printf '%s\n' \
  '[Desktop Entry]' 'Type=Application' 'Name=DeepSeek 办公助手' \
  'Comment=Local DeepSeek Harness Web UI' \
  "Exec=$USER_BIN/dsh-web" 'Terminal=true' 'Categories=Development;Utility;' \
  'X-DSH-Kylin-Managed=true' > "$desktop_tmp"
chmod 644 "$desktop_tmp"
mv -f -- "$desktop_tmp" "$DESKTOP_DIR/deepseek-harness.desktop"

"$USER_BIN/dsh-diagnose" --core-only
[[ "$(getconf GNU_LIBC_VERSION 2>/dev/null)" == "$glibc_line" ]] || die "系统 glibc 检测结果在安装后发生变化。"

INSTALL_OK=1
log "安装成功：$RELEASE_DIR"
log "系统 glibc 仍为：$glibc_line（未修改系统 loader/library）。"
log "命令：$USER_BIN/dsh、$USER_BIN/dsh-web、$USER_BIN/dsh-diagnose"
log "首次使用请运行：$USER_BIN/dsh-configure-key"
log "若 PATH 尚未包含 ~/.local/bin，可直接使用以上绝对路径。"
