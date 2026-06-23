import { mkdirSync, writeFileSync, readFileSync, realpathSync, rmSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir, hostname } from 'node:os';
import { createHash, randomBytes } from 'node:crypto';

const MAX_CLAIM_ATTEMPTS = 3;
const STABLE_READ_TRIES = 10;
const STABLE_READ_SLEEP_MS = 15;

function locksDir() {
  const agentHome = process.env.LAICLUSE_HOME || join(homedir(), '.laicluse');
  return join(agentHome, 'locks');
}

function ensureLocksDir() {
  mkdirSync(locksDir(), { recursive: true });
}

function canonicalDir(dir) {
  if (!dir || !String(dir).trim()) throw new Error('a directory path is required');
  if (!existsSync(dir)) throw new Error(`directory does not exist: ${dir}`);
  return realpathSync(dir);
}

function lockPathFor(dir) {
  return lockPathForRealpath(canonicalDir(dir));
}

function lockPathForRealpath(realpath) {
  const sha = createHash('sha256').update(realpath).digest('hex');
  return join(locksDir(), `${sha}.lock`);
}

function isAlive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (err) {
    return err.code === 'EPERM';
  }
}

export function formatHolder(record) {
  return `held by ${record.agent} (pid ${record.pid}) on ${record.hostname} since ${record.acquiredAt}`;
}

function buildRecord({ realpath, pid, agent, session, owner }) {
  return {
    realpath,
    pid,
    agent: agent || 'unknown',
    session: session || null,
    owner: owner || null,
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

// allow-comment: a partial write makes the record briefly unreadable; retry that, but treat a record still unreadable past the window as genuinely corrupt
function readRecordStable(path) {
  for (let i = 0; i < STABLE_READ_TRIES; i++) {
    const rec = readRecord(path);
    if (rec) return rec;
    if (!existsSync(path)) return null;
    sleepMs(STABLE_READ_SLEEP_MS);
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
  const alive = sameHost ? isAlive(record.pid) : null;
  if (sameHost) {
    if (!alive) return { breakable: true, reason: 'holder-dead', alive };
    if (ageExceeded(record, maxAgeHours)) return { breakable: true, reason: 'age-cap', alive };
    return { breakable: false, reason: 'holder-alive', alive };
  }
  if (ageExceeded(record, maxAgeHours)) return { breakable: true, reason: 'age-cap-foreign-host', alive };
  return { breakable: false, reason: 'foreign-host', alive };
}

function sameOwner(existing, incoming) {
  return existing.owner
    && incoming.owner
    && existing.owner === incoming.owner
    && existing.agent === incoming.agent;
}

function legacyCodexResume(existing, incoming, enabled) {
  return enabled
    && !existing.owner
    && incoming.owner
    && existing.agent === 'codex'
    && incoming.agent === 'codex'
    && existing.hostname !== hostname();
}

function inspectExisting(path, incoming, maxAgeHours, legacyCodexResumeEnabled) {
  const existing = readRecordStable(path);
  if (!existing) {
    return existsSync(path) ? { action: 'break', reason: 'corrupt' } : { action: 'retry' };
  }
  if (existing.hostname === hostname() && existing.pid === incoming.pid) {
    return { action: 'held-by-self', holder: existing };
  }
  if (sameOwner(existing, incoming)) {
    return { action: 'reclaim-by-owner', reason: 'same-owner', previous: existing };
  }
  if (legacyCodexResume(existing, incoming, legacyCodexResumeEnabled)) {
    return { action: 'reclaim-by-owner', reason: 'legacy-codex-resume', previous: existing };
  }
  const decision = classifyHolder(existing, maxAgeHours);
  return decision.breakable
    ? { action: 'break', reason: decision.reason, previous: existing }
    : { action: 'refuse', reason: decision.reason, holder: existing };
}

export function claim({ dir, pid, agent, session, owner, maxAgeHours, legacyCodexResume: legacyCodexResumeEnabled }) {
  const realpath = canonicalDir(dir);
  const path = lockPathForRealpath(realpath);
  ensureLocksDir();
  const record = buildRecord({ realpath, pid, agent, session, owner });
  const json = JSON.stringify(record, null, 2);
  let displaced = null;
  let displacedState = null;
  for (let attempt = 0; attempt < MAX_CLAIM_ATTEMPTS; attempt++) {
    try {
      // allow-comment: the exclusive wx create is the sole arbiter; do not relax it to an overwrite
      writeFileSync(path, json, { flag: 'wx' });
      if (displacedState === 'reclaimed-by-owner') return { ok: true, state: 'reclaimed-by-owner', path, holder: record, reclaimed: displaced };
      return displaced
        ? { ok: true, state: 'took-over-stale', path, holder: record, brokeStale: displaced }
        : { ok: true, state: 'claimed', path, holder: record };
    } catch (err) {
      if (err.code !== 'EEXIST') throw err;
    }
    const verdict = inspectExisting(path, record, maxAgeHours, legacyCodexResumeEnabled);
    if (verdict.action === 'held-by-self') {
      return { ok: true, state: 'held-by-self', path, holder: verdict.holder };
    }
    if (verdict.action === 'refuse') {
      return { ok: false, state: 'refused', path, holder: verdict.holder, reason: verdict.reason };
    }
    if (verdict.action === 'break') {
      rmSync(path, { force: true });
      displaced = { reason: verdict.reason, previous: verdict.previous };
      displacedState = 'took-over-stale';
    }
    if (verdict.action === 'reclaim-by-owner') {
      rmSync(path, { force: true });
      displaced = { reason: verdict.reason, previous: verdict.previous };
      displacedState = 'reclaimed-by-owner';
    }
  }
  const finalHolder = readRecordStable(path);
  if (!finalHolder) return { ok: false, state: 'refused', path, holder: null, reason: 'contended' };
  return { ok: false, state: 'refused', path, holder: finalHolder, reason: classifyHolder(finalHolder, maxAgeHours).reason };
}

export function release({ dir, pid, nonce }) {
  const path = lockPathForRealpath(canonicalDir(dir));
  const existing = readRecordStable(path);
  if (!existing) return { ok: true, state: 'not-held', path };
  const mine = existing.hostname === hostname()
    && existing.pid === pid
    && (nonce === undefined || existing.nonce === nonce);
  if (mine) {
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
  const decision = classifyHolder(existing, maxAgeHours);
  return {
    state: 'held',
    path,
    realpath,
    holder: existing,
    sameHost: existing.hostname === hostname(),
    alive: decision.alive,
    stale: decision.breakable,
  };
}
