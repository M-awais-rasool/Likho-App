import { useInfiniteQuery, useQueryClient } from '@tanstack/react-query'
import clsx from 'clsx'
import { Activity as ActivityIcon, Pause, Play } from 'lucide-react'
import { useEffect, useState } from 'react'
import { EventRow } from '../components/EventRow'
import { Button, Card, Empty, ErrorBox, Loading, PageHeader } from '../components/ui'
import { get, qs, type ActivityEvent } from '../lib/api'
import { eventMeta } from '../lib/format'

const PAGE = 50

export default function Activity() {
  const [types, setTypes] = useState<string[]>([])
  const [live, setLive] = useState(true)
  const qc = useQueryClient()
  const key = ['activity', types.join(',')]
  const q = useInfiniteQuery({
    queryKey: key,
    initialPageParam: 0,
    queryFn: ({ pageParam }) => get<{ items: ActivityEvent[] }>('/activity' + qs({ types: types.join(','), before: pageParam || undefined, limit: PAGE })).then((r) => r.items),
    getNextPageParam: (last) => (last.length === PAGE ? last[last.length - 1].id : undefined),
  })

  // live: fetch only what is newer than the top event, every 5 seconds
  const newest = q.data?.pages[0]?.[0]?.id ?? 0
  useEffect(() => {
    if (!live || !q.data) return
    const t = setInterval(async () => {
      const fresh = await get<{ items: ActivityEvent[] }>('/activity' + qs({ types: types.join(','), after: newest, limit: 100 })).then((r) => r.items).catch(() => [])
      if (fresh.length)
        qc.setQueryData(key, (old: { pages: ActivityEvent[][]; pageParams: unknown[] } | undefined) =>
          old ? { ...old, pages: [[...fresh, ...old.pages[0]], ...old.pages.slice(1)] } : old,
        )
    }, 5000)
    return () => clearInterval(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [live, newest, types.join(','), q.data !== undefined])

  const toggle = (t: string) => setTypes((x) => (x.includes(t) ? x.filter((y) => y !== t) : [...x, t]))
  const events = q.data?.pages.flat() ?? []

  return (
    <div>
      <PageHeader
        title="Live activity"
        subtitle="Everything families do, as it happens."
        actions={
          <Button onClick={() => setLive(!live)} icon={live ? <Pause className="size-4" /> : <Play className="size-4" />}>
            {live ? (
              <span className="flex items-center gap-1.5">
                <span className="size-2 animate-pulse rounded-full bg-good" /> Live
              </span>
            ) : (
              'Paused'
            )}
          </Button>
        }
      />
      <div className="mb-4 flex flex-wrap gap-1.5">
        <button onClick={() => setTypes([])} className={clsx('h-8 cursor-pointer rounded-full border px-3 text-[12.5px] font-medium', types.length === 0 ? 'border-brand bg-brand-soft text-brand-ink' : 'border-line bg-surface text-ink-2 hover:text-ink')}>
          Everything
        </button>
        {Object.entries(eventMeta).map(([t, m]) => (
          <button key={t} onClick={() => toggle(t)} className={clsx('h-8 cursor-pointer rounded-full border px-3 text-[12.5px] font-medium', types.includes(t) ? 'border-brand bg-brand-soft text-brand-ink' : 'border-line bg-surface text-ink-2 hover:text-ink')}>
            {m.label}
          </button>
        ))}
      </div>
      <Card padded={false}>
        {q.isLoading ? (
          <Loading />
        ) : q.error ? (
          <div className="p-4">
            <ErrorBox error={q.error} retry={() => q.refetch()} />
          </div>
        ) : events.length === 0 ? (
          <Empty icon={<ActivityIcon className="size-5" />} title="No activity yet">
            Events appear here when families sign in, add children and finish levels.
          </Empty>
        ) : (
          <>
            <ul className="divide-y divide-line">
              {events.map((e) => (
                <EventRow key={e.id} e={e} />
              ))}
            </ul>
            {q.hasNextPage && (
              <div className="border-t border-line p-3 text-center">
                <Button loading={q.isFetchingNextPage} onClick={() => q.fetchNextPage()}>
                  Load older
                </Button>
              </div>
            )}
          </>
        )}
      </Card>
    </div>
  )
}
