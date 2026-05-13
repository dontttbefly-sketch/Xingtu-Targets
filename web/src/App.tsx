import { useEffect, useMemo, useReducer, useRef, useState } from "react";
import type { CSSProperties, ChangeEvent, MouseEvent, PointerEvent, ReactNode, WheelEvent } from "react";
import {
  Archive,
  AlertTriangle,
  Bell,
  Check,
  ChevronLeft,
  Clock3,
  Database,
  Download,
  Edit3,
  Flame,
  HardDrive,
  Minus,
  Orbit,
  Plus,
  Radar,
  RotateCcw,
  Save,
  ShieldCheck,
  Sparkles,
  Trash2,
  Upload,
  X
} from "lucide-react";
import {
  buildCheckInItems,
  calculateGoalStats,
  canCompleteRoutineOnDate,
  createInitialState,
  frequencyLabel,
  getBackfillDates,
  isRoutineCompletedOnDate,
  reducer,
  shouldShowRoutineForDate,
  todayISO
} from "./domain";
import { sendEveningNotification, shouldShowEveningReview } from "./notifications";
import { createBackupPayload, loadStoredState, parseBackupPayload, saveStoredState } from "./storage";
import type { LoadStoredStateResult } from "./storage";
import type { AppState, Goal, ISODate, Routine, RoutineFrequency } from "./types";

type Dialog =
  | { type: "goal"; goal?: Goal }
  | { type: "routine"; goalId: string; routine?: Routine }
  | { type: "task"; goalId: string }
  | null;

type View = "starfield" | "review";
type FocusPhase = "idle" | "entering" | "focused" | "exiting";
type StorageViewState = {
  kind: "saved" | "error";
  message: string;
  lastSavedAt?: string;
};
type ImportMessage = { kind: "success" | "error"; title: string; detail: string } | null;
type PersistenceStatus = "unknown" | "protected" | "unprotected" | "unsupported";
const FOCUS_TRANSITION_MS = 920;

const emptyState = createInitialState();

