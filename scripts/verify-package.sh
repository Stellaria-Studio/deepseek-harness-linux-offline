#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
bundle_dir="$(cd -- "$script_dir/.." && pwd -P)"
fail() { printf '[verify-package] FAIL: %s\n' "$*" >&2; exit 1; }

for script in \
  "$bundle_dir/install.sh" "$bundle_dir/start-dsh.sh" "$bundle_dir/verify.sh" \
  "$bundle_dir/diagnose.sh" "$bundle_dir/configure-api-key.sh" \
  "$bundle_dir/rollback.sh" "$bundle_dir/uninstall.sh" "$script_dir"/*.sh; do
  bash -n "$script" || fail "syntax: $script"
done

[[ "$(uname -s)" != Linux || "$(uname -m)" == aarch64 ]] || fail "Linux bundle payload must be checked on aarch64."
[[ -f "$bundle_dir/metadata/conda-package-sha256s.txt" ]] || fail "missing Conda manifest"
[[ -f "$bundle_dir/payload/compat/debs/SHA256SUMS" ]] || fail "missing Debian manifest"
[[ -f "$bundle_dir/metadata/dsh-package-lock.json" ]] || fail "missing npm lock"
[[ -f "$bundle_dir/metadata/sha256sums.txt" ]] || fail "missing bundle manifest"

if command -v sha256sum >/dev/null 2>&1; then
  (cd "$bundle_dir" && sha256sum --quiet -c metadata/sha256sums.txt)
  (cd "$bundle_dir/payload/compat/debs" && sha256sum -c SHA256SUMS)
fi

if command -v node >/dev/null 2>&1; then
  node -e '
    const lock=require(process.argv[1]);
    const d=lock.packages["node_modules/@deepseek-ai/dsh"];
    const p=lock.packages["node_modules/node-pty"];
    if(d?.version!=="0.1.0-rc.7" || p?.version!=="1.2.0-beta.15") process.exit(1);
  ' "$bundle_dir/metadata/dsh-package-lock.json" || fail "npm lock versions"
fi

if find "$bundle_dir" -type f \( -path '*/_logs/*' -o -name '_update-notifier-last-checked' \) | grep -q .; then
  fail "npm log/update-notifier debris is present"
fi
printf '[verify-package] shell syntax, manifests and locked versions: OK\n'
