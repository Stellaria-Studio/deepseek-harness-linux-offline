#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

credentials_dir="$HOME/.dsh"
credentials_file="$credentials_dir/.credentials.yaml"
replace=0
[[ "${1:-}" != --replace ]] || replace=1

if [[ -e "$credentials_file" && "$replace" -ne 1 ]]; then
  printf '凭据文件已经存在：%s\n' "$credentials_file" >&2
  printf '为避免覆盖其他 Provider 凭据，本脚本没有修改它。确认只需 DeepSeek Key 时可运行：dsh-configure-key --replace\n' >&2
  exit 2
fi

printf '请输入 DEEPSEEK_API_KEY（输入不会显示）：' >&2
IFS= read -r -s api_key
printf '\n' >&2
[[ "$api_key" =~ ^[A-Za-z0-9._-]{8,}$ ]] || { printf 'Key 格式不安全或过短，未写入。\n' >&2; exit 2; }

mkdir -p "$credentials_dir"
chmod 700 "$credentials_dir"
if [[ -e "$credentials_file" ]]; then
  backup="$credentials_file.backup.$(date +%Y%m%d-%H%M%S)"
  cp -p -- "$credentials_file" "$backup"
  chmod 600 "$backup"
  printf '旧凭据已备份到：%s\n' "$backup"
fi
temporary="$credentials_dir/.credentials.yaml.$$.new"
printf 'DEEPSEEK_API_KEY: %s\n' "$api_key" > "$temporary"
chmod 600 "$temporary"
mv -f -- "$temporary" "$credentials_file"
unset api_key
printf '已安全写入 %s（权限 600）。\n' "$credentials_file"
