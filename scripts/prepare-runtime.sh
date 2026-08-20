#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
bundle_dir="$(cd -- "$script_dir/.." && pwd -P)"
deb_dir="$bundle_dir/payload/compat/debs"
root_dir="$bundle_dir/payload/compat/root"
mkdir -p "$deb_dir" "$root_dir"

download() {
  name="$1"
  url="$2"
  expected="$3"
  curl --fail --location --retry 4 --output "$deb_dir/$name.part" "$url"
  actual="$(sha256sum "$deb_dir/$name.part" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || { printf 'SHA256 mismatch: %s\n' "$name" >&2; exit 1; }
  mv -f -- "$deb_dir/$name.part" "$deb_dir/$name"
}

download libc6_2.28-10+deb10u4_arm64.deb \
  https://archive.debian.org/debian/pool/main/g/glibc/libc6_2.28-10+deb10u4_arm64.deb \
  299556e1d1bf80617b417c82521f1f0bcb111933c40016fbe8a303b73e6a6a22
download libgcc1_8.3.0-6_arm64.deb \
  https://archive.debian.org/debian-archive/debian/pool/main/g/gcc-8/libgcc1_8.3.0-6_arm64.deb \
  2851ac25d12958586c035de5ec4f2fc17272dec48f776dd0dd24c62f62674fd9
download libstdc++6_8.3.0-6_arm64.deb \
  https://archive.debian.org/debian-archive/debian/pool/main/g/gcc-8/libstdc++6_8.3.0-6_arm64.deb \
  52cf36333a405867a079a695f6a37cb63558859d7d19cef40fc7d112c39fefd6
download patchelf_0.9+52.20180509-1_arm64.deb \
  https://archive.debian.org/debian/pool/main/p/patchelf/patchelf_0.9+52.20180509-1_arm64.deb \
  a261bd96bdd2f2c9b240589f3319e24a567c604af5c9132e0da970f2cbd6b1ab

(cd "$deb_dir" && sha256sum -c SHA256SUMS)
for deb in "$deb_dir"/*.deb; do
  work="$(mktemp -d "${TMPDIR:-/tmp}/dsh-deb.XXXXXX")"
  (cd "$work" && ar x "$deb")
  archive="$(find "$work" -maxdepth 1 -type f -name 'data.tar.*' -print -quit)"
  tar -xf "$archive" -C "$root_dir"
  rm -rf -- "$work"
done
printf 'Private compatibility runtime prepared at %s\n' "$root_dir"
