import { useQuery } from '@tanstack/react-query'
import { Flame } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { FunnelChart } from '../components/charts'
import { Badge, Card, ErrorBox, Loading, PageHeader, Stars, Stat, Th } from '../components/ui'
import { get, qs, type LevelStats } from '../lib/api'
import { duration, num, pct } from '../lib/format'
import { useSession } from '../lib/session'
import { useContent } from './Content'

type SortKey = 'level' | 'children' | 'avgStars' | 'oneStar' | 'avgSeconds' | 'current' | 'drop'

export default function Insights() {
  const { course } = useSession()
  const content = useContent()
  const navigate = useNavigate()
  const [sort, setSort] = useState<SortKey>('level')
  const [desc, setDesc] = useState(false)
  const q = useQuery({ queryKey: ['levelstats', course], queryFn: () => get<LevelStats>('/levels/stats' + qs({ course })), enabled: !!course, refetchInterval: 60_000 })

  const rows = useMemo(() => {
    const ls = q.data?.levels ?? []
    return ls.map((s, i) => {
      const prev = i === 0 ? s.children + s.current : ls[i - 1].children
      // children who finished the level before but not this one yet
      const drop = prev > 0 ? Math.max(0, prev - s.children) / prev : 0
      const name = content.data?.levels.find((l) => l.number === s.level)?.name ?? ''
      return { ...s, drop, name }
    })
  }, [q.data, content.data])
  const sorted = [...rows].sort((a, b) => {
    const v = sort === 'level' ? a.level - b.level : (a[sort] as number) - (b[sort] as number)
    return desc ? -v : v
  })
  const hardest = [...rows].filter((r) => r.children >= 3).sort((a, b) => a.avgStars - b.avgStars).slice(0, 3)
  const onSort = (s: string) => {
    if (s === sort) setDesc(!desc)
    else {
      setSort(s as SortKey)
      setDesc(s !== 'level')
    }
  }

  if (q.isLoading || content.isLoading) return <Loading />
  if (q.error) return <ErrorBox error={q.error} />
  const d = q.data!
  const total = d.notStarted + rows.reduce((s, r) => s + r.current, 0) + d.finished
  return (
    <div>
      <PageHeader title="Level insights" subtitle="Which levels children finish, how well, how long they take and where they get stuck." />
      <div className="mb-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Stat label="Learners" value={num(total)} />
        <Stat label="Not started" value={num(d.notStarted)} hint={pct(d.notStarted, total)} />
        <Stat label="Finished the course" value={num(d.finished)} hint={pct(d.finished, total)} tone="good" />
        <Stat label="Hardest level" value={hardest[0] ? `#${hardest[0].level}` : '—'} hint={hardest[0] ? `${hardest[0].name} · ${hardest[0].avgStars.toFixed(2)} avg stars` : 'Needs 3+ finishes per level'} tone="bad" icon={<Flame className="size-4" />} />
      </div>
      <Card title="Children who finished each level" className="mb-5">
        <FunnelChart data={rows} total={total} onLevel={(n) => navigate(`/content/levels/${n}`)} height={260} />
      </Card>
      <Card padded={false} title="Every level">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[860px] text-[13.5px]">
            <thead className="border-b border-line bg-surface-2/60">
              <tr>
                <Th sort="level" current={sort} desc={desc} onSort={onSort}>Level</Th>
                <Th sort="children" current={sort} desc={desc} onSort={onSort} className="text-right">Finished</Th>
                <Th sort="current" current={sort} desc={desc} onSort={onSort} className="text-right">Playing now</Th>
                <Th sort="avgStars" current={sort} desc={desc} onSort={onSort}>Avg stars</Th>
                <Th sort="oneStar" current={sort} desc={desc} onSort={onSort} className="text-right">1-star</Th>
                <Th sort="avgSeconds" current={sort} desc={desc} onSort={onSort} className="text-right">Avg time</Th>
                <Th sort="drop" current={sort} desc={desc} onSort={onSort} className="text-right">Not past it yet</Th>
              </tr>
            </thead>
            <tbody className="divide-y divide-line">
              {sorted.map((r) => (
                <tr key={r.level} onClick={() => navigate(`/content/levels/${r.level}`)} className="cursor-pointer hover:bg-surface-2/60">
                  <td className="px-4 py-2.5">
                    <span className="tabular mr-2 font-semibold">{r.level}</span>
                    {r.name}
                    {hardest.some((h) => h.level === r.level) && <Badge tone="bad" className="ml-2">Hard</Badge>}
                  </td>
                  <td className="tabular px-4 py-2.5 text-right">{num(r.children)}</td>
                  <td className="tabular px-4 py-2.5 text-right">{num(r.current)}</td>
                  <td className="px-4 py-2.5">{r.children ? <span className="flex items-center gap-2"><Stars n={Math.round(r.avgStars)} /> <span className="tabular text-ink-2">{r.avgStars.toFixed(2)}</span></span> : <span className="text-ink-3">—</span>}</td>
                  <td className="tabular px-4 py-2.5 text-right">{r.children ? pct(r.oneStar, r.children) : '—'}</td>
                  <td className="tabular px-4 py-2.5 text-right">{duration(r.avgSeconds)}</td>
                  <td className="tabular px-4 py-2.5 text-right">{r.drop ? pct(r.drop, 1) : '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  )
}
