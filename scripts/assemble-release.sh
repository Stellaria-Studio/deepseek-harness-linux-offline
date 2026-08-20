#!/usr/bin/env bash
set -Eeuo pipefail

[[ $# -eq 2 ]] || { printf 'Usage: %s READY_BUNDLE RELEASE_NAME\n' "$0" >&2; exit 2; }
bundle="$(cd -- "$1" && pwd -P)"
release_name="$2"
dist="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)/dist"
[[ "$release_name" =~ ^[A-Za-z0-9._-]+$ ]] || { printf 'Unsafe release name.\n' >&2; exit 2; }
[[ -f "$bundle/install.sh" && -f "$bundle/metadata/sha256sums.txt" ]] || { printf 'Bundle is incomplete.\n' >&2; exit 2; }

(cd "$bundle" && sha256sum --quiet -c metadata/sha256sums.txt)
mkdir -p "$dist"
archive="$dist/$release_name.tar.gz"
parent="$(dirname "$bundle")"
base="$(basename "$bundle")"
if tar --help 2>&1 | grep -q -- '--transform'; then
  COPYFILE_DISABLE=1 tar --exclude='.DS_Store' --exclude='._*' --exclude='npm-cache/_logs' \
    --transform "s|^$base|$release_name|" -czf "$archive" -C "$parent" "$base"
else
  COPYFILE_DISABLE=1 tar --exclude='.DS_Store' --exclude='._*' --exclude='npm-cache/_logs' \
    -czf "$archive" -C "$parent" -s "|^$base|$release_name|" "$base"
fi
(cd "$dist" && sha256sum "$(basename "$archive")" > SHA256SUMS)
printf 'Release archive: %s\n' "$archive"
printf 'Checksums: %s/SHA256SUMS\n' "$dist"
