import { after, before, it } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { tmpdir } from 'node:os';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import {
  DEFAULT_PAUSE_MINUTES,
  fallbackCommitMessage,
  findDibsBin,
  preflightRepository,
  probeLlmCommand,
  registrationPathForRoot,
  repoKey,
  resolveGitRoot,
} from '../runtime.mjs';

let tmp;

before(() => {
  tmp = mkdtempSync(join(tmpdir(), 'vaultsync-test-'));
});

after(() => {
  rmSync(tmp, { recursive: true, force: true });
});

function git(cwd, args) {
  return execFileSync('git', args, {
    cwd,
    encoding: 'utf8',
    env: {
      ...process.env,
      GIT_AUTHOR_NAME: 'Vaultsync Test',
      GIT_AUTHOR_EMAIL: 'vaultsync@example.invalid',
      GIT_COMMITTER_NAME: 'Vaultsync Test',
      GIT_COMMITTER_EMAIL: 'vaultsync@example.invalid',
    },
  }).trim();
}

function createRepo(name) {
  const dir = join(tmp, name);
  mkdirSync(dir);
  git(dir, ['init', '-q']);
  writeFileSync(join(dir, 'README.md'), '# Test\n');
  git(dir, ['add', 'README.md']);
  git(dir, ['commit', '-q', '-m', 'Initial commit']);
  return dir;
}

function runNode(args, options = {}) {
  const result = spawnSync(process.execPath, args, {
    encoding: 'utf8',
    env: { ...process.env, ...(options.env || {}) },
    cwd: options.cwd || tmp,
  });
  if (result.status !== 0) {
    throw new Error([result.stdout, result.stderr].filter(Boolean).join('\n'));
  }
  return result;
}

it('keys registrations by the resolved Git worktree root', () => {
  const repo = createRepo('identity-main');
  mkdirSync(join(repo, 'notes'));
  const root = resolveGitRoot(join(repo, 'notes'), { PWD: repo, HOME: tmp, LAICLUSE_HOME: join(tmp, 'home') });
  assert.equal(root, realpathSync(repo));
  assert.equal(repoKey(root), repoKey(realpathSync(repo)));
  assert.equal(registrationPathForRoot(root, { HOME: tmp, LAICLUSE_HOME: join(tmp, 'home') }), join(tmp, 'home', 'vaultsync', 'registrations', `${repoKey(root)}.json`));
});

it('keeps linked worktrees isolated from the main checkout', () => {
  const repo = createRepo('identity-worktree-main');
  const linked = join(tmp, 'identity-worktree-linked');
  git(repo, ['worktree', 'add', '-q', linked, '-b', 'linked']);
  assert.notEqual(repoKey(resolveGitRoot(repo)), repoKey(resolveGitRoot(linked)));
});

it('allows repository preflight without a branch upstream', () => {
  const repo = createRepo('no-upstream');
  const preflight = preflightRepository(repo);
  assert.equal(preflight.branch, git(repo, ['rev-parse', '--abbrev-ref', 'HEAD']));
  assert.equal(preflight.upstream, null);
});

it('reports whether a checkout is managed through the public CLI', () => {
  const managed = createRepo('managed-query-managed');
  const unmanaged = createRepo('managed-query-unmanaged');
  const fakeDibs = join(tmp, 'managed-query-dibs.mjs');
  writeFileSync(fakeDibs, [
    '#!/usr/bin/env node',
    'const command = process.argv[2];',
    'if (command === "claim") process.stdout.write(JSON.stringify({ state: "claimed", holder: { nonce: "abc" } }));',
    'else if (command === "release") process.stdout.write(JSON.stringify({ state: "released" }));',
    'else if (command === "check") process.stdout.write(JSON.stringify({ state: "free" }));',
    'else process.exit(2);',
    '',
  ].join('\n'), { mode: 0o755 });
  const llm = join(tmp, 'managed-query-llm.mjs');
  writeFileSync(llm, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task === "resolve_conflict") process.stdout.write(JSON.stringify({ resolved: "Remote truth line.\\n" }));',
    '  else if (payload.task === "commit_message") process.stdout.write(JSON.stringify({ message: "Record managed query\\n\\nExercise the managed query contract.\\n\\nSlice: docs-only" }));',
    '  else process.exit(2);',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  const cli = fileURLToPath(new URL('../../bin/vaultsync', import.meta.url));
  const env = {
    LAICLUSE_HOME: join(tmp, 'managed-query-home'),
    DIBS_BIN: fakeDibs,
    HOME: tmp,
  };
  runNode([cli, 'install', managed, '--llm-command', `${process.execPath} ${llm}`, '--no-launchd'], { env });

  const managedResult = JSON.parse(runNode([cli, 'managed', managed, '--json'], { env }).stdout);
  const unmanagedResult = JSON.parse(runNode([cli, 'managed', unmanaged, '--json'], { env }).stdout);

  assert.equal(managedResult.managed, true);
  assert.equal(managedResult.root, realpathSync(managed));
  assert.equal(unmanagedResult.managed, false);
  assert.equal(unmanagedResult.root, realpathSync(unmanaged));
});

