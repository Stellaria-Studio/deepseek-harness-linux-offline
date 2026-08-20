#!/usr/bin/env bash
set -Eeuo pipefail

base="$HOME/.local/share/dsh-kylin"
current="$base/current"
release="$(readlink -f "$current" 2>/dev/null || true)"
node="$release/env/bin/node"
dsh="$release/env/bin/dsh"
loader="$release/compat/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1"
patchelf="$release/compat/usr/bin/patchelf"
compat_lib="$release/compat/lib/aarch64-linux-gnu"
compat_usr_lib="$release/compat/usr/lib/aarch64-linux-gnu"
state_dir="$HOME/.local/state/dsh-kylin"
url="http://127.0.0.1:3080"

say() { printf '[dsh-diagnose] %s\n' "$*"; }
fail() { printf '[dsh-diagnose] FAIL: %s\n' "$*" >&2; exit 1; }

[[ -n "$release" && -f "$release/.dsh-kylin-release" ]] || fail "没有找到有效安装：$current"
[[ -x "$node" && -f "$dsh" && -x "$loader" && -x "$patchelf" ]] || fail "当前版本不完整：$release"

probe_web() {
  "$node" -e '
    const http=require("node:http");
    const r=http.get(process.argv[1],x=>{x.resume();process.exit(x.statusCode ? 0 : 1)});
    r.setTimeout(900,()=>r.destroy(new Error("timeout")));
    r.on("error",()=>process.exit(1));
  ' "$url" >/dev/null 2>&1
}

open_web() {
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 &
  elif command -v gio >/dev/null 2>&1; then
    gio open "$url" >/dev/null 2>&1 &
  else
    say "浏览器自动打开工具不可用，请手动访问 $url"
  fi
}

