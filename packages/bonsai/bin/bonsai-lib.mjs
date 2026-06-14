import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
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
