// The admin API (/admin/api/v1 on the Likho backend). The session is an
// HttpOnly cookie; every change carries X-Requested-With (CSRF guard).

export class ApiError extends Error {
  status: number
  code: string
  problems: string[]
  constructor(status: number, code: string, message: string, problems: string[] = []) {
    super(message)
    this.status = status
    this.code = code
    this.problems = problems
  }
}

const BASE = '/admin/api/v1'

let onSignedOut: (() => void) | null = null
export function setSignedOutHandler(f: () => void) {
  onSignedOut = f
}

export async function api<T = unknown>(path: string, init: { method?: string; body?: unknown } = {}): Promise<T> {
  const method = init.method ?? 'GET'
  let res: Response
  try {
    res = await fetch(BASE + path, {
      method,
      credentials: 'same-origin',
      headers: {
        Accept: 'application/json',
        ...(init.body !== undefined ? { 'Content-Type': 'application/json' } : {}),
        ...(method !== 'GET' ? { 'X-Requested-With': 'likho-admin' } : {}),
      },
      body: init.body !== undefined ? JSON.stringify(init.body) : undefined,
    })
  } catch {
    throw new ApiError(0, 'offline', 'Cannot reach the Likho API. Is the backend running?')
  }
  if (res.status === 204) return undefined as T
  const text = await res.text()
  let data: unknown = null
  try {
    data = text ? JSON.parse(text) : null
  } catch {
    data = null
  }
  if (!res.ok) {
    const d = (data ?? {}) as { error?: string; message?: string; problems?: string[] }
    if (res.status === 401 && path !== '/auth/login') onSignedOut?.()
    throw new ApiError(res.status, d.error ?? 'error', d.message ?? `Request failed (${res.status})`, d.problems ?? [])
  }
  return data as T
}

export const get = <T>(path: string) => api<T>(path)
export const post = <T>(path: string, body: unknown = {}) => api<T>(path, { method: 'POST', body })
export const put = <T>(path: string, body: unknown) => api<T>(path, { method: 'PUT', body })
export const patch = <T>(path: string, body: unknown) => api<T>(path, { method: 'PATCH', body })
export const del = <T>(path: string) => api<T>(path, { method: 'DELETE' })

export function qs(params: Record<string, string | number | boolean | undefined | null>) {
  const p = new URLSearchParams()
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== null && v !== '') p.set(k, String(v))
  }
  const s = p.toString()
  return s ? `?${s}` : ''
}

// ------------------------------------------------------------------ types

export type Role = 'owner' | 'editor' | 'viewer'

export interface Admin {
  id: string
  email: string
  name: string
  role: Role
  disabled: boolean
  createdAt: string
  lastLoginAt: string | null
}

export interface CourseSummary {
  id: string
  title: string
  description: string
  locale: string
  worlds: number
  levels: number
  version: string
  updatedAt: string
}

export interface KeyCount {
  key: string
  n: number
}

export interface DayPoint {
  day: string
  signups: number
  active: number
  levels: number
}

export interface LevelStat {
  level: number
  children: number
  plays: number
  avgStars: number
  threeStars: number
  oneStar: number
  avgSeconds: number
  current: number
}

export interface Totals {
  parents: number
  children: number
  newParents: number
  newToday: number
  activeToday: number
  active7: number
  active30: number
  onlineNow: number
  plus: number
  trialsUsed: number
  levelsCompleted: number
  starsEarned: number
  plays: number
  levelsInPeriod: number
  atEnd: number
  finished: number
  countries: number
}

export interface Overview {
  totals: Totals
  series: DayPoint[]
  countries: KeyCount[]
  platforms: KeyCount[]
  versions: KeyCount[]
  ages: KeyCount[]
  course: CourseSummary
  lastLevel: number
  funnel: LevelStat[]
  notStarted: number
  unreadAlerts: number
  recentAlerts: Alert[]
  recentActivity: ActivityEvent[]
  courses: CourseSummary[]
}

export interface Page<T> {
  items: T[]
  total: number
  page: number
  pageSize: number
}

export interface Family {
  id: string
  email: string
  name: string
  pictureUrl: string
  country: string
  countrySource: string
  platform: string
  appVersion: string
  createdAt: string
  lastSeenAt: string
  plusUntil: string | null
  trialUsed: boolean
  children: number
  stars: number
  levels: number
  starsEarned: number
  topLevel: number
}

