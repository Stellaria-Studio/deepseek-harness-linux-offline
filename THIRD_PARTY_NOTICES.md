# Third-Party Notices

The root MIT license covers only original Stellaria Studio scripts and
documentation. Offline Release assets aggregate independently licensed
software; no single repository license replaces those terms.

## Major redistributed components

| Component | Version | License summary | Source |
| --- | --- | --- | --- |
| DeepSeek Harness | 0.1.0-rc.7 | MIT | https://github.com/deepseek-ai/deepseek-harness |
| Node.js | 22.23.2 | MIT plus bundled third-party notices | https://github.com/nodejs/node |
| Miniforge | 26.3.2-3 | BSD-3-Clause installer; embedded packages retain their licenses | https://github.com/conda-forge/miniforge |
| GNU C Library | 2.28-10+deb10u4 | LGPL-2.1-or-later and component-specific terms | https://sourceware.org/git/glibc.git |
| GCC runtime libraries | 8.3.0-6 / 16.1.0 | GPL with GCC Runtime Library Exception and component-specific terms | https://gcc.gnu.org/git/gcc.git |
| patchelf | 0.9+52.20180509-1 | GPL-3.0-or-later | https://github.com/NixOS/patchelf |
| sharp / libvips | 0.35.3 / 8.18.3 payload | Apache-2.0 / LGPL-2.1-or-later | https://github.com/lovell/sharp / https://github.com/libvips/libvips |

The exact npm dependency lock is `metadata/dsh-package-lock.json`; Conda
package versions, declared licenses, URLs and hashes are derived from
`metadata/conda-solve-plan.json`. A generated SPDX 2.3 inventory is kept in
`sbom/SBOM.spdx.json` and attached to each release.

## Where license texts are preserved

- DeepSeek Harness and npm package tarballs retain their upstream license files.
- Each Conda archive retains `info/licenses/` and package metadata.
- Debian runtime files retain `/usr/share/doc/<package>/copyright` in the
  offline payload.
- Miniforge retains its installer notice and package license metadata.
- Representative notices are copied to `licenses/` for convenient review.

## Corresponding source

Canonical source locations and exact binary URLs are recorded in
`metadata/source-urls.txt`, `metadata/conda-sources.tsv`, npm lock `resolved`
fields and the SPDX SBOM. See [SOURCE_AVAILABILITY.md](SOURCE_AVAILABILITY.md)
for the source and recipe retrieval map. Stellaria Studio does not claim
authorship of those components.