it('formats a git-discipline-friendly fallback commit message', () => {
  const message = fallbackCommitMessage('debounce');
  assert.match(message, /^Sync vault content\n\n/);
  assert.match(message, /Tests: n\/a \(docs-only\)/);
  assert.match(message, /Slice: docs-only/);
  assert.match(message, /Red-then-green: n\/a \(no executable behaviour changed\)/);
  assert.match(message, /Vaultsync-Reason: debounce/);
});

it('finds dibs through DIBS_BIN first', () => {
  const fake = join(tmp, 'fake-dibs');
  writeFileSync(fake, '#!/bin/sh\nexit 0\n', { mode: 0o755 });
  assert.equal(findDibsBin({ DIBS_BIN: fake, PATH: '' }), fake);
});

it('finds the newest dibs executable in the local plugin cache', () => {
  const home = join(tmp, 'plugin-cache-home');
  const oldDibs = join(home, '.codex', 'plugins', 'cache', 'laicluse-agent-fieldkit', 'dibs', '2.0.30', 'bin', 'dibs');
  const currentDibs = join(home, '.codex', 'plugins', 'cache', 'laicluse-agent-fieldkit', 'dibs', '2.0.31', 'bin', 'dibs');
  mkdirSync(dirname(oldDibs), { recursive: true });
  mkdirSync(dirname(currentDibs), { recursive: true });
  writeFileSync(oldDibs, '#!/bin/sh\nexit 0\n', { mode: 0o755 });
  writeFileSync(currentDibs, '#!/bin/sh\nexit 0\n', { mode: 0o755 });

  assert.equal(findDibsBin({ HOME: home, PATH: '' }), currentDibs);
});

it('probes the mandatory conflict resolver contract', () => {
  const helper = join(tmp, 'llm-helper.mjs');
  writeFileSync(helper, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task !== "resolve_conflict") process.exit(2);',
    '  process.stdout.write(JSON.stringify({ resolved: "Remote truth line.\\n" }));',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  assert.equal(probeLlmCommand(`node ${helper}`, tmp), true);
});

it('keeps the default pause window at two hours', () => {
  assert.equal(DEFAULT_PAUSE_MINUTES, 120);
});

