import { existsSync, readFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';

export function angerDir() {
  const agentHome = process.env.LAICLUSE_HOME || join(homedir(), '.laicluse');
  const dir = join(agentHome, 'anger-management');
  mkdirSync(dir, { recursive: true });
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
