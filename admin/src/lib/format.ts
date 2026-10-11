// Formatting helpers: numbers, dates, countries, event names.

const nf = new Intl.NumberFormat('en')
export const num = (n: number | null | undefined) => nf.format(n ?? 0)

export function pct(part: number, whole: number) {
  if (!whole) return '0%'
  const v = (part / whole) * 100
  return `${v < 10 && v > 0 ? v.toFixed(1) : Math.round(v)}%`
}

const rtf = new Intl.RelativeTimeFormat('en', { numeric: 'auto' })

export function ago(iso: string | null | undefined) {
  if (!iso) return 'never'
  const t = new Date(iso).getTime()
  if (Number.isNaN(t) || t < 0) return 'never'
  const s = Math.round((t - Date.now()) / 1000)
  const a = Math.abs(s)
  if (a < 45) return 'just now'
  if (a < 3600) return rtf.format(Math.round(s / 60), 'minute')
  if (a < 86400) return rtf.format(Math.round(s / 3600), 'hour')
  if (a < 86400 * 30) return rtf.format(Math.round(s / 86400), 'day')
  if (a < 86400 * 365) return rtf.format(Math.round(s / (86400 * 30)), 'month')
  return rtf.format(Math.round(s / (86400 * 365)), 'year')
}

export function date(iso: string | null | undefined) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })
}

export function dateTime(iso: string | null | undefined) {
  if (!iso) return '—'
  return new Date(iso).toLocaleString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}

export function shortDay(day: string) {
  return new Date(day + 'T00:00:00').toLocaleDateString('en-GB', { day: 'numeric', month: 'short' })
}

export function duration(seconds: number) {
  if (!seconds) return '—'
  const s = Math.round(seconds)
  if (s < 60) return `${s}s`
  return `${Math.floor(s / 60)}m ${String(s % 60).padStart(2, '0')}s`
}

const regionNames = (() => {
  try {
    return new Intl.DisplayNames(['en'], { type: 'region' })
  } catch {
    return null
  }
})()

export function countryName(code: string) {
  if (!code) return 'Unknown'
  try {
    return regionNames?.of(code) ?? code
  } catch {
    return code
  }
}

export function flag(code: string) {
  if (!code || code.length !== 2) return '🌐'
  return String.fromCodePoint(...[...code.toUpperCase()].map((c) => 0x1f1e6 + c.charCodeAt(0) - 65))
}

export const platformName: Record<string, string> = {
  ios: 'iOS',
  android: 'Android',
  web: 'Web',
  macos: 'macOS',
  windows: 'Windows',
  linux: 'Linux',
  '': 'Unknown',
}

export const countrySourceName: Record<string, string> = {
  cdn: 'from the CDN',
  ip: 'from the IP address',
  device: "from the phone's region setting",
  '': 'not known yet',
}

export const eventMeta: Record<string, { label: string; tone: 'brand' | 'good' | 'warn' | 'bad' | 'info' | 'muted' }> = {
  signed_up: { label: 'Signed up', tone: 'brand' },
  signed_in: { label: 'Signed in', tone: 'muted' },
  child_added: { label: 'Added a child', tone: 'info' },
  child_removed: { label: 'Removed a child', tone: 'muted' },
  level_completed: { label: 'Finished a level', tone: 'good' },
  course_completed: { label: 'Finished the course', tone: 'warn' },
  item_bought: { label: 'Bought a room item', tone: 'info' },
  trial_started: { label: 'Started Plus trial', tone: 'brand' },
  plus_purchased: { label: 'Bought Likho Plus', tone: 'good' },
  account_deleted: { label: 'Deleted the account', tone: 'bad' },
}

export function initials(name: string, email = '') {
  const s = (name || email).trim()
  const parts = s.split(/[\s@._-]+/).filter(Boolean)
  return ((parts[0]?.[0] ?? '?') + (parts[1]?.[0] ?? '')).toUpperCase()
}

export function plusActive(until: string | null) {
  return !!until && new Date(until).getTime() > Date.now()
}
