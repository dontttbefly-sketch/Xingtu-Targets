import { todayISO } from "./domain";
import type { AppState, ISODate } from "./types";

export function shouldShowEveningReview(state: AppState, now = new Date()): boolean {
  const hour = now.getHours();
  const today = todayISO(now);
  return hour >= 21 && state.lastReminderDate !== today;
}

export async function requestNotificationPermission(): Promise<NotificationPermission> {
  if (!("Notification" in window)) {
    return "denied";
  }
  if (Notification.permission === "default") {
    return Notification.requestPermission();
  }
  return Notification.permission;
}

export async function sendEveningNotification(): Promise<boolean> {
  if (!("Notification" in window)) {
    return false;
  }

  const permission = await requestNotificationPermission();
  if (permission !== "granted") {
    return false;
  }

  new Notification("今晚复盘", {
    body: "检查今天的行星轨道，把完成的 routine 点亮。",
    tag: "starfield-evening-review"
  });
  return true;
}

export function reviewDateFromInput(date: ISODate): ISODate {
  return date;
}
