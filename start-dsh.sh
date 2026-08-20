#!/usr/bin/env bash
set -Eeuo pipefail
launcher="$HOME/.local/bin/dsh-web"
[[ -x "$launcher" ]] || { printf '尚未安装。请先在离线包目录运行：bash install.sh\n' >&2; exit 2; }
exec "$launcher" "$@"
