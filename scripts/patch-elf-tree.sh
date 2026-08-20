#!/usr/bin/env bash
set -Eeuo pipefail

[[ $# -eq 3 ]] || { printf 'Usage: %s TREE ENV_PREFIX COMPAT_PREFIX\n' "$0" >&2; exit 2; }
tree="$1"
env_prefix="$2"
compat="$3"
loader="$compat/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1"
patchelf="$compat/usr/bin/patchelf"
compat_lib="$compat/lib/aarch64-linux-gnu"
compat_usr_lib="$compat/usr/lib/aarch64-linux-gnu"

[[ -d "$tree" && -d "$env_prefix/lib" ]] || { printf 'Invalid patch tree or environment.\n' >&2; exit 2; }
[[ -x "$loader" && -x "$patchelf" ]] || { printf 'Private loader/patchelf is missing.\n' >&2; exit 2; }

run_patchelf() {
  "$loader" --library-path "$compat_lib:$compat_usr_lib" "$patchelf" "$@"
}

is_elf() {
  [[ "$(LC_ALL=C od -An -tx1 -N4 "$1" 2>/dev/null | tr -d ' \n')" == 7f454c46 ]]
}

is_aarch64() {
  # ELF e_machine at byte offset 18; little-endian EM_AARCH64 is 0x00b7.
  [[ "$(LC_ALL=C od -An -tx1 -j18 -N2 "$1" 2>/dev/null | tr -d ' \n')" == b700 ]]
}

append_path() {
  current="$1"
  addition="$2"
  case ":$current:" in
    *":$addition:"*) printf '%s' "$current" ;;
    *) if [[ -n "$current" ]]; then printf '%s:%s' "$current" "$addition"; else printf '%s' "$addition"; fi ;;
  esac
}

patched=0
static_count=0
foreign_count=0
while IFS= read -r -d '' candidate; do
  is_elf "$candidate" || continue
  if ! is_aarch64 "$candidate"; then
    foreign_count=$((foreign_count + 1))
    continue
  fi
  interpreter="$(run_patchelf --print-interpreter "$candidate" 2>/dev/null || true)"
  needed="$(run_patchelf --print-needed "$candidate" 2>/dev/null || true)"
  if [[ -z "$interpreter" && -z "$needed" ]]; then
    static_count=$((static_count + 1))
    continue
  fi
  [[ -z "$interpreter" ]] || run_patchelf --set-interpreter "$loader" "$candidate"
  old_rpath="$(run_patchelf --print-rpath "$candidate" 2>/dev/null || true)"
  new_rpath="$(append_path "$old_rpath" "$env_prefix/lib")"
  new_rpath="$(append_path "$new_rpath" "$compat_lib")"
  new_rpath="$(append_path "$new_rpath" "$compat_usr_lib")"
  run_patchelf --set-rpath "$new_rpath" "$candidate"
  patched=$((patched + 1))
done < <(find "$tree" -type f -print0)

printf '[patch-elf] patched=%s static_or_non_dynamic=%s foreign_elf=%s tree=%s\n' \
  "$patched" "$static_count" "$foreign_count" "$tree"
