#!/usr/bin/env bash
set -Eeuo pipefail

base="$HOME/.local/share/dsh-kylin"
releases="$base/releases"
current="$base/current"
[[ -d "$releases" && -L "$current" ]] || { printf '没有可回滚的安装。\n' >&2; exit 2; }
current_real="$(readlink -f "$current")"

if [[ -n "${1:-}" ]]; then
  [[ "$1" != */* && "$1" != .* ]] || { printf '无效版本名。\n' >&2; exit 2; }
  target="$releases/$1"
else
  target=""
  while IFS= read -r candidate; do
    candidate_real="$(readlink -f "$candidate")"
    if [[ "$candidate_real" != "$current_real" && -f "$candidate/.dsh-kylin-release" ]]; then
      target="$candidate"
      break
    fi
  done < <(find "$releases" -mindepth 1 -maxdepth 1 -type d -print | sort -r)
fi

[[ -n "$target" && -f "$target/.dsh-kylin-release" ]] || { printf '没有找到上一版本。\n' >&2; exit 2; }
case "$(readlink -f "$target")" in "$releases"/*) ;; *) printf '拒绝越界版本路径。\n' >&2; exit 2;; esac
"$target/env/bin/node" "$target/env/bin/dsh" --version >/dev/null
new_link="$base/.current.rollback.$$.new"
ln -s -- "$target" "$new_link"
mv -Tf -- "$new_link" "$current"
printf '已切换到：%s\n' "$target"
