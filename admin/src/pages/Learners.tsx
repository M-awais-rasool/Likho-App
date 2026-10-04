import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { Baby, Trophy } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { Avatar, Badge, Card, Empty, ErrorBox, Loading, PageHeader, Pagination, SearchInput, Select, Th } from '../components/ui'
import { get, qs, type ContentCourse, type Learner, type Page } from '../lib/api'
import { ago, countryName, flag, num } from '../lib/format'
import { useSession } from '../lib/session'
import { useListParams } from '../lib/useListParams'
import { useCountries } from './Families'

const PAGE = 25

export default function Learners() {
  const { course } = useSession()
  const p = useListParams({ sort: 'lastPlayed' })
  const navigate = useNavigate()
  const countries = useCountries(course)
  const content = useQuery({ queryKey: ['content', course], queryFn: () => get<ContentCourse>(`/content/courses/${course}`), enabled: !!course })
  const last = content.data?.liveLevels ?? 0
  const params = { course, q: p.q, country: p.country, filter: p.filter, sort: p.sort, desc: p.desc, page: p.page, pageSize: PAGE }
  const list = useQuery({
    queryKey: ['learners', params],
    queryFn: () => get<Page<Learner>>('/learners' + qs(params)),
    placeholderData: keepPreviousData,
  })

  return (
    <div>
      <PageHeader title="Learners" subtitle="Every child: how many levels they finished, their stars and where they are on the map." />
      <Card padded={false}>
        <div className="flex flex-wrap items-center gap-2 border-b border-line p-3">
          <SearchInput value={p.draft} onChange={p.setDraft} placeholder="Search child or parent" />
          <Select value={p.country} onChange={(e) => p.set({ country: e.target.value, page: '' })} className="w-auto" aria-label="Country">
            <option value="">All countries</option>
            {countries.data?.map((c) => (
              <option key={c.key} value={c.key}>
                {flag(c.key)} {countryName(c.key)}
              </option>
            ))}
          </Select>
          <Select value={p.filter} onChange={(e) => p.set({ filter: e.target.value, page: '' })} className="w-auto" aria-label="Progress">
            <option value="">All progress</option>
            <option value="new">Not started</option>
            <option value="active7">Played this week</option>
            <option value="at_end">On the last level</option>
            <option value="finished">Finished the course</option>
          </Select>
          <div className="ml-auto text-[12.5px] text-ink-3 tabular">{list.data ? `${num(list.data.total)} learners` : ''}</div>
        </div>
        {list.isLoading ? (
          <Loading />
        ) : list.error ? (
          <div className="p-4">
            <ErrorBox error={list.error} retry={() => list.refetch()} />
          </div>
        ) : list.data!.items.length === 0 ? (
          <Empty icon={<Baby className="size-5" />} title="No learners match" />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[900px] text-[13.5px]">
              <thead className="border-b border-line bg-surface-2/60">
                <tr>
                  <Th sort="name" current={p.sort} desc={p.desc} onSort={p.onSort}>
                    Learner
                  </Th>
                  <Th>Family</Th>
                  <Th sort="levels" current={p.sort} desc={p.desc} onSort={p.onSort}>
                    Progress
                  </Th>
                  <Th sort="stars" current={p.sort} desc={p.desc} onSort={p.onSort} className="text-right">
                    Stars earned
                  </Th>
                  <Th sort="balance" current={p.sort} desc={p.desc} onSort={p.onSort} className="text-right">
                    Balance
                  </Th>
                  <Th sort="lastPlayed" current={p.sort} desc={p.desc} onSort={p.onSort}>
                    Last played
                  </Th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {list.data!.items.map((l) => {
                  const finished = last > 0 && l.topLevel >= last
                  const atEnd = last > 0 && !finished && l.topLevel >= last - 1
                  const current = Math.min(l.topLevel + 1, last || l.topLevel + 1)
                  return (
                    <tr key={l.id} onClick={() => navigate(`/families/${l.parentId}`)} className="cursor-pointer hover:bg-surface-2/60">
                      <td className="px-4 py-2.5">
                        <div className="flex items-center gap-3">
                          <Avatar label={l.name[0]?.toUpperCase() ?? '?'} color={l.color} />
                          <div>
                            <div className="font-medium">{l.name}</div>
                            <div className="text-[12.5px] text-ink-3">Age {l.age}</div>
                          </div>
                        </div>
                      </td>
                      <td className="max-w-[220px] px-4 py-2.5">
                        <div className="truncate text-ink-2">{l.parentEmail}</div>
                        <div className="text-[12.5px] text-ink-3">{l.country ? `${flag(l.country)} ${countryName(l.country)}` : 'Unknown country'}</div>
                      </td>
                      <td className="px-4 py-2.5">
                        <div className="flex items-center gap-2">
                          <div className="h-1.5 w-28 overflow-hidden rounded-full bg-surface-2">
                            <div className="h-full rounded-full bg-[var(--series-1)]" style={{ width: `${last ? (l.levels / last) * 100 : 0}%` }} />
                          </div>
                          <span className="tabular text-[12.5px] text-ink-2">
                            {l.levels}/{last}
                          </span>
                          {finished ? (
                            <Badge tone="good">
                              <Trophy className="size-3" /> Finished
                            </Badge>
                          ) : atEnd ? (
                            <Badge tone="warn">Last level</Badge>
                          ) : null}
                        </div>
                        <div className="mt-0.5 text-[12px] text-ink-3">{finished ? 'All levels done' : `On level ${current}`} · {l.threeStars} with 3 stars</div>
                      </td>
                      <td className="tabular px-4 py-2.5 text-right">{num(l.starsEarned)}</td>
                      <td className="tabular px-4 py-2.5 text-right">⭐ {num(l.stars)}</td>
                      <td className="px-4 py-2.5 whitespace-nowrap text-ink-2">{l.lastPlayed ? ago(l.lastPlayed) : <span className="text-ink-3">Not yet</span>}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
        {list.data && list.data.total > 0 && <Pagination page={p.page} pageSize={PAGE} total={list.data.total} onPage={(n) => p.set({ page: String(n) })} />}
      </Card>
    </div>
  )
}
