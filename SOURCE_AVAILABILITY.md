# Source Availability

Release assets contain unmodified upstream binary packages and cached npm
tarballs. Their corresponding source and build recipes remain available from
the upstream locations below under each component's own license.

## Exact package provenance

- DeepSeek Harness: the exact npm tarball, repository and lock data are listed
  in `metadata/source-urls.txt` and `metadata/dsh-package-lock.json`.
- Debian compatibility runtime: exact binary package URLs and SHA-256 values
  are listed in `metadata/source-urls.txt` and
  `metadata/debian-runtime-sha256s.txt`. Matching Debian source packages are in
  the same Debian archive pool directories.
- Conda runtime and toolchain: exact package URLs, builds and SHA-256 values are
  listed in `metadata/conda-sources.tsv`,
  `metadata/conda-package-sha256s.txt` and
  `metadata/conda-solve-plan.json`. Each package retains its `info/recipe` and
  `info/licenses` metadata; corresponding recipes are maintained in the
  package's conda-forge feedstock.
- Miniforge: source, installer release and license are available from the
  conda-forge Miniforge repository and the exact release recorded in
  `metadata/source-urls.txt`.
- npm dependencies: each `resolved` URL and integrity value is preserved in
  `metadata/dsh-package-lock.json`; cached package tarballs retain upstream
  license files.

The generated `sbom/SBOM.spdx.json` maps the complete locked inventory to its
download location and declared license. The Release archive also preserves
Debian copyright files, Conda package metadata and representative notices in
`licenses/`.

If an exact upstream source or recipe can no longer be retrieved, open an issue
before relying on or redistributing that Release. Maintainers will provide the
retained corresponding source where available or withdraw the affected asset.
