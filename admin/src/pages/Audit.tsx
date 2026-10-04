import { useInfiniteQuery } from '@tanstack/react-query'
import { ScrollText } from 'lucide-react'
import { Badge, Button, Card, Empty, ErrorBox, Loading, PageHeader } from '../components/ui'
import { get, qs, type AuditEntry } from '../lib/api'
import { ago, dateTime } from '../lib/format'

const PAGE = 50

export default function Audit() {
  const q = useInfiniteQuery({
    queryKey: ['audit'],
    initialPageParam: 0,
    queryFn: ({ pageParam }) => get<{ items: AuditEntry[] }>('/audit' + qs({ before: pageParam || undefined, limit: PAGE })).then((r) => r.items),
    getNextPageParam: (last) => (last.length === PAGE ? last[last.length - 1].id : undefined),
  })
  const items = q.data?.pages.flat() ?? []
  return (
    <div>
      <PageHeader title="Audit log" subtitle="Every change made in this panel: who, what and when." />
      <Card padded={false}>
        {q.isLoading ? <Loading /> : q.error ? <div className="p-4"><ErrorBox error={q.error} /></div> : items.length === 0 ? (
          <Empty icon={<ScrollText className="size-5" />} title="Nothing yet" />
        ) : (
          <>
            <div className="overflow-x-auto">
              <table className="w-full min-w-[720px] text-[13.5px]">
                <thead className="border-b border-line bg-surface-2/60">
                  <tr>{['When', 'Who', 'What', 'Target', 'Details'].map((h) => <th key={h} className="px-4 py-2.5 text-left text-[11.5px] font-semibold text-ink-3 uppercase">{h}</th>)}</tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {items.map((e) => (
                    <tr key={e.id} className="align-top">
                      <td className="px-4 py-2.5 whitespace-nowrap text-ink-2" title={dateTime(e.at)}>{ago(e.at)}</td>
                      <td className="px-4 py-2.5">{e.adminEmail}</td>
                      <td className="px-4 py-2.5"><Badge tone={e.action.includes('deleted') || e.action.includes('removed') ? 'bad' : e.action.startsWith('content') ? 'brand' : 'muted'}>{e.action}</Badge></td>
                      <td className="max-w-[200px] truncate px-4 py-2.5 font-mono text-[12px] text-ink-2">{e.target}</td>
                      <td className="max-w-[360px] px-4 py-2.5 font-mono text-[11.5px] break-all text-ink-3">{e.detail && Object.keys(e.detail).length ? JSON.stringify(e.detail) : ''}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            {q.hasNextPage && <div className="border-t border-line p-3 text-center"><Button loading={q.isFetchingNextPage} onClick={() => q.fetchNextPage()}>Load older</Button></div>}
          </>
        )}
      </Card>
    </div>
  )
}
