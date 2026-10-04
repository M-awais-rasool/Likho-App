import { useQuery, useQueryClient } from '@tanstack/react-query'
import clsx from 'clsx'
import { BellRing, Check, CheckCheck, Settings2, Trophy, TriangleAlert, UserPlus, Gift } from 'lucide-react'
import { Link } from 'react-router-dom'
import { Button, Card, Empty, ErrorBox, Loading, PageHeader, Segmented } from '../components/ui'
import { get, post, type Alert } from '../lib/api'
import { ago, dateTime, flag } from '../lib/format'
import { useState, type ReactNode } from 'react'

const kinds: Record<string, { icon: ReactNode; cls: string }> = {
  reached_end: { icon: <TriangleAlert className="size-4" />, cls: 'bg-warn-soft text-warn' },
  course_completed: { icon: <Trophy className="size-4" />, cls: 'bg-good-soft text-good' },
  new_signup: { icon: <UserPlus className="size-4" />, cls: 'bg-brand-soft text-brand-ink' },
  trial_started: { icon: <Gift className="size-4" />, cls: 'bg-info-soft text-info' },
}

export default function Alerts() {
  const [show, setShow] = useState<'all' | 'unread'>('unread')
  const qc = useQueryClient()
  const q = useQuery({
    queryKey: ['alerts', 'list', show],
    queryFn: () => get<{ items: Alert[] }>(`/alerts?limit=200${show === 'unread' ? '&unread=1' : ''}`).then((r) => r.items),
    refetchInterval: 15_000,
  })
  const read = async (ids: number[]) => {
    await post('/alerts/read', { ids })
    qc.invalidateQueries({ queryKey: ['alerts'] })
  }
  return (
    <div>
      <PageHeader
        title="Alerts"
        subtitle="The team is alerted when a child reaches the last level or finishes the course, so new levels can be added in time."
        actions={
          <>
            <Link to="/settings">
              <Button variant="ghost" icon={<Settings2 className="size-4" />}>
                Alert rules
              </Button>
            </Link>
            <Button icon={<CheckCheck className="size-4" />} onClick={() => read([])}>
              Mark all read
            </Button>
          </>
        }
      />
      <div className="mb-4">
        <Segmented value={show} onChange={setShow} options={[{ value: 'unread', label: 'Unread' }, { value: 'all', label: 'All' }]} />
      </div>
      <Card padded={false}>
        {q.isLoading ? (
          <Loading />
        ) : q.error ? (
          <div className="p-4">
            <ErrorBox error={q.error} />
          </div>
        ) : q.data!.length === 0 ? (
          <Empty icon={<BellRing className="size-5" />} title={show === 'unread' ? 'All caught up' : 'No alerts yet'}>
            New alerts show up here, as a badge on the bell and as a browser notification (turn those on in Settings).
          </Empty>
        ) : (
          <ul className="divide-y divide-line">
            {q.data!.map((a) => {
              const k = kinds[a.kind] ?? kinds.reached_end
              return (
                <li key={a.id} className={clsx('flex flex-wrap items-start gap-3 px-4 py-3.5 sm:flex-nowrap', !a.readAt && 'bg-warn-soft/30')}>
                  <span className={`grid size-9 shrink-0 place-items-center rounded-full ${k.cls}`}>{k.icon}</span>
                  <div className="min-w-0 flex-1">
                    <div className="text-[14px] font-medium">{a.title}</div>
                    <div className="mt-0.5 text-[13px] text-ink-2">{a.body}</div>
                    <div className="mt-1 text-[12px] text-ink-3" title={dateTime(a.at)}>
                      {ago(a.at)}
                      {a.country && ` · ${flag(a.country)}`}
                      {a.readAt && ` · read by ${a.readBy}`}
                    </div>
                  </div>
                  <div className="flex shrink-0 gap-1.5">
                    {a.kind === 'reached_end' || a.kind === 'course_completed' ? (
                      <Link to="/content">
                        <Button size="sm" variant="primary">
                          Add levels
                        </Button>
                      </Link>
                    ) : null}
                    {a.parentId && (
                      <Link to={`/families/${a.parentId}`}>
                        <Button size="sm">Family</Button>
                      </Link>
                    )}
                    {!a.readAt && <Button size="sm" variant="ghost" aria-label="Mark read" icon={<Check className="size-4" />} onClick={() => read([a.id])} />}
                  </div>
                </li>
              )
            })}
          </ul>
        )}
      </Card>
    </div>
  )
}
