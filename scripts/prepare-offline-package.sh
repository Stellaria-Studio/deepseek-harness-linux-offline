#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
bundle="${1:-$repo/build/dsh-linux-arm64-offline}"
miniforge_sha="2c113a69297e612b01ca0f320c22a3107a11f2ab9b573d79ac868a175945ce29"

log() { printf '[prepare-offline] %s\n' "$*"; }
fail() { printf '[prepare-offline] ERROR: %s\n' "$*" >&2; exit 1; }

for tool in bash curl sha256sum node npm awk tar ar; do
  command -v "$tool" >/dev/null 2>&1 || fail "missing build-host tool: $tool"
done
[[ "$(node -p 'process.versions.node.split(`.`)[0]')" -ge 22 ]] || fail "Node >=22 is required on the online build host."
[[ "$(npm --version | cut -d. -f1)" -eq 10 ]] || fail "npm 10 is required for the locked cache build."

mkdir -p "$bundle/scripts" "$bundle/metadata" "$bundle/conda-pkgs" \
  "$bundle/npm-cache" "$bundle/payload/compat/debs"
for source_file in install.sh diagnose.sh uninstall.sh configure-api-key.sh rollback.sh start-dsh.sh verify.sh; do
  cp "$repo/$source_file" "$bundle/$source_file"
done
cp "$repo/scripts/"*.sh "$repo/scripts/"*.mjs "$bundle/scripts/"
cp "$repo/metadata/"* "$bundle/metadata/"
cp "$repo/README.zh-CN.md" "$bundle/README.md"
cp "$repo/metadata/debian-runtime-sha256s.txt" "$bundle/payload/compat/debs/SHA256SUMS"
chmod 755 "$bundle/"*.sh "$bundle/scripts/"*.sh

log "Download and verify Miniforge."
curl --fail --location --retry 4 \
  --output "$bundle/Miniforge3-Linux-aarch64.sh.part" \
  https://github.com/conda-forge/miniforge/releases/download/26.3.2-3/Miniforge3-26.3.2-3-Linux-aarch64.sh
[[ "$(sha256sum "$bundle/Miniforge3-Linux-aarch64.sh.part" | awk '{print $1}')" == "$miniforge_sha" ]] || fail "Miniforge checksum mismatch"
mv -f "$bundle/Miniforge3-Linux-aarch64.sh.part" "$bundle/Miniforge3-Linux-aarch64.sh"

log "Download and verify the 45 locked Conda archives."
while IFS=$'\t' read -r name platform upstream mirror; do
  [[ -n "$name" ]] || continue
  if ! curl --fail --location --retry 3 --output "$bundle/conda-pkgs/$name.part" "$upstream"; then
    curl --fail --location --retry 3 --output "$bundle/conda-pkgs/$name.part" "$mirror"
  fi
  expected="$(awk -v package="$name" '$2==package {print $1}' "$repo/metadata/conda-package-sha256s.txt")"
  actual="$(sha256sum "$bundle/conda-pkgs/$name.part" | awk '{print $1}')"
  [[ -n "$expected" && "$actual" == "$expected" ]] || fail "Conda checksum mismatch: $name"
  mv -f "$bundle/conda-pkgs/$name.part" "$bundle/conda-pkgs/$name"
done < "$repo/metadata/conda-sources.tsv"

log "Prepare Debian glibc 2.28 compatibility runtime."
bash "$bundle/scripts/prepare-runtime.sh"

log "Populate the exact Linux ARM64/glibc npm cache from the committed lock."
stage="$(mktemp -d "${TMPDIR:-/tmp}/dsh-npm-lock.XXXXXX")"
cp "$repo/metadata/dsh-package-lock.json" "$stage/package-lock.json"
node -e '
  const fs=require("node:fs");
  const lock=JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  fs.writeFileSync(process.argv[2], JSON.stringify(lock.packages[""], null, 2)+"\n");
' "$stage/package-lock.json" "$stage/package.json"
(cd "$stage" && npm ci --ignore-scripts --include=optional --os=linux --cpu=arm64 --libc=glibc \
  --no-audit --no-fund --cache "$bundle/npm-cache")
npm cache verify --cache "$bundle/npm-cache"

find "$bundle" -type f ! -name .DS_Store ! -path '*/_logs/*' \
  ! -name _update-notifier-last-checked ! -path "$bundle/metadata/sha256sums.txt" -print0 | \
  LC_ALL=C sort -z | xargs -0 sha256sum | sed "s#  $bundle/#  ./#" > "$bundle/metadata/sha256sums.txt"

log "Bundle prepared at $bundle"
log "Run: bash scripts/assemble-release.sh '$bundle' RELEASE_NAME"
