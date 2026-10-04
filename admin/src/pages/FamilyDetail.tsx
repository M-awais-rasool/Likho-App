import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Crown, LogOut, Smartphone, Star, Trash2 } from 'lucide-react'
import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { EventRow } from '../components/EventRow'
import { Avatar, Badge, Button, Card, Empty, ErrorBox, Field, Input, Loading, Modal, Select, Stars, useConfirm, useToast } from '../components/ui'
import { del, get, post, qs, type ChildView, type ContentCourse, type FamilyDetail as Detail } from '../lib/api'
import { ago, countryName, countrySourceName, date, dateTime, flag, initials, num, platformName } from '../lib/format'
import { useSession } from '../lib/session'

export default function FamilyDetail() {
  const { id = '' } = useParams()
  const { course, can } = useSession()
  const qc = useQueryClient()
  const toast = useToast()
  const confirm = useConfirm()
  const navigate = useNavigate()
  const [plusOpen, setPlusOpen] = useState(false)
  const [starsFor, setStarsFor] = useState<ChildView | null>(null)

  const q = useQuery({ queryKey: ['family', id, course], queryFn: () => get<Detail>(`/families/${id}` + qs({ course })) })
  const content = useQuery({ queryKey: ['content', course], queryFn: () => get<ContentCourse>(`/content/courses/${course}`), enabled: !!course })
  const refresh = () => {
    qc.invalidateQueries({ queryKey: ['family', id] })
    qc.invalidateQueries({ queryKey: ['families'] })
  }
  const revoke = useMutation({
    mutationFn: () => del(`/families/${id}/plus`),
    onSuccess: () => {
      toast('Likho Plus ended.', 'good')
      refresh()
    },
    onError: (e) => toast(e.message, 'bad'),
  })

  if (q.isLoading) return <Loading />
  if (q.error) return <ErrorBox error={q.error} retry={() => q.refetch()} />
  const d = q.data!
  const f = d.family
  const editor = can('editor')
  const levels = content.data?.levels ?? []
  const last = d.lastLevel

  const signOut = async () => {
    if (!(await confirm({ title: 'Sign out every device?', body: `${f.email} will have to sign in with Google again on every phone. Their data stays.`, confirm: 'Sign out everywhere' }))) return
    try {
      await post(`/families/${id}/sign-out`)
      toast('Signed out on every device.', 'good')
      refresh()
    } catch (e) {
      toast((e as Error).message, 'bad')
    }
  }
  const remove = async () => {
    if (!(await confirm({ title: 'Delete this account?', body: <>This permanently deletes <b>{f.email}</b>, their {d.children.length} child profiles and all progress. It cannot be undone.</>, confirm: 'Delete account', danger: true, typeToConfirm: 'DELETE' }))) return
    try {
      await del(`/families/${id}`)
      toast('Account deleted.', 'good')
      qc.invalidateQueries({ queryKey: ['families'] })
      navigate('/families')
    } catch (e) {
      toast((e as Error).message, 'bad')
    }
  }

  return (
    <div>
      <Link to="/families" className="mb-4 inline-flex items-center gap-1.5 text-[13px] text-ink-2 hover:text-ink">
        <ArrowLeft className="size-4" /> Families
      </Link>

      <div className="mb-5 flex flex-wrap items-start justify-between gap-4 rounded-xl border border-line bg-surface p-5 shadow-card">
        <div className="flex min-w-0 items-center gap-4">
          <Avatar src={f.pictureUrl} label={initials(f.name, f.email)} size={56} />
          <div className="min-w-0">
            <h1 className="truncate text-[20px] font-semibold">{f.name || f.email}</h1>
            <div className="truncate text-[13.5px] text-ink-2">{f.email}</div>
            <div className="mt-2 flex flex-wrap gap-1.5">
              <Badge title={countrySourceName[f.countrySource]}>{f.country ? `${flag(f.country)} ${countryName(f.country)}` : '🌐 Unknown country'}</Badge>
              <Badge>
                <Smartphone className="size-3" /> {platformName[f.platform] ?? f.platform} {f.appVersion}
              </Badge>
              {d.subscription.active ? (
                <Badge tone="warn">
                  <Crown className="size-3" /> Plus until {date(d.subscription.plusUntil)}
                </Badge>
              ) : (
                <Badge>Free{d.subscription.trialUsed ? ' · trial used' : ''}</Badge>
              )}
              <Badge>Joined {date(f.createdAt)}</Badge>
              <Badge tone={Date.now() - new Date(f.lastSeenAt).getTime() < 300_000 ? 'good' : 'muted'}>Seen {ago(f.lastSeenAt)}</Badge>
            </div>
          </div>
        </div>
        {editor && (
          <div className="flex flex-wrap gap-2">
            <Button icon={<Crown className="size-4" />} onClick={() => setPlusOpen(true)}>
              Give Plus
            </Button>
            {d.subscription.active && (
              <Button variant="ghost" loading={revoke.isPending} onClick={async () => (await confirm({ title: 'End Likho Plus now?', body: 'Plus levels lock again for this family.', confirm: 'End Plus', danger: true })) && revoke.mutate()}>
                End Plus
              </Button>
            )}
            <Button variant="ghost" icon={<LogOut className="size-4" />} onClick={signOut}>
              Sign out devices
            </Button>
            {can('owner') && (
              <Button variant="ghost" className="text-bad" icon={<Trash2 className="size-4" />} onClick={remove}>
                Delete
              </Button>
            )}
          </div>
        )}
      </div>

      <div className="grid gap-5 xl:grid-cols-3">
        <div className="space-y-5 xl:col-span-2">
          {d.children.length === 0 && (
            <Card>
              <Empty title="No child profiles yet" />
            </Card>
          )}
          {d.children.map((c) => {
            const ls = c.progress[course]?.levelStars ?? {}
            const done = Object.keys(ls).length
            const earned = Object.values(ls).reduce((s, n) => s + n, 0)
            const top = Math.max(0, ...Object.keys(ls).map(Number))
            return (
              <Card
                key={c.id}
                title={
                  <span className="flex items-center gap-2.5">
                    <Avatar label={c.name[0]} color={c.color} size={26} />
                    {c.name} <span className="font-normal text-ink-3">· age {c.age}</span>
                    {top >= last && last > 0 ? <Badge tone="good">Finished</Badge> : top >= last - 1 && last > 0 ? <Badge tone="warn">On the last level</Badge> : null}
                  </span>
                }
                action={
                  editor && (
                    <Button size="sm" variant="ghost" icon={<Star className="size-3.5" />} onClick={() => setStarsFor(c)}>
                      Adjust stars
                    </Button>
                  )
                }
              >
                <div className="mb-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
                  {[
                    ['Levels done', `${done} / ${last}`],
                    ['Stars earned', num(earned)],
                    ['Star balance', `⭐ ${num(c.stars)}`],
                    ['Days played', `${c.daysPlayed} · ${c.minutesThisWeek} min this week`],
                  ].map(([k, v]) => (
                    <div key={k} className="rounded-lg bg-surface-2 px-3 py-2">
                      <div className="text-[11.5px] text-ink-3">{k}</div>
                      <div className="tabular text-[14px] font-semibold">{v}</div>
                    </div>
                  ))}
                </div>
                <div className="grid grid-cols-[repeat(auto-fill,minmax(52px,1fr))] gap-1.5" aria-label="Stars per level">
                  {Array.from({ length: last }, (_, i) => i + 1).map((n) => {
                    const s = ls[String(n)]
                    const isNext = !s && n === top + 1
                    const lv = levels.find((l) => l.number === n)
                    return (
                      <Link
                        to={`/content/levels/${n}`}
                        key={n}
                        title={`Level ${n}${lv ? `: ${lv.name}` : ''}${s ? ` · ${s} stars` : isNext ? ' · playing now' : ''}`}
                        className={`flex flex-col items-center rounded-md border py-1 text-[11px] ${s ? 'border-transparent bg-good-soft' : isNext ? 'border-brand bg-brand-soft' : 'border-line text-ink-3'}`}
                      >
                        <span className="tabular font-semibold">{n}</span>
                        {s ? <Stars n={s} size={9} /> : <span className="h-[9px] text-[9px]">{isNext ? 'now' : ''}</span>}
                      </Link>
                    )
                  })}
                </div>
                {c.owned.length > 0 && <div className="mt-3 text-[12px] text-ink-3">Room: {c.owned.join(', ')}</div>}
              </Card>
            )
          })}
          <Card title="Activity" padded={false}>
            {d.activity.length === 0 ? (
              <Empty title="No activity yet" />
            ) : (
              <ul className="divide-y divide-line">
                {d.activity.map((e) => (
                  <EventRow key={e.id} e={e} showFamily={false} />
                ))}
              </ul>
            )}
          </Card>
        </div>
        <div className="space-y-5">
          <Card title="Devices (sign-ins)" padded={false}>
            {d.devices.length === 0 ? (
              <Empty title="No sign-ins" />
            ) : (
              <ul className="divide-y divide-line">
                {d.devices.map((s) => (
                  <li key={s.id} className="px-4 py-3 text-[13px]">
                    <div className="truncate font-medium">{s.device || 'Unknown device'}</div>
                    <div className="text-[12px] text-ink-3">
                      Signed in {dateTime(s.createdAt)} · {s.revokedAt ? <span>signed out {ago(s.revokedAt)}</span> : new Date(s.expiresAt) < new Date() ? 'expired' : <span className="text-good">active</span>}
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </Card>
          <Card title="App settings">
            <dl className="grid grid-cols-2 gap-y-2 text-[13px]">
              {Object.entries(d.settings).map(([k, v]) => (
                <div key={k} className="contents">
                  <dt className="text-ink-3">{k.replace(/([A-Z])/g, ' $1').toLowerCase()}</dt>
                  <dd className="text-right font-medium">{typeof v === 'boolean' ? (v ? 'On' : 'Off') : k === 'sessionMinutes' ? `${v} min` : String(v)}</dd>
                </div>
              ))}
            </dl>
          </Card>
        </div>
      </div>

      <GrantPlus open={plusOpen} onClose={() => setPlusOpen(false)} parentId={id} onDone={refresh} />
      <AdjustStars child={starsFor} onClose={() => setStarsFor(null)} onDone={refresh} />
    </div>
  )
}

function GrantPlus({ open, onClose, parentId, onDone }: { open: boolean; onClose: () => void; parentId: string; onDone: () => void }) {
  const [days, setDays] = useState('30')
  const toast = useToast()
  const m = useMutation({
    mutationFn: () => post(`/families/${parentId}/plus`, { days: Number(days) }),
    onSuccess: () => {
      toast(`Likho Plus given for ${days} days.`, 'good')
      onDone()
      onClose()
    },
    onError: (e) => toast(e.message, 'bad'),
  })
  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Give Likho Plus"
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" loading={m.isPending} onClick={() => m.mutate()}>
            Give Plus
          </Button>
        </>
      }
    >
      <Field label="How long" hint="Added after the current Plus ends, if they have it. The app sees it on its next refresh.">
        <Select value={days} onChange={(e) => setDays(e.target.value)}>
          <option value="7">7 days</option>
          <option value="30">30 days</option>
          <option value="90">90 days</option>
          <option value="365">1 year</option>
        </Select>
      </Field>
    </Modal>
  )
}

function AdjustStars({ child, onClose, onDone }: { child: ChildView | null; onClose: () => void; onDone: () => void }) {
  const [delta, setDelta] = useState('10')
  const [reason, setReason] = useState('')
  const toast = useToast()
  const m = useMutation({
    mutationFn: () => post<{ stars: number }>(`/children/${child!.id}/stars`, { delta: Number(delta), reason }),
    onSuccess: (r) => {
      toast(`${child!.name} now has ${r.stars} stars.`, 'good')
      onDone()
      onClose()
    },
    onError: (e) => toast(e.message, 'bad'),
  })
  return (
    <Modal
      open={!!child}
      onClose={onClose}
      title={`Adjust ${child?.name ?? ''}'s stars`}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" loading={m.isPending} disabled={!Number(delta)} onClick={() => m.mutate()}>
            Save
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        <p className="text-[13px] text-ink-2">Balance now: ⭐ {child?.stars}. Stars are spent in Pencil's room. Use a minus number to take stars away (never below 0).</p>
        <Field label="Change by">
          <Input type="number" value={delta} onChange={(e) => setDelta(e.target.value)} />
        </Field>
        <Field label="Reason (audit log)">
          <Input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="e.g. lost stars after a bug" />
        </Field>
      </div>
    </Modal>
  )
}
