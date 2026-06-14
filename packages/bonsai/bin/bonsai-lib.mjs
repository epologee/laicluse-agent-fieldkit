import { existsSync, mkdirSync, writeFileSync, readFileSync, copyFileSync, readdirSync, statSync } from 'node:fs';
import { join, resolve, dirname, basename } from 'node:path';
import { execFileSync } from 'node:child_process';

export function git(repo, args) {
  return execFileSync('git', args, { cwd: repo, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
}

export function isGitRepo(repo) {
  try {
    git(repo, ['rev-parse', '--is-inside-work-tree']);
    return true;
  } catch {
    return false;
  }
}

export function branchToDir(branch) {
  return branch.replace(/\//g, '-');
}

// Deterministic dev-server port hint in [3100, 3999]. Cross-platform and
// dependency-free; the value is a hint, not a guarantee of freeness.
export function computePort(name) {
  let h = 5381;
  for (let i = 0; i < name.length; i++) h = ((h << 5) + h + name.charCodeAt(i)) >>> 0;
  return 3100 + (h % 900);
}

function refExists(repo, ref) {
  try {
    git(repo, ['rev-parse', '--verify', '--quiet', ref]);
    return true;
  } catch {
    return false;
  }
}

// Freshest default branch: prefer origin/<default> only when origin is strictly
// ahead of the local ref; otherwise the local ref. Falls back to HEAD.
export function resolveBase(repo) {
  let local = null;
  for (const candidate of ['main', 'master']) {
    if (refExists(repo, `refs/heads/${candidate}`)) {
      local = candidate;
      break;
    }
  }
  if (!local) return 'HEAD';
  if (!refExists(repo, `refs/remotes/origin/${local}`)) return local;
  try {
    const counts = git(repo, ['rev-list', '--left-right', '--count', `refs/heads/${local}...refs/remotes/origin/${local}`]).trim();
    const [ahead, behind] = counts.split(/\s+/).map((n) => parseInt(n, 10));
    return ahead === 0 && behind > 0 ? `origin/${local}` : local;
  } catch {
    return local;
  }
}

export function createWorktree({ repo, branch, base }) {
  if (!isGitRepo(repo)) {
    throw new Error(`${repo} is not a git repository`);
  }
  const resolvedBase = base || resolveBase(repo);
  const baseSha = git(repo, ['rev-parse', resolvedBase]).trim();
  const worktreesDir = join(repo, 'worktrees');
  mkdirSync(worktreesDir, { recursive: true });
  const gitignore = join(worktreesDir, '.gitignore');
  if (!existsSync(gitignore)) writeFileSync(gitignore, '*\n');
  const dir = branchToDir(branch);
  const worktree = join(worktreesDir, dir);
  if (refExists(repo, `refs/heads/${branch}`)) {
    throw new Error(`branch ${branch} already exists in ${repo}; wrap and tear down that work first, never a numbered branch`);
  }
  git(repo, ['worktree', 'add', '-b', branch, worktree, resolvedBase]);
  return { worktree, branch, base: resolvedBase, baseSha, port: computePort(dir) };
}

const INSTALL_COMMANDS = {
  yarn: ['yarn', ['install', '--frozen-lockfile']],
  pnpm: ['pnpm', ['install', '--frozen-lockfile']],
  bun: ['bun', ['install']],
  npm: ['npm', ['install']],
  bundler: ['bundle', ['install']],
};

function readBonsaiList(repo) {
  const file = join(repo, '.bonsai');
  if (!existsSync(file)) return [];
  return readFileSync(file, 'utf8')
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#'));
}

export function detectInstalls(worktree) {
  const dirs = [worktree];
  for (const name of readdirSync(worktree)) {
    if (name === 'node_modules') continue;
    const p = join(worktree, name);
    try {
      if (statSync(p).isDirectory()) dirs.push(p);
    } catch {}
  }
  const installs = [];
  for (const dir of dirs) {
    if (existsSync(join(dir, 'package.json'))) {
      const manager = existsSync(join(dir, 'yarn.lock')) ? 'yarn'
        : existsSync(join(dir, 'pnpm-lock.yaml')) ? 'pnpm'
        : (existsSync(join(dir, 'bun.lock')) || existsSync(join(dir, 'bun.lockb'))) ? 'bun'
        : 'npm';
      installs.push({ dir, manager });
    }
    if (existsSync(join(dir, 'Gemfile'))) installs.push({ dir, manager: 'bundler' });
  }
  return installs;
}

export function setupWorktree({ repo, worktree, install = true, exec = execFileSync }) {
  if (!existsSync(worktree)) throw new Error(`worktree ${worktree} does not exist`);
  const copied = [];
  const warnings = [];
  for (const rel of readBonsaiList(repo)) {
    const from = join(repo, rel);
    if (!existsSync(from)) continue;
    const to = join(worktree, rel);
    mkdirSync(dirname(to), { recursive: true });
    copyFileSync(from, to);
    copied.push(rel);
  }
  const installs = detectInstalls(worktree);
  let ran = false;
  if (install) {
    for (const { dir, manager } of installs) {
      const [cmd, args] = INSTALL_COMMANDS[manager];
      try {
        exec(cmd, args, { cwd: dir, stdio: ['ignore', 'pipe', 'pipe'] });
        ran = true;
      } catch (err) {
        warnings.push(`install in ${dir} via ${manager} failed: ${err.message.split('\n')[0]}`);
      }
    }
  }
  return { worktree, copied, installs, ran, warnings };
}

export function defaultBranch(repo) {
  for (const candidate of ['main', 'master']) {
    if (refExists(repo, `refs/heads/${candidate}`)) return candidate;
  }
  return null;
}

function parseWorktrees(repo) {
  const out = git(repo, ['worktree', 'list', '--porcelain']);
  const entries = [];
  let cur = {};
  for (const line of out.split('\n')) {
    if (line.startsWith('worktree ')) {
      if (cur.path) entries.push(cur);
      cur = { path: line.slice('worktree '.length) };
    } else if (line.startsWith('branch ')) {
      cur.branch = line.slice('branch '.length).replace('refs/heads/', '');
    } else if (line === '' && cur.path) {
      entries.push(cur);
      cur = {};
    }
  }
  if (cur.path) entries.push(cur);
  return entries;
}

function isAncestor(repo, a, b) {
  try {
    git(repo, ['merge-base', '--is-ancestor', a, b]);
    return true;
  } catch {
    return false;
  }
}

function countRange(repo, range) {
  try {
    return parseInt(git(repo, ['rev-list', '--count', range]).trim(), 10) || 0;
  } catch {
    return 0;
  }
}

function branchPushed(repo, branch) {
  try {
    const up = git(repo, ['rev-parse', '--abbrev-ref', `${branch}@{upstream}`]).trim();
    if (!up) return false;
    return countRange(repo, `${up}..${branch}`) === 0;
  } catch {
    return false;
  }
}

export function classifyTeardown({ repo, target }) {
  const worktrees = parseWorktrees(repo);
  const abs = resolve(target);
  let entry = worktrees.find((w) => resolve(w.path) === abs)
    || worktrees.find((w) => w.branch === target)
    || worktrees.find((w) => resolve(w.path) === resolve(join(repo, 'worktrees', target)));
  if (!entry) throw new Error(`no worktree or branch matching ${target} in ${repo}`);
  const { path: worktree, branch } = entry;
  const def = defaultBranch(repo);
  const dirty = git(worktree, ['status', '--porcelain']).trim().length > 0;
  const integrated = def && branch ? isAncestor(repo, branch, def) : false;
  const ahead = def && branch ? countRange(repo, `${def}..${branch}`) : 0;
  const behind = def && branch ? countRange(repo, `${branch}..${def}`) : 0;
  const pushed = branch ? branchPushed(repo, branch) : false;
  const removable = integrated || (!dirty && ahead === 0);
  const warnings = [];
  if (ahead > 0 && !pushed) warnings.push(`${ahead} unpushed commit(s) ahead of ${def} would be orphaned by removal`);
  if (behind > 0) warnings.push(`${def} advanced by ${behind} commit(s) since this branch; rebase before wrap`);
  if (dirty) warnings.push('worktree has uncommitted changes');
  if (branch && worktrees.filter((w) => w.branch === branch).length > 1) {
    warnings.push(`branch ${branch} is checked out in more than one worktree`);
  }
  return { worktree, branch, integrated, dirty, ahead, behind, pushed, removable, warnings };
}

function keptReasonFor(c) {
  if (c.dirty) return 'worktree has uncommitted changes; commit them or pass --force';
  if (!c.integrated && c.ahead > 0) return `branch has ${c.ahead} unmerged commit(s); wrap them or pass --force`;
  return 'not integrated and not safe to drop; pass --force to override';
}

export function teardownWorktree({ repo, target, force = false, dryRun = false }) {
  const c = classifyTeardown({ repo, target });
  const base = { worktree: c.worktree, branch: c.branch, removable: c.removable, warnings: c.warnings };
  if (dryRun) return { ...base, removed: false, keptReason: c.removable ? null : keptReasonFor(c) };
  if (!c.removable && !force) return { ...base, removed: false, keptReason: keptReasonFor(c) };
  git(repo, ['worktree', 'remove', ...(force ? ['--force'] : []), c.worktree]);
  if (c.branch) {
    try {
      git(repo, ['branch', force ? '-D' : '-d', c.branch]);
    } catch {}
  }
  return { ...base, removed: true, keptReason: null };
}
