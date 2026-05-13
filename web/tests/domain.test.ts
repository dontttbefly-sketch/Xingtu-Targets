import { describe, expect, it } from "vitest";
import {
  buildCheckInItems,
  calculateGoalStats,
  canCompleteRoutineOnDate,
  createInitialState,
  daysBetweenInclusive,
  getBackfillDates,
  getWeeklyCompletionCount,
  isRoutineCompletedOnDate,
  reducer
} from "../src/domain";
import type { Goal, Routine } from "../src/types";

const goal: Goal = {
  id: "goal-1",
  title: "写完一本书",
  startDate: "2026-05-01",
  dueDate: "2026-05-31",
  status: "active",
  createdAt: "2026-05-01T08:00:00.000Z",
  updatedAt: "2026-05-01T08:00:00.000Z"
};

const dailyRoutine: Routine = {
  id: "routine-daily",
  goalId: "goal-1",
  title: "写 500 字",
  frequency: { type: "daily" },
  createdAt: "2026-05-01T08:00:00.000Z",
  updatedAt: "2026-05-01T08:00:00.000Z"
};

const weeklyRoutine: Routine = {
  id: "routine-weekly",
  goalId: "goal-1",
  title: "长篇复盘",
  frequency: { type: "weeklyCount", timesPerWeek: 2 },
  createdAt: "2026-05-01T08:00:00.000Z",
  updatedAt: "2026-05-01T08:00:00.000Z"
};

describe("starfield goal rules", () => {
  it("counts calendar days inclusively for started goals", () => {
    expect(daysBetweenInclusive("2026-05-01", "2026-05-10")).toBe(10);
  });

  it("offers only the last 7 dates for backfill", () => {
    expect(getBackfillDates("2026-05-10")).toEqual([
      "2026-05-10",
      "2026-05-09",
      "2026-05-08",
      "2026-05-07",
      "2026-05-06",
      "2026-05-05",
      "2026-05-04"
    ]);
  });

  it("keeps daily routines in the review list every day", () => {
    const items = buildCheckInItems({
      goals: [goal],
      routines: [dailyRoutine],
      checkIns: [],
      date: "2026-05-10"
    });

    expect(items).toHaveLength(1);
    expect(items[0]).toMatchObject({
      routineId: "routine-daily",
      goalTitle: "写完一本书",
      completed: false
    });
  });

  it("hides a weekly routine once this week's target has been met", () => {
    const items = buildCheckInItems({
      goals: [goal],
      routines: [weeklyRoutine],
      checkIns: [
        {
          id: "check-1",
          routineId: "routine-weekly",
          date: "2026-05-04",
          completed: true,
          recordedAt: "2026-05-04T21:00:00.000Z"
        },
        {
          id: "check-2",
          routineId: "routine-weekly",
          date: "2026-05-07",
          completed: true,
          recordedAt: "2026-05-07T21:00:00.000Z"
        }
      ],
      date: "2026-05-10"
    });

    expect(items).toEqual([]);
  });

  it("calculates days, remaining days, routine completions, due counts, and completion rate", () => {
    const stats = calculateGoalStats({
      goal,
      routines: [dailyRoutine, weeklyRoutine],
      tasks: [],
      checkIns: [
        {
          id: "check-1",
          routineId: "routine-daily",
          date: "2026-05-01",
          completed: true,
          recordedAt: "2026-05-01T21:00:00.000Z"
        },
        {
          id: "check-2",
          routineId: "routine-weekly",
          date: "2026-05-04",
          completed: true,
          recordedAt: "2026-05-04T21:00:00.000Z"
        }
      ],
      today: "2026-05-10"
    });

    expect(stats.daysStarted).toBe(10);
    expect(stats.daysRemaining).toBe(21);
    expect(stats.completedCheckIns).toBe(2);
    expect(stats.dueCheckIns).toBe(14);
    expect(stats.completionRate).toBe(14);
  });

  it("deletes a goal together with its routines, one-off tasks, and check-ins", () => {
    const initial = createInitialState();
    const state = {
      ...initial,
      goals: [goal],
      routines: [dailyRoutine],
      tasks: [
        {
          id: "task-1",
          goalId: "goal-1",
          title: "整理提纲",
          completed: false,
          createdAt: "2026-05-01T08:00:00.000Z"
        }
      ],
      checkIns: [
        {
          id: "check-1",
          routineId: "routine-daily",
          date: "2026-05-01",
          completed: true,
          recordedAt: "2026-05-01T21:00:00.000Z"
        }
      ]
    };

    const next = reducer(state, { type: "deleteGoal", goalId: "goal-1" });

    expect(next.goals).toEqual([]);
    expect(next.routines).toEqual([]);
    expect(next.tasks).toEqual([]);
    expect(next.checkIns).toEqual([]);
  });

  it("identifies whether a routine is completed on a specific date", () => {
    expect(
      isRoutineCompletedOnDate(
        [
          {
            id: "check-1",
            routineId: "routine-daily",
            date: "2026-05-10",
            completed: true,
            recordedAt: "2026-05-10T21:00:00.000Z"
          }
        ],
        "routine-daily",
        "2026-05-10"
      )
    ).toBe(true);
  });

  it("allows a weekly routine to be completed before the weekly target is met", () => {
    expect(
      canCompleteRoutineOnDate(
        weeklyRoutine,
        [
          {
            id: "check-1",
            routineId: "routine-weekly",
            date: "2026-05-04",
            completed: true,
            recordedAt: "2026-05-04T21:00:00.000Z"
          }
        ],
        "2026-05-10"
      )
    ).toBe(true);
  });

  it("prevents adding another weekly completion after the weekly target is met", () => {
    const checkIns = [
      {
        id: "check-1",
        routineId: "routine-weekly",
        date: "2026-05-04",
        completed: true,
        recordedAt: "2026-05-04T21:00:00.000Z"
      },
      {
        id: "check-2",
        routineId: "routine-weekly",
        date: "2026-05-07",
        completed: true,
        recordedAt: "2026-05-07T21:00:00.000Z"
      }
    ];

    expect(getWeeklyCompletionCount(weeklyRoutine, checkIns, "2026-05-10")).toBe(2);
    expect(canCompleteRoutineOnDate(weeklyRoutine, checkIns, "2026-05-10")).toBe(false);
  });

  it("allows cancelling today's weekly completion even after the target is met", () => {
    expect(
      canCompleteRoutineOnDate(
        weeklyRoutine,
        [
          {
            id: "check-1",
            routineId: "routine-weekly",
            date: "2026-05-04",
            completed: true,
            recordedAt: "2026-05-04T21:00:00.000Z"
          },
          {
            id: "check-2",
            routineId: "routine-weekly",
            date: "2026-05-10",
            completed: true,
            recordedAt: "2026-05-10T21:00:00.000Z"
          }
        ],
        "2026-05-10"
      )
    ).toBe(true);
  });
});
