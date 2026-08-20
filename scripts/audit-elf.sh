#!/usr/bin/env bash
set -Eeuo pipefail

[[ $# -ge 1 ]] || { printf 'Usage: %s TREE [OUTPUT.tsv]\n' "$0" >&2; exit 2; }
tree="$1"
output="${2:-/dev/stdout}"
command -v objdump >/dev/null 2>&1 || { printf 'objdump is required.\n' >&2; exit 2; }

is_elf() {
  [[ "$(LC_ALL=C od -An -tx1 -N4 "$1" 2>/dev/null | tr -d ' \n')" == 7f454c46 ]]
}

max_symbol_version() {
  pattern="$1"
  file="$2"
  objdump -p "$file" 2>/dev/null | awk '/^Version References:/{references=1; next} references{print}' | \
    sed -n "s/.*${pattern}_\([0-9][0-9.]*\).*/\1/p" | \
    awk -F. '{printf "%09d %09d %09d %s\n", $1, $2, $3, $0}' | sort | tail -n 1 | awk '{print $4}'
}

tmp="${output}.$$.new"
printf 'path\tformat\tinterpreter\tmax_glibc\tmax_glibcxx\tneeded\n' > "$tmp"
count=0
while IFS= read -r -d '' elf_file; do
  is_elf "$elf_file" || continue
  format="$(file -b "$elf_file" 2>/dev/null | tr '\t' ' ')"
  interpreter="$(objdump -p "$elf_file" 2>/dev/null | sed -n 's/.*INTERP[[:space:]]*//p' | head -n 1)"
  glibc="$(max_symbol_version GLIBC "$elf_file")"
  glibcxx="$(max_symbol_version GLIBCXX "$elf_file")"
  needed="$(objdump -p "$elf_file" 2>/dev/null | sed -n 's/^[[:space:]]*NEEDED[[:space:]]*//p' | paste -sd, -)"
  relative="${elf_file#"$tree"/}"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$relative" "$format" "${interpreter:--}" "${glibc:--}" "${glibcxx:--}" "${needed:--}" >> "$tmp"
  count=$((count + 1))
done < <(find "$tree" -type f -print0)
mv -f -- "$tmp" "$output"
printf '[audit-elf] files=%s output=%s\n' "$count" "$output" >&2
