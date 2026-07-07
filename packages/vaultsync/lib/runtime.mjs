import { accessSync, constants, existsSync, mkdirSync, readFileSync, realpathSync, readdirSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, isAbsolute, join, relative, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { homedir, platform, userInfo } from 'node:os';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';

export const DEFAULT_DEBOUNCE_SECONDS = 300;
export const DEFAULT_IDLE_POLL_SECONDS = 300;
export const DEFAULT_PAUSE_MINUTES = 120;
export const DIBS_PAUSE_EXTENSION_MINUTES = 60;
export const SERVICE_LABEL = 'com.laicluse.vaultsync';
const REGISTRATION_VERSION = 1;
const DAEMON_SLEEP_MS = 10000;
const MAX_REBASE_RESOLUTION_STEPS = 20;
const MAX_VERIFICATION_REPAIR_STEPS = 5;
const MAX_VERIFICATION_REPAIR_FILES = 1;
const MAX_VERIFICATION_REPAIR_FILE_BYTES = 60000;
const MAX_VERIFICATION_REPAIR_DETAIL_BYTES = 60000;

const sleepSlot = new Int32Array(new SharedArrayBuffer(4));

function sleepMs(ms) {
  Atomics.wait(sleepSlot, 0, 0, ms);
}

export function laicluseHome(env = process.env) {
  if (process.env.NODE_TEST_CONTEXT && !env.LAICLUSE_HOME && env.HOME === homedir()) {
    throw new Error('vaultsync: refusing the real laicluse home under the test runner; set LAICLUSE_HOME or HOME to a temp dir');
  }
  return env.LAICLUSE_HOME || join(env.HOME || homedir(), '.laicluse');
}

export function vaultsyncDir(env = process.env) {
  return join(laicluseHome(env), 'vaultsync');
}

export function registrationsDir(env = process.env) {
  return join(vaultsyncDir(env), 'registrations');
}

export function logsDir(env = process.env) {
  return join(vaultsyncDir(env), 'logs');
}

function ensureRuntimeDirs(env = process.env) {
  mkdirSync(registrationsDir(env), { recursive: true });
  mkdirSync(logsDir(env), { recursive: true });
}

function nowIso() {
  return new Date().toISOString();
}

function writeJsonAtomic(path, payload) {
  mkdirSync(dirname(path), { recursive: true });
  const tmp = `${path}.${process.pid}.tmp`;
  writeFileSync(tmp, `${JSON.stringify(payload, null, 2)}\n`);
  renameSync(tmp, path);
}

export function repoKey(rootRealpath) {
  return createHash('sha256').update(rootRealpath).digest('hex');
}

export function registrationPathForKey(key, env = process.env) {
  return join(registrationsDir(env), `${key}.json`);
}

export function registrationPathForRoot(rootRealpath, env = process.env) {
  return registrationPathForKey(repoKey(rootRealpath), env);
}

function readJsonFile(path) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

export function loadRegistrations(env = process.env) {
  const dir = registrationsDir(env);
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((entry) => entry.endsWith('.json'))
    .sort()
    .map((entry) => {
      const path = join(dir, entry);
      try {
        return { ...readJsonFile(path), path };
      } catch (err) {
        return { path, unreadable: true, error: err.message };
      }
    });
}

export function saveRegistration(registration, env = process.env) {
  const updated = { ...registration, updatedAt: nowIso() };
  writeJsonAtomic(registrationPathForKey(updated.key, env), updated);
  return updated;
}

function git(cwd, args, options = {}) {
  const result = spawnSync('git', args, {
    cwd,
    input: options.input,
    encoding: 'utf8',
    env: { ...process.env, ...(options.env || {}) },
  });
  if (result.error) {
    const err = new Error(result.error.message);
    err.exitCode = result.status || 1;
    throw err;
  }
  if (result.status !== 0 && !options.allowFailure) {
    const message = (result.stderr || result.stdout || `git ${args.join(' ')} failed`).trim();
    const err = new Error(message);
    err.exitCode = result.status || 1;
    throw err;
  }
  return result;
}

function gitOut(cwd, args, options = {}) {
  return git(cwd, args, options).stdout.trim();
}

function gitCombinedOutput(result) {
  return [result.stdout, result.stderr].filter(Boolean).join('\n');
}

function isManagedSyncGitGuard(output) {
  return /via '[^']+ sync' beheerd/.test(output) && output.includes('--no-verify');
}

function throwGitResult(result, fallbackMessage) {
  const output = gitCombinedOutput(result).trim();
  const err = new Error(output || fallbackMessage);
  err.exitCode = result.status || 1;
  throw err;
}

export function resolveGitRoot(dir, env = process.env) {
  const requested = resolve(dir || env.PWD || process.cwd());
  const result = spawnSync('git', ['-C', requested, 'rev-parse', '--show-toplevel'], { encoding: 'utf8' });
  if (result.status !== 0) {
    throw new Error(`not inside a Git worktree: ${requested}`);
  }
  return realpathSync(result.stdout.trim());
}

function resolveGitCommonDir(root) {
  const raw = gitOut(root, ['rev-parse', '--git-common-dir']);
  return realpathSync(resolve(root, raw));
}

function branchName(root) {
  const branch = gitOut(root, ['rev-parse', '--abbrev-ref', 'HEAD']);
  if (branch === 'HEAD') throw new Error('detached HEAD is not supported');
  return branch;
}

function upstreamName(root) {
  const result = git(root, ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}'], { allowFailure: true });
  if (result.status !== 0) {
    throw new Error('current branch has no upstream');
  }
  return result.stdout.trim();
}

