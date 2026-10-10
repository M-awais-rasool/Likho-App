import { useQuery, useQueryClient } from '@tanstack/react-query'
import clsx from 'clsx'
import {
  Activity,
  Bell,
  BookOpen,
  ChartColumn,
  ChevronDown,
  Cog,
  FlaskConical,
  LayoutDashboard,
  LogOut,
  Menu,
  Moon,
  ScrollText,
  Server,
  Shield,
  Sun,
  Users,
  Baby,
  X,
} from 'lucide-react'
import { Suspense, useEffect, useRef, useState, type ReactNode } from 'react'
import { Link, NavLink, Outlet, useLocation } from 'react-router-dom'
import { get, post, type Alert } from '../lib/api'
import { ago } from '../lib/format'
import { localStorageGet, localStorageSet, useSession } from '../lib/session'
import { PageBoundary } from './Boundary'
import { Avatar, Badge, Loading, useToast } from './ui'

const nav: { to: string; label: string; icon: ReactNode; owner?: boolean }[] = [
  { to: '/', label: 'Overview', icon: <LayoutDashboard className="size-4" /> },
  { to: '/closed-test', label: 'Closed test', icon: <FlaskConical className="size-4" /> },
  { to: '/families', label: 'Families', icon: <Users className="size-4" /> },
  { to: '/learners', label: 'Learners', icon: <Baby className="size-4" /> },
  { to: '/activity', label: 'Live activity', icon: <Activity className="size-4" /> },
  { to: '/alerts', label: 'Alerts', icon: <Bell className="size-4" /> },
  { to: '/content', label: 'Levels & content', icon: <BookOpen className="size-4" /> },
  { to: '/insights', label: 'Level insights', icon: <ChartColumn className="size-4" /> },
]
const navAdmin: { to: string; label: string; icon: ReactNode; owner?: boolean }[] = [
  { to: '/team', label: 'Team', icon: <Shield className="size-4" />, owner: true },
  { to: '/audit', label: 'Audit log', icon: <ScrollText className="size-4" /> },
  { to: '/settings', label: 'Settings', icon: <Cog className="size-4" /> },
  { to: '/system', label: 'System', icon: <Server className="size-4" /> },
]

type Theme = 'light' | 'dark' | 'system'

function useTheme(): [Theme, (t: Theme) => void] {
  const [theme, setTheme] = useState<Theme>(() => (localStorageGet('likho.theme') as Theme) || 'system')
  useEffect(() => {
    const el = document.documentElement
    if (theme === 'system') el.removeAttribute('data-theme')
    else el.setAttribute('data-theme', theme)
    localStorageSet('likho.theme', theme)
  }, [theme])
  return [theme, setTheme]
}

/** A soft two-note chime (no audio file needed). */
function chime() {
  try {
    const ctx = new AudioContext()
    ;[660, 880].forEach((f, i) => {
      const o = ctx.createOscillator()
      const g = ctx.createGain()
      o.frequency.value = f
      o.type = 'sine'
      g.gain.setValueAtTime(0.0001, ctx.currentTime + i * 0.14)
      g.gain.exponentialRampToValueAtTime(0.12, ctx.currentTime + i * 0.14 + 0.02)
      g.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + i * 0.14 + 0.35)
      o.connect(g).connect(ctx.destination)
      o.start(ctx.currentTime + i * 0.14)
      o.stop(ctx.currentTime + i * 0.14 + 0.4)
    })
    setTimeout(() => ctx.close(), 1000)
  } catch {
    /* no audio: fine */
  }
}

/** Polls for new alerts; a new one shows a toast, a browser notification
 *  (when allowed) and plays a chime. */
function useAlertWatch() {
  const toast = useToast()
  const qc = useQueryClient()
  const seen = useRef<number | null>(null)
  const unread = useQuery({
    queryKey: ['alerts', 'unread'],
    queryFn: () => get<{ count: number; latest: number }>('/alerts/unread'),
    refetchInterval: 15_000,
    refetchIntervalInBackground: true,
  })
  useEffect(() => {
    if (!unread.data) return
    const latest = unread.data.latest
    // remembered across reloads, so an alert is announced once
    if (seen.current === null) seen.current = Math.max(Number(localStorageGet('likho.alertSeen') ?? 0), 0) || latest
    if (latest > seen.current) {
      seen.current = latest
      localStorageSet('likho.alertSeen', String(latest))
      qc.invalidateQueries({ queryKey: ['alerts', 'list'] })
      get<{ items: Alert[] }>('/alerts?unread=1&limit=1').then(({ items }) => {
        const a = items[0]
        if (!a) return
        toast(
          <span>
            <b className="block">{a.title}</b>
            <span className="opacity-80">{a.body}</span>
          </span>,
          'warn',
        )
        if (localStorageGet('likho.sound') !== 'off') chime()
        if ('Notification' in window && Notification.permission === 'granted' && document.visibilityState !== 'visible') {
          new Notification('Likho: ' + a.title, { body: a.body, icon: '/admin/favicon.svg', tag: `alert-${a.id}` })
        }
      })
    }
  }, [unread.data, qc, toast])
  return unread.data?.count ?? 0
}

