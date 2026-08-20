import { fork, spawnSync } from 'node:child_process';
import { Worker } from 'node:worker_threads';
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { promises as dns } from 'node:dns';
import https from 'node:https';

const log = (name, value = 'OK') => console.log(`[node-smoke] ${name}=${value}`);
const assert = (condition, message) => { if (!condition) throw new Error(message); };

assert(process.platform === 'linux', `platform ${process.platform}`);
assert(process.arch === 'arm64', `arch ${process.arch}`);
log('process', `${process.version} ${process.platform}/${process.arch}`);
log('execPath', process.execPath);

const dir = mkdtempSync(join(tmpdir(), 'dsh-node-smoke-'));
try {
  const path = join(dir, 'value.txt');
  writeFileSync(path, 'deepseek-harness', { mode: 0o600 });
  assert(readFileSync(path, 'utf8') === 'deepseek-harness', 'filesystem mismatch');
  log('filesystem');
} finally {
  rmSync(dir, { recursive: true, force: true });
}

const spawned = spawnSync(process.execPath, ['-e', 'process.stdout.write(process.execPath)'], { encoding: 'utf8' });
assert(spawned.status === 0 && spawned.stdout === process.execPath, `spawn failed: ${spawned.stderr}`);
log('child_process.spawn', spawned.stdout);

const childFile = join(dirname(fileURLToPath(import.meta.url)), 'child-smoke.mjs');
await new Promise((resolve, reject) => {
  const child = fork(childFile, [], { stdio: ['ignore', 'ignore', 'pipe', 'ipc'], timeout: 8000 });
  let received = false;
  child.once('message', message => {
    received = Boolean(message?.ok && message?.execPath === process.execPath && message?.arch === 'arm64');
  });
  child.once('error', reject);
  child.once('exit', code => received && code === 0 ? resolve() : reject(new Error(`fork code=${code}`)));
});
log('child_process.fork');

await new Promise((resolve, reject) => {
  const worker = new Worker('const {parentPort}=require("node:worker_threads"); parentPort.postMessage(6*7)', { eval: true });
  worker.once('message', value => value === 42 ? resolve() : reject(new Error(`worker value=${value}`)));
  worker.once('error', reject);
});
log('worker_threads');

assert(createHash('sha256').update('dsh').digest('hex').length === 64, 'crypto failed');
log('crypto');

if (process.argv.includes('--network')) {
  try {
    const addresses = await Promise.race([
      dns.resolve4('api.deepseek.com'),
      new Promise((_, reject) => setTimeout(() => reject(new Error('DNS timeout')), 5000)),
    ]);
    log('dns', addresses.join(','));
  } catch (error) {
    log('dns', `UNAVAILABLE (${error.message})`);
  }
  await new Promise(resolve => {
    const request = https.request('https://api.deepseek.com/', { method: 'HEAD', timeout: 7000 }, response => {
      response.resume();
      log('https_tls', `HTTP ${response.statusCode}`);
      resolve();
    });
    request.on('timeout', () => request.destroy(new Error('timeout')));
    request.on('error', error => { log('https_tls', `UNAVAILABLE (${error.message})`); resolve(); });
    request.end();
  });
}