function optionalUpstreamName(root) {
  const result = git(root, ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}'], { allowFailure: true });
  if (result.status !== 0) return null;
  return result.stdout.trim();
}

function statusPorcelain(root) {
  return gitOut(root, ['status', '--porcelain=v1', '-z']);
}

function isDirty(root) {
  return statusPorcelain(root).length > 0;
}

function changedPaths(root, staged = false) {
  const args = staged
    ? ['diff', '--cached', '--name-only', '-z']
    : ['status', '--porcelain=v1', '-z'];
  const raw = gitOut(root, args);
  if (!raw) return [];
  if (staged) return raw.split('\0').filter(Boolean);
  const entries = raw.split('\0').filter(Boolean);
  return entries.map((entry) => entry.slice(3)).filter(Boolean);
}

function aheadBehind(root) {
  const result = git(root, ['rev-list', '--left-right', '--count', 'HEAD...@{u}'], { allowFailure: true });
  if (result.status !== 0) return { ahead: 0, behind: 0, known: false };
  const [ahead, behind] = result.stdout.trim().split(/\s+/).map((n) => Number(n));
  return { ahead: ahead || 0, behind: behind || 0, known: true };
}

export function preflightRepository(dir, env = process.env) {
  const requestedCwd = resolve(dir || env.PWD || process.cwd());
  const rootRealpath = resolveGitRoot(requestedCwd, env);
  const branch = branchName(rootRealpath);
  const upstream = optionalUpstreamName(rootRealpath);
  const gitCommonDir = resolveGitCommonDir(rootRealpath);
  return {
    requestedCwd,
    rootRealpath,
    gitCommonDir,
    key: repoKey(rootRealpath),
    branch,
    upstream,
  };
}