export interface Learner {
  id: string
  name: string
  age: number
  color: string
  stars: number
  createdAt: string
  parentId: string
  parentEmail: string
  parentName: string
  country: string
  platform: string
  levels: number
  starsEarned: number
  threeStars: number
  topLevel: number
  lastPlayed: string | null
}

export interface ChildView {
  id: string
  name: string
  age: number
  color: string
  stars: number
  wearing: string | null
  owned: string[]
  room: string[]
  daysPlayed: number
  minutesThisWeek: number
  progress: Record<string, { levelStars: Record<string, number> }>
}

export interface FamilyDetail {
  family: Family
  subscription: { active: boolean; plusUntil: string | null; trialUsed: boolean; store?: string; plan?: string; autoRenewing: boolean }
  settings: Record<string, number | boolean>
  children: ChildView[]
  devices: { id: string; device: string; createdAt: string; expiresAt: string; revokedAt: string | null }[]
  activity: ActivityEvent[]
  lastLevel: number
  purchases: Purchase[]
}

/** A Google Play purchase of Likho Plus. */
export interface Purchase {
  token: string
  plan: string
  offer: string
  state: string
  expiresAt: string
  autoRenewing: boolean
  orderId: string
  test: boolean
  createdAt: string
}

export interface ActivityEvent {
  id: number
  at: string
  type: string
  parentId: string | null
  childId: string | null
  courseId: string
  level: number
  stars: number
  seconds: number
  detail: Record<string, unknown>
  parentEmail: string
  parentName: string
  country: string
  childName: string
}

export interface Alert {
  id: number
  at: string
  kind: string
  parentId: string | null
  childId: string | null
  courseId: string
  level: number
  title: string
  body: string
  readAt: string | null
  readBy: string
  parentEmail: string
  childName: string
  country: string
}

export interface AlertRules {
  reachedEnd: boolean
  levelsBeforeEnd: number
  courseCompleted: boolean
  newSignup: boolean
  trialStarted: boolean
}

export interface ContentWorld {
  folder: string
  id: string
  order: number
  name: string
  skill: string
  icon: string
  themeId: string
  bossId: string
  bossName: string
  source: 'builtin' | 'admin'
  live: boolean
  levels: number[]
}

export type LevelStatus = 'live' | 'draft' | 'changed'

export interface ContentLevel {
  number: number
  id: string
  name: string
  skill: string
  icon: string
  world: string
  worldId: string
  isBoss: boolean
  requiresSubscription: boolean
  rounds: number
  source: 'builtin' | 'edited' | 'new'
  status: LevelStatus
  updatedAt: string | null
  updatedBy: string
  publishedAt: string | null
}

export interface ContentLevelDetail extends ContentLevel {
  doc: string
  liveDoc: string | null
  builtinDoc: string | null
}

export interface ContentCourse {
  id: string
  title: string
  version: string
  liveLevels: number
  nextNumber: number
  revision: number
  problems: string[]
  worlds: ContentWorld[]
  levels: ContentLevel[]
  themes: string[]
  bosses: string[]
  emptyWorlds: ContentWorld[]
  courses: CourseSummary[]
}

export interface LevelStats {
  levels: LevelStat[]
  notStarted: number
  finished: number
}

export interface AuditEntry {
  id: number
  at: string
  adminId: string
  adminEmail: string
  action: string
  target: string
  detail: Record<string, unknown> | null
}

// Google Play closed test

export interface ClosedTestSettings {
  startDate: string // YYYY-MM-DD, '' = not set up
  days: number
  needed: number
  timeZone: string
  plus: boolean
  plusUntil: string
  openLevels: boolean
  optInUrl: string
  reminder: string // {name} {day} {days}
}

export interface TestAccount {
  parentId: string
  email: string
  name: string
  pictureUrl: string
  platform: string
  appVersion: string
  country: string
  createdAt: string
  lastSeenAt: string | null
  plusUntil: string | null
  openLevels: boolean
  children: number
  levels: number
  testerId: string | null
  auto: boolean
  days: string[]
}

export interface Tester {
  id: string
  name: string
  email: string
  phone: string
  note: string
  createdAt: string
  accounts: TestAccount[]
  days: string[]
}

export interface ClosedTestBoard {
  settings: ClosedTestSettings
  today: string
  endDate: string
  day: number
  testers: Tester[]
  newAccounts: TestAccount[]
  notTesters: TestAccount[]
}
