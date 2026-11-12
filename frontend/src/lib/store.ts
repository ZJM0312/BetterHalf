'use client';
import { useSyncExternalStore } from 'react';

export interface Moment { id: string; date: string; text: string; mood: string; photo?: string; by: 'me' | 'partner'; }
export interface Anniversary { id: string; name: string; date: string; yearly: boolean; }
export interface BucketItem { id: string; text: string; done: boolean; doneAt?: string; }
export interface DecisionList { id: string; name: string; options: string[]; }
export interface Answer { me?: string; partner?: string; }
export interface State {
  v: 1;
  me: string; partner: string; startDate: string;
  moments: Moment[]; anniversaries: Anniversary[]; bucket: BucketItem[];
  decisions: DecisionList[]; answers: Record<string, Answer>;
}

const KEY = 'betterhalf:v1';
export const uid = () => Math.random().toString(36).slice(2, 10) + Date.now().toString(36).slice(-4);
export const todayKey = (d = new Date()) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

let state: State | null = null;
let loaded = false;
const listeners = new Set<() => void>();

function load() {
  if (loaded || typeof window === 'undefined') return;
  loaded = true;
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) state = JSON.parse(raw) as State;
  } catch { /* corrupted storage -> start fresh */ }
}
function persist(): boolean {
  try { localStorage.setItem(KEY, JSON.stringify(state)); return true; } catch { return false; }
}
function emit() { listeners.forEach((l) => l()); }

export function setState(updater: (s: State) => State): boolean {
  if (!state) return false;
  const prev = state;
  state = updater(state);
  if (!persist()) { state = prev; emit(); return false; } // e.g. photo too big for quota
  emit();
  return true;
}

export function createSpace(me: string, partner: string, startDate: string) {
  state = {
    v: 1, me, partner, startDate, moments: [], anniversaries: [], bucket: [],
    decisions: [{ id: uid(), name: '今天吃什么', options: ['火锅', '日料', '烧烤', '麻辣烫', '家常菜', '披萨'] }],
    answers: {},
  };
  persist(); emit();
}
export function importData(json: string): boolean {
  try {
    const s = JSON.parse(json) as State;
    if (s.v !== 1 || !s.me || !s.startDate || !Array.isArray(s.moments)) return false;
    state = s; persist(); emit(); return true;
  } catch { return false; }
}
export function resetAll() { state = null; try { localStorage.removeItem(KEY); } catch {} emit(); }

export function useSpace(): { state: State | null; ready: boolean } {
  const snap = useSyncExternalStore(
    (cb) => { listeners.add(cb); return () => listeners.delete(cb); },
    () => { load(); return state; },
    () => null,
  );
  const ready = useSyncExternalStore(() => () => {}, () => true, () => false);
  return { state: snap, ready };
}

/* ---------- date helpers ---------- */
const parse = (s: string) => { const [y, m, d] = s.split('-').map(Number); return new Date(y, m - 1, d); };
export const daysBetween = (a: string, b: string) => Math.round((parse(b).getTime() - parse(a).getTime()) / 86400000);

/** Days until next occurrence (0 = today). Returns null if one-off date already passed. */
export function daysUntil(a: Anniversary, today = todayKey()): number | null {
  const t = parse(today); const d = parse(a.date);
  if (!a.yearly) { const n = daysBetween(today, a.date); return n >= 0 ? n : null; }
  let next = new Date(t.getFullYear(), d.getMonth(), d.getDate());
  if (next < t) next = new Date(t.getFullYear() + 1, d.getMonth(), d.getDate());
  return Math.round((next.getTime() - t.getTime()) / 86400000);
}

/** Next day-count milestone (第 100/200/520/1314… 天). Calendar anniversaries are handled by daysUntil. */
export function nextMilestone(together: number) {
  const special = [520, 1314, 3344, 5200];
  const nextHundred = (Math.floor(together / 100) + 1) * 100;
  const day = Math.min(nextHundred, ...special.filter((d) => d > together));
  return { label: `第 ${day} 天`, day, left: day - together };
}