start_web() {
  shift
  [[ $# -eq 0 ]] || fail "dsh-web 不接受额外监听参数；固定使用 127.0.0.1:3080。"
  mkdir -p "$state_dir"
  chmod 700 "$state_dir"
  pid_file="$state_dir/web.pid"
  log_file="$state_dir/web.log"

  if probe_web; then
    say "Web UI 已在运行：$url"
    open_web
    return 0
  fi
  if [[ -f "$pid_file" ]]; then
    old_pid="$(sed -n '1p' "$pid_file" 2>/dev/null || true)"
    if [[ "$old_pid" =~ ^[0-9]+$ ]] && kill -0 "$old_pid" 2>/dev/null; then
      say "已有启动进程 $old_pid，等待服务就绪。"
    else
      rm -f -- "$pid_file"
      old_pid=""
    fi
  else
    old_pid=""
  fi
  if [[ -z "$old_pid" ]]; then
    say "启动 DeepSeek Harness Web UI（仅监听 127.0.0.1:3080）。"
    nohup "$node" "$dsh" web --host 127.0.0.1 --port 3080 --no-open \
      >>"$log_file" 2>&1 </dev/null &
    web_pid=$!
    printf '%s\n' "$web_pid" > "$pid_file"
  else
    web_pid="$old_pid"
  fi

  attempts=0
  while (( attempts < 120 )); do
    if probe_web; then
      say "Web UI 已就绪：$url"
      open_web
      return 0
    fi
    if ! kill -0 "$web_pid" 2>/dev/null; then
      say "Web 进程提前退出，最近日志："
      tail -n 30 "$log_file" 2>/dev/null || true
      fail "Web UI 启动失败。完整日志：$log_file"
    fi
    sleep 0.25
    attempts=$((attempts + 1))
  done
  fail "30 秒内未就绪。日志：$log_file"
}

if [[ "${1:-}" == --start-web ]]; then
  start_web "$@"
  exit 0
fi

network_arg="--network"
if [[ "${1:-}" == --core-only ]]; then
  network_arg=""
fi

say "hostname=$(hostname 2>/dev/null || true) user=$(id -un) uid=$(id -u)"
say "arch=$(uname -m) kernel=$(uname -r)"
say "system_glibc=$(getconf GNU_LIBC_VERSION 2>/dev/null || true)"
say "release=$release"
say "node=$($node --version) npm=$($node "$release/env/bin/npm" --version)"
say "dsh=$($node "$dsh" --version 2>&1 | tail -n 1)"
say "LD_LIBRARY_PATH=${LD_LIBRARY_PATH-<unset>}（本包不依赖全局设置）"

objdump_cmd="$release/env/bin/aarch64-conda-linux-gnu-objdump"
strings_cmd="$release/env/bin/aarch64-conda-linux-gnu-strings"
[[ -x "$objdump_cmd" ]] || fail "环境中的 ARM64 objdump 缺失。"
[[ -x "$strings_cmd" ]] || fail "环境中的 ARM64 strings 缺失。"
max_abi() {
  symbol="$1"
  shift
  for abi_file in "$@"; do
    [[ -f "$abi_file" ]] || continue
    "$objdump_cmd" -p "$abi_file" 2>/dev/null | awk '/^Version References:/{references=1; next} references{print}' | \
      sed -n "s/.*${symbol}_\([0-9][0-9.]*\).*/\1/p"
  done | awk -F. '{printf "%09d %09d %09d %s\n", $1, $2, $3, $0}' | sort | tail -n 1 | awk '{print $4}'
}
libnode="$release/env/lib/libnode.so.127"
say "node_required_GLIBC=$(max_abi GLIBC "$node" "$libnode")"
say "node_required_GLIBCXX=$(max_abi GLIBCXX "$node" "$libnode")"
bundled_stdlib="$(readlink -f "$release/env/lib/libstdc++.so.6")"
say "bundled_libstdc++=$(basename "$bundled_stdlib") max_GLIBCXX=$($strings_cmd "$bundled_stdlib" | sed -n 's/^GLIBCXX_\([0-9][0-9.]*\)$/\1/p' | sort -V | tail -n 1)"
system_stdlib=""
for system_candidate in /usr/lib/aarch64-linux-gnu/libstdc++.so.6 /usr/lib64/libstdc++.so.6 /lib/aarch64-linux-gnu/libstdc++.so.6; do
  [[ ! -e "$system_candidate" ]] || { system_stdlib="$system_candidate"; break; }
done
if [[ -n "$system_stdlib" ]]; then
  say "system_GLIBCXX=$($strings_cmd "$system_stdlib" 2>/dev/null | sed -n 's/^GLIBCXX_\([0-9][0-9.]*\)$/\1/p' | sort -V | tail -n 1) path=$system_stdlib"
else
  say "system_GLIBCXX=not-found"
fi
native_count="$(find "$release/env/lib/node_modules/@deepseek-ai/dsh" -type f -name '*.node' | wc -l | tr -d ' ')"
say "native_addon_files=$native_count"

private_patchelf() {
  "$loader" --library-path "$compat_lib:$compat_usr_lib" "$patchelf" "$@"
}
node_interp="$(private_patchelf --print-interpreter "$node")"
node_rpath="$(private_patchelf --print-rpath "$node")"
[[ "$node_interp" == "$loader" ]] || fail "Node PT_INTERP 未指向当前私有 loader：$node_interp"
case ":$node_rpath:" in
  *":$release/env/lib:"*) ;;
  *) fail "Node RPATH 未包含当前环境 lib。" ;;
esac
say "node_PT_INTERP=$node_interp"
private_glibc="$($strings_cmd "$compat_lib/libc.so.6" | sed -n '/^GNU C Library /p')"
[[ "$private_glibc" == *"release version 2.28."* ]] || fail "无法确认私有 glibc 2.28：${private_glibc:-not-found}"
say "private_glibc=$private_glibc"
"$loader" --library-path "$release/env/lib:$compat_lib:$compat_usr_lib" --list "$node" >/dev/null
say "private loader dependency resolution=OK"

if [[ -n "$network_arg" ]]; then
  "$node" "$release/support/node-smoke.mjs" "$network_arg"
else
  "$node" "$release/support/node-smoke.mjs"
fi
say "核心诊断通过。"