it('ignores a stale registered dibs path when a current dibs is discoverable', () => {
  const local = createRepo('stale-dibs');

  const installDibs = join(tmp, 'stale-install-dibs.mjs');
  writeFileSync(installDibs, [
    '#!/usr/bin/env node',
    'const command = process.argv[2];',
    'if (command === "claim") process.stdout.write(JSON.stringify({ state: "claimed", holder: { nonce: "abc" } }));',
    'else if (command === "release") process.stdout.write(JSON.stringify({ state: "released" }));',
    'else if (command === "check") process.stdout.write(JSON.stringify({ state: "free" }));',
    'else process.exit(2);',
    '',
  ].join('\n'), { mode: 0o755 });
  const pathDibsDir = join(tmp, 'stale-path-bin');
  mkdirSync(pathDibsDir);
  const pathDibs = join(pathDibsDir, 'dibs');
  writeFileSync(pathDibs, readFileSync(installDibs, 'utf8'), { mode: 0o755 });
  const llm = join(tmp, 'stale-llm.mjs');
  writeFileSync(llm, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task === "commit_message") process.stdout.write(JSON.stringify({ message: "Record stale dibs recovery\\n\\nCapture the vault edit after resolving dibs dynamically.\\n\\nSlice: docs-only" }));',
    '  else if (payload.task === "resolve_conflict") process.stdout.write(JSON.stringify({ resolved: "Remote truth line.\\n" }));',
    '  else process.exit(2);',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  const cli = fileURLToPath(new URL('../../bin/vaultsync', import.meta.url));
  const env = {
    LAICLUSE_HOME: join(tmp, 'stale-home'),
    DIBS_BIN: installDibs,
    HOME: tmp,
    GIT_AUTHOR_NAME: 'Vaultsync Test',
    GIT_AUTHOR_EMAIL: 'vaultsync@example.invalid',
    GIT_COMMITTER_NAME: 'Vaultsync Test',
    GIT_COMMITTER_EMAIL: 'vaultsync@example.invalid',
  };
  runNode([cli, 'install', local, '--llm-command', `${process.execPath} ${llm}`, '--no-launchd'], { env });

  const registrationPath = registrationPathForRoot(realpathSync(local), env);
  const registration = JSON.parse(readFileSync(registrationPath, 'utf8'));
  writeFileSync(registrationPath, JSON.stringify({ ...registration, dibsBin: join(tmp, 'missing-dibs') }, null, 2));
  writeFileSync(join(local, 'README.md'), '# Test\n\nChanged with stale dibs registration.\n');

  runNode([cli, 'now', local, '--json'], {
    env: {
      ...env,
      DIBS_BIN: '',
      PATH: `${pathDibsDir}:${process.env.PATH}`,
    },
  });

  const saved = JSON.parse(readFileSync(registrationPath, 'utf8'));
  assert.equal(git(local, ['status', '--porcelain']), '');
  assert.equal(saved.lastError, null);
  assert.match(git(local, ['log', '-1', '--pretty=%s']), /Record stale dibs recovery/);
});

