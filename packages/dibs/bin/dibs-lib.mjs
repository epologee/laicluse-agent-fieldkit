import { mkdirSync, writeFileSync, readFileSync, realpathSync, rmSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { homedir, hostname } from 'node:os';
import { createHash, randomBytes } from 'node:crypto';

export function locksDir() {
  const agentHome = process.env.LAICLUSE_HOME || join(homedir(), '.laicluse');
  return join(agentHome, 'locks');
}

function ensureLocksDir() {
  mkdirSync(locksDir(), { recursive: true });
}

export function canonicalDir(dir) {
  if (!dir || !String(dir).trim()) throw new Error('a directory path is required');
  try {
    return realpathSync(dir);
  } catch {
    return resolve(dir);
  }
}

export function lockPathFor(dir) {
  return lockPathForRealpath(canonicalDir(dir));
}

function lockPathForRealpath(realpath) {
  const sha = createHash('sha256').update(realpath).digest('hex');
  return join(locksDir(), `${sha}.lock`);
}

export function isAlive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (err) {
    return err.code === 'EPERM';
  }
}

function buildRecord({ realpath, pid, agent, session }) {
  return {
    realpath,
    pid,
    agent: agent || 'unknown',
    session: session || null,
    hostname: hostname(),
    nonce: randomBytes(8).toString('hex'),
    acquiredAt: new Date().toISOString(),
  };
}

function readRecord(path) {
  try {
    const rec = JSON.parse(readFileSync(path, 'utf8'));
    if (!rec || typeof rec !== 'object' || typeof rec.pid !== 'number') return null;
    return rec;
  } catch {
    return null;
  }
}

const SLEEP_SLOT = new Int32Array(new SharedArrayBuffer(4));

function sleepMs(ms) {
  Atomics.wait(SLEEP_SLOT, 0, 0, ms);
}

// allow-comment: distinguishes a lock caught mid-write (retry) from a truly corrupt one (give up)
function readRecordStable(path) {
  for (let i = 0; i < 10; i++) {
    const rec = readRecord(path);
    if (rec) return rec;
    if (!existsSync(path)) return null;
    sleepMs(15);
  }
  return null;
}

function ageExceeded(record, maxAgeHours) {
  if (!maxAgeHours || maxAgeHours <= 0) return false;
  const acquired = Date.parse(record.acquiredAt);
  if (Number.isNaN(acquired)) return false;
  return Date.now() - acquired > maxAgeHours * 3600 * 1000;
}

function classifyHolder(record, maxAgeHours) {
  const sameHost = record.hostname === hostname();
  if (sameHost) {
    if (!isAlive(record.pid)) return { breakable: true, reason: 'holder-dead' };
    if (ageExceeded(record, maxAgeHours)) return { breakable: true, reason: 'age-cap' };
    return { breakable: false, reason: 'holder-alive' };
  }
  if (ageExceeded(record, maxAgeHours)) return { breakable: true, reason: 'age-cap-foreign-host' };
  return { breakable: false, reason: 'foreign-host' };
}

export function claim({ dir, pid, agent, session, maxAgeHours }) {
  if (!existsSync(dir)) throw new Error(`directory does not exist: ${dir}`);
  const realpath = canonicalDir(dir);
  const path = lockPathForRealpath(realpath);
  ensureLocksDir();
  const record = buildRecord({ realpath, pid, agent, session });
  const json = JSON.stringify(record, null, 2);
  let broke = null;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      // allow-comment: the exclusive wx create is the sole arbiter; do not relax it to an overwrite
      writeFileSync(path, json, { flag: 'wx' });
      return broke
        ? { ok: true, state: 'took-over-stale', path, holder: record, brokeStale: broke }
        : { ok: true, state: 'claimed', path, holder: record };
    } catch (err) {
      if (err.code !== 'EEXIST') throw err;
    }
    const existing = readRecordStable(path);
    if (!existing) {
      if (existsSync(path)) {
        rmSync(path, { force: true });
        broke = { reason: 'corrupt' };
      }
      continue;
    }
    if (existing.hostname === hostname() && existing.pid === pid) {
      return { ok: true, state: 'held-by-self', path, holder: existing };
    }
    const decision = classifyHolder(existing, maxAgeHours);
    if (!decision.breakable) {
      return { ok: false, state: 'refused', path, holder: existing, reason: decision.reason };
    }
    rmSync(path, { force: true });
    broke = { reason: decision.reason, previous: existing };
  }
  const finalHolder = readRecordStable(path);
  return finalHolder
    ? { ok: false, state: 'refused', path, holder: finalHolder, reason: 'holder-alive' }
    : { ok: false, state: 'refused', path, holder: null, reason: 'contended' };
}

export function release({ dir, pid }) {
  const path = lockPathForRealpath(canonicalDir(dir));
  const existing = readRecordStable(path);
  if (!existing) return { ok: true, state: 'not-held', path };
  if (existing.hostname === hostname() && existing.pid === pid) {
    rmSync(path, { force: true });
    return { ok: true, state: 'released', path, holder: existing };
  }
  return { ok: false, state: 'held-by-other', path, holder: existing };
}

export function check({ dir, maxAgeHours }) {
  const realpath = canonicalDir(dir);
  const path = lockPathForRealpath(realpath);
  const existing = readRecordStable(path);
  if (!existing) {
    return existsSync(path)
      ? { state: 'corrupt', path, realpath }
      : { state: 'free', path, realpath };
  }
  const sameHost = existing.hostname === hostname();
  return {
    state: 'held',
    path,
    realpath,
    holder: existing,
    sameHost,
    alive: sameHost ? isAlive(existing.pid) : null,
    stale: classifyHolder(existing, maxAgeHours).breakable,
  };
}
