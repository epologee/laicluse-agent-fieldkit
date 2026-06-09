import { existsSync, readFileSync, mkdirSync, renameSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';

// allow-comment: legacy leclause storage migrates here once; new writes never land there
export function angerDir() {
  const agentHome = process.env.LAICLUSE_AGENT_HOME || join(homedir(), '.laicluse-agent');
  const dir = join(agentHome, 'anger-management');
  mkdirSync(dir, { recursive: true });
  const legacy = join(homedir(), '.claude', 'var', 'leclause', 'anger-management');
  if (existsSync(legacy)) {
    for (const name of readdirSync(legacy)) {
      const from = join(legacy, name);
      const to = join(dir, name);
      if (!existsSync(to)) {
        try { renameSync(from, to); } catch {}
      }
    }
  }
  return dir;
}

export function jsonlLines(path) {
  if (!existsSync(path)) return [];
  return readFileSync(path, 'utf8').trim().split('\n').filter(Boolean);
}

export function repairWatermark(repairsPath) {
  return jsonlLines(repairsPath).reduce((max, l) => {
    try { const t = JSON.parse(l).covered_through; return t && t > max ? t : max; } catch { return max; }
  }, '');
}

export function openCaptures(logPath, watermark) {
  return jsonlLines(logPath).filter((l) => {
    try { return JSON.parse(l).ts > watermark; } catch { return false; }
  });
}

export function newestCaptureTs(logPath) {
  return jsonlLines(logPath).reduce((max, l) => {
    try { const t = JSON.parse(l).ts; return t > max ? t : max; } catch { return max; }
  }, '');
}