it('installs and runs one dirty checkout sync cycle against a bare remote', () => {
  const remote = join(tmp, 'sync-remote.git');
  const local = join(tmp, 'sync-local');
  git(tmp, ['init', '--bare', '-q', remote]);
  git(tmp, ['clone', '-q', remote, local]);
  writeFileSync(join(local, 'note.md'), '# Note\n');
  git(local, ['add', 'note.md']);
  git(local, ['commit', '-q', '-m', 'Initial commit']);
  git(local, ['push', '-q', '-u', 'origin', 'HEAD']);

  const fakeDibs = join(tmp, 'sync-dibs.mjs');
  writeFileSync(fakeDibs, [
    '#!/usr/bin/env node',
    'const command = process.argv[2];',
    'if (command === "claim") process.stdout.write(JSON.stringify({ state: "claimed", holder: { nonce: "abc" } }));',
    'else if (command === "release") process.stdout.write(JSON.stringify({ state: "released" }));',
    'else if (command === "check") process.stdout.write(JSON.stringify({ state: "free" }));',
    'else process.exit(2);',
    '',
  ].join('\n'), { mode: 0o755 });
  const llm = join(tmp, 'sync-llm.mjs');
  writeFileSync(llm, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task === "commit_message") {',
    '    process.stdout.write(JSON.stringify({ message: "Update vault note\\n\\nThis sync records the changed vault note before remote reconciliation.\\n\\nSlice: docs-only" }));',
    '  } else if (payload.task === "resolve_conflict") {',
    '    process.stdout.write(JSON.stringify({ resolved: "Remote truth line.\\n" }));',
    '  } else process.exit(2);',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  const cli = fileURLToPath(new URL('../../bin/vaultsync', import.meta.url));
  const env = {
    LAICLUSE_HOME: join(tmp, 'sync-home'),
    DIBS_BIN: fakeDibs,
    HOME: tmp,
    GIT_AUTHOR_NAME: 'Vaultsync Test',
    GIT_AUTHOR_EMAIL: 'vaultsync@example.invalid',
    GIT_COMMITTER_NAME: 'Vaultsync Test',
    GIT_COMMITTER_EMAIL: 'vaultsync@example.invalid',
  };
  runNode([cli, 'install', local, '--llm-command', `${process.execPath} ${llm}`, '--no-launchd'], { env });
  writeFileSync(join(local, '.git', 'hooks', 'pre-commit'), [
    '#!/bin/sh',
    "echo \"managed-git: deze vault wordt via 'vault sync' beheerd, niet via plain git.\" >&2",
    "echo \"Draai 'vault sync', of voeg '--no-verify' toe om dit bewust te omzeilen.\" >&2",
    'exit 1',
    '',
  ].join('\n'), { mode: 0o755 });
  writeFileSync(join(local, '.git', 'hooks', 'pre-push'), [
    '#!/bin/sh',
    "echo \"managed-git: deze vault wordt via 'vault sync' beheerd, niet via plain git.\" >&2",
    "echo \"Draai 'vault sync', of voeg '--no-verify' toe om dit bewust te omzeilen.\" >&2",
    'exit 1',
    '',
  ].join('\n'), { mode: 0o755 });
  writeFileSync(join(local, 'note.md'), '# Note\n\nChanged locally.\n');
  runNode([cli, 'now', local, '--json'], { env });

  assert.equal(git(local, ['status', '--porcelain']), '');
  assert.match(git(local, ['log', '-1', '--pretty=%s']), /Update vault note/);
  assert.match(git(tmp, ['--git-dir', remote, 'log', '-1', '--pretty=%s']), /Update vault note/);
});

it('installs and auto-commits a local-only checkout without an upstream', () => {
  const local = createRepo('local-only');

  const fakeDibs = join(tmp, 'local-only-dibs.mjs');
  writeFileSync(fakeDibs, [
    '#!/usr/bin/env node',
    'const command = process.argv[2];',
    'if (command === "claim") process.stdout.write(JSON.stringify({ state: "claimed", holder: { nonce: "abc" } }));',
    'else if (command === "release") process.stdout.write(JSON.stringify({ state: "released" }));',
    'else if (command === "check") process.stdout.write(JSON.stringify({ state: "free" }));',
    'else process.exit(2);',
    '',
  ].join('\n'), { mode: 0o755 });
  const llm = join(tmp, 'local-only-llm.mjs');
  writeFileSync(llm, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task === "commit_message") {',
    '    process.stdout.write(JSON.stringify({ message: "Record local vault note\\n\\nCapture the local-only vault edit without requiring remote synchronization.\\n\\nSlice: docs-only" }));',
    '  } else if (payload.task === "resolve_conflict") {',
    '    process.stdout.write(JSON.stringify({ resolved: "Remote truth line.\\n" }));',
    '  } else process.exit(2);',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  const cli = fileURLToPath(new URL('../../bin/vaultsync', import.meta.url));
  const home = join(tmp, 'local-only-home');
  const env = {
    LAICLUSE_HOME: home,
    DIBS_BIN: fakeDibs,
    HOME: tmp,
    GIT_AUTHOR_NAME: 'Vaultsync Test',
    GIT_AUTHOR_EMAIL: 'vaultsync@example.invalid',
    GIT_COMMITTER_NAME: 'Vaultsync Test',
    GIT_COMMITTER_EMAIL: 'vaultsync@example.invalid',
  };
  runNode([cli, 'install', local, '--llm-command', `${process.execPath} ${llm}`, '--no-launchd'], { env });
  writeFileSync(join(local, '.git', 'hooks', 'commit-msg'), [
    '#!/bin/sh',
    'grep -q "^Tests:" "$1" || { echo "missing Tests trailer" >&2; exit 1; }',
    'grep -q "^Slice: docs-only$" "$1" || { echo "invalid Slice trailer" >&2; exit 1; }',
    'grep -q "^Red-then-green:" "$1" || { echo "missing Red-then-green trailer" >&2; exit 1; }',
    '',
  ].join('\n'), { mode: 0o755 });
  writeFileSync(join(local, 'README.md'), '# Test\n\nChanged locally.\n');
  runNode([cli, 'now', local, '--json'], { env });

  const registration = JSON.parse(readFileSync(registrationPathForRoot(realpathSync(local), env), 'utf8'));
  const upstream = spawnSync('git', ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}'], {
    cwd: local,
    encoding: 'utf8',
  });
  assert.equal(git(local, ['status', '--porcelain']), '');
  assert.notEqual(upstream.status, 0);
  assert.match(git(local, ['log', '-1', '--pretty=%s']), /Record local vault note/);
  assert.equal(registration.upstreamAtInstall, null);
  assert.equal(registration.lastError, null);
  assert.equal(registration.lastResult.upstream, null);
  assert.equal(registration.lastResult.committed, true);
});

