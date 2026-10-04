import { useQuery } from '@tanstack/react-query'
import { CheckCircle2, XCircle } from 'lucide-react'
import { Badge, Card, ErrorBox, Loading, PageHeader } from '../components/ui'
import { get, type CourseSummary } from '../lib/api'
import { dateTime, num } from '../lib/format'

interface SystemInfo {
  info: { env: string; startedAt: string; geoip: boolean; countryHeader: string; devLogin: boolean }
  uptime: string
  go: string
  memoryMb: number
  postgres: { ok: boolean; ms?: number; error?: string }
  redis: { ok: boolean; ms?: number; error?: string }
  content: { revision: number; problems: string[]; courses: CourseSummary[] }
  tables: Record<string, number>
}

function Health({ name, h }: { name: string; h: { ok: boolean; ms?: number; error?: string } }) {
  return (
    <div className="flex items-center gap-3 rounded-lg border border-line px-3 py-2.5">
      {h.ok ? <CheckCircle2 className="size-5 text-good" /> : <XCircle className="size-5 text-bad" />}
      <div className="flex-1"><div className="font-medium">{name}</div><div className="text-[12px] text-ink-3">{h.ok ? `answers in ${h.ms} ms` : h.error}</div></div>
    </div>
  )
}

export default function System() {
  const q = useQuery({ queryKey: ['system'], queryFn: () => get<SystemInfo>('/system'), refetchInterval: 10_000 })
  if (q.isLoading) return <Loading />
  if (q.error) return <ErrorBox error={q.error} />
  const s = q.data!
  const rows: [string, React.ReactNode][] = [
    ['Environment', <Badge tone={s.info.env === 'production' ? 'good' : 'info'}>{s.info.env || 'development'}</Badge>],
    ['Started', `${dateTime(s.info.startedAt)} (up ${s.uptime})`],
    ['Go / memory', `${s.go} · ${s.memoryMb} MB`],
    ['Content revision', s.content.revision],
    ['Countries from', [s.info.countryHeader && `CDN header ${s.info.countryHeader}`, s.info.geoip && 'GeoIP database', "phone's region"].filter(Boolean).join(' → ')],
    ['Dev sign-in', s.info.devLogin ? <Badge tone="warn">On (development only)</Badge> : 'Off'],
  ]
  return (
    <div>
      <PageHeader title="System" subtitle="Health of the API and its databases. Refreshes every 10 seconds." />
      <div className="grid gap-5 xl:grid-cols-2">
        <Card title="Health">
          <div className="space-y-2"><Health name="PostgreSQL" h={s.postgres} /><Health name="Redis (cache)" h={s.redis} /></div>
          {!s.info.geoip && !s.info.countryHeader && <p className="mt-3 text-[12.5px] text-ink-3">Tip: run <code>make geoip</code> in backend/ and set GEOIP_DB for countries from IP addresses.</p>}
        </Card>
        <Card title="Server">
          <dl className="grid grid-cols-[auto_1fr] gap-x-6 gap-y-2 text-[13px]">
            {rows.map(([k, v]) => <div key={k} className="contents"><dt className="text-ink-3">{k}</dt><dd>{v}</dd></div>)}
          </dl>
        </Card>
        <Card title="Courses served">
          <ul className="space-y-2 text-[13px]">
            {s.content.courses.map((c) => <li key={c.id} className="flex justify-between gap-3"><span>{c.title} <span className="text-ink-3">({c.id})</span></span><span className="tabular text-ink-2">{c.worlds} worlds · {c.levels} levels · <code>{c.version}</code></span></li>)}
          </ul>
          {s.content.problems.length > 0 && <div className="mt-3 rounded-lg bg-bad-soft p-3 text-[12.5px] text-bad">{s.content.problems.join('\n')}</div>}
        </Card>
        <Card title="Database rows">
          <dl className="grid grid-cols-2 gap-x-6 gap-y-1.5 text-[13px]">
            {Object.entries(s.tables).map(([k, v]) => <div key={k} className="contents"><dt className="font-mono text-[12px] text-ink-3">{k}</dt><dd className="tabular text-right">{num(v)}</dd></div>)}
          </dl>
        </Card>
      </div>
    </div>
  )
}
