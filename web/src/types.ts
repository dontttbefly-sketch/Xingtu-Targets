export type ISODate = string;

export type GoalStatus = "active" | "completed";

export interface Goal {
  id: string;
  title: string;
  startDate: ISODate;
  dueDate?: ISODate;
  status: GoalStatus;
  completedAt?: string;
  createdAt: string;
  updatedAt: string;
}

export type RoutineFrequency =
  | { type: "daily" }
  | { type: "weeklyCount"; timesPerWeek: number };

export interface Routine {
  id: string;
  goalId: string;
  title: string;
  frequency: RoutineFrequency;
  createdAt: string;
  updatedAt: string;
}

export interface OneOffTask {
  id: string;
  goalId: string;
  title: string;
  completed: boolean;
  date?: ISODate;
  createdAt: string;
  completedAt?: string;
}

export interface CheckIn {
  id: string;
  routineId: string;
  date: ISODate;
  completed: boolean;
  recordedAt: string;
}

export interface AppState {
  version: 1;
  goals: Goal[];
  routines: Routine[];
  tasks: OneOffTask[];
  checkIns: CheckIn[];
  lastReminderDate?: ISODate;
}

export interface CheckInItem {
  routineId: string;
  routineTitle: string;
  goalId: string;
  goalTitle: string;
  frequencyLabel: string;
  completed: boolean;
}

export interface GoalStats {
  daysStarted: number;
  daysRemaining?: number;
  completedCheckIns: number;
  dueCheckIns: number;
  completionRate: number;
  routineCount: number;
  taskCount: number;
  completedTaskCount: number;
}

export type AppAction =
  | {
      type: "addGoal";
      title: string;
      startDate: ISODate;
      dueDate?: ISODate;
    }
  | {
      type: "updateGoal";
      goalId: string;
      title: string;
      startDate: ISODate;
      dueDate?: ISODate;
    }
  | { type: "deleteGoal"; goalId: string }
  | { type: "completeGoal"; goalId: string }
  | {
      type: "addRoutine";
      goalId: string;
      title: string;
      frequency: RoutineFrequency;
    }
  | {
      type: "updateRoutine";
      routineId: string;
      title: string;
      frequency: RoutineFrequency;
    }
  | { type: "deleteRoutine"; routineId: string }
  | { type: "toggleCheckIn"; routineId: string; date: ISODate; completed: boolean }
  | { type: "addTask"; goalId: string; title: string; date?: ISODate }
  | { type: "toggleTask"; taskId: string; completed: boolean }
  | { type: "deleteTask"; taskId: string }
  | { type: "markReminderSent"; date: ISODate }
  | { type: "hydrate"; state: AppState };
