import { useQuery } from '@tanstack/react-query'
import { AlertTriangle, ArrowRight, Baby, BookOpen, Crown, Globe2, Radio, Star, Trophy, Users } from 'lucide-react'
import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { FunnelChart, ShareBars, SplitBar, TrendChart } from '../components/charts'
import { EventRow } from '../components/EventRow'
import { Badge, Button, Card, Empty, ErrorBox, Loading, PageHeader, Segmented, Stat } from '../components/ui'
import { get, qs, type Overview as OverviewData } from '../lib/api'
import { ago, countryName, flag, num, pct, platformName } from '../lib/format'
import { useSession } from '../lib/session'

type Metric = 'active' | 'signups' | 'levels'
const metrics: { value: Metric; label: string; color: string }[] = [
  { value: 'active', label: 'Active families', color: 'var(--series-1)' },
  { value: 'signups', label: 'Sign-ups', color: 'var(--series-2)' },
  { value: 'levels', label: 'Levels finished', color: 'var(--series-3)' },
]

export default function Overview() {
  const { course } = useSession()
  const [days, setDays] = useState<'7' | '30' | '90'>('30')
  const [metric, setMetric] = useState<Metric>('active')
  const navigate = useNavigate()
  const q = useQuery({
    queryKey: ['overview', course, days],
    queryFn: () => get<OverviewData>('/overview' + qs({ course, days })),
    refetchInterval: 30_000,
  })
  if (q.isLoading) return <Loading />
  if (q.error) return <ErrorBox error={q.error} retry={() => q.refetch()} />
  const o = q.data!
  const t = o.totals
  const m = metrics.find((x) => x.value === metric)!
  const periodTotal = o.series.reduce((s, d) => s + d[metric], 0)
  const endTotal = t.atEnd + t.finished

  return (
    <div>
      <PageHeader
        title="Overview"
        subtitle={
          <>
            {o.course.title} · {o.lastLevel} levels live ·{' '}
            <span className="inline-flex items-center gap-1 text-good">
              <Radio className="size-3.5" /> {num(t.onlineNow)} online now
            </span>
          </>
        }
        actions={
          <Segmented
            value={days}
            onChange={setDays}
            options={[
              { value: '7', label: '7 days' },
              { value: '30', label: '30 days' },
              { value: '90', label: '90 days' },
            ]}
          />
        }
      />

      {endTotal > 0 && (
        <div className="mb-5 flex flex-wrap items-center gap-3 rounded-xl border border-warn/30 bg-warn-soft px-4 py-3">
          <AlertTriangle className="size-5 shrink-0 text-warn" />
          <div className="min-w-0 flex-1 text-[13.5px] text-ink">
            <b>{num(t.atEnd)}</b> {t.atEnd === 1 ? 'child is' : 'children are'} on the last level and <b>{num(t.finished)}</b> finished every level. They need new levels to keep learning.
          </div>
          <Button size="sm" variant="primary" onClick={() => navigate('/content')} icon={<BookOpen className="size-4" />}>
            Add levels
          </Button>
        </div>
      )}

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Stat label="Families" value={num(t.parents)} hint={`+${num(t.newParents)} in ${days} days · +${num(t.newToday)} today`} icon={<Users className="size-4" />} tone="brand" />
        <Stat label="Learners" value={num(t.children)} hint={`${(t.children / Math.max(t.parents, 1)).toFixed(1)} per family`} icon={<Baby className="size-4" />} tone="info" />
        <Stat label="Active families" value={num(t.activeToday)} hint={`today · ${num(t.active7)} this week · ${num(t.active30)} in 30 days`} icon={<Radio className="size-4" />} tone="good" />
        <Stat label="Likho Plus" value={num(t.plus)} hint={`${pct(t.plus, t.parents)} of families · ${num(t.trialsUsed)} trials used`} icon={<Crown className="size-4" />} tone="warn" />
        <Stat label="Levels completed" value={num(t.levelsCompleted)} hint={`${num(t.plays)} plays · ${num(t.levelsInPeriod)} in ${days} days`} icon={<Trophy className="size-4" />} tone="good" />
        <Stat label="Stars earned" value={num(t.starsEarned)} hint={`${t.levelsCompleted ? (t.starsEarned / t.levelsCompleted).toFixed(2) : '0'} per level (of 3)`} icon={<Star className="size-4" />} tone="warn" />
        <Stat label="At the end" value={num(endTotal)} hint={`${num(t.atEnd)} on the last level · ${num(t.finished)} finished`} icon={<AlertTriangle className="size-4" />} tone={endTotal ? 'bad' : 'muted'} />
        <Stat label="Countries" value={num(t.countries)} hint={o.countries.find((c) => c.key) ? `Most: ${countryName(o.countries.find((c) => c.key)!.key)}` : 'none known yet'} icon={<Globe2 className="size-4" />} tone="info" />
      </div>

      <div className="mt-5 grid gap-5 xl:grid-cols-3">
        <Card
          className="xl:col-span-2"
          title={
            <span>
              {m.label} <span className="tabular font-normal text-ink-3">· {num(periodTotal)} in {days} days</span>
            </span>
          }
          action={<Segmented value={metric} onChange={setMetric} options={metrics.map(({ value, label }) => ({ value, label }))} />}
        >
          <TrendChart data={o.series as unknown as Record<string, unknown>[]} dataKey={metric} label={m.label} color={m.color} />
        </Card>
        <Card title="Where families are" action={<Link to="/families" className="text-[12.5px] font-medium text-brand-ink hover:underline">All families</Link>}>
          {o.countries.length === 0 ? (
            <Empty title="No families yet" />
          ) : (
            <ShareBars
              items={o.countries.slice(0, 7)}
              total={t.parents}
              render={(k) => (
                <Link to={k ? `/families?country=${k}` : '/families'} className="hover:underline">
                  {flag(k)} {countryName(k)}
                </Link>
              )}
            />
          )}
        </Card>
      </div>

      <div className="mt-5 grid gap-5 xl:grid-cols-3">
        <Card
          className="xl:col-span-2"
          title={
            <span>
              How far children get <span className="font-normal text-ink-3">· children who finished each level</span>
            </span>
          }
          action={<Link to="/insights" className="text-[12.5px] font-medium text-brand-ink hover:underline">Level insights</Link>}
        >
          <FunnelChart data={o.funnel} total={t.children} onLevel={(n) => navigate(`/content/levels/${n}`)} />
          <p className="mt-2 text-[12px] text-ink-3">
            {num(o.notStarted)} {o.notStarted === 1 ? 'child has' : 'children have'} not finished a level yet. Click a bar to open the level.
          </p>
        </Card>
        <div className="grid gap-5">
          <Card title="Devices">
            <SplitBar items={o.platforms} render={(k) => platformName[k] ?? k} />
            {o.versions.length > 0 && (
              <div className="mt-4 border-t border-line pt-3">
                <div className="mb-2 text-[12px] font-medium text-ink-3">App versions</div>
                <div className="flex flex-wrap gap-1.5">
                  {o.versions.map((v) => (
                    <Badge key={v.key}>
                      {v.key} · {num(v.n)}
                    </Badge>
                  ))}
                </div>
              </div>
            )}
          </Card>
          <Card title="Learners by age">
            <div className="flex items-end gap-2">
              {[5, 6, 7, 8].map((age) => {
                const n = o.ages.find((a) => a.key === String(age))?.n ?? 0
                const max = Math.max(1, ...o.ages.map((a) => a.n))
                return (
                  <div key={age} className="flex flex-1 flex-col items-center gap-1" title={`Age ${age}: ${n}`}>
                    <span className="tabular text-[12px] text-ink-2">{num(n)}</span>
                    <div className="w-full rounded-t-[4px] bg-[var(--series-1)]" style={{ height: 4 + (n / max) * 56 }} />
                    <span className="text-[12px] text-ink-3">{age}</span>
                  </div>
                )
              })}
            </div>
          </Card>
        </div>
      </div>

      <div className="mt-5 grid gap-5 xl:grid-cols-2">
        <Card title="Latest alerts" padded={false} action={<Link to="/alerts" className="text-[12.5px] font-medium text-brand-ink hover:underline">All alerts {o.unreadAlerts > 0 && `(${o.unreadAlerts} unread)`}</Link>}>
          {o.recentAlerts.length === 0 ? (
            <Empty title="No alerts yet">You will be alerted when a child reaches the last level.</Empty>
          ) : (
            <ul className="divide-y divide-line">
              {o.recentAlerts.map((a) => (
                <li key={a.id} className="flex items-start gap-3 px-4 py-3">
                  <span className={`mt-1.5 size-2 shrink-0 rounded-full ${a.readAt ? 'bg-line-strong' : 'bg-warn'}`} />
                  <div className="min-w-0 flex-1">
                    <div className="text-[13.5px] font-medium">{a.title}</div>
                    <div className="truncate text-[12px] text-ink-3">
                      {a.country && flag(a.country)} {a.parentEmail} · {ago(a.at)}
                    </div>
                  </div>
                  {a.parentId && (
                    <Link to={`/families/${a.parentId}`} className="text-ink-3 hover:text-brand-ink" aria-label="Open family">
                      <ArrowRight className="size-4" />
                    </Link>
                  )}
                </li>
              ))}
            </ul>
          )}
        </Card>
        <Card title="Live activity" padded={false} action={<Link to="/activity" className="text-[12.5px] font-medium text-brand-ink hover:underline">Open feed</Link>}>
          {o.recentActivity.length === 0 ? (
            <Empty title="Nothing yet">Sign-ins, finished levels and more show here as they happen.</Empty>
          ) : (
            <ul className="divide-y divide-line">
              {o.recentActivity.map((e) => (
                <EventRow key={e.id} e={e} />
              ))}
            </ul>
          )}
        </Card>
      </div>
    </div>
  )
}