function isExecutable(path) {
  try {
    accessSync(path, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

export function findDibsBin(env = process.env) {
  return findDibsBinForRegistration(null, env);
}

function childDirectoryNames(path) {
  try {
    return readdirSync(path, { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => entry.name);
  } catch {
    return [];
  }
}

function dibsPluginCacheRoots(env = process.env) {
  const home = env.HOME || homedir();
  return [
    join(home, '.codex', 'plugins', 'cache'),
    join(home, '.claude', 'plugins', 'cache'),
  ];
}

function versionSegmentForDibsPath(path) {
  const parts = String(path).split(/[\\/]/);
  return parts[parts.length - 3] || '';
}

function compareVersionSegments(left, right) {
  const leftMatch = /^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$/.exec(left);
  const rightMatch = /^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$/.exec(right);
  if (leftMatch && rightMatch) {
    for (let i = 1; i <= 3; i += 1) {
      const diff = Number(leftMatch[i]) - Number(rightMatch[i]);
      if (diff !== 0) return diff;
    }
    return 0;
  }
  if (leftMatch) return 1;
  if (rightMatch) return -1;
  return left.localeCompare(right);
}

function dibsCandidatesInCacheRoot(cacheRoot) {
  return childDirectoryNames(cacheRoot).flatMap((marketplace) => {
    const dibsRoot = join(cacheRoot, marketplace, 'dibs');
    return childDirectoryNames(dibsRoot).map((version) => join(dibsRoot, version, 'bin', 'dibs'));
  });
}

function dibsPluginCacheCandidates(env = process.env) {
  const candidates = dibsPluginCacheRoots(env).flatMap(dibsCandidatesInCacheRoot);
  return candidates.sort((left, right) => {
    const byVersion = compareVersionSegments(versionSegmentForDibsPath(right), versionSegmentForDibsPath(left));
    if (byVersion !== 0) return byVersion;
    return left.localeCompare(right);
  });
}

function isPluginCacheDibsPath(path) {
  const normalized = String(path).replace(/\\/g, '/');
  return normalized.includes('/plugins/cache/') && normalized.includes('/dibs/') && normalized.endsWith('/bin/dibs');
}

function findDibsBinForRegistration(registration, env = process.env) {
  const candidates = [];
  if (env.DIBS_BIN) candidates.push(env.DIBS_BIN);
  candidates.push(...dibsPluginCacheCandidates(env));
  for (const dir of (env.PATH || '').split(':').filter(Boolean)) {
    candidates.push(join(dir, 'dibs'));
  }
  if (registration?.dibsBin) candidates.push(registration.dibsBin);
  const seen = new Set();
  for (const candidate of candidates) {
    if (!candidate || seen.has(candidate)) continue;
    seen.add(candidate);
    if (isExecutable(candidate)) return candidate;
  }
  return null;
}

function registrationDibsBinForInstall(dibsBin) {
  if (!dibsBin || isPluginCacheDibsPath(dibsBin)) return null;
  return dibsBin;
}

function runDibs(registration, command, args = [], env = process.env) {
  const dibsBin = findDibsBinForRegistration(registration, env);
  if (!dibsBin) throw new Error('dibs executable not found; put dibs on PATH or set DIBS_BIN');
  const result = spawnSync(dibsBin, [command, registration.rootRealpath, '--json', ...args], {
    encoding: 'utf8',
    env,
  });
  if (result.error) {
    const err = new Error(`failed to start dibs at ${dibsBin}: ${result.error.message}`);
    err.exitCode = result.status || 1;
    throw err;
  }
  let json = null;
  try {
    json = result.stdout ? JSON.parse(result.stdout) : null;
  } catch {
    json = null;
  }
  if (result.status !== 0) {
    const err = new Error((json && json.error) || (result.stderr || '').trim() || (result.stdout || '').trim() || `dibs ${command} failed`);
    err.exitCode = result.status || 1;
    err.result = json;
    throw err;
  }
  return json;
}

function isHeldByThisProcess(checkResult) {
  return checkResult?.state === 'held'
    && checkResult.holder?.pid === process.pid
    && checkResult.holder?.agent === 'vaultsync';
}

function externalDibsLockActive(registration, env = process.env) {
  const result = runDibs(registration, 'check', [], env);
  return result.state === 'held' && !isHeldByThisProcess(result);
}

function claimDibs(registration, env = process.env) {
  return runDibs(registration, 'claim', [
    '--pid', String(process.pid),
    '--agent', 'vaultsync',
    '--session', `vaultsync-${registration.key}`,
    '--owner', registration.key,
  ], env);
}

function releaseDibs(registration, claimResult, env = process.env) {
  if (claimResult?.state === 'excluded') return null;
  const args = ['--pid', String(process.pid)];
  if (claimResult?.holder?.nonce) args.push('--nonce', claimResult.holder.nonce);
  return runDibs(registration, 'release', args, env);
}

export function fallbackCommitMessage(reason = 'debounce') {
  return [
    'Sync vault content',
    '',
    'Vaultsync captured Git-visible local changes before reconciling with the remote truth.',
    'This keeps the vault state durable and ready for the next sync cycle.',
    '',
    'Tests: n/a (docs-only)',
    'Slice: docs-only',
    'Red-then-green: n/a (no executable behaviour changed)',
    `Vaultsync-Reason: ${reason}`,
  ].join('\n');
}

function withoutVaultsyncTrailers(message) {
  return message
    .split('\n')
    .filter((line) => !/^(Tests|Slice|Red-then-green|Vaultsync-Reason):\s*/i.test(line.trim()))
    .join('\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function normalizeCommitMessage(message, reason) {
  const cleaned = String(message || '').replace(/\r\n/g, '\n').trim();
  if (!cleaned) return fallbackCommitMessage(reason);
  const content = withoutVaultsyncTrailers(cleaned);
  const [subject, ...rest] = content.split('\n');
  const body = rest.join('\n').trim();
  return [
    subject.trim() || 'Sync vault content',
    '',
    body || 'This sync records the local vault changes before reconciling with the remote truth.',
    '',
    'Tests: n/a (docs-only)',
    'Slice: docs-only',
    'Red-then-green: n/a (no executable behaviour changed)',
    `Vaultsync-Reason: ${reason}`,
  ].join('\n');
}

function shellCommand(command, { cwd, input, env = process.env, timeoutMs = 120000 } = {}) {
  const result = spawnSync(command, {
    cwd,
    input,
    env,
    shell: true,
    encoding: 'utf8',
    timeout: timeoutMs,
    maxBuffer: 20 * 1024 * 1024,
  });
  if (result.error) {
    const err = new Error(result.error.message);
    err.exitCode = result.status || 1;
    throw err;
  }
  return result;
}

function callLlm(registration, payload, { mandatory = false, timeoutMs = 120000 } = {}) {
  if (!registration.llmCommand) {
    if (mandatory) throw new Error('llmCommand is required for this vaultsync task');
    return null;
  }
  const result = shellCommand(registration.llmCommand, {
    cwd: registration.rootRealpath,
    input: `${JSON.stringify(payload)}\n`,
    timeoutMs,
  });
  if (result.status !== 0) {
    if (mandatory) {
      const err = new Error(result.stderr.trim() || result.stdout.trim() || 'LLM command failed');
      err.exitCode = result.status || 1;
      throw err;
    }
    return null;
  }
  try {
    return JSON.parse(result.stdout);
  } catch (err) {
    if (mandatory) throw new Error(`LLM command returned invalid JSON: ${err.message}`);
    return null;
  }
}

export function probeLlmCommand(llmCommand, rootRealpath = process.cwd()) {
  const registration = { llmCommand, rootRealpath };
  const result = callLlm(registration, {
    protocol: 'vaultsync.llm.v1',
    task: 'resolve_conflict',
    repository: { root: rootRealpath },
    path: 'probe.md',
    policy: {
      remoteTruth: true,
      sidecarPattern: '<name>.conflict-<extra-info>.md',
    },
    content: [
      '<<<<<<< HEAD',
      'Local draft line.',
      '=======',
      'Remote truth line.',
      '>>>>>>> upstream',
      '',
    ].join('\n'),
  }, { mandatory: true });
  if (!result || typeof result.resolved !== 'string' || result.resolved.includes('<<<<<<<')) {
    throw new Error('LLM command probe failed: resolve_conflict must return JSON with a resolved string and no conflict markers');
  }
  return true;
}

function llmCommitMessage(registration, diff, paths, reason) {
  const result = callLlm(registration, {
    protocol: 'vaultsync.llm.v1',
    task: 'commit_message',
    repository: {
      root: registration.rootRealpath,
      branch: safeGitInfo(registration.rootRealpath, branchName),
      upstream: safeGitInfo(registration.rootRealpath, upstreamName),
    },
    reason,
    paths,
    diff,
    requirements: {
      language: 'English',
      substantive: true,
      includeBody: true,
      includeSliceTrailer: true,
    },
  }, { mandatory: false });
  if (!result || typeof result.message !== 'string') return fallbackCommitMessage(reason);
  return normalizeCommitMessage(result.message, reason);
}

function safeGitInfo(root, fn) {
  try {
    return fn(root);
  } catch {
    return null;
  }
}

function resolveConflictFile(registration, path) {
  const fullPath = join(registration.rootRealpath, path);
  const content = readFileSync(fullPath, 'utf8');
  const result = callLlm(registration, {
    protocol: 'vaultsync.llm.v1',
    task: 'resolve_conflict',
    repository: {
      root: registration.rootRealpath,
      branch: safeGitInfo(registration.rootRealpath, branchName),
      upstream: safeGitInfo(registration.rootRealpath, upstreamName),
    },
    path,
    policy: {
      remoteTruth: true,
      sidecarPattern: '<name>.conflict-<extra-info>.md',
    },
    content,
  }, { mandatory: true, timeoutMs: 240000 });
  if (!result || typeof result.resolved !== 'string' || result.resolved.includes('<<<<<<<')) {
    throw new Error(`LLM did not resolve conflict markers in ${path}`);
  }
  writeFileSync(fullPath, result.resolved);
  git(registration.rootRealpath, ['add', '--', path]);
}

function conflictedPaths(root) {
  const raw = gitOut(root, ['diff', '--name-only', '--diff-filter=U', '-z']);
  return raw.split('\0').filter(Boolean);
}

function rebaseInProgress(root) {
  const common = resolveGitCommonDir(root);
  return existsSync(join(common, 'rebase-merge')) || existsSync(join(common, 'rebase-apply'));
}

function abortRebase(root) {
  if (!rebaseInProgress(root)) return;
  git(root, ['rebase', '--abort'], { allowFailure: true });
}

function pullRebaseWithLlm(registration) {
  const root = registration.rootRealpath;
  const pull = git(root, ['pull', '--rebase'], { allowFailure: true });
  if (pull.status === 0) return { rebased: true, conflictsResolved: 0 };
  if (!rebaseInProgress(root)) {
    const err = new Error((pull.stderr || pull.stdout || 'git pull --rebase failed').trim());
    err.exitCode = pull.status || 1;
    throw err;
  }
  let resolved = 0;
  try {
    for (let step = 0; step < MAX_REBASE_RESOLUTION_STEPS; step++) {
      const paths = conflictedPaths(root);
      if (paths.length === 0) {
        const cont = git(root, ['rebase', '--continue'], {
          allowFailure: true,
          env: { GIT_EDITOR: 'true' },
        });
        if (cont.status === 0) return { rebased: true, conflictsResolved: resolved };
        if (!rebaseInProgress(root)) {
          const err = new Error((cont.stderr || cont.stdout || 'git rebase --continue failed').trim());
          err.exitCode = cont.status || 1;
          throw err;
        }
        continue;
      }
      for (const path of paths) {
        resolveConflictFile(registration, path);
        resolved += 1;
      }
      const cont = git(root, ['rebase', '--continue'], {
        allowFailure: true,
        env: { GIT_EDITOR: 'true' },
      });
      if (cont.status === 0) return { rebased: true, conflictsResolved: resolved };
    }
    throw new Error('rebase did not complete after repeated conflict-resolution attempts');
  } catch (err) {
    abortRebase(root);
    throw err;
  }
}

function runVerification(registration) {
  if (!registration.verifyCommand) return { skipped: true };
  const result = shellCommand(registration.verifyCommand, {
    cwd: registration.rootRealpath,
    timeoutMs: 10 * 60 * 1000,
  });
  if (result.status !== 0) {
    const err = new Error(`verification command failed: ${registration.verifyCommand}`);
    const detail = [result.stdout, result.stderr].filter(Boolean).join('\n').trim();
    err.detail = detail.slice(0, 4000);
    err.repairDetail = detail.slice(0, MAX_VERIFICATION_REPAIR_DETAIL_BYTES);
    err.exitCode = result.status || 1;
    throw err;
  }
  return { skipped: false };
}

function isTextRepairPath(path) {
  return /\.(md|markdown|txt|csv|tsv|json|ya?ml)$/i.test(path);
}

function safeRelativePath(root, path) {
  const abs = isAbsolute(path) ? path : join(root, path);
  const rel = relative(root, abs);
  if (!rel || rel.startsWith('..') || isAbsolute(rel)) return null;
  return rel;
}

function parseVerifierPaths(root, detail = '') {
  const out = [];
  const rootPrefix = `${root}/`;
  for (const line of String(detail).split('\n')) {
    const start = line.indexOf(rootPrefix);
    if (start < 0) continue;
    const tail = line.slice(start + rootPrefix.length);
    const match = tail.match(/^(.+?\.(?:md|markdown|txt|csv|tsv|json|ya?ml))(?::|\s|$)/i);
    if (match) out.push(match[1]);
  }
  return out;
}

function readRepairCandidate(root, path) {
  const rel = safeRelativePath(root, path);
  if (!rel || !isTextRepairPath(rel)) return null;
  const full = join(root, rel);
  if (!existsSync(full)) return null;
  const content = readFileSync(full, 'utf8');
  if (Buffer.byteLength(content, 'utf8') > MAX_VERIFICATION_REPAIR_FILE_BYTES) return null;
  return { path: rel, content };
}

function verificationRepairCandidates(registration, verificationError, cyclePaths = []) {
  const root = registration.rootRealpath;
  const cycle = new Set(cyclePaths.map((p) => safeRelativePath(root, p)).filter(Boolean));
  const verifier = parseVerifierPaths(root, verificationError.repairDetail || verificationError.detail);
  const candidates = [];
  const add = (path) => {
    const candidate = readRepairCandidate(root, path);
    if (!candidate || candidates.some((c) => c.path === candidate.path)) return;
    candidates.push(candidate);
  };
  for (const path of verifier) {
    add(path);
  }
  for (const path of cycle) add(path);
  return candidates.slice(0, MAX_VERIFICATION_REPAIR_FILES);
}

function verifierDetailForFiles(root, detail, files) {
  const text = String(detail || '');
  const absolutePaths = files.map((file) => `${root}/${file.path}`);
  const lines = text.split('\n').filter((line) => absolutePaths.some((path) => line.includes(path)));
  return (lines.length > 0 ? lines.join('\n') : text).slice(0, MAX_VERIFICATION_REPAIR_DETAIL_BYTES);
}

function mechanicalVerifierRepairs(registration, verificationError) {
  const root = registration.rootRealpath;
  const byPath = new Map();
  const detail = verificationError.repairDetail || verificationError.detail || '';
  for (const line of String(detail).split('\n')) {
    const path = parseVerifierPaths(root, line)[0];
    if (!path) continue;
    const current = byPath.get(path) || { trailingWhitespace: false, finalNewline: false, blankRuns: false };
    if (line.includes('trailing whitespace')) current.trailingWhitespace = true;
    if (line.includes('geen afsluitende newline')) current.finalNewline = true;
    if (line.includes('drie of meer opeenvolgende lege regels')) current.blankRuns = true;
    byPath.set(path, current);
  }
  const paths = [];
  for (const [path, fixes] of byPath) {
    const candidate = readRepairCandidate(root, path);
    if (!candidate) continue;
    let content = candidate.content;
    if (fixes.trailingWhitespace) content = content.replace(/[ \t]+$/gm, '');
    if (fixes.blankRuns) content = content.replace(/\n{3,}/g, '\n\n');
    if (fixes.finalNewline && !content.endsWith('\n')) content = `${content}\n`;
    if (content === candidate.content) continue;
    writeFileSync(join(root, candidate.path), content);
    paths.push(candidate.path);
  }
  return { repaired: paths.length > 0, kind: 'mechanical', paths };
}

function repairVerificationFailure(registration, verificationError, cyclePaths, reason) {
  const files = verificationRepairCandidates(registration, verificationError, cyclePaths);
  if (files.length === 0) return { repaired: false, reason: 'no-repair-candidates', paths: [] };
  const allowed = new Set(files.map((file) => file.path));
  const repairDetail = verifierDetailForFiles(
    registration.rootRealpath,
    verificationError.repairDetail || verificationError.detail || '',
    files,
  );
  const result = callLlm(registration, {
    protocol: 'vaultsync.llm.v1',
    task: 'repair_verifier',
    repository: {
      root: registration.rootRealpath,
      branch: safeGitInfo(registration.rootRealpath, branchName),
      upstream: safeGitInfo(registration.rootRealpath, upstreamName),
    },
    reason,
    verifier: {
      command: registration.verifyCommand,
      message: verificationError.message,
      detail: repairDetail,
    },
    policy: {
      modifyOnlyIncludedFiles: true,
      preserveUserMeaning: true,
      noSecrets: true,
      noToolAttribution: true,
    },
    files,
  }, { mandatory: true, timeoutMs: 240000 });
  const repairs = Array.isArray(result?.repairs) ? result.repairs : [];
  const written = [];
  for (const repair of repairs) {
    if (!repair || typeof repair.path !== 'string' || typeof repair.content !== 'string') continue;
    const rel = safeRelativePath(registration.rootRealpath, repair.path);
    if (!rel || !allowed.has(rel) || !isTextRepairPath(rel)) continue;
    writeFileSync(join(registration.rootRealpath, rel), repair.content);
    written.push(rel);
  }
  return { repaired: written.length > 0, paths: written };
}

function verifyWithRepairs(registration, cyclePaths, reason) {
  const repairs = [];
  for (let step = 0; step <= MAX_VERIFICATION_REPAIR_STEPS; step += 1) {
    try {
      const verification = runVerification(registration);
      if (repairs.length > 0) verification.repairs = repairs;
      return { verification, repaired: repairs.length > 0 };
    } catch (err) {
      if (step === MAX_VERIFICATION_REPAIR_STEPS) throw err;
      let repair = mechanicalVerifierRepairs(registration, err);
      if (!repair.repaired) repair = repairVerificationFailure(registration, err, cyclePaths, reason);
      if (!repair.repaired) throw err;
      const repairCommit = commitDirtyState(registration, `${reason}-verifier-repair`);
      if (!repairCommit.committed) throw err;
      repairs.push(repair);
    }
  }
  throw new Error('verification repair loop exhausted unexpectedly');
}

function pushCurrentBranch(root) {
  const push = git(root, ['push'], { allowFailure: true });
  if (push.status === 0) return push;
  const output = gitCombinedOutput(push);
  if (!isManagedSyncGitGuard(output)) throwGitResult(push, 'git push failed');
  return git(root, ['push', '--no-verify']);
}

function fetchRemote(root) {
  if (!optionalUpstreamName(root)) return { skipped: true };
  return git(root, ['fetch', '--quiet']);
}

function aheadChangedPaths(root) {
  const result = git(root, ['diff', '--name-only', '-z', '@{u}...HEAD'], { allowFailure: true });
  if (result.status !== 0 || !result.stdout) return [];
  return result.stdout.split('\0').filter(Boolean);
}

function commitDirtyState(registration, reason) {
  const root = registration.rootRealpath;
  git(root, ['add', '-A']);
  const diff = gitOut(root, ['diff', '--cached', '--no-ext-diff']);
  if (!diff.trim()) return { committed: false, paths: [] };
  const paths = changedPaths(root, true);
  const message = llmCommitMessage(registration, diff, paths, reason);
  const commit = git(root, ['commit', '-F', '-'], { input: `${message.trim()}\n`, allowFailure: true });
  if (commit.status !== 0) {
    const output = gitCombinedOutput(commit);
    if (!isManagedSyncGitGuard(output)) throwGitResult(commit, 'git commit failed');
    git(root, ['commit', '--no-verify', '-F', '-'], { input: `${message.trim()}\n` });
  }
  return { committed: true, paths };
}

function maybeExtendExpiredPause(registration, env = process.env) {
  if (!registration.pausedUntil) return { active: false, registration };
  const until = Date.parse(registration.pausedUntil);
  if (!Number.isFinite(until)) return { active: false, registration };
  if (until > Date.now()) return { active: true, registration };
  if (externalDibsLockActive(registration, env)) {
    const extended = {
      ...registration,
      pausedUntil: new Date(Date.now() + DIBS_PAUSE_EXTENSION_MINUTES * 60000).toISOString(),
      pauseReason: registration.pauseReason || 'dibs lock still active at pause expiry',
      lastError: null,
    };
    return { active: true, registration: saveRegistration(extended, env), extended: true };
  }
  return { active: false, registration: saveRegistration({ ...registration, pausedUntil: null, pauseReason: null }, env) };
}

export async function runCycle(registration, { reason = 'daemon', force = false, env = process.env } = {}) {
  let reg = registration;
  const pause = maybeExtendExpiredPause(reg, env);
  reg = pause.registration;
  if (pause.active) {
    return { state: pause.extended ? 'pause-extended' : 'paused', registration: reg };
  }
  const preflight = preflightRepository(reg.rootRealpath, env);
  if (preflight.key !== reg.key) {
    throw new Error(`registration key mismatch for ${reg.rootRealpath}`);
  }
  fetchRemote(reg.rootRealpath);
  const dirty = isDirty(reg.rootRealpath);
  const relation = aheadBehind(reg.rootRealpath);
  if (!dirty && relation.ahead === 0 && relation.behind === 0 && !force) {
    return saveCycleResult(reg, { state: 'idle', lastPollAt: nowIso(), lastError: null }, env);
  }
  let claim = null;
  try {
    claim = claimDibs(reg, env);
    let committed = null;
    if (dirty) {
      committed = commitDirtyState(reg, reason);
    }
    let afterCommitRelation = aheadBehind(reg.rootRealpath);
    let rebase = { rebased: false, conflictsResolved: 0 };
    if (afterCommitRelation.known && (afterCommitRelation.behind > 0 || committed?.committed)) {
      rebase = pullRebaseWithLlm(reg);
      afterCommitRelation = aheadBehind(reg.rootRealpath);
    }
    const cyclePaths = committed?.committed ? committed.paths : aheadChangedPaths(reg.rootRealpath);
    const verificationResult = verifyWithRepairs(reg, cyclePaths, reason);
    const verification = verificationResult.verification;
    if (verificationResult.repaired) {
      afterCommitRelation = aheadBehind(reg.rootRealpath);
    }
    if (afterCommitRelation.known && (afterCommitRelation.ahead > 0 || committed?.committed)) {
      pushCurrentBranch(reg.rootRealpath);
    }
    return saveCycleResult(reg, {
      state: 'synced',
      lastCycleAt: nowIso(),
      lastPollAt: nowIso(),
      lastSeenDirtyAt: null,
      lastError: null,
      lastResult: {
        reason,
        committed: Boolean(committed?.committed),
        paths: committed?.paths || [],
        rebased: rebase.rebased,
        conflictsResolved: rebase.conflictsResolved,
	upstream: optionalUpstreamName(reg.rootRealpath),
        verification,
      },
    }, env);
  } catch (err) {
    const at = nowIso();
    let stillDirty = true;
    try {
      stillDirty = isDirty(reg.rootRealpath);
    } catch {
      stillDirty = true;
    }
    return saveCycleResult(reg, {
      state: 'error',
      lastCycleAt: at,
      lastPollAt: at,
      lastSeenDirtyAt: stillDirty ? reg.lastSeenDirtyAt : null,
      lastError: {
        at,
        message: err.message,
        detail: err.detail || null,
      },
    }, env, err);
  } finally {
    if (claim) releaseDibs(reg, claim, env);
  }
}

function saveCycleResult(registration, patch, env, throwAfterSave = null) {
  const saved = saveRegistration({ ...registration, ...patch }, env);
  if (throwAfterSave) throw throwAfterSave;
  return { state: patch.state, registration: saved, result: patch.lastResult || null };
}

function registrationForDir(dir, env = process.env) {
  const root = resolveGitRoot(dir || env.PWD || process.cwd(), env);
  const path = registrationPathForRoot(root, env);
  if (!existsSync(path)) throw new Error(`vaultsync is not installed for ${root}`);
  return readJsonFile(path);
}

function parseCommonTarget(args, env = process.env) {
  const parsed = parseArgs({
    args,
    allowPositionals: true,
    options: {
      json: { type: 'boolean', default: false },
    },
  });
  return {
    dir: parsed.positionals[0] || env.PWD || process.cwd(),
    json: parsed.values.json,
  };
}

function emit(data, json = false) {
  if (json) process.stdout.write(`${JSON.stringify(data, null, 2)}\n`);
  else if (typeof data === 'string') process.stdout.write(`${data}\n`);
  else process.stdout.write(`${JSON.stringify(data, null, 2)}\n`);
}

async function commandInstall(args, env = process.env) {
  const parsed = parseArgs({
    args,
    allowPositionals: true,
    options: {
      'llm-command': { type: 'string' },
      verify: { type: 'string' },
      'debounce-seconds': { type: 'string' },
      'idle-poll-seconds': { type: 'string' },
      json: { type: 'boolean', default: false },
      'no-launchd': { type: 'boolean', default: false },
    },
  });
  const dir = parsed.positionals[0] || env.PWD || process.cwd();
  const preflight = preflightRepository(dir, env);
  const dibsBin = findDibsBin(env);
  if (!dibsBin) throw new Error('dibs executable not found; put dibs on PATH or set DIBS_BIN before installing');
  const llmCommand = parsed.values['llm-command'] || env.VAULTSYNC_LLM_COMMAND;
  if (!llmCommand) throw new Error('--llm-command is required; vaultsync must have a conflict resolver');
  probeLlmCommand(llmCommand, preflight.rootRealpath);
  ensureRuntimeDirs(env);
  const registration = {
    version: REGISTRATION_VERSION,
    key: preflight.key,
    requestedCwd: preflight.requestedCwd,
    rootRealpath: preflight.rootRealpath,
    gitCommonDir: preflight.gitCommonDir,
    branchAtInstall: preflight.branch,
    upstreamAtInstall: preflight.upstream,
    llmCommand,
    verifyCommand: parsed.values.verify || null,
    debounceSeconds: numberOption(parsed.values['debounce-seconds'], DEFAULT_DEBOUNCE_SECONDS, 'debounce-seconds'),
    idlePollSeconds: numberOption(parsed.values['idle-poll-seconds'], DEFAULT_IDLE_POLL_SECONDS, 'idle-poll-seconds'),
    enabled: true,
    pausedUntil: null,
    pauseReason: null,
    lastSeenDirtyAt: null,
    lastCycleAt: null,
    lastPollAt: null,
    lastError: null,
    createdAt: nowIso(),
  };
  const registrationDibsBin = registrationDibsBinForInstall(dibsBin);
  if (registrationDibsBin) registration.dibsBin = registrationDibsBin;
  const savedRegistration = saveRegistration(registration, env);
  const launchd = parsed.values['no-launchd'] ? { skipped: true } : installLaunchAgent(env);
  emit({
    installed: true,
    requestedCwd: preflight.requestedCwd,
    gitRoot: preflight.rootRealpath,
    branch: preflight.branch,
    upstream: preflight.upstream,
    registration: registrationPathForKey(savedRegistration.key, env),
    launchd,
  }, parsed.values.json);
}

function numberOption(value, fallback, name) {
  if (value == null) return fallback;
  const n = Number(value);
  if (!Number.isInteger(n) || n <= 0) throw new Error(`--${name} must be a positive integer`);
  return n;
}

function commandDoctor(args, env = process.env) {
  const parsed = parseArgs({
    args,
    allowPositionals: true,
    options: {
      'llm-command': { type: 'string' },
      json: { type: 'boolean', default: false },
    },
  });
  const preflight = preflightRepository(parsed.positionals[0] || env.PWD || process.cwd(), env);
  const dibsBin = findDibsBin(env);
  const llmCommand = parsed.values['llm-command'] || env.VAULTSYNC_LLM_COMMAND;
  const llmProbe = llmCommand ? probeLlmCommand(llmCommand, preflight.rootRealpath) : false;
  emit({ ...preflight, dibsBin, llmProbe }, parsed.values.json);
}

function commandStatus(args, env = process.env) {
  const parsed = parseArgs({
    args,
    allowPositionals: true,
    options: {
      json: { type: 'boolean', default: false },
    },
  });
  const regs = parsed.positionals[0]
    ? [registrationForDir(parsed.positionals[0], env)]
    : loadRegistrations(env).filter((reg) => !reg.unreadable);
  const statuses = regs.map((reg) => {
    let live = {};
    try {
      live = {
        branch: branchName(reg.rootRealpath),
	upstream: optionalUpstreamName(reg.rootRealpath),
        dirty: isDirty(reg.rootRealpath),
        relation: aheadBehind(reg.rootRealpath),
      };
    } catch (err) {
      live = { error: err.message };
    }
    return {
      key: reg.key,
      root: reg.rootRealpath,
      enabled: reg.enabled,
      pausedUntil: reg.pausedUntil,
      pauseReason: reg.pauseReason,
      lastCycleAt: reg.lastCycleAt,
      lastPollAt: reg.lastPollAt,
      lastError: reg.lastError,
      live,
    };
  });
  if (parsed.values.json) return emit(statuses, true);
  if (statuses.length === 0) return emit('No vaultsync registrations found.');
  const lines = [];
  for (const status of statuses) {
    lines.push(status.root);
    lines.push(`  branch: ${status.live.branch || '(unknown)'}`);
    lines.push(`  upstream: ${status.live.upstream || '(unknown)'}`);
    lines.push(`  dirty: ${status.live.dirty === true ? 'yes' : 'no'}`);
    if (status.live.relation?.known) lines.push(`  ahead/behind: ${status.live.relation.ahead}/${status.live.relation.behind}`);
    if (status.pausedUntil) lines.push(`  paused until: ${status.pausedUntil}`);
    if (status.lastError) lines.push(`  last error: ${status.lastError.message}`);
  }
  emit(lines.join('\n'));
}

function commandPause(args, env = process.env) {
  const parsed = parseArgs({
    args,
    allowPositionals: true,
    options: {
      minutes: { type: 'string' },
      until: { type: 'string' },
      reason: { type: 'string' },
      json: { type: 'boolean', default: false },
    },
  });
  const dir = parsed.positionals[0] || env.PWD || process.cwd();
  const reg = registrationForDir(dir, env);
  let until;
  if (parsed.values.until) {
    until = new Date(parsed.values.until);
    if (!Number.isFinite(until.getTime())) throw new Error('--until must be an ISO-like date/time');
  } else {
    const minutes = numberOption(parsed.values.minutes, DEFAULT_PAUSE_MINUTES, 'minutes');
    until = new Date(Date.now() + minutes * 60000);
  }
  const saved = saveRegistration({
    ...reg,
    pausedUntil: until.toISOString(),
    pauseReason: parsed.values.reason || 'manual pause',
  }, env);
  emit({ paused: true, root: saved.rootRealpath, until: saved.pausedUntil }, parsed.values.json);
}

function commandResume(args, env = process.env) {
  const target = parseCommonTarget(args, env);
  const reg = registrationForDir(target.dir, env);
  const saved = saveRegistration({ ...reg, pausedUntil: null, pauseReason: null }, env);
  emit({ resumed: true, root: saved.rootRealpath }, target.json);
}

async function commandNow(args, env = process.env) {
  const target = parseCommonTarget(args, env);
  const reg = registrationForDir(target.dir, env);
  const result = await runCycle(reg, { reason: 'manual', force: true, env });
  emit(result, target.json);
}

async function commandDaemon(args, env = process.env) {
  const parsed = parseArgs({
    args,
    allowPositionals: false,
    options: {
      once: { type: 'boolean', default: false },
      json: { type: 'boolean', default: false },
    },
  });
  ensureRuntimeDirs(env);
  const result = await daemonTick(env);
  if (parsed.values.once) {
    emit(result, parsed.values.json);
    return;
  }
  process.stdout.write(`vaultsync daemon running (${SERVICE_LABEL})\n`);
  process.on('SIGTERM', () => process.exit(0));
  process.on('SIGINT', () => process.exit(0));
  while (true) {
    sleepMs(DAEMON_SLEEP_MS);
    await daemonTick(env);
  }
}

export async function daemonTick(env = process.env) {
  const registrations = loadRegistrations(env).filter((reg) => !reg.unreadable && reg.enabled !== false);
  const results = [];
  for (const reg of registrations) {
    try {
      const dirty = isDirty(reg.rootRealpath);
      const now = Date.now();
      const lastSeenDirtyAt = reg.lastSeenDirtyAt ? Date.parse(reg.lastSeenDirtyAt) : null;
      if (dirty && !lastSeenDirtyAt) {
        saveRegistration({ ...reg, lastSeenDirtyAt: nowIso() }, env);
        results.push({ root: reg.rootRealpath, state: 'debouncing' });
        continue;
      }
      const debounceMs = (reg.debounceSeconds || DEFAULT_DEBOUNCE_SECONDS) * 1000;
      if (dirty && lastSeenDirtyAt && now - lastSeenDirtyAt >= debounceMs) {
        results.push(await runCycle(reg, { reason: 'debounce', force: true, env }));
        continue;
      }
      const lastPollAt = reg.lastPollAt ? Date.parse(reg.lastPollAt) : 0;
      const pollMs = (reg.idlePollSeconds || DEFAULT_IDLE_POLL_SECONDS) * 1000;
      if (!dirty && now - lastPollAt >= pollMs) {
        results.push(await runCycle(reg, { reason: 'poll', force: false, env }));
        continue;
      }
      results.push({ root: reg.rootRealpath, state: dirty ? 'debouncing' : 'waiting' });
    } catch (err) {
      const saved = saveRegistration({
        ...reg,
        lastError: { at: nowIso(), message: err.message, detail: err.detail || null },
      }, env);
      results.push({ root: reg.rootRealpath, state: 'error', registration: saved, error: err.message });
    }
  }
  return results;
}

function currentBinPath() {
  return fileURLToPath(new URL('../bin/vaultsync', import.meta.url));
}

function xmlEscape(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

export function launchAgentPlist(env = process.env) {
  const outLog = join(logsDir(env), 'daemon.out.log');
  const errLog = join(logsDir(env), 'daemon.err.log');
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${SERVICE_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${xmlEscape(process.execPath)}</string>
    <string>${xmlEscape(currentBinPath())}</string>
    <string>daemon</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key>
    <false/>
  </dict>
  <key>StandardOutPath</key>
  <string>${xmlEscape(outLog)}</string>
  <key>StandardErrorPath</key>
  <string>${xmlEscape(errLog)}</string>
</dict>
</plist>
`;
}

export function installLaunchAgent(env = process.env) {
  if (platform() !== 'darwin') return { skipped: true, reason: 'launchd is only available on macOS' };
  ensureRuntimeDirs(env);
  const launchAgents = join(env.HOME || homedir(), 'Library', 'LaunchAgents');
  mkdirSync(launchAgents, { recursive: true });
  const plistPath = join(launchAgents, `${SERVICE_LABEL}.plist`);
  writeFileSync(plistPath, launchAgentPlist(env));
  const uid = userInfo().uid;
  spawnSync('launchctl', ['bootout', `gui/${uid}`, plistPath], { encoding: 'utf8' });
  const bootstrap = spawnSync('launchctl', ['bootstrap', `gui/${uid}`, plistPath], { encoding: 'utf8' });
  if (bootstrap.status !== 0) {
    throw new Error((bootstrap.stderr || bootstrap.stdout || 'launchctl bootstrap failed').trim());
  }
  spawnSync('launchctl', ['kickstart', '-k', `gui/${uid}/${SERVICE_LABEL}`], { encoding: 'utf8' });
  return { installed: true, label: SERVICE_LABEL, plist: plistPath };
}

export async function runCommand(command, args, env = process.env) {
  switch (command) {
    case 'install': return commandInstall(args, env);
    case 'status': return commandStatus(args, env);
    case 'pause': return commandPause(args, env);
    case 'resume': return commandResume(args, env);
    case 'now': return commandNow(args, env);
    case 'daemon': return commandDaemon(args, env);
    case 'doctor': return commandDoctor(args, env);
    default: throw new Error(`unknown command: ${command}`);
  }
}

export function testInternals() {
  return {
    git,
    gitOut,
    isDirty,
    aheadBehind,
    statusPorcelain,
    changedPaths,
  };
}
