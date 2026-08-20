#!/usr/bin/env bash
set -Eeuo pipefail
bundle_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ -x "$HOME/.local/bin/dsh-diagnose" ]]; then
  exec "$HOME/.local/bin/dsh-diagnose" "$@"
fi
printf '尚未安装；先检查离线包自身。\n'
exec "$bundle_dir/scripts/verify-package.sh"
