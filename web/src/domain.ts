import type {
  AppAction,
  AppState,
  CheckIn,
  CheckInItem,
  Goal,
  GoalStats,
  ISODate,
  OneOffTask,
  Routine,
  RoutineFrequency
} from "./types";

const DAY_MS = 24 * 60 * 60 * 1000;

export function createInitialState(): AppState {
  return {
    version: 1,
    goals: [],
    routines: [],
    tasks: [],
    checkIns: []
  };
}

export function todayISO(now = new Date()): ISODate {
  return formatDate(now);
}

export function formatDate(date: Date): ISODate {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export function daysBetweenInclusive(start: ISODate, end: ISODate): number {
  if (end < start) {
    return 0;
  }
  return Math.floor((toDate(end).getTime() - toDate(start).getTime()) / DAY_MS) + 1;
}

export function getBackfillDates(today: ISODate): ISODate[] {
  const start = toDate(today);
  return Array.from({ length: 7 }, (_, index) => {
    const date = new Date(start);
    date.setDate(start.getDate() - index);
    return formatDate(date);
  });
}

export function frequencyLabel(frequency: RoutineFrequency): string {
  if (frequency.type === "daily") {
    return "每日";
  }
  return `每周 ${frequency.timesPerWeek} 次`;
}

export function buildCheckInItems(input: {
  goals: Goal[];
  routines: Routine[];
  checkIns: CheckIn[];
  date: ISODate;
}): CheckInItem[] {
  const activeGoals = new Map(
    input.goals.filter((goal) => goal.status === "active").map((goal) => [goal.id, goal])
  );

  return input.routines
    .filter((routine) => activeGoals.has(routine.goalId))
    .filter((routine) => shouldShowRoutineForDate(routine, input.checkIns, input.date))
    .map((routine) => {
      const goal = activeGoals.get(routine.goalId)!;
      return {
        routineId: routine.id,
        routineTitle: routine.title,
        goalId: goal.id,
        goalTitle: goal.title,
        frequencyLabel: frequencyLabel(routine.frequency),
        completed: isRoutineCompletedOnDate(input.checkIns, routine.id, input.date)
      };
    });
}

export function calculateGoalStats(input: {
  goal: Goal;
  routines: Routine[];
  tasks: OneOffTask[];
  checkIns: CheckIn[];
  today: ISODate;
}): GoalStats {
  const goalRoutines = input.routines.filter((routine) => routine.goalId === input.goal.id);
  const routineIds = new Set(goalRoutines.map((routine) => routine.id));
  const goalCheckIns = input.checkIns.filter(
    (checkIn) => routineIds.has(checkIn.routineId) && checkIn.completed
  );
  const today = input.goal.status === "completed" && input.goal.completedAt
    ? input.goal.completedAt.slice(0, 10)
    : input.today;
  const statsEnd = today < input.goal.startDate ? input.goal.startDate : today;
  const daysStarted = daysBetweenInclusive(input.goal.startDate, statsEnd);
  const dueCheckIns = goalRoutines.reduce(
    (sum, routine) => sum + dueCountForRoutine(routine, input.goal.startDate, statsEnd),
    0
  );
  const goalTasks = input.tasks.filter((task) => task.goalId === input.goal.id);
  const daysRemaining = input.goal.dueDate
    ? Math.max(0, daysBetweenInclusive(input.today, input.goal.dueDate) - 1)
    : undefined;

  return {
    daysStarted,
    daysRemaining,
    completedCheckIns: goalCheckIns.length,
    dueCheckIns,
    completionRate: dueCheckIns === 0 ? 0 : Math.round((goalCheckIns.length / dueCheckIns) * 100),
    routineCount: goalRoutines.length,
    taskCount: goalTasks.length,
    completedTaskCount: goalTasks.filter((task) => task.completed).length
  };
}

export function reducer(state: AppState, action: AppAction): AppState {
  const now = new Date().toISOString();

  switch (action.type) {
    case "hydrate":
      return action.state;
    case "addGoal": {
      const goal: Goal = {
        id: createId("goal"),
        title: action.title.trim(),
        startDate: action.startDate,
        dueDate: action.dueDate || undefined,
        status: "active",
        createdAt: now,
        updatedAt: now
      };
      return { ...state, goals: [...state.goals, goal] };
    }
    case "updateGoal":
      return {
        ...state,
        goals: state.goals.map((goal) =>
          goal.id === action.goalId
            ? {
                ...goal,
                title: action.title.trim(),
                startDate: action.startDate,
                dueDate: action.dueDate || undefined,
                updatedAt: now
              }
            : goal
        )
      };
    case "deleteGoal": {
      const routineIds = new Set(
        state.routines.filter((routine) => routine.goalId === action.goalId).map((routine) => routine.id)
      );
      return {
        ...state,
        goals: state.goals.filter((goal) => goal.id !== action.goalId),
        routines: state.routines.filter((routine) => routine.goalId !== action.goalId),
        tasks: state.tasks.filter((task) => task.goalId !== action.goalId),
        checkIns: state.checkIns.filter((checkIn) => !routineIds.has(checkIn.routineId))
      };
    }
    case "completeGoal":
      return {
        ...state,
        goals: state.goals.map((goal) =>
          goal.id === action.goalId
            ? { ...goal, status: "completed", completedAt: now, updatedAt: now }
            : goal
        )
      };
    case "addRoutine": {
      const routine: Routine = {
        id: createId("routine"),
        goalId: action.goalId,
        title: action.title.trim(),
        frequency: normalizeFrequency(action.frequency),
        createdAt: now,
        updatedAt: now
      };
      return { ...state, routines: [...state.routines, routine] };
    }
    case "updateRoutine":
      return {
        ...state,
        routines: state.routines.map((routine) =>
          routine.id === action.routineId
            ? {
                ...routine,
                title: action.title.trim(),
                frequency: normalizeFrequency(action.frequency),
                updatedAt: now
              }
            : routine
        )
      };
    case "deleteRoutine":
      return {
        ...state,
        routines: state.routines.filter((routine) => routine.id !== action.routineId),
        checkIns: state.checkIns.filter((checkIn) => checkIn.routineId !== action.routineId)
      };
    case "toggleCheckIn": {
      const existing = state.checkIns.find(
        (checkIn) => checkIn.routineId === action.routineId && checkIn.date === action.date
      );
      const nextCheckIns = existing
        ? state.checkIns.map((checkIn) =>
            checkIn.id === existing.id
              ? { ...checkIn, completed: action.completed, recordedAt: now }
              : checkIn
          )
        : [
            ...state.checkIns,
            {
              id: createId("check"),
              routineId: action.routineId,
              date: action.date,
              completed: action.completed,
              recordedAt: now
            }
          ];
      return { ...state, checkIns: nextCheckIns };
    }
    case "addTask": {
      const task: OneOffTask = {
        id: createId("task"),
        goalId: action.goalId,
        title: action.title.trim(),
        completed: false,
        date: action.date || undefined,
        createdAt: now
      };
      return { ...state, tasks: [...state.tasks, task] };
    }
    case "toggleTask":
      return {
        ...state,
        tasks: state.tasks.map((task) =>
          task.id === action.taskId
            ? { ...task, completed: action.completed, completedAt: action.completed ? now : undefined }
            : task
        )
      };
    case "deleteTask":
      return { ...state, tasks: state.tasks.filter((task) => task.id !== action.taskId) };
    case "markReminderSent":
      return { ...state, lastReminderDate: action.date };
    default:
      return state;
  }
}

export function shouldShowRoutineForDate(
  routine: Routine,
  checkIns: CheckIn[],
  date: ISODate
): boolean {
  if (routine.frequency.type === "daily") {
    return true;
  }

  return getWeeklyCompletionCount(routine, checkIns, date) < routine.frequency.timesPerWeek;
}

export function isRoutineCompletedOnDate(
  checkIns: CheckIn[],
  routineId: string,
  date: ISODate
): boolean {
  return checkIns.some(
    (checkIn) => checkIn.routineId === routineId && checkIn.date === date && checkIn.completed
  );
}

export function getWeeklyCompletionCount(
  routine: Routine,
  checkIns: CheckIn[],
  date: ISODate
): number {
  const [weekStart, weekEnd] = weekBounds(date);
  return checkIns.filter(
    (checkIn) =>
      checkIn.routineId === routine.id &&
      checkIn.completed &&
      checkIn.date >= weekStart &&
      checkIn.date <= weekEnd
  ).length;
}

export function canCompleteRoutineOnDate(
  routine: Routine,
  checkIns: CheckIn[],
  date: ISODate
): boolean {
  if (routine.frequency.type === "daily") {
    return true;
  }
  if (isRoutineCompletedOnDate(checkIns, routine.id, date)) {
    return true;
  }
  return getWeeklyCompletionCount(routine, checkIns, date) < routine.frequency.timesPerWeek;
}

function dueCountForRoutine(routine: Routine, start: ISODate, end: ISODate): number {
  if (routine.frequency.type === "daily") {
    return daysBetweenInclusive(start, end);
  }

  let count = 0;
  let cursor = toDate(start);
  while (formatDate(cursor) <= end) {
    const current = formatDate(cursor);
    const [weekStart, weekEnd] = weekBounds(current);
    const countedStart = start > weekStart ? start : weekStart;
    const countedEnd = end < weekEnd ? end : weekEnd;
    const daysInRange = daysBetweenInclusive(countedStart, countedEnd);
    count += Math.min(routine.frequency.timesPerWeek, daysInRange);
    cursor = toDate(weekEnd);
    cursor.setDate(cursor.getDate() + 1);
  }
  return count;
}

function weekBounds(date: ISODate): [ISODate, ISODate] {
  const parsed = toDate(date);
  const day = parsed.getDay();
  const offsetToMonday = day === 0 ? -6 : 1 - day;
  const monday = new Date(parsed);
  monday.setDate(parsed.getDate() + offsetToMonday);
  const sunday = new Date(monday);
  sunday.setDate(monday.getDate() + 6);
  return [formatDate(monday), formatDate(sunday)];
}

function toDate(date: ISODate): Date {
  const [year, month, day] = date.split("-").map(Number);
  return new Date(year, month - 1, day);
}

function normalizeFrequency(frequency: RoutineFrequency): RoutineFrequency {
  if (frequency.type === "daily") {
    return frequency;
  }
  return {
    type: "weeklyCount",
    timesPerWeek: Math.min(7, Math.max(1, Math.round(frequency.timesPerWeek)))
  };
}

function createId(prefix: string): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}