it('records a poll timestamp when verification fails after committing', () => {
  const remote = join(tmp, 'verify-remote.git');
  const local = join(tmp, 'verify-local');
  git(tmp, ['init', '--bare', '-q', remote]);
  git(tmp, ['clone', '-q', remote, local]);
  writeFileSync(join(local, 'note.md'), '# Note\n');
  git(local, ['add', 'note.md']);
  git(local, ['commit', '-q', '-m', 'Initial commit']);
  git(local, ['push', '-q', '-u', 'origin', 'HEAD']);

  const fakeDibs = join(tmp, 'verify-dibs.mjs');
  writeFileSync(fakeDibs, [
    '#!/usr/bin/env node',
    'const command = process.argv[2];',
    'if (command === "claim") process.stdout.write(JSON.stringify({ state: "claimed", holder: { nonce: "abc" } }));',
    'else if (command === "release") process.stdout.write(JSON.stringify({ state: "released" }));',
    'else if (command === "check") process.stdout.write(JSON.stringify({ state: "free" }));',
    'else process.exit(2);',
    '',
  ].join('\n'), { mode: 0o755 });
  const llm = join(tmp, 'verify-llm.mjs');
  writeFileSync(llm, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task === "commit_message") process.stdout.write(JSON.stringify({ message: "Update vault note\\n\\nRecord a note change before verifier failure handling.\\n\\nSlice: docs-only" }));',
    '  else if (payload.task === "resolve_conflict") process.stdout.write(JSON.stringify({ resolved: "Remote truth line.\\n" }));',
    '  else if (payload.task === "repair_verifier") process.stdout.write(JSON.stringify({ repairs: [] }));',
    '  else process.exit(2);',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  const cli = fileURLToPath(new URL('../../bin/vaultsync', import.meta.url));
  const home = join(tmp, 'verify-home');
  const env = {
    LAICLUSE_HOME: home,
    DIBS_BIN: fakeDibs,
    HOME: tmp,
    GIT_AUTHOR_NAME: 'Vaultsync Test',
    GIT_AUTHOR_EMAIL: 'vaultsync@example.invalid',
    GIT_COMMITTER_NAME: 'Vaultsync Test',
    GIT_COMMITTER_EMAIL: 'vaultsync@example.invalid',
  };
  runNode([cli, 'install', local, '--llm-command', `${process.execPath} ${llm}`, '--verify', 'false', '--no-launchd'], { env });
  writeFileSync(join(local, 'note.md'), '# Note\n\nChanged locally.\n');
  assert.throws(() => runNode([cli, 'now', local, '--json'], { env }), /verification command failed/);

  const registration = JSON.parse(readFileSync(registrationPathForRoot(realpathSync(local), env), 'utf8'));
  assert.equal(git(local, ['status', '--porcelain']), '');
  assert.equal(git(local, ['rev-list', '--left-right', '--count', 'HEAD...@{u}']), '1\t0');
  assert.equal(registration.lastSeenDirtyAt, null);
  assert.match(registration.lastPollAt, /^\d{4}-/);
  assert.match(registration.lastError.message, /verification command failed/);
});