function AlertBell({ count }: { count: number }) {
  const [open, setOpen] = useState(false)
  const qc = useQueryClient()
  const list = useQuery({
    queryKey: ['alerts', 'list', 'bell'],
    queryFn: () => get<{ items: Alert[] }>('/alerts?limit=6').then((r) => r.items),
    enabled: open,
  })
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => {
    if (!open) return
    const close = (e: MouseEvent) => !ref.current?.contains(e.target as Node) && setOpen(false)
    document.addEventListener('mousedown', close)
    return () => document.removeEventListener('mousedown', close)
  }, [open])
  return (
    <div className="relative" ref={ref}>
      <button onClick={() => setOpen(!open)} className="relative grid size-9 cursor-pointer place-items-center rounded-lg text-ink-2 hover:bg-surface-2 hover:text-ink" aria-label={`Alerts, ${count} unread`}>
        <Bell className="size-[18px]" />
        {count > 0 && <span className="tabular absolute -top-0.5 -right-0.5 grid h-[18px] min-w-[18px] place-items-center rounded-full bg-bad px-1 text-[10.5px] font-bold text-white">{count > 99 ? '99+' : count}</span>}
      </button>
      {open && (
        <div className="animate-pop absolute right-0 z-40 mt-2 w-[min(360px,calc(100vw-2rem))] overflow-hidden rounded-xl border border-line bg-surface shadow-xl">
          <div className="flex items-center justify-between border-b border-line px-4 py-2.5">
            <span className="text-[13px] font-semibold">Alerts</span>
            {count > 0 && (
              <button
                className="cursor-pointer text-[12px] font-medium text-brand-ink hover:underline"
                onClick={async () => {
                  await post('/alerts/read', {})
                  qc.invalidateQueries({ queryKey: ['alerts'] })
                }}
              >
                Mark all read
              </button>
            )}
          </div>
          <div className="max-h-96 overflow-y-auto">
            {list.data?.length === 0 && <div className="px-4 py-8 text-center text-[13px] text-ink-3">No alerts yet</div>}
            {list.data?.map((a) => (
              <div key={a.id} className={clsx('border-b border-line px-4 py-3 last:border-0', !a.readAt && 'bg-warn-soft/40')}>
                <div className="flex items-start gap-2">
                  {!a.readAt && <span className="mt-1.5 size-2 shrink-0 rounded-full bg-warn" />}
                  <div className="min-w-0">
                    <div className="text-[13px] font-medium text-ink">{a.title}</div>
                    <div className="mt-0.5 text-[12px] text-ink-3">{ago(a.at)}</div>
                  </div>
                </div>
              </div>
            ))}
          </div>
          <Link to="/alerts" onClick={() => setOpen(false)} className="block border-t border-line px-4 py-2.5 text-center text-[12.5px] font-medium text-brand-ink hover:bg-surface-2">
            See all alerts
          </Link>
        </div>
      )}
    </div>
  )
}

function UserMenu() {
  const { admin, logout } = useSession()
  const [open, setOpen] = useState(false)
  const [theme, setTheme] = useTheme()
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => {
    if (!open) return
    const close = (e: MouseEvent) => !ref.current?.contains(e.target as Node) && setOpen(false)
    document.addEventListener('mousedown', close)
    return () => document.removeEventListener('mousedown', close)
  }, [open])
  if (!admin) return null
  return (
    <div className="relative" ref={ref}>
      <button onClick={() => setOpen(!open)} className="flex cursor-pointer items-center gap-2 rounded-lg py-1 pr-2 pl-1 hover:bg-surface-2" aria-label="Account menu">
        <Avatar label={(admin.name || admin.email)[0].toUpperCase()} size={28} />
        <span className="hidden text-[13px] font-medium sm:block">{admin.name || admin.email}</span>
        <ChevronDown className="size-3.5 text-ink-3" />
      </button>
      {open && (
        <div className="animate-pop absolute right-0 z-40 mt-2 w-60 rounded-xl border border-line bg-surface p-1.5 shadow-xl">
          <div className="px-2.5 py-2">
            <div className="truncate text-[13px] font-medium">{admin.email}</div>
            <Badge tone="brand" className="mt-1 capitalize">
              {admin.role}
            </Badge>
          </div>
          <div className="my-1 border-t border-line" />
          <div className="px-2.5 py-1.5 text-[11.5px] font-semibold text-ink-3 uppercase">Theme</div>
          <div className="flex gap-1 px-1.5 pb-1.5">
            {(['light', 'dark', 'system'] as Theme[]).map((t) => (
              <button
                key={t}
                onClick={() => setTheme(t)}
                className={clsx('flex flex-1 cursor-pointer items-center justify-center gap-1 rounded-md py-1.5 text-[12px] capitalize', theme === t ? 'bg-brand-soft text-brand-ink' : 'hover:bg-surface-2')}
              >
                {t === 'light' ? <Sun className="size-3.5" /> : t === 'dark' ? <Moon className="size-3.5" /> : null}
                {t}
              </button>
            ))}
          </div>
          <div className="my-1 border-t border-line" />
          <Link to="/settings" onClick={() => setOpen(false)} className="flex items-center gap-2 rounded-md px-2.5 py-2 text-[13px] hover:bg-surface-2">
            <Cog className="size-4" /> Settings & password
          </Link>
          <button onClick={logout} className="flex w-full cursor-pointer items-center gap-2 rounded-md px-2.5 py-2 text-[13px] text-bad hover:bg-bad-soft">
            <LogOut className="size-4" /> Sign out
          </button>
        </div>
      )}
    </div>
  )
}

