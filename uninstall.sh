#!/usr/bin/env bash
set -Eeuo pipefail

base="$HOME/.local/share/dsh-kylin"
user_bin="$HOME/.local/bin"
desktop="$HOME/.local/share/applications/deepseek-harness.desktop"
state="$HOME/.local/state/dsh-kylin"

[[ "$base" == "$HOME/.local/share/dsh-kylin" && "$base" != / ]] || { printf '拒绝不安全的卸载路径。\n' >&2; exit 2; }

for name in dsh dsh-web dsh-diagnose dsh-configure-key dsh-rollback; do
  path="$user_bin/$name"
  if [[ -f "$path" ]] && grep -q '^# dsh-kylin-managed$' "$path"; then
    rm -f -- "$path"
  fi
done
if [[ -f "$desktop" ]] && grep -q '^X-DSH-Kylin-Managed=true$' "$desktop"; then
  rm -f -- "$desktop"
fi
if [[ -d "$state" ]]; then
  pid="$(sed -n '1p' "$state/web.pid" 2>/dev/null || true)"
  if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null && \
     tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q '/.local/share/dsh-kylin/'; then
    kill "$pid" 2>/dev/null || true
  fi
  rm -rf -- "$state"
fi
[[ ! -e "$base" ]] || rm -rf -- "$base"
printf 'DeepSeek Harness 离线运行时已卸载。\n'
printf '用户数据与凭据目录 %s 未删除。\n' "$HOME/.dsh"