it('asks the LLM command to repair verifier failures before pushing', () => {
  const remote = join(tmp, 'repair-remote.git');
  const local = join(tmp, 'repair-local');
  git(tmp, ['init', '--bare', '-q', remote]);
  git(tmp, ['clone', '-q', remote, local]);
  writeFileSync(join(local, 'note.md'), '# Note\n');
  writeFileSync(join(local, 'legacy.md'), '# Legacy\n\nMentions E-Flux.\n');
  writeFileSync(join(local, 'other.md'), '# Other\n\nMentions Zaptec.\n');
  git(local, ['add', 'note.md', 'legacy.md', 'other.md']);
  git(local, [
    'commit',
    '-q',
    '-m', 'Seed repair fixture',
    '-m', 'Seed the test repository with a clean current note and one legacy lint issue. This gives the verifier repair test a pre-existing warning outside the current sync commit.',
    '-m', 'Tests: n/a (test fixture)',
    '-m', 'Slice: docs-only',
  ]);
  git(local, ['push', '-q', '-u', 'origin', 'HEAD']);

  const fakeDibs = join(tmp, 'repair-dibs.mjs');
  writeFileSync(fakeDibs, [
    '#!/usr/bin/env node',
    'const command = process.argv[2];',
    'if (command === "claim") process.stdout.write(JSON.stringify({ state: "claimed", holder: { nonce: "abc" } }));',
    'else if (command === "release") process.stdout.write(JSON.stringify({ state: "released" }));',
    'else if (command === "check") process.stdout.write(JSON.stringify({ state: "free" }));',
    'else process.exit(2);',
    '',
  ].join('\n'), { mode: 0o755 });
  const verifier = join(tmp, 'repair-verifier.mjs');
  writeFileSync(verifier, [
    '#!/usr/bin/env node',
    'import { readFileSync } from "node:fs";',
    'import { join } from "node:path";',
    'let failed = false;',
    'const checks = [["legacy.md", "E-Flux"], ["other.md", "Zaptec"]];',
    'for (const [name, topic] of checks) {',
    '  const path = join(process.cwd(), name);',
    '  const text = readFileSync(path, "utf8");',
    '  if (text.includes(topic) && !text.includes(`[[${topic}]]`)) {',
    '    process.stdout.write(`${path}: topic ${JSON.stringify(topic)} matcht een bestaande note maar is niet gelinkt\\n`);',
    '    failed = true;',
    '  }',
    '}',
    'if (failed) process.exit(1);',
    '',
  ].join('\n'), { mode: 0o755 });
  const llm = join(tmp, 'repair-llm.mjs');
  writeFileSync(llm, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task === "commit_message") {',
    '    process.stdout.write(JSON.stringify({ message: "Update vault note\\n\\nRecord and repair the note change before remote reconciliation.\\n\\nSlice: docs-only" }));',
    '  } else if (payload.task === "resolve_conflict") {',
    '    process.stdout.write(JSON.stringify({ resolved: "Remote truth line.\\n" }));',
    '  } else if (payload.task === "repair_verifier") {',
    '    if (payload.files.length !== 1) process.exit(3);',
    '    if (!payload.verifier.detail.includes(payload.files[0].path)) process.exit(4);',
    '    if (payload.files[0].path !== "other.md" && payload.verifier.detail.includes("other.md")) process.exit(5);',
    '    const repairs = payload.files.map((file) => ({ path: file.path, content: file.content.replace(/E-Flux/g, "[[E-Flux]]").replace(/Zaptec/g, "[[Zaptec]]"), reason: "link verifier topic" }));',
    '    process.stdout.write(JSON.stringify({ repairs }));',
    '  } else process.exit(2);',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  const cli = fileURLToPath(new URL('../../bin/vaultsync', import.meta.url));
  const env = {
    LAICLUSE_HOME: join(tmp, 'repair-home'),
    DIBS_BIN: fakeDibs,
    HOME: tmp,
    GIT_AUTHOR_NAME: 'Vaultsync Test',
    GIT_AUTHOR_EMAIL: 'vaultsync@example.invalid',
    GIT_COMMITTER_NAME: 'Vaultsync Test',
    GIT_COMMITTER_EMAIL: 'vaultsync@example.invalid',
  };
  runNode([cli, 'install', local, '--llm-command', `${process.execPath} ${llm}`, '--verify', `${process.execPath} ${verifier}`, '--no-launchd'], { env });
  writeFileSync(join(local, 'note.md'), '# Note\n\nChanged locally.\n');
  runNode([cli, 'now', local, '--json'], { env });

  assert.equal(git(local, ['status', '--porcelain']), '');
  assert.equal(git(local, ['rev-list', '--left-right', '--count', 'HEAD...@{u}']), '0\t0');
  assert.equal(readFileSync(join(local, 'note.md'), 'utf8'), '# Note\n\nChanged locally.\n');
  assert.equal(readFileSync(join(local, 'legacy.md'), 'utf8'), '# Legacy\n\nMentions [[E-Flux]].\n');
  assert.equal(readFileSync(join(local, 'other.md'), 'utf8'), '# Other\n\nMentions [[Zaptec]].\n');
  assert.match(git(tmp, ['--git-dir', remote, 'log', '-1', '--pretty=%B']), /Update vault note/);
});
