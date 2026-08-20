# DeepSeek Harness Linux Offline

[简体中文](README.zh-CN.md)

Community-maintained, no-sudo offline installer and private compatibility
runtime for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)
on ARM64 GNU/Linux.

> [!IMPORTANT]
> This is not an official DeepSeek project and is not affiliated with or
> endorsed by DeepSeek AI. See [DISCLAIMER.md](DISCLAIMER.md).

## Current release target

The first pre-release provides **Linux ARM64 only**:

- DeepSeek Harness `0.1.0-rc.7` (upstream package, unmodified)
- Node.js `22.23.2`
- bundled Debian 10 ARM64 glibc `2.28`
- bundled Conda libstdc++/libgcc runtime and offline native toolchain
- no root access, no network access on the target, no global
  `LD_LIBRARY_PATH`
- install root: `~/.local/share/dsh-kylin`

The installer accepts GNU/Linux `aarch64`, host glibc `>= 2.17`, and kernel
`>= 4.4`. Node.js upstream currently lists kernel `>= 4.18` and glibc `>= 2.28`
for Tier 1 Linux ARM64; the bundled glibc supplies the latter, while kernels
4.4–4.17 remain an explicitly experimental compatibility range.

Designed distributions include Kylin, UOS, openEuler, Debian, Ubuntu, RHEL,
Rocky Linux, AlmaLinux and Anolis OS on ARM64. Distribution branding alone is
not a compatibility guarantee; run the included diagnostics on each target.

## Install from a GitHub Release

Download the ARM64 archive and `SHA256SUMS` from the matching pre-release, then:

```bash
sha256sum -c SHA256SUMS
tar -xzf dsh-linux-arm64-offline-0.1.0-rc.7-stellaria.2.tar.gz
cd dsh-linux-arm64-offline-0.1.0-rc.7-stellaria.2
bash install.sh
```

After installation:

```bash
$HOME/.local/bin/dsh-diagnose
$HOME/.local/bin/dsh-configure-key
$HOME/.local/bin/dsh-web
```

The Web UI listens only on `127.0.0.1:3080`. Credentials are stored by the
upstream DSH credential mechanism in `~/.dsh/.credentials.yaml` with mode 600.

## How isolation works

Each install creates a versioned release under
`~/.local/share/dsh-kylin/releases/`. All ARM64 dynamic ELF executables and
native modules in that release are patched with a release-local PT_INTERP and
runtime search paths. As a result, `process.execPath`, `child_process.fork()`
and Node re-execution stay on the private glibc instead of falling back to the
host loader.

The system `/lib`, `/usr/lib`, loader cache and shell profiles are not changed.
Failed installs restore the previous `current` symlink.

## Repository vs. Release assets

This Git repository contains scripts, lock files, ABI audits, notices and build
metadata. It intentionally excludes the 100+ MiB binary payloads. Complete
offline archives are published as GitHub Release assets.

To reproduce a bundle on an online build host with Node 22/npm 10:

```bash
bash scripts/prepare-offline-package.sh
bash scripts/assemble-release.sh build/dsh-linux-arm64-offline \
  dsh-linux-arm64-offline-0.1.0-rc.7-stellaria.2
```

## Verification status

The committed audits cover 508 Conda ARM64 ELF files and 8 npm ARM64 ELF
files. The highest external requirements are GLIBC 2.28 and GLIBCXX 3.4.32,
both supplied in the bundle. GitHub Actions performs source checks and a real
ARM64 release-asset install on Ubuntu. Kylin kernel 4.4 qualification still
requires a real device or self-hosted runner.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md),
[SOURCE_AVAILABILITY.md](SOURCE_AVAILABILITY.md), [SECURITY.md](SECURITY.md),
and [CONTRIBUTING.md](CONTRIBUTING.md).
