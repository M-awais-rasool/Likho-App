import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { Crown, Download, Users } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { Avatar, Badge, Button, Card, Empty, ErrorBox, Loading, PageHeader, Pagination, SearchInput, Select, Th } from '../components/ui'
import { get, qs, type Family, type KeyCount, type Overview, type Page } from '../lib/api'
import { ago, countryName, countrySourceName, date, flag, initials, num, platformName, plusActive } from '../lib/format'
import { useSession } from '../lib/session'
import { useListParams } from '../lib/useListParams'

const PAGE = 25

export function useCountries(course: string) {
  return useQuery({
    queryKey: ['overview', course, '30'],
    queryFn: () => get<Overview>('/overview' + qs({ course, days: 30 })),
    select: (o): KeyCount[] => o.countries.filter((c) => c.key),
    staleTime: 60_000,
  })
}

export default function Families() {
  const { course } = useSession()
  const p = useListParams({ sort: 'lastSeen' })
  const navigate = useNavigate()
  const countries = useCountries(course)
  const params = { course, q: p.q, country: p.country, filter: p.filter, sort: p.sort, desc: p.desc, page: p.page, pageSize: PAGE }
  const list = useQuery({
    queryKey: ['families', params],
    queryFn: () => get<Page<Family>>('/families' + qs(params)),
    placeholderData: keepPreviousData,
  })

  return (
    <div>
      <PageHeader
        title="Families"
        subtitle="Parent accounts with where they are, their device and how far their children got."
        actions={
          <a href={'/admin/api/v1/families.csv' + qs({ ...params, page: undefined, pageSize: undefined })} download>
            <Button icon={<Download className="size-4" />}>Export CSV</Button>
          </a>
        }
      />
      <Card padded={false}>
        <div className="flex flex-wrap items-center gap-2 border-b border-line p-3">
          <SearchInput value={p.draft} onChange={p.setDraft} placeholder="Search email, parent or child name" />
          <Select value={p.country} onChange={(e) => p.set({ country: e.target.value, page: '' })} className="w-auto" aria-label="Country">
            <option value="">All countries</option>
            {countries.data?.map((c) => (
              <option key={c.key} value={c.key}>
                {flag(c.key)} {countryName(c.key)} ({c.n})
              </option>
            ))}
          </Select>
          <Select value={p.filter} onChange={(e) => p.set({ filter: e.target.value, page: '' })} className="w-auto" aria-label="Filter">
            <option value="">Everyone</option>
            <option value="online">Online now</option>
            <option value="active7">Active this week</option>
            <option value="inactive30">Inactive 30+ days</option>
            <option value="plus">Likho Plus</option>
            <option value="free">Free</option>
          </Select>
          <div className="ml-auto text-[12.5px] text-ink-3 tabular">{list.data ? `${num(list.data.total)} families` : ''}</div>
        </div>
        {list.isLoading ? (
          <Loading />
        ) : list.error ? (
          <div className="p-4">
            <ErrorBox error={list.error} retry={() => list.refetch()} />
          </div>
        ) : list.data!.items.length === 0 ? (
          <Empty icon={<Users className="size-5" />} title="No families match">
            Try another search or filter.
          </Empty>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[920px] text-[13.5px]">
              <thead className="border-b border-line bg-surface-2/60">
                <tr>
                  <Th sort="email" current={p.sort} desc={p.desc} onSort={p.onSort}>
                    Family
                  </Th>
                  <Th sort="country" current={p.sort} desc={p.desc} onSort={p.onSort}>
                    Country
                  </Th>
                  <Th>Device</Th>
                  <Th sort="children" current={p.sort} desc={p.desc} onSort={p.onSort} className="text-right">
                    Kids
                  </Th>
                  <Th sort="levels" current={p.sort} desc={p.desc} onSort={p.onSort} className="text-right">
                    Levels done
                  </Th>
                  <Th sort="stars" current={p.sort} desc={p.desc} onSort={p.onSort} className="text-right">
                    Stars
                  </Th>
                  <Th>Plan</Th>
                  <Th sort="lastSeen" current={p.sort} desc={p.desc} onSort={p.onSort}>
                    Last seen
                  </Th>
                  <Th sort="created" current={p.sort} desc={p.desc} onSort={p.onSort}>
                    Joined
                  </Th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {list.data!.items.map((f) => {
                  const online = Date.now() - new Date(f.lastSeenAt).getTime() < 5 * 60_000
                  return (
                    <tr key={f.id} onClick={() => navigate(`/families/${f.id}`)} className="cursor-pointer hover:bg-surface-2/60">
                      <td className="px-4 py-2.5">
                        <div className="flex items-center gap-3">
                          <div className="relative">
                            <Avatar src={f.pictureUrl} label={initials(f.name, f.email)} />
                            {online && <span className="absolute -right-0.5 -bottom-0.5 size-3 rounded-full border-2 border-surface bg-good" title="Online now" />}
                          </div>
                          <div className="min-w-0">
                            <div className="truncate font-medium text-ink">{f.name || '—'}</div>
                            <div className="truncate text-[12.5px] text-ink-3">{f.email}</div>
                          </div>
                        </div>
                      </td>
                      <td className="px-4 py-2.5 whitespace-nowrap" title={countrySourceName[f.countrySource]}>
                        {f.country ? (
                          <>
                            {flag(f.country)} {countryName(f.country)}
                          </>
                        ) : (
                          <span className="text-ink-3">Unknown</span>
                        )}
                      </td>
                      <td className="px-4 py-2.5 whitespace-nowrap text-ink-2">
                        {platformName[f.platform] ?? f.platform}
                        {f.appVersion && <span className="ml-1 text-[12px] text-ink-3">{f.appVersion}</span>}
                      </td>
                      <td className="tabular px-4 py-2.5 text-right">{f.children}</td>
                      <td className="tabular px-4 py-2.5 text-right">
                        {num(f.levels)}
                        {f.topLevel > 0 && <div className="text-[11.5px] text-ink-3">up to {f.topLevel}</div>}
                      </td>
                      <td className="tabular px-4 py-2.5 text-right">{num(f.starsEarned)}</td>
                      <td className="px-4 py-2.5">
                        {plusActive(f.plusUntil) ? (
                          <Badge tone="warn">
                            <Crown className="size-3" /> Plus
                          </Badge>
                        ) : (
                          <Badge>Free</Badge>
                        )}
                      </td>
                      <td className="px-4 py-2.5 whitespace-nowrap text-ink-2">{online ? <span className="text-good">Online</span> : ago(f.lastSeenAt)}</td>
                      <td className="px-4 py-2.5 whitespace-nowrap text-ink-2">{date(f.createdAt)}</td>
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
