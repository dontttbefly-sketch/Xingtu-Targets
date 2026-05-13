import { createInitialState } from "./domain";
import type { AppState } from "./types";

const STORAGE_KEY = "starfield-goals:v1";
const LAST_GOOD_KEY = "starfield-goals:v1:last-good";
const LAST_SAVED_AT_KEY = "starfield-goals:v1:last-saved-at";
const BACKUP_APP_ID = "starfield-goals";
const BACKUP_SCHEMA_VERSION = 1;

export type LoadStoredStateResult = {
  state: AppState;
  status: "ok" | "empty" | "recovered" | "invalid";
  message?: string;
};

export type SaveStoredStateResult =
  | { ok: true; savedAt: string }
  | { ok: false; message: string };

export type ParseBackupResult =
  | { ok: true; state: AppState }
  | { ok: false; message: string };

export function loadStoredState(): LoadStoredStateResult {
  if (!canUseLocalStorage()) {
    return {
      state: createInitialState(),
      status: "empty",
      message: "当前环境无法访问浏览器本地存储。"
    };
  }

  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      return { state: createInitialState(), status: "empty" };
    }

    const primary = parseStoredState(raw);
    if (primary) {
      return { state: primary, status: "ok" };
    }

    const recovered = loadLastGoodState();
    if (recovered) {
      return {
        state: recovered,
        status: "recovered",
        message: "主数据无法读取，已从备用镜像恢复。建议导出一次新备份。"
      };
    }

    return {
      state: createInitialState(),
      status: "invalid",
      message: "无法读取本地星图数据，已使用安全初始星图。"
    };
  } catch {
    const recovered = loadLastGoodState();
    if (recovered) {
      return {
        state: recovered,
        status: "recovered",
        message: "读取主数据时出错，已从备用镜像恢复。建议导出一次新备份。"
      };
    }

    return {
      state: createInitialState(),
      status: "invalid",
      message: "无法读取本地星图数据，已使用安全初始星图。"
    };
  }
}

export function saveStoredState(state: AppState): SaveStoredStateResult {
  if (!canUseLocalStorage()) {
    return { ok: false, message: "无法保存：当前环境无法访问浏览器本地存储。" };
  }

  try {
    const payload = JSON.stringify(state);
    const savedAt = new Date().toISOString();
    localStorage.setItem(STORAGE_KEY, payload);
    localStorage.setItem(LAST_GOOD_KEY, payload);
    localStorage.setItem(LAST_SAVED_AT_KEY, savedAt);
    return { ok: true, savedAt };
  } catch {
    return { ok: false, message: "无法保存：浏览器拒绝写入本地数据，请导出备份后检查存储空间或隐私模式。" };
  }
}

export function createBackupPayload(state: AppState): string {
  return JSON.stringify(
    {
      app: BACKUP_APP_ID,
      schemaVersion: BACKUP_SCHEMA_VERSION,
      exportedAt: new Date().toISOString(),
      state
    },
    null,
    2
  );
}

export function parseBackupPayload(raw: string): ParseBackupResult {
  try {
    const parsed = JSON.parse(raw) as {
      app?: unknown;
      schemaVersion?: unknown;
      state?: unknown;
    };

    if (parsed.app !== BACKUP_APP_ID || parsed.schemaVersion !== BACKUP_SCHEMA_VERSION) {
      return { ok: false, message: "导入失败：这不是星图目标管理的 v1 备份文件。" };
    }

    const state = normalizeState(parsed.state);
    if (!state) {
      return { ok: false, message: "导入失败：备份文件里的星图数据不完整或已损坏。" };
    }

    return { ok: true, state };
  } catch {
    return { ok: false, message: "导入失败：备份文件不是有效的 JSON。" };
  }
}

export function loadState(): AppState {
  return loadStoredState().state;
}

export function saveState(state: AppState): void {
  saveStoredState(state);
}

function loadLastGoodState(): AppState | null {
  try {
    const raw = localStorage.getItem(LAST_GOOD_KEY);
    return raw ? parseStoredState(raw) : null;
  } catch {
    return null;
  }
}

function parseStoredState(raw: string): AppState | null {
  try {
    return normalizeState(JSON.parse(raw));
  } catch {
    return null;
  }
}

function normalizeState(value: unknown): AppState | null {
  if (!isRecord(value) || value.version !== 1) {
    return null;
  }

  if (!isOptionalArray(value.goals) || !isOptionalArray(value.routines) || !isOptionalArray(value.tasks) || !isOptionalArray(value.checkIns)) {
    return null;
  }

  return {
    ...createInitialState(),
    ...value,
    version: 1,
    goals: Array.isArray(value.goals) ? value.goals : [],
    routines: Array.isArray(value.routines) ? value.routines : [],
    tasks: Array.isArray(value.tasks) ? value.tasks : [],
    checkIns: Array.isArray(value.checkIns) ? value.checkIns : [],
    lastReminderDate: typeof value.lastReminderDate === "string" ? value.lastReminderDate : undefined
  } as AppState;
}

function isOptionalArray(value: unknown): boolean {
  return value === undefined || Array.isArray(value);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function canUseLocalStorage(): boolean {
  return typeof localStorage !== "undefined";
}
