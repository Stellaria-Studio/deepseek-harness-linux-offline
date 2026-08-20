import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const lock = JSON.parse(fs.readFileSync(path.join(root, 'metadata/dsh-package-lock.json'), 'utf8'));
const solve = JSON.parse(fs.readFileSync(path.join(root, 'metadata/conda-solve-plan.json'), 'utf8'));
const packages = [];
const inventory = ['ecosystem\tname\tversion\tlicense\tsource'];
let serial = 0;

function clean(value) { return String(value).replace(/[^A-Za-z0-9.-]+/g, '-').replace(/^-|-$/g, ''); }
function add(pkg) {
  serial += 1;
  pkg.SPDXID = `SPDXRef-Package-${serial}-${clean(pkg.name)}`;
  packages.push(pkg);
  inventory.push([pkg.ecosystem, pkg.name, pkg.versionInfo, pkg.licenseDeclared, pkg.downloadLocation].join('\t'));
}
function npmName(lockPath) {
  const tail = lockPath.split('node_modules/').at(-1);
  return tail.startsWith('@') ? tail.split('/').slice(0, 2).join('/') : tail.split('/')[0];
}
function npmPurlName(name) {
  if (!name.startsWith('@')) return encodeURIComponent(name);
  const [scope, packageName] = name.slice(1).split('/', 2);
  return `%40${encodeURIComponent(scope)}/${encodeURIComponent(packageName)}`;
}
function licenseFields(raw) {
  const invalid = new Set([
    'blessing',
    'license',
    'LGPL-2.0-or-later AND LGPL-2.0-or-later WITH exceptions AND GPL-2.0-or-later',
  ]);
  if (!raw) return { licenseDeclared: 'NOASSERTION' };
  if (invalid.has(raw)) {
    return { licenseDeclared: 'NOASSERTION', licenseComments: `Upstream metadata declared: ${raw}` };
  }
  return { licenseDeclared: raw };
}
function sriChecksum(integrity) {
  if (!integrity) return undefined;
  const [algorithm, encoded] = integrity.split('-', 2);
  if (algorithm !== 'sha512' || !encoded) return undefined;
  return { algorithm: 'SHA512', checksumValue: Buffer.from(encoded, 'base64').toString('hex').toUpperCase() };
}

for (const [lockPath, entry] of Object.entries(lock.packages)) {
  if (!lockPath || !lockPath.includes('node_modules/') || !entry.version) continue;
  const name = npmName(lockPath);
  const checksum = sriChecksum(entry.integrity);
  add({
    ecosystem: 'npm', name, versionInfo: entry.version,
    downloadLocation: entry.resolved || 'NOASSERTION',
    filesAnalyzed: false,
    licenseConcluded: 'NOASSERTION',
    ...licenseFields(entry.license),
    copyrightText: 'NOASSERTION',
    externalRefs: [{ referenceCategory: 'PACKAGE-MANAGER', referenceType: 'purl', referenceLocator: `pkg:npm/${npmPurlName(name)}@${entry.version}` }],
    ...(checksum ? { checksums: [checksum] } : {}),
  });
}

for (const entry of solve.actions?.FETCH || []) {
  add({
    ecosystem: 'conda', name: entry.name, versionInfo: `${entry.version}-${entry.build}`,
    downloadLocation: entry.url || 'NOASSERTION', filesAnalyzed: false,
    licenseConcluded: 'NOASSERTION', ...licenseFields(entry.license),
    copyrightText: 'NOASSERTION',
    checksums: [{ algorithm: 'SHA256', checksumValue: entry.sha256.toUpperCase() }],
    externalRefs: [{ referenceCategory: 'PACKAGE-MANAGER', referenceType: 'purl', referenceLocator: `pkg:conda/${entry.name}@${entry.version}?build=${encodeURIComponent(entry.build)}&subdir=${entry.subdir}` }],
  });
}

const fixed = [
  ['Miniforge', '26.3.2-3', 'BSD-3-Clause', 'https://github.com/conda-forge/miniforge/releases/tag/26.3.2-3', '2c113a69297e612b01ca0f320c22a3107a11f2ab9b573d79ac868a175945ce29'],
  ['Debian-libc6-arm64', '2.28-10+deb10u4', 'LGPL-2.1-or-later', 'https://archive.debian.org/debian/pool/main/g/glibc/libc6_2.28-10+deb10u4_arm64.deb', '299556e1d1bf80617b417c82521f1f0bcb111933c40016fbe8a303b73e6a6a22'],
  ['Debian-libgcc1-arm64', '8.3.0-6', 'GPL-3.0-or-later WITH GCC-exception-3.1', 'https://archive.debian.org/debian-archive/debian/pool/main/g/gcc-8/libgcc1_8.3.0-6_arm64.deb', '2851ac25d12958586c035de5ec4f2fc17272dec48f776dd0dd24c62f62674fd9'],
  ['Debian-libstdc++6-arm64', '8.3.0-6', 'GPL-3.0-or-later WITH GCC-exception-3.1', 'https://archive.debian.org/debian-archive/debian/pool/main/g/gcc-8/libstdc++6_8.3.0-6_arm64.deb', '52cf36333a405867a079a695f6a37cb63558859d7d19cef40fc7d112c39fefd6'],
  ['Debian-patchelf-arm64', '0.9+52.20180509-1', 'GPL-3.0-or-later', 'https://archive.debian.org/debian/pool/main/p/patchelf/patchelf_0.9+52.20180509-1_arm64.deb', 'a261bd96bdd2f2c9b240589f3319e24a567c604af5c9132e0da970f2cbd6b1ab'],
];
for (const [name, versionInfo, licenseDeclared, downloadLocation, checksum] of fixed) {
  add({ ecosystem: 'binary', name, versionInfo, downloadLocation, filesAnalyzed: false,
    licenseConcluded: 'NOASSERTION', licenseDeclared, copyrightText: 'NOASSERTION',
    checksums: [{ algorithm: 'SHA256', checksumValue: checksum.toUpperCase() }] });
}

const namespaceHash = crypto.createHash('sha256').update(packages.map(p => `${p.name}@${p.versionInfo}`).join('\n')).digest('hex');
const document = {
  spdxVersion: 'SPDX-2.3', dataLicense: 'CC0-1.0', SPDXID: 'SPDXRef-DOCUMENT',
  name: 'deepseek-harness-linux-offline-0.1.0-rc.7-stellaria.1',
  documentNamespace: `https://github.com/Stellaria-Studio/deepseek-harness-linux-offline/sbom/${namespaceHash}`,
  creationInfo: { created: '2026-08-20T00:00:00Z', creators: ['Organization: Stellaria Studio', 'Tool: scripts/generate-sbom.mjs'] },
  packages: packages.map(({ ecosystem, ...pkg }) => pkg),
  relationships: packages.map(pkg => ({ spdxElementId: 'SPDXRef-DOCUMENT', relationshipType: 'DESCRIBES', relatedSpdxElement: pkg.SPDXID })),
};
fs.mkdirSync(path.join(root, 'sbom'), { recursive: true });
fs.writeFileSync(path.join(root, 'sbom/SBOM.spdx.json'), `${JSON.stringify(document, null, 2)}\n`);
fs.writeFileSync(path.join(root, 'metadata/dependencies-license-inventory.tsv'), `${inventory.join('\n')}\n`);
console.log(`Generated SPDX packages: ${packages.length}`);
