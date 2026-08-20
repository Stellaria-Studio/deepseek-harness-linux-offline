# Contributing

Contributions for additional GNU/Linux distributions and architectures are
welcome, but each platform must have an independent payload, ELF audit and
runtime qualification. Do not relabel an ARM64 archive for another architecture.

Before opening a pull request:

1. Keep upstream DeepSeek Harness unmodified unless a narrowly documented fix
   is unavoidable.
2. Preserve the no-sudo, target-offline and no-global-`LD_LIBRARY_PATH` model.
3. Add exact versions, source URLs, hashes, license metadata and an SPDX SBOM.
4. Run `bash -n` on every shell script and the applicable ARM64 smoke tests.
5. Never commit archives, package caches, API keys or other files above 100 MiB.

Kernel 4.4 claims require evidence from a real device or self-hosted runner.
Clearly separate static ABI checks, hosted ARM64 tests and actual Kylin results.