export default function App() {
  const [storedState] = useState<LoadStoredStateResult>(() => loadStoredState());
  const [state, dispatch] = useReducer(reducer, emptyState, () => storedState.state);
  const [selectedGoalId, setSelectedGoalId] = useState<string | null>(null);
  const [selectedRoutineId, setSelectedRoutineId] = useState<string | null>(null);
  const [dialog, setDialog] = useState<Dialog>(null);
  const [dataPanelOpen, setDataPanelOpen] = useState(false);
  const [storageAlert, setStorageAlert] = useState<string | null>(() =>
    storedState.status === "invalid" || storedState.status === "recovered" ? storedState.message ?? null : null
  );
  const [storageView, setStorageView] = useState<StorageViewState>(() => ({
    kind: storedState.status === "invalid" ? "error" : "saved",
    message: storedState.message ?? "本地数据已保存"
  }));
  const [importMessage, setImportMessage] = useState<ImportMessage>(null);
  const [persistenceStatus, setPersistenceStatus] = useState<PersistenceStatus>("unknown");
  const [view, setView] = useState<View>("starfield");
  const [reviewDate, setReviewDate] = useState<ISODate>(todayISO());
  const [reminderBanner, setReminderBanner] = useState(false);
  const [focusPhase, setFocusPhase] = useState<FocusPhase>("idle");
  const focusTransitionTimerRef = useRef<number | null>(null);
  const today = todayISO();

  const clearFocusTransition = (nextPhase: FocusPhase = "idle") => {
    if (focusTransitionTimerRef.current !== null) {
      window.clearTimeout(focusTransitionTimerRef.current);
      focusTransitionTimerRef.current = null;
    }
    setFocusPhase(nextPhase);
  };

  const startFocusTransition = () => {
    clearFocusTransition();
    if (prefersReducedMotion()) {
      setFocusPhase("focused");
      return;
    }
    setFocusPhase("entering");
    focusTransitionTimerRef.current = window.setTimeout(() => {
      setFocusPhase("focused");
      focusTransitionTimerRef.current = null;
    }, FOCUS_TRANSITION_MS);
  };

  const dismissFocus = () => {
    if (!selectedGoalId) {
      clearFocusTransition();
      return;
    }
    setSelectedRoutineId(null);
    if (prefersReducedMotion()) {
      setSelectedGoalId(null);
      clearFocusTransition();
      return;
    }
    clearFocusTransition("exiting");
    focusTransitionTimerRef.current = window.setTimeout(() => {
      setSelectedGoalId(null);
      setFocusPhase("idle");
      focusTransitionTimerRef.current = null;
    }, FOCUS_TRANSITION_MS);
  };

  useEffect(() => {
    const result = saveStoredState(state);
    if (result.ok) {
      setStorageView({ kind: "saved", message: "本地数据已保存", lastSavedAt: result.savedAt });
      return;
    }
    setStorageView({ kind: "error", message: result.message });
    setStorageAlert(result.message);
  }, [state]);

  useEffect(() => {
    if (selectedGoalId && !state.goals.some((goal) => goal.id === selectedGoalId)) {
      setSelectedGoalId(null);
      clearFocusTransition();
    }
  }, [selectedGoalId, state.goals]);

  useEffect(() => {
    if (selectedRoutineId && !state.routines.some((routine) => routine.id === selectedRoutineId)) {
      setSelectedRoutineId(null);
    }
  }, [selectedRoutineId, state.routines]);

  useEffect(() => {
    const checkReminder = () => {
      if (shouldShowEveningReview(state)) {
        setReminderBanner(true);
        sendEveningNotification().finally(() => {
          dispatch({ type: "markReminderSent", date: todayISO() });
        });
      }
    };
    checkReminder();
    const timer = window.setInterval(checkReminder, 60 * 1000);
    return () => window.clearInterval(timer);
  }, [state]);

  useEffect(() => {
    return () => {
      if (focusTransitionTimerRef.current !== null) {
        window.clearTimeout(focusTransitionTimerRef.current);
      }
    };
  }, []);

  const selectedGoal = state.goals.find((goal) => goal.id === selectedGoalId) ?? null;
  const selectedRoutine = state.routines.find((routine) => routine.id === selectedRoutineId) ?? null;
  const selectedRoutineGoal = selectedRoutine
    ? state.goals.find((goal) => goal.id === selectedRoutine.goalId) ?? null
    : null;
  const isFocusMode = view === "starfield" && selectedGoal !== null;
  const activeGoals = state.goals.filter((goal) => goal.status === "active");
  const completedGoals = state.goals.filter((goal) => goal.status === "completed");
  const isFocusTransitioning = isFocusMode && focusPhase === "entering";
  const isFocusExiting = isFocusMode && focusPhase === "exiting";
  const shouldHideOverview = isFocusMode && !isFocusExiting;
  const isDrawerOpen = view === "review" || (selectedGoal !== null && !isFocusExiting);
  const totalCompletedCheckIns = state.checkIns.filter((checkIn) => checkIn.completed).length;
  const totalDays = state.goals.reduce(
    (sum, goal) => sum + calculateGoalStats({ goal, routines: state.routines, tasks: state.tasks, checkIns: state.checkIns, today }).daysStarted,
    0
  );

  const reviewItems = useMemo(
    () =>
      buildCheckInItems({
        goals: state.goals,
        routines: state.routines,
        checkIns: state.checkIns,
        date: reviewDate
      }),
    [state.goals, state.routines, state.checkIns, reviewDate]
  );

  const resetToStarfield = () => {
    setSelectedGoalId(null);
    setSelectedRoutineId(null);
    setView("starfield");
    clearFocusTransition();
  };

  const handleExportBackup = () => {
    const payload = createBackupPayload(state);
    const dateStamp = todayISO();
    const anchor = document.createElement("a");
    anchor.href = `data:application/json;charset=utf-8,${encodeURIComponent(payload)}`;
    anchor.download = `starfield-goals-backup-${dateStamp}.json`;
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
    setImportMessage({
      kind: "success",
      title: "备份已导出",
      detail: "浏览器已经生成当前星图备份文件。"
    });
  };

  const handleImportBackup = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.currentTarget.files?.[0];
    event.currentTarget.value = "";
    if (!file) {
      return;
    }

    const raw = await file.text();
    const parsed = parseBackupPayload(raw);
    if (!parsed.ok) {
      setImportMessage({ kind: "error", title: "导入失败", detail: parsed.message });
      return;
    }

    if (!window.confirm("导入备份会覆盖当前本机星图数据。确定继续吗？")) {
      return;
    }

    dispatch({ type: "hydrate", state: parsed.state });
    resetToStarfield();
    setImportMessage({
      kind: "success",
      title: "备份已导入",
      detail: "星图已经恢复到备份文件中的状态。"
    });
  };

  const handleRequestPersistence = async () => {
    if (!navigator.storage?.persist) {
      setPersistenceStatus("unsupported");
      return;
    }

    try {
      const granted = await navigator.storage.persist();
      setPersistenceStatus(granted ? "protected" : "unprotected");
    } catch {
      setPersistenceStatus("unsupported");
    }
  };

  return (
    <main className="app-shell universe-shell">
      <StarMap
        state={state}
        today={today}
        selectedGoalId={selectedGoalId}
        selectedRoutineId={selectedRoutineId}
        isFocusMode={isFocusMode}
        isFocusTransitioning={isFocusTransitioning}
        isFocusExiting={isFocusExiting}
        focusPhase={focusPhase}
        onSelectGoal={(goalId) => {
          if (selectedGoalId === goalId && isFocusMode && focusPhase !== "exiting") {
            return;
          }
          setSelectedGoalId(goalId);
          setSelectedRoutineId(null);
          setView("starfield");
          startFocusTransition();
        }}
        onSelectRoutine={(routineId) => {
          const routine = state.routines.find((item) => item.id === routineId);
          if (!routine) {
            return;
          }
          if (selectedGoalId !== routine.goalId) {
            setSelectedGoalId(null);
            clearFocusTransition();
          }
          setSelectedRoutineId(routineId);
          setView("starfield");
        }}
        onDismissFocus={dismissFocus}
      />

      <header className="top-bar">
        <button
          className="brand-mark"
          type="button"
          onClick={resetToStarfield}
        >
          <span className="brand-star" />
          <span>
            <strong>星图</strong>
            <small>私人航行日志</small>
          </span>
        </button>
        <div className="top-actions">
          <button
            className="icon-button"
            type="button"
            onClick={() => setDataPanelOpen(true)}
            title="数据舱"
          >
            <Database size={18} />
            <span>数据舱</span>
          </button>
          <button
            className="icon-button"
            type="button"
            onClick={() => {
              setSelectedRoutineId(null);
              setView("review");
              clearFocusTransition();
            }}
            title="今晚复盘"
          >
            <Clock3 size={18} />
            <span>今晚复盘</span>
          </button>
          <button className="primary-button" type="button" onClick={() => setDialog({ type: "goal" })}>
            <Plus size={18} />
            <span>新建目标</span>
          </button>
        </div>
      </header>

      {reminderBanner && (
        <section className="review-banner">
          <div>
            <p className="eyebrow">21:00 复盘窗口</p>
            <strong>检查今天的行星轨道，把完成的 routine 点亮。</strong>
          </div>
          <button
            className="primary-button"
            type="button"
            onClick={() => {
              setSelectedRoutineId(null);
              setView("review");
              setReminderBanner(false);
              clearFocusTransition();
            }}
          >
            <Bell size={18} />
            <span>开始复盘</span>
          </button>
        </section>
      )}

      {storageAlert && (
        <section className={`storage-alert ${storageView.kind === "error" ? "error" : ""}`} role="status">
          <AlertTriangle size={18} />
          <div>
            <strong>本地数据提示</strong>
            <span>{storageAlert}</span>
          </div>
          <button className="icon-only" type="button" aria-label="关闭存储提示" onClick={() => setStorageAlert(null)}>
            <X size={16} />
          </button>
        </section>
      )}

      <section className={`overview-strip ${shouldHideOverview ? "focus-hidden" : ""}`} aria-label="星图总览">
        <Metric label="活跃恒星" value={activeGoals.length.toString()} />
        <Metric label="完成恒星" value={completedGoals.length.toString()} />
        <Metric label="坚持次数" value={totalCompletedCheckIns.toString()} />
        <Metric label="累计航行天数" value={totalDays.toString()} />
      </section>

      <div
        className={`drawer-layer ${isDrawerOpen ? "open" : ""} ${isFocusMode ? "focus-detail" : ""} ${
          isFocusTransitioning ? "focus-transitioning" : ""
        } ${isFocusExiting ? "focus-exiting" : ""}`}
        data-testid="drawer-layer"
      >
        {view === "review" ? (
          <ReviewPanel
            dates={getBackfillDates(today)}
            reviewDate={reviewDate}
            items={reviewItems}
            selectedStats={
              selectedGoal
                ? calculateGoalStats({
                    goal: selectedGoal,
                    routines: state.routines,
                    tasks: state.tasks,
                    checkIns: state.checkIns,
                    today
                  })
                : undefined
            }
            onDateChange={setReviewDate}
            onToggle={(routineId, completed) =>
              dispatch({ type: "toggleCheckIn", routineId, date: reviewDate, completed })
            }
          />
        ) : selectedGoal && !isFocusExiting ? (
          <GoalDetail
            state={state}
            goal={selectedGoal}
            today={today}
            onBack={() => {
              dismissFocus();
            }}
            onEditGoal={() => setDialog({ type: "goal", goal: selectedGoal })}
            onAddRoutine={() => setDialog({ type: "routine", goalId: selectedGoal.id })}
            onEditRoutine={(routine) => setDialog({ type: "routine", goalId: selectedGoal.id, routine })}
            onAddTask={() => setDialog({ type: "task", goalId: selectedGoal.id })}
            onCompleteGoal={() => dispatch({ type: "completeGoal", goalId: selectedGoal.id })}
            onDeleteGoal={() => {
              if (window.confirm("删除目标会同时删除它的 routines、临时事项和所有打卡记录。确定继续吗？")) {
                dispatch({ type: "deleteGoal", goalId: selectedGoal.id });
                setSelectedGoalId(null);
                setSelectedRoutineId(null);
                clearFocusTransition();
              }
            }}
            onDeleteRoutine={(routineId) => {
              if (window.confirm("删除这个 routine 会同时删除它的打卡记录。确定继续吗？")) {
                dispatch({ type: "deleteRoutine", routineId });
                if (selectedRoutineId === routineId) {
                  setSelectedRoutineId(null);
                }
              }
            }}
            onToggleRoutineToday={(routineId, completed) =>
              dispatch({ type: "toggleCheckIn", routineId, date: today, completed })
            }
            onToggleTask={(taskId, completed) => dispatch({ type: "toggleTask", taskId, completed })}
            onDeleteTask={(taskId) => dispatch({ type: "deleteTask", taskId })}
          />
        ) : (
          <HomePanel onCreateGoal={() => setDialog({ type: "goal" })} />
        )}
      </div>

      {selectedRoutine && selectedRoutineGoal && (
        <RoutineQuickPanel
          state={state}
          routine={selectedRoutine}
          goal={selectedRoutineGoal}
          today={today}
          onClose={() => setSelectedRoutineId(null)}
          onOpenGoal={() => {
            setSelectedGoalId(selectedRoutineGoal.id);
            setSelectedRoutineId(null);
            startFocusTransition();
          }}
          onEditRoutine={() => setDialog({ type: "routine", goalId: selectedRoutineGoal.id, routine: selectedRoutine })}
          onDeleteRoutine={() => {
            if (window.confirm("删除这个 routine 会同时删除它的打卡记录。确定继续吗？")) {
              dispatch({ type: "deleteRoutine", routineId: selectedRoutine.id });
              setSelectedRoutineId(null);
            }
          }}
          onToggleRoutineToday={(completed) =>
            dispatch({ type: "toggleCheckIn", routineId: selectedRoutine.id, date: today, completed })
          }
        />
      )}

      {dataPanelOpen && (
        <DataPanel
          state={state}
          storageView={storageView}
          importMessage={importMessage}
          persistenceStatus={persistenceStatus}
          onClose={() => setDataPanelOpen(false)}
          onExportBackup={handleExportBackup}
          onImportBackup={handleImportBackup}
          onRequestPersistence={handleRequestPersistence}
        />
      )}

      {dialog?.type === "goal" && (
        <GoalDialog
          goal={dialog.goal}
          onClose={() => setDialog(null)}
          onSubmit={(title, startDate, dueDate) => {
            if (dialog.goal) {
              dispatch({ type: "updateGoal", goalId: dialog.goal.id, title, startDate, dueDate });
            } else {
              dispatch({ type: "addGoal", title, startDate, dueDate });
            }
            setDialog(null);
          }}
        />
      )}

      {dialog?.type === "routine" && (
        <RoutineDialog
          routine={dialog.routine}
          onClose={() => setDialog(null)}
          onSubmit={(title, frequency) => {
            if (dialog.routine) {
              dispatch({ type: "updateRoutine", routineId: dialog.routine.id, title, frequency });
            } else {
              dispatch({ type: "addRoutine", goalId: dialog.goalId, title, frequency });
            }
            setDialog(null);
          }}
        />
      )}

      {dialog?.type === "task" && (
        <TaskDialog
          onClose={() => setDialog(null)}
          onSubmit={(title, date) => {
            dispatch({ type: "addTask", goalId: dialog.goalId, title, date });
            setDialog(null);
          }}
        />
      )}
    </main>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="metric">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function DataPanel({
  state,
  storageView,
  importMessage,
  persistenceStatus,
  onClose,
  onExportBackup,
  onImportBackup,
  onRequestPersistence
}: {
  state: AppState;
  storageView: StorageViewState;
  importMessage: ImportMessage;
  persistenceStatus: PersistenceStatus;
  onClose: () => void;
  onExportBackup: () => void;
  onImportBackup: (event: ChangeEvent<HTMLInputElement>) => void;
  onRequestPersistence: () => void;
}) {
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const totalItems = state.goals.length + state.routines.length + state.tasks.length + state.checkIns.length;

  return (
    <aside className="data-panel" role="complementary" aria-label="数据舱">
      <div className="panel-header">
        <div>
          <p className="eyebrow">Data Vault</p>
          <h2>数据舱</h2>
        </div>
        <button className="icon-only" type="button" aria-label="关闭数据舱" onClick={onClose}>
          <X size={16} />
        </button>
      </div>

      <div className={`data-status ${storageView.kind}`}>
        {storageView.kind === "saved" ? <Save size={18} /> : <AlertTriangle size={18} />}
        <div>
          <strong>{storageView.kind === "saved" ? "本地数据已保存" : "本地数据保存异常"}</strong>
          <span>{storageView.kind === "saved" ? "目标、routine 和打卡记录正在本机保存。" : storageView.message}</span>
          <small>{storageView.lastSavedAt ? `最后保存 ${formatStorageDate(storageView.lastSavedAt)}` : "等待第一次保存记录"}</small>
        </div>
      </div>

      <div className="data-counts" aria-label="本地数据数量">
        <span>目标 {state.goals.length}</span>
        <span>routine {state.routines.length}</span>
        <span>事项 {state.tasks.length}</span>
        <span>打卡 {state.checkIns.length}</span>
      </div>

      <div className="data-persistence">
        <HardDrive size={18} />
        <div>
          <strong>{persistenceTitle(persistenceStatus)}</strong>
          <span>{persistenceDescription(persistenceStatus)}</span>
        </div>
      </div>

      <div className="data-actions">
        <button className="secondary-button" type="button" onClick={onRequestPersistence}>
          <ShieldCheck size={18} />
          <span>保护本地数据</span>
        </button>
        <button className="secondary-button" type="button" onClick={onExportBackup}>
          <Download size={18} />
          <span>导出备份</span>
        </button>
        <button className="secondary-button" type="button" onClick={() => fileInputRef.current?.click()}>
          <Upload size={18} />
          <span>导入备份</span>
        </button>
        <input
          ref={fileInputRef}
          className="file-input-hidden"
          type="file"
          accept="application/json,.json"
          aria-label="选择备份文件"
          onChange={onImportBackup}
        />
      </div>

      {importMessage && (
        <div className={`import-message ${importMessage.kind}`} role="status">
          <strong>{importMessage.title}</strong>
          <span>{importMessage.detail}</span>
        </div>
      )}

      <p className="data-footnote">当前星图共有 {totalItems} 条本地记录。清除浏览器站点数据会移除它们，长期使用请定期导出备份。</p>
    </aside>
  );
}

function StarMap({
  state,
  today,
  selectedGoalId,
  selectedRoutineId,
  isFocusMode,
  isFocusTransitioning,
  isFocusExiting,
  focusPhase,
  onSelectGoal,
  onSelectRoutine,
  onDismissFocus
}: {
  state: AppState;
  today: ISODate;
  selectedGoalId: string | null;
  selectedRoutineId: string | null;
  isFocusMode: boolean;
  isFocusTransitioning: boolean;
  isFocusExiting: boolean;
  focusPhase: FocusPhase;
  onSelectGoal: (goalId: string) => void;
  onSelectRoutine: (routineId: string) => void;
  onDismissFocus: () => void;
}) {
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [tilt, setTilt] = useState({ x: 0, y: 0 });
  const zoomConfig = getZoomConfig(state.goals.length);
  const [zoomOverride, setZoomOverride] = useState<number | null>(null);
  const zoom = zoomOverride ?? zoomConfig.default;
  const [isDragging, setIsDragging] = useState(false);
  const tiltRef = useRef({ x: 0, y: 0 });
  const targetTiltRef = useRef({ x: 0, y: 0 });
  const animationFrameRef = useRef<number | null>(null);
  const dragRef = useRef({
    active: false,
    lastX: 0,
    lastY: 0,
    totalDistance: 0,
    pointerId: -1
  });
  const suppressClickRef = useRef(false);
  const animateTilt = () => {
    const current = tiltRef.current;
    const target = targetTiltRef.current;
    const next = {
      x: current.x + (target.x - current.x) * 0.16,
      y: current.y + (target.y - current.y) * 0.16
    };
    const isSettled = Math.abs(next.x - target.x) < 0.02 && Math.abs(next.y - target.y) < 0.02;

    tiltRef.current = isSettled ? target : next;
    setTilt(tiltRef.current);
    animationFrameRef.current = isSettled ? null : window.requestAnimationFrame(animateTilt);
  };
  const setTiltTarget = (next: { x: number; y: number }) => {
    targetTiltRef.current = next;
    if (prefersReducedMotion() || typeof window.requestAnimationFrame !== "function") {
      tiltRef.current = next;
      setTilt(next);
      return;
    }
    if (animationFrameRef.current === null) {
      animationFrameRef.current = window.requestAnimationFrame(animateTilt);
    }
  };
  const updateTilt = (event: PointerEvent<HTMLElement>) => {
    const rect = event.currentTarget.getBoundingClientRect();
    const x = ((event.clientX - rect.left) / rect.width - 0.5) * 2;
    const y = ((event.clientY - rect.top) / rect.height - 0.5) * 2;
    setTiltTarget({
      x: clamp(y * -7, -7, 7),
      y: clamp(x * 8, -8, 8)
    });
  };
  const zoomBy = (delta: number) => {
    setZoomOverride((current) => roundZoom(clamp((current ?? zoomConfig.default) + delta, zoomConfig.min, zoomConfig.max)));
  };
  const resetZoom = () => {
    setZoomOverride(null);
  };
  const handleWheel = (event: WheelEvent<HTMLElement>) => {
    if ((event.target as HTMLElement).closest(".celestial-control")) {
      return;
    }
    event.preventDefault();
    if (isFocusMode) {
      return;
    }
    const zoomDelta = clamp(-event.deltaY / 1500, -0.16, 0.16);
    if (zoomDelta !== 0) {
      zoomBy(zoomDelta);
    }
  };

  useEffect(() => {
    return () => {
      if (animationFrameRef.current !== null) {
        window.cancelAnimationFrame(animationFrameRef.current);
      }
    };
  }, []);

  const positionedGoals = state.goals.map((goal, index) => {
    const stats = calculateGoalStats({ goal, routines: state.routines, tasks: state.tasks, checkIns: state.checkIns, today });
    const position = getGoalPosition(index);
    return {
      goal,
      stats,
      x: position.x,
      y: position.y,
      size: Math.max(62, Math.min(104, 64 + stats.routineCount * 10 + stats.completedCheckIns * 2))
    };
  });
  const selectedPositionedGoal = positionedGoals.find(({ goal }) => goal.id === selectedGoalId) ?? null;
  const selectedFocusRoutines = selectedGoalId
    ? state.routines.filter((routine) => routine.goalId === selectedGoalId).slice(0, 6)
    : [];
  const selectedFocusMaxOrbitRadius = selectedFocusRoutines.reduce(
    (maxRadius, routine, index) => Math.max(maxRadius, getFocusOrbitRadius(routine, index)),
    0
  );
  const focusCamera =
    isFocusMode && !isFocusExiting && selectedPositionedGoal
      ? createFocusCamera(
          selectedPositionedGoal.x,
          selectedPositionedGoal.y,
          selectedFocusRoutines.length,
          selectedFocusMaxOrbitRadius
        )
      : null;
  const layerTransform = focusCamera
    ? `translate3d(${Math.round(focusCamera.x)}px, ${Math.round(focusCamera.y)}px, 0) rotateX(0deg) rotateY(0deg) scale(${focusCamera.zoom})`
    : `translate3d(${pan.x}px, ${pan.y}px, 0) rotateX(${tilt.x}deg) rotateY(${tilt.y}deg) scale(${zoom})`;
  const focusStyle = selectedPositionedGoal
    ? ({
        "--focus-glow-x": `${selectedPositionedGoal.x}%`,
        "--focus-glow-y": `${selectedPositionedGoal.y}%`
      } as CSSProperties)
    : undefined;

  const handleStarfieldClick = (event: MouseEvent<HTMLElement>) => {
    if (
      !isFocusMode ||
      (event.target as HTMLElement).closest(".celestial-control") ||
      suppressClickRef.current
    ) {
      return;
    }
    onDismissFocus();
  };

  const handlePointerDown = (event: PointerEvent<HTMLElement>) => {
    if (event.button !== 0) {
      return;
    }
    if ((event.target as HTMLElement).closest(".celestial-control, .orbit-visual-only")) {
      return;
    }
    updateTilt(event);
    if (isFocusMode) {
      return;
    }
    dragRef.current = {
      active: true,
      lastX: event.clientX,
      lastY: event.clientY,
      totalDistance: 0,
      pointerId: event.pointerId
    };
    setIsDragging(true);
    if ("setPointerCapture" in event.currentTarget) {
      event.currentTarget.setPointerCapture(event.pointerId);
    }
  };

  const handlePointerMove = (event: PointerEvent<HTMLElement>) => {
    updateTilt(event);
    if (!dragRef.current.active || dragRef.current.pointerId !== event.pointerId) {
      return;
    }
    const dx = event.clientX - dragRef.current.lastX;
    const dy = event.clientY - dragRef.current.lastY;
    if (dx === 0 && dy === 0) {
      return;
    }

    dragRef.current.lastX = event.clientX;
    dragRef.current.lastY = event.clientY;
    dragRef.current.totalDistance += Math.abs(dx) + Math.abs(dy);
    setPan((current) => ({
      x: clamp(current.x + dx, -320, 320),
      y: clamp(current.y + dy, -240, 240)
    }));
  };

  const finishDrag = (event: PointerEvent<HTMLElement>) => {
    if (!dragRef.current.active || dragRef.current.pointerId !== event.pointerId) {
      return;
    }
    if (dragRef.current.totalDistance > 6) {
      suppressClickRef.current = true;
      window.setTimeout(() => {
        suppressClickRef.current = false;
      }, 0);
    }
    dragRef.current.active = false;
    setIsDragging(false);
    if ("releasePointerCapture" in event.currentTarget) {
      event.currentTarget.releasePointerCapture(event.pointerId);
    }
  };

  return (
    <section
      className={`starfield-panel ${isDragging ? "dragging" : ""} ${isFocusMode ? "focus-mode" : ""} ${
        isFocusTransitioning ? "focus-entering" : ""
      } ${isFocusExiting ? "focus-exiting" : ""}`}
      aria-label="互动星图"
      style={focusStyle}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={finishDrag}
      onPointerCancel={finishDrag}
      onWheel={handleWheel}
      onClick={handleStarfieldClick}
      onPointerLeave={() => {
        if (!dragRef.current.active) {
          setTiltTarget({ x: 0, y: 0 });
        }
      }}
    >
      <div
        className="starfield-layer"
        data-testid="starfield-layer"
        data-camera-mode={focusCamera ? "focus" : "free"}
        style={{ transform: layerTransform }}
      >
        <div className="starfield-grid" />
        <div className="star-noise" />
        {positionedGoals.length === 0 && (
          <div className="empty-starfield">
            <Sparkles size={28} />
            <p>还没有恒星。创建第一个目标，让这片星域开始发光。</p>
          </div>
        )}
        {positionedGoals.map(({ goal, stats, x, y, size }) => {
          const routines = state.routines.filter((routine) => routine.goalId === goal.id);
          const isSelectedGoal = selectedGoalId === goal.id;
          const isNearFocus = isFocusMode && isSelectedGoal && !isFocusExiting;
          return (
            <div
              key={goal.id}
              className={`star-system ${goal.status} ${isNearFocus ? "focus-near" : ""} ${
                isFocusExiting && isSelectedGoal ? "focus-leaving" : ""
              }`}
              data-focus-phase={isNearFocus ? focusPhase : undefined}
              style={
                {
                  left: `${x}%`,
                  top: `${y}%`,
                  "--star-size": `${size}px`,
                  "--focus-orbit-scale": focusCamera?.orbitScale ?? 1
                } as CSSProperties
              }
            >
              <button
                className={`star-node celestial-control ${goal.status} ${selectedGoalId === goal.id ? "selected" : ""}`}
                style={{ ...createStarColorStyle(goal), width: size, height: size }}
                type="button"
                aria-label={`进入 ${goal.title}`}
                onClick={(event) => {
                  if (suppressClickRef.current) {
                    event.preventDefault();
                    event.stopPropagation();
                    return;
                  }
                  onSelectGoal(goal.id);
                }}
              >
                <span className="stellar-core" style={{ "--completion": `${Math.max(18, stats.completionRate)}%` } as CSSProperties} />
              </button>
              {routines.slice(0, 6).map((routine, index) => {
                const completed = state.checkIns.filter((checkIn) => checkIn.routineId === routine.id && checkIn.completed).length;
                return (
                  <div
                    key={routine.id}
                    className={`orbit-shell orbit-visual-only ${
                      selectedRoutineId === routine.id ? "selected" : ""
                    }`}
                    style={createOrbitStyle(routine, index, completed, isNearFocus)}
                    aria-hidden="true"
                  >
                    <span className="orbit-path" />
                    <span className="orbit-runner">
                      <span className="planet" />
                    </span>
                  </div>
                );
              })}
              {isNearFocus && (
                <div className="near-routine-labels" aria-label="近景 routine 轨道">
                  {routines.slice(0, 6).map((routine, index, visibleRoutines) => {
                    const labelLayout = createFocusLabelLayout(routine, index, visibleRoutines.length);
                    return (
                      <button
                        className={`near-routine-label celestial-control ${selectedRoutineId === routine.id ? "selected" : ""}`}
                        data-side={labelLayout.side}
                        key={routine.id}
                        style={labelLayout.style}
                        type="button"
                        aria-label={`查看轨道 ${routine.title}`}
                        onClick={(event) => {
                          event.stopPropagation();
                          onSelectRoutine(routine.id);
                        }}
                      >
                        {routine.title}
                      </button>
                    );
                  })}
                </div>
              )}
              <span className="star-label">
                <strong>{goal.title}</strong>
                <small>{goal.status === "completed" ? "已点亮" : `${stats.completionRate}%`}</small>
              </span>
            </div>
          );
        })}
      </div>
      <div className="starfield-zoom-controls celestial-control" aria-label="星图缩放">
        <button className="icon-only" type="button" aria-label="缩小星图" onClick={() => zoomBy(-0.1)} disabled={zoom <= zoomConfig.min}>
          <Minus size={16} />
        </button>
        <button className="icon-only" type="button" aria-label="重置星图缩放" onClick={resetZoom}>
          <RotateCcw size={15} />
        </button>
        <button className="icon-only" type="button" aria-label="放大星图" onClick={() => zoomBy(0.1)} disabled={zoom >= zoomConfig.max}>
          <Plus size={16} />
        </button>
        <span>{Math.round(zoom * 100)}%</span>
      </div>
      <div className="starfield-hint" aria-hidden="true">
        <Radar size={15} />
        <span>拖拽查看星域</span>
      </div>
    </section>
  );
}

function createOrbitStyle(routine: Routine, index: number, completedCount: number, isNearFocus = false): CSSProperties {
  const seed = hashString(routine.id);
  const radius = isNearFocus ? getFocusOrbitRadius(routine, index) : getFreeOrbitRadius(routine, index);
  const duration = isNearFocus ? 50 + index * 13 + (seed % 22) : 38 + index * 10 + (seed % 18);
  const delay = -Math.round(((seed % 100) / 100) * duration);
  const tilt = isNearFocus ? -12 + (seed % 25) : -18 + (seed % 37);
  const planetSize = isNearFocus ? completedCount > 0 ? 12 : 10 : 7 + (seed % 4);
  const alpha = isNearFocus ? 0.34 + (index % 2) * 0.08 : 0.22 + (index % 3) * 0.08;

  return {
    "--orbit-radius": `${radius}px`,
    "--orbit-duration": `${duration}s`,
    "--orbit-delay": `${delay}s`,
    "--orbit-tilt": `${tilt}deg`,
    "--planet-size": `${planetSize}px`,
    "--planet-glow": completedCount > 0 ? "1" : ".38",
    "--orbit-alpha": alpha.toString()
  } as CSSProperties;
}

function getFocusOrbitRadius(routine: Routine, index: number): number {
  return 178 + index * 42 + (hashString(routine.id) % 18);
}

function getFreeOrbitRadius(routine: Routine, index: number): number {
  return 62 + index * 16 + (hashString(routine.id) % 12);
}

function getGoalPosition(index: number): { x: number; y: number } {
  const centeredPositions = [
    { x: 45, y: 50 },
    { x: 58, y: 43 },
    { x: 40, y: 62 },
    { x: 64, y: 58 },
    { x: 36, y: 39 },
    { x: 53, y: 66 },
    { x: 66, y: 35 },
    { x: 34, y: 54 },
    { x: 48, y: 37 },
    { x: 60, y: 67 }
  ];

  if (index < centeredPositions.length) {
    return centeredPositions[index];
  }

  const overflowIndex = index - centeredPositions.length;
  return {
    x: clamp(34 + ((overflowIndex * 17) % 33), 34, 66),
    y: clamp(35 + ((overflowIndex * 23) % 34), 35, 68)
  };
}

function hashString(value: string): number {
  return [...value].reduce((hash, char) => (hash * 31 + char.charCodeAt(0)) >>> 0, 7);
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function roundZoom(value: number): number {
  return Math.round(value * 100) / 100;
}

function getZoomConfig(goalCount: number) {
  if (goalCount <= 1) {
    return { min: 0.82, max: 1.38, default: 1.08 };
  }
  if (goalCount <= 3) {
    return { min: 0.74, max: 1.28, default: 1 };
  }
  if (goalCount <= 6) {
    return { min: 0.66, max: 1.18, default: 0.9 };
  }
  return { min: 0.58, max: 1.08, default: 0.8 };
}

function prefersReducedMotion(): boolean {
  return typeof window !== "undefined" && window.matchMedia?.("(prefers-reduced-motion: reduce)").matches === true;
}

function createFocusCamera(goalX: number, goalY: number, routineCount: number, maxOrbitRadius: number) {
  const width = typeof window === "undefined" ? 1280 : window.innerWidth || 1280;
  const height = typeof window === "undefined" ? 720 : window.innerHeight || 720;
  const isCompact = width <= 980;
  const routinePressure = Math.max(0, routineCount - 1) * (isCompact ? 0.045 : 0.055);
  const orbitPressure = Math.max(0, maxOrbitRadius - 190) / (isCompact ? 1050 : 950);
  const focusZoom = roundZoom(
    clamp((isCompact ? 1.42 : 1.68) - routinePressure - orbitPressure, isCompact ? 1.02 : 1.12, isCompact ? 1.5 : 1.72)
  );
  const orbitScale = roundZoom(
    clamp(
      (isCompact ? 0.84 : 0.96) - Math.max(0, routineCount - 3) * 0.04 - Math.max(0, maxOrbitRadius - 260) / 1600,
      isCompact ? 0.66 : 0.72,
      isCompact ? 0.86 : 0.98
    )
  );
  const layerWidth = width * 1.24;
  const layerHeight = height * 1.24;
  const starX = -width * 0.12 + layerWidth * (goalX / 100);
  const starY = -height * 0.12 + layerHeight * (goalY / 100);
  const targetX = width * (isCompact ? 0.5 : 0.29);
  const targetY = height * (isCompact ? 0.36 : 0.52);
  const centerX = width / 2;
  const centerY = height / 2;
  const scaledStarX = centerX + (starX - centerX) * focusZoom;
  const scaledStarY = centerY + (starY - centerY) * focusZoom;

  return {
    x: clamp(targetX - scaledStarX, width * -1.3, width * 1.3),
    y: clamp(targetY - scaledStarY, height * -1.15, height * 1.15),
    zoom: focusZoom,
    orbitScale
  };
}

function createStarColorStyle(goal: Goal): CSSProperties {
  const seed = hashString(goal.id);
  const hue = (seed % 260) + 20;
  const secondaryHue = (hue + 28 + (seed % 34)) % 360;

  return {
    "--star-core": `hsl(${hue} 32% 88%)`,
    "--star-mid": `hsl(${hue} 24% 62%)`,
    "--star-accent": `hsla(${secondaryHue} 24% 58% / 0.38)`,
    "--star-faint": `hsla(${hue} 18% 54% / 0.12)`,
    "--star-halo": `hsla(${hue} 24% 58% / 0.28)`,
    "--star-halo-soft": `hsla(${secondaryHue} 22% 54% / 0.14)`,
    "--star-completed-glow": `hsla(${hue} 28% 70% / 0.46)`
  } as CSSProperties;
}

function createFocusLabelLayout(
  routine: Routine,
  index: number,
  total: number
): { side: "left" | "right"; style: CSSProperties } {
  const side = index % 2 === 0 ? "right" : "left";
  const radius = getFocusOrbitRadius(routine, index);
  const rawHorizontalOffset = radius + 52;
  const horizontalOffset =
    side === "right" ? clamp(rawHorizontalOffset, 190, 270) : clamp(rawHorizontalOffset, 170, 210);
  const centeredIndex = index - (total - 1) / 2;
  const ringDrift = (radius - 178) * 0.08;
  const labelY = clamp(centeredIndex * 48 + (side === "right" ? -ringDrift : ringDrift), -242, 242);

  return {
    side,
    style: {
      "--caption-x": `${side === "right" ? horizontalOffset : -horizontalOffset}px`,
      "--caption-y": `${Math.round(labelY)}px`,
    "--caption-delay": `${160 + index * 46}ms`
    } as CSSProperties
  };
}

function HomePanel({ onCreateGoal }: { onCreateGoal: () => void }) {
  return (
    <section className="panel intro-panel">
      <p className="eyebrow">Starfield OS</p>
      <h1>把目标点成恒星，把 routine 稳定成轨道。</h1>
      <p>
        这里不会替你规划人生，只负责让你每天看见自己是否真的在靠近。今晚复盘、勾上完成项，星图会记住每一次坚持。
      </p>
      <button className="primary-button" type="button" aria-label="从首页新建目标" onClick={onCreateGoal}>
        <Plus size={18} />
        <span>新建目标</span>
      </button>
    </section>
  );
}

function GoalDetail({
  state,
  goal,
  today,
  onBack,
  onEditGoal,
  onAddRoutine,
  onEditRoutine,
  onAddTask,
  onCompleteGoal,
  onDeleteGoal,
  onDeleteRoutine,
  onToggleRoutineToday,
  onToggleTask,
  onDeleteTask
}: {
  state: AppState;
  goal: Goal;
  today: ISODate;
  onBack: () => void;
  onEditGoal: () => void;
  onAddRoutine: () => void;
  onEditRoutine: (routine: Routine) => void;
  onAddTask: () => void;
  onCompleteGoal: () => void;
  onDeleteGoal: () => void;
  onDeleteRoutine: (routineId: string) => void;
  onToggleRoutineToday: (routineId: string, completed: boolean) => void;
  onToggleTask: (taskId: string, completed: boolean) => void;
  onDeleteTask: (taskId: string) => void;
}) {
  const routines = state.routines.filter((routine) => routine.goalId === goal.id);
  const tasks = state.tasks.filter((task) => task.goalId === goal.id);
  const stats = calculateGoalStats({ goal, routines: state.routines, tasks: state.tasks, checkIns: state.checkIns, today });

  return (
    <section className="panel detail-panel">
      <div className="panel-header">
        <button className="ghost-button" type="button" onClick={onBack}>
          <ChevronLeft size={18} />
          <span>星图</span>
        </button>
        <span className={`status-chip ${goal.status}`}>
          {goal.status === "completed" ? "已点亮恒星" : "航行中"}
        </span>
      </div>

      <div className="goal-title-row">
        <div>
          <p className="eyebrow">恒星档案</p>
          <h1>{goal.title}</h1>
        </div>
        <div className="compact-actions">
          <button className="icon-only" type="button" onClick={onEditGoal} title="编辑目标">
            <Edit3 size={17} />
          </button>
          <button className="icon-only danger" type="button" onClick={onDeleteGoal} title="删除目标">
            <Trash2 size={17} />
          </button>
        </div>
      </div>

      <div className="stats-grid">
        <Metric label="已经开始" value={`${stats.daysStarted} 天`} />
        <Metric label="剩余时间" value={stats.daysRemaining === undefined ? "未设定" : `${stats.daysRemaining} 天`} />
        <Metric label="routine" value={`${stats.routineCount} 个`} />
        <Metric label="完成率" value={`${stats.completionRate}%`} />
      </div>
      <div className="signal-line">
        <Flame size={17} />
        <span>已完成 {stats.completedCheckIns} 次</span>
        <span>完成率 {stats.completionRate}%</span>
      </div>

      <div className="section-heading">
        <h2>行星 routine</h2>
        <button className="secondary-button" type="button" onClick={onAddRoutine}>
          <Plus size={16} />
          <span>添加 routine</span>
        </button>
      </div>
      <div className="item-list">
        {routines.length === 0 ? (
          <p className="empty-copy">还没有行星。添加一个每日或每周 routine，让目标拥有稳定轨道。</p>
        ) : (
          routines.map((routine) => {
            const completed = state.checkIns.filter((checkIn) => checkIn.routineId === routine.id && checkIn.completed).length;
            const visibleToday = shouldShowRoutineForDate(routine, state.checkIns, today);
            const completedToday = isRoutineCompletedOnDate(state.checkIns, routine.id, today);
            const canCompleteToday = canCompleteRoutineOnDate(routine, state.checkIns, today);
            const actionLabel = completedToday
              ? "已点亮"
              : canCompleteToday
                ? "今日点亮"
                : "本周已达标";
            return (
              <article className="routine-row" key={routine.id}>
                <Orbit size={18} />
                <div>
                  <strong>{routine.title}</strong>
                  <small>
                    {frequencyLabel(routine.frequency)} · {completed} 次 · {visibleToday ? "今日待检查" : "本周已达标"}
                  </small>
                </div>
                <button
                  className={`routine-check-button ${completedToday ? "completed" : ""}`}
                  type="button"
                  disabled={!canCompleteToday}
                  aria-label={`${actionLabel} ${routine.title}`}
                  onClick={() => onToggleRoutineToday(routine.id, !completedToday)}
                >
                  {actionLabel}
                </button>
                <button className="icon-only" type="button" onClick={() => onEditRoutine(routine)} title="编辑 routine">
                  <Edit3 size={16} />
                </button>
                <button className="icon-only danger" type="button" onClick={() => onDeleteRoutine(routine.id)} title="删除 routine">
                  <Trash2 size={16} />
                </button>
              </article>
            );
          })
        )}
      </div>

      <div className="section-heading">
        <h2>临时事项</h2>
        <button className="secondary-button" type="button" onClick={onAddTask}>
          <Plus size={16} />
          <span>添加事项</span>
        </button>
      </div>
      <div className="item-list">
        {tasks.length === 0 ? (
          <p className="empty-copy">没有临时事项。需要推进目标时，可以临时加一个任务节点。</p>
        ) : (
          tasks.map((task) => (
            <label className="task-row" key={task.id}>
              <input
                type="checkbox"
                checked={task.completed}
                onChange={(event) => onToggleTask(task.id, event.currentTarget.checked)}
              />
              <span>{task.title}</span>
              {task.date && <small>{task.date}</small>}
              <button className="icon-only danger" type="button" onClick={() => onDeleteTask(task.id)} title="删除事项">
                <Trash2 size={16} />
              </button>
            </label>
          ))
        )}
      </div>

      {goal.status === "active" && (
        <button className="complete-button" type="button" onClick={onCompleteGoal}>
          <Archive size={18} />
          <span>标记目标完成</span>
        </button>
      )}
    </section>
  );
}

function RoutineQuickPanel({
  state,
  routine,
  goal,
  today,
  onClose,
  onOpenGoal,
  onEditRoutine,
  onDeleteRoutine,
  onToggleRoutineToday
}: {
  state: AppState;
  routine: Routine;
  goal: Goal;
  today: ISODate;
  onClose: () => void;
  onOpenGoal: () => void;
  onEditRoutine: () => void;
  onDeleteRoutine: () => void;
  onToggleRoutineToday: (completed: boolean) => void;
}) {
  const stats = calculateGoalStats({ goal, routines: state.routines, tasks: state.tasks, checkIns: state.checkIns, today });
  const completed = state.checkIns.filter((checkIn) => checkIn.routineId === routine.id && checkIn.completed).length;
  const visibleToday = shouldShowRoutineForDate(routine, state.checkIns, today);
  const completedToday = isRoutineCompletedOnDate(state.checkIns, routine.id, today);
  const canCompleteToday = canCompleteRoutineOnDate(routine, state.checkIns, today);
  const actionLabel = completedToday
    ? "已点亮"
    : canCompleteToday
      ? "今日点亮"
      : "本周已达标";

  return (
    <aside className="routine-quick-panel" aria-label={`行星信标 ${routine.title}`}>
      <div className="panel-header">
        <div>
          <p className="eyebrow">行星信标</p>
          <h2>{routine.title}</h2>
        </div>
        <button className="icon-only" type="button" onClick={onClose} title="关闭行星信标">
          <X size={16} />
        </button>
      </div>
      <div className="planet-meta">
        <span>{goal.title}</span>
        <span>{frequencyLabel(routine.frequency)}</span>
        <span>{visibleToday ? "今日待检查" : "本周已达标"}</span>
      </div>
      <div className="quick-stats">
        <Metric label="已完成" value={`${completed} 次`} />
        <Metric label="完成率" value={`${stats.completionRate}%`} />
      </div>
      <div className="signal-line quick-signal">
        <Flame size={16} />
        <span>已完成 {completed} 次</span>
        <span>完成率 {stats.completionRate}%</span>
      </div>
      <button
        className={`routine-check-button ${completedToday ? "completed" : ""}`}
        type="button"
        disabled={!canCompleteToday}
        aria-label={`${actionLabel} ${routine.title}`}
        onClick={() => onToggleRoutineToday(!completedToday)}
      >
        {actionLabel}
      </button>
      <div className="quick-actions">
        <button className="secondary-button" type="button" onClick={onOpenGoal}>
          <Orbit size={16} />
          <span>打开恒星档案</span>
        </button>
        <button className="icon-only" type="button" onClick={onEditRoutine} title="编辑 routine">
          <Edit3 size={16} />
        </button>
        <button className="icon-only danger" type="button" onClick={onDeleteRoutine} title="删除 routine">
          <Trash2 size={16} />
        </button>
      </div>
    </aside>
  );
}

function ReviewPanel({
  dates,
  reviewDate,
  items,
  selectedStats,
  onDateChange,
  onToggle
}: {
  dates: ISODate[];
  reviewDate: ISODate;
  items: ReturnType<typeof buildCheckInItems>;
  selectedStats?: ReturnType<typeof calculateGoalStats>;
  onDateChange: (date: ISODate) => void;
  onToggle: (routineId: string, completed: boolean) => void;
}) {
  return (
    <section className="panel review-panel">
      <p className="eyebrow">Evening Review</p>
      <h1>今晚复盘</h1>
      <div className="date-rail" role="group" aria-label="补记日期">
        {dates.map((date) => (
          <button
            key={date}
            className={date === reviewDate ? "selected" : ""}
            type="button"
            onClick={() => onDateChange(date)}
          >
            {date.slice(5)}
          </button>
        ))}
      </div>
      <div className="review-list">
        {items.length === 0 ? (
          <div className="empty-review">
            <Check size={28} />
            <p>这一天没有待检查的 routine。轨道安静，星图仍在。</p>
          </div>
        ) : (
          items.map((item) => (
            <label className="review-item" key={item.routineId}>
              <input
                type="checkbox"
                checked={item.completed}
                aria-label={item.routineTitle}
                onChange={(event) => onToggle(item.routineId, event.currentTarget.checked)}
              />
              <span className="review-orbit" />
              <span>
                <strong>{item.routineTitle}</strong>
                <small>{item.goalTitle} · {item.frequencyLabel}</small>
              </span>
            </label>
          ))
        )}
      </div>
      {selectedStats && (
        <div className="review-summary">
          <span>已完成 {selectedStats.completedCheckIns} 次</span>
          <span>完成率 {selectedStats.completionRate}%</span>
        </div>
      )}
    </section>
  );
}

function GoalDialog({
  goal,
  onClose,
  onSubmit
}: {
  goal?: Goal;
  onClose: () => void;
  onSubmit: (title: string, startDate: ISODate, dueDate?: ISODate) => void;
}) {
  const [title, setTitle] = useState(goal?.title ?? "");
  const [startDate, setStartDate] = useState(goal?.startDate ?? todayISO());
  const [dueDate, setDueDate] = useState(goal?.dueDate ?? "");

  return (
    <Modal title={goal ? "编辑目标" : "新建目标"} onClose={onClose}>
      <form
        className="form"
        onSubmit={(event) => {
          event.preventDefault();
          if (title.trim()) {
            onSubmit(title, startDate, dueDate || undefined);
          }
        }}
      >
        <label>
          <span>目标名称</span>
          <input value={title} onChange={(event) => setTitle(event.currentTarget.value)} autoFocus />
        </label>
        <label>
          <span>开始日期</span>
          <input type="date" value={startDate} onChange={(event) => setStartDate(event.currentTarget.value)} />
        </label>
        <label>
          <span>完成期限</span>
          <input type="date" value={dueDate} onChange={(event) => setDueDate(event.currentTarget.value)} />
        </label>
        <button className="primary-button" type="submit">
          <Save size={18} />
          <span>保存目标</span>
        </button>
      </form>
    </Modal>
  );
}

function RoutineDialog({
  routine,
  onClose,
  onSubmit
}: {
  routine?: Routine;
  onClose: () => void;
  onSubmit: (title: string, frequency: RoutineFrequency) => void;
}) {
  const [title, setTitle] = useState(routine?.title ?? "");
  const [frequencyType, setFrequencyType] = useState<RoutineFrequency["type"]>(routine?.frequency.type ?? "daily");
  const [timesPerWeek, setTimesPerWeek] = useState(
    routine?.frequency.type === "weeklyCount" ? routine.frequency.timesPerWeek : 2
  );

  return (
    <Modal title={routine ? "编辑 routine" : "添加 routine"} onClose={onClose}>
      <form
        className="form"
        onSubmit={(event) => {
          event.preventDefault();
          if (!title.trim()) {
            return;
          }
          onSubmit(
            title,
            frequencyType === "daily"
              ? { type: "daily" }
              : { type: "weeklyCount", timesPerWeek }
          );
        }}
      >
        <label>
          <span>routine 名称</span>
          <input value={title} onChange={(event) => setTitle(event.currentTarget.value)} autoFocus />
        </label>
        <label>
          <span>频率</span>
          <select value={frequencyType} onChange={(event) => setFrequencyType(event.currentTarget.value as RoutineFrequency["type"])}>
            <option value="daily">每日</option>
            <option value="weeklyCount">每周 N 次</option>
          </select>
        </label>
        {frequencyType === "weeklyCount" && (
          <label>
            <span>每周次数</span>
            <input
              type="number"
              min={1}
              max={7}
              value={timesPerWeek}
              onChange={(event) => setTimesPerWeek(Number(event.currentTarget.value))}
            />
          </label>
        )}
        <button className="primary-button" type="submit">
          <Save size={18} />
          <span>保存 routine</span>
        </button>
      </form>
    </Modal>
  );
}

function TaskDialog({
  onClose,
  onSubmit
}: {
  onClose: () => void;
  onSubmit: (title: string, date?: ISODate) => void;
}) {
  const [title, setTitle] = useState("");
  const [date, setDate] = useState("");

  return (
    <Modal title="添加临时事项" onClose={onClose}>
      <form
        className="form"
        onSubmit={(event) => {
          event.preventDefault();
          if (title.trim()) {
            onSubmit(title, date || undefined);
          }
        }}
      >
        <label>
          <span>事项名称</span>
          <input value={title} onChange={(event) => setTitle(event.currentTarget.value)} autoFocus />
        </label>
        <label>
          <span>事项日期</span>
          <input type="date" value={date} onChange={(event) => setDate(event.currentTarget.value)} />
        </label>
        <button className="primary-button" type="submit">
          <Save size={18} />
          <span>保存事项</span>
        </button>
      </form>
    </Modal>
  );
}

function formatStorageDate(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "刚刚";
  }
  return date.toLocaleString("zh-CN", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit"
  });
}

function persistenceTitle(status: PersistenceStatus): string {
  switch (status) {
    case "protected":
      return "本地存储已受保护";
    case "unprotected":
      return "浏览器暂未授予保护";
    case "unsupported":
      return "当前浏览器不支持持久化保护";
    default:
      return "本地存储保护未开启";
  }
}

function persistenceDescription(status: PersistenceStatus): string {
  switch (status) {
    case "protected":
      return "浏览器会尽量避免自动清理这份星图数据。";
    case "unprotected":
      return "仍然可以使用本地保存和备份导出，建议定期导出备份。";
    case "unsupported":
      return "备份导出仍可使用，请定期保存备份文件。";
    default:
      return "可请求浏览器保护此站点数据，降低被自动清理的风险。";
  }
}

function Modal({
  title,
  children,
  onClose
}: {
  title: string;
  children: ReactNode;
  onClose: () => void;
}) {
  return (
    <div className="modal-backdrop" role="presentation">
      <section className="modal" role="dialog" aria-modal="true" aria-label={title}>
        <div className="panel-header">
          <h2>{title}</h2>
          <button className="ghost-button" type="button" onClick={onClose}>
            关闭
          </button>
        </div>
        {children}
      </section>
    </div>
  );
}
