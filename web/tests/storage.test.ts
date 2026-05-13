import { describe, expect, it } from "vitest";
import { createInitialState } from "../src/domain";
import {
  createBackupPayload,
  loadStoredState,
  parseBackupPayload,
  saveStoredState
} from "../src/storage";
import type { AppState } from "../src/types";

const STORAGE_KEY = "starfield-goals:v1";
const LAST_GOOD_KEY = "starfield-goals:v1:last-good";
const LAST_SAVED_AT_KEY = "starfield-goals:v1:last-saved-at";

function populatedState(): AppState {
  return {
    ...createInitialState(),
    goals: [
      {
        id: "goal-1",
        title: "长期目标",
        startDate: "2026-05-11",
        status: "active",
        createdAt: "2026-05-11T10:00:00.000Z",
        updatedAt: "2026-05-11T10:00:00.000Z"
      }
    ],
    routines: [
      {
        id: "routine-1",
        goalId: "goal-1",
        title: "每日点亮",
        frequency: { type: "daily" },
        createdAt: "2026-05-11T10:00:00.000Z",
        updatedAt: "2026-05-11T10:00:00.000Z"
      }
    ],
    checkIns: [
      {
        id: "check-1",
        routineId: "routine-1",
        date: "2026-05-11",
        completed: true,
        recordedAt: "2026-05-11T21:00:00.000Z"
      }
    ]
  };
}

describe("local starfield storage", () => {
  it("loads valid v1 state from localStorage", () => {
    const state = populatedState();
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));

    const result = loadStoredState();

    expect(result.status).toBe("ok");
    expect(result.state.goals[0]?.title).toBe("长期目标");
    expect(result.state.routines[0]?.title).toBe("每日点亮");
  });

  it("recovers from the last good mirror when the primary data is damaged", () => {
    const state = populatedState();
    localStorage.setItem(STORAGE_KEY, "{bad json");
    localStorage.setItem(LAST_GOOD_KEY, JSON.stringify(state));

    const result = loadStoredState();

    expect(result.status).toBe("recovered");
    expect(result.state.goals[0]?.title).toBe("长期目标");
    expect(result.message).toContain("备用");
  });

  it("falls back to an empty safe state for unsupported or invalid data", () => {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({
        version: 2,
        goals: [{ id: "future-goal" }],
        routines: [],
        tasks: [],
        checkIns: []
      })
    );

    const result = loadStoredState();

    expect(result.status).toBe("invalid");
    expect(result.state).toEqual(createInitialState());
    expect(result.message).toContain("无法读取");
  });

  it("saves state, last saved time, and a last good mirror", () => {
    const state = populatedState();

    const result = saveStoredState(state);

    expect(result.ok).toBe(true);
    expect(localStorage.getItem(STORAGE_KEY)).toEqual(JSON.stringify(state));
    expect(localStorage.getItem(LAST_GOOD_KEY)).toEqual(JSON.stringify(state));
    expect(localStorage.getItem(LAST_SAVED_AT_KEY)).toEqual(result.ok ? result.savedAt : "");
  });

  it("returns a failure result when localStorage refuses writes", () => {
    const originalSetItem = localStorage.setItem;
    localStorage.setItem = () => {
      throw new Error("quota exceeded");
    };

    const result = saveStoredState(populatedState());

    localStorage.setItem = originalSetItem;
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.message).toContain("无法保存");
    }
  });

  it("round-trips app state through a backup payload and rejects invalid backups", () => {
    const state = populatedState();
    const payload = createBackupPayload(state);

    const parsed = parseBackupPayload(payload);
    const invalid = parseBackupPayload(JSON.stringify({ app: "elsewhere", schemaVersion: 1, state }));

    expect(parsed.ok).toBe(true);
    expect(parsed.ok ? parsed.state : createInitialState()).toEqual(state);
    expect(invalid.ok).toBe(false);
  });
});