function NavItem({ to, label, icon, badge, onClick }: { to: string; label: string; icon: ReactNode; badge?: number; onClick?: () => void }) {
  return (
    <NavLink
      to={to}
      end={to === '/'}
      onClick={onClick}
      className={({ isActive }) =>
        clsx(
          'flex items-center gap-2.5 rounded-lg px-2.5 py-2 text-[13.5px] font-medium transition-colors',
          isActive ? 'bg-brand-soft text-brand-ink' : 'text-ink-2 hover:bg-surface-2 hover:text-ink',
        )
      }
    >
      {icon}
      <span className="flex-1">{label}</span>
      {!!badge && <span className="tabular rounded-full bg-bad px-1.5 text-[10.5px] font-bold text-white">{badge}</span>}
    </NavLink>
  )
}

export function Layout() {
  const { can, courses, course, setCourse } = useSession()
  const unread = useAlertWatch()
  const [mobileNav, setMobileNav] = useState(false)
  const loc = useLocation()
  useEffect(() => setMobileNav(false), [loc.pathname])

  const sidebar = (
    <div className="flex h-full flex-col">
      <Link to="/" className="flex items-center gap-2.5 px-4 pt-5 pb-4">
        <img src="/admin/favicon.svg" alt="" className="size-8" />
        <span>
          <span className="block font-display text-[21px] leading-none font-extrabold text-ink">Likho</span>
          <span className="block text-[11px] font-medium tracking-wide text-ink-3 uppercase">Admin</span>
        </span>
      </Link>
      <nav className="flex-1 space-y-0.5 overflow-y-auto px-2.5 pb-4">
        {nav.map((n) => (
          <NavItem key={n.to} {...n} badge={n.to === '/alerts' ? unread : undefined} />
        ))}
        <div className="px-2.5 pt-5 pb-1.5 text-[11px] font-semibold tracking-wide text-ink-3 uppercase">Admin</div>
        {navAdmin.filter((n) => !n.owner || can('owner')).map((n) => (
          <NavItem key={n.to} {...n} />
        ))}
      </nav>
      {courses.length > 1 && (
        <div className="border-t border-line p-3">
          <label className="mb-1 block text-[11px] font-semibold text-ink-3 uppercase">Course</label>
          <select value={course} onChange={(e) => setCourse(e.target.value)} className="h-8 w-full rounded-md border border-line-strong bg-surface px-2 text-[12.5px]">
            {courses.map((c) => (
              <option key={c.id} value={c.id}>
                {c.title}
              </option>
            ))}
          </select>
        </div>
      )}
    </div>
  )

  return (
    <div className="min-h-screen lg:pl-60">
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-60 border-r border-line bg-surface lg:block">{sidebar}</aside>
      {mobileNav && (
        <div className="fixed inset-0 z-40 lg:hidden">
          <div className="absolute inset-0 bg-black/40" onClick={() => setMobileNav(false)} />
          <aside className="animate-pop absolute inset-y-0 left-0 w-64 bg-surface shadow-xl">
            <button onClick={() => setMobileNav(false)} className="absolute top-4 right-3 cursor-pointer rounded-md p-1.5 text-ink-3 hover:bg-surface-2" aria-label="Close menu">
              <X className="size-4" />
            </button>
            {sidebar}
          </aside>
        </div>
      )}
      <header className="sticky top-0 z-20 flex h-14 items-center gap-2 border-b border-line bg-surface/85 px-4 backdrop-blur lg:px-8">
        <button onClick={() => setMobileNav(true)} className="grid size-9 cursor-pointer place-items-center rounded-lg text-ink-2 hover:bg-surface-2 lg:hidden" aria-label="Open menu">
          <Menu className="size-5" />
        </button>
        <div className="flex-1" />
        <AlertBell count={unread} />
        <UserMenu />
      </header>
      <main className="mx-auto max-w-[1400px] px-4 py-6 lg:px-8">
        <PageBoundary>
          <Suspense fallback={<Loading />}>
            <Outlet />
          </Suspense>
        </PageBoundary>
      </main>
    </div>
  )
}
