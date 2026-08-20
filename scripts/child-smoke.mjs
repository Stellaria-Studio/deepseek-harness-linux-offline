if (typeof process.send !== 'function') process.exit(2);
process.send({ ok: true, execPath: process.execPath, arch: process.arch });
process.disconnect();
