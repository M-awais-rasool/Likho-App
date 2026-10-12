import { useQuery, useQueryClient } from '@tanstack/react-query'
import clsx from 'clsx'
import { CalendarDays, CircleCheck, ClipboardCheck, Copy, Crown, FlaskConical, MessageCircle, Pencil, Settings2, Undo2, UserPlus, Users } from 'lucide-react'
import { useMemo, useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { TesterDaysChart } from '../components/charts'
import { Avatar, Badge, Button, Card, Empty, ErrorBox, Field, Input, Loading, Modal, PageHeader, Select, Stat, Textarea, Th, Toggle, useConfirm, useToast } from '../components/ui'
import { del, get, patch, post, put, type ClosedTestBoard, type ClosedTestSettings, type TestAccount, type Tester } from '../lib/api'
import { ago, initials, plusActive, platformName, shortDay } from '../lib/format'
import { useSession } from '../lib/session'

// Google Play closed test: who used Likho on which day. Testers are told
// apart by the Likho account they sign in with (never by their phone).

const KEY = ['closed-test']

const addDays = (day: string, n: number) => {
  const d = new Date(day + 'T00:00:00Z')
  d.setUTCDate(d.getUTCDate() + n)
  return d.toISOString().slice(0, 10)
}

function daysBetween(start: string, end: string) {
  const out: string[] = []
  if (!start || !end) return out
  for (let d = start; d <= end && out.length < 366; d = addDays(d, 1)) out.push(d)
  return out
}

const firstName = (name: string) => name.trim().split(/\s+/)[0] ?? ''

function fill(template: string, name: string, day: number, days: number) {
  return template.replaceAll('{name}', firstName(name)).replaceAll('{day}', String(day)).replaceAll('{days}', String(days))
}

const whatsApp = (phone: string, text: string) => `https://wa.me/${phone}?text=${encodeURIComponent(text)}`

function inviteText(s: ClosedTestSettings) {
  return [
    "Hi! Thank you for testing Likho, our handwriting app for kids.",
    '',
    `1. Join the test with the Google account you gave me: ${s.optInUrl || '(link from Play Console)'}`,
    '2. Install Likho from the Play Store page that opens.',
    '3. Open Likho, tap "Continue with Google" and add your child.',
    `4. Please open Likho every day for the next ${s.days} days. A minute is enough.`,
    '',
    'Thank you!',
  ].join('\n')
}

type Run = (f: () => Promise<unknown>, done?: string) => Promise<boolean>

/** A tester with what the page shows about them. */
type Row = {
  t: Tester
  used: Set<string>
  usedDays: number
  today: boolean
  noMiss: boolean
  lastSeen: string | null
  levels: number
}

export default function ClosedTest() {
  const { can } = useSession()
  const editable = can('editor')
  const toast = useToast()
  const qc = useQueryClient()
  const q = useQuery({ queryKey: KEY, queryFn: () => get<ClosedTestBoard>('/closed-test'), refetchInterval: 60_000 })
  const [adding, setAdding] = useState(false)
  const [editing, setEditing] = useState<Tester | null>(null)
  const [settingsOpen, setSettingsOpen] = useState(false)
  const [inviteOpen, setInviteOpen] = useState(false)

  // runs a change; true when it worked (a problem shows as a toast)
  const run: Run = async (f, done) => {
    try {
      await f()
      if (done) toast(done, 'good')
      return true
    } catch (e) {
      toast((e as Error).message, 'bad')
      return false
    } finally {
      qc.invalidateQueries({ queryKey: KEY })
    }
  }

  const b = q.data
  const view = useMemo(() => {
    if (!b) return null
    const s = b.settings
    const testDays = daysBetween(s.startDate, b.endDate)
    const last = b.today < b.endDate ? b.today : b.endDate
    const past = testDays.filter((d) => d < b.today)
    const rows: Row[] = b.testers.map((t) => {
      const used = new Set(t.days)
      const seen = t.accounts.map((a) => a.lastSeenAt).filter(Boolean) as string[]
      return {
        t,
        used,
        usedDays: testDays.filter((d) => d <= last && used.has(d)).length,
        today: used.has(b.today),
        noMiss: t.accounts.length > 0 && past.every((d) => used.has(d)),
        lastSeen: seen.sort().at(-1) ?? null,
        levels: t.accounts.reduce((n, a) => n + a.levels, 0),
      }
    })
    const running = b.endDate !== '' && b.day >= 1 && b.day <= s.days
    const chart = testDays
      .filter((d) => d <= last)
      .map((day) => ({ day, n: rows.filter((r) => r.used.has(day)).length, total: rows.length }))
    return { s, testDays, rows, running, chart, elapsed: testDays.filter((d) => d <= last).length }
  }, [b])

  if (q.isLoading) return <Loading />
  if (q.error || !b || !view) return <ErrorBox error={q.error} retry={() => q.refetch()} />
  const { s, rows, running } = view
  const signedIn = rows.filter((r) => r.t.accounts.length > 0).length
  const openedToday = rows.filter((r) => r.today).length
  const noMiss = rows.filter((r) => r.noMiss).length
  const waiting = rows.filter((r) => !r.today)

  return (
    <div>
      <PageHeader
        title="Closed test"
        subtitle={
          <>
            Google Play needs {s.needed}+ testers opted in for {s.days} days in a row before launch. Here you see who used Likho on each day, by the account they
            sign in with (not their phone), so a different email than the one in Play Console is fine.
          </>
        }
        actions={
          <>
            <Button variant="ghost" icon={<ClipboardCheck className="size-4" />} onClick={() => setInviteOpen(true)}>
              Invite message
            </Button>
            {editable && (
              <>
                <Button icon={<Settings2 className="size-4" />} onClick={() => setSettingsOpen(true)}>
                  Settings
                </Button>
                <Button variant="primary" icon={<UserPlus className="size-4" />} onClick={() => setAdding(true)}>
                  Add testers
                </Button>
              </>
            )}
          </>
        }
      />

      {b.endDate === '' && (
        <Card className="mb-5" title={<span className="flex items-center gap-2"><CalendarDays className="size-4" /> Start the test</span>}>
          {editable ? (
            <SettingsForm initial={{ ...s, startDate: b.today }} submit="Start tracking" onSave={(v) => run(() => put('/closed-test/settings', v), 'The closed test is set up.')} />
          ) : (
            <p className="text-[13.5px] text-ink-2">An editor sets the first day of the test here.</p>
          )}
        </Card>
      )}

      <div className="mb-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Stat
          label="Test day"
          icon={<CalendarDays className="size-4" />}
          tone="brand"
          value={b.endDate === '' ? '—' : b.day < 1 ? 'Soon' : b.day > s.days ? 'Done' : `${b.day} / ${s.days}`}
          hint={b.endDate === '' ? 'Not set up yet' : b.day < 1 ? `Starts ${shortDay(s.startDate)}` : b.day > s.days ? `Ended ${shortDay(b.endDate)}` : `Ends ${shortDay(b.endDate)}`}
        />
        <Stat label="Signed in" icon={<Users className="size-4" />} value={`${signedIn} / ${rows.length}`} hint="Testers with a Likho account" />
        <Stat
          label="Opened today"
          icon={<CircleCheck className="size-4" />}
          tone={rows.length > 0 && waiting.length === 0 ? 'good' : 'warn'}
          value={`${openedToday} / ${rows.length}`}
          hint={running ? (waiting.length ? `${waiting.length} not yet today` : 'Everyone, well done') : 'Counted while the test runs'}
        />
        <Stat label="No day missed" icon={<FlaskConical className="size-4" />} tone={noMiss >= s.needed ? 'good' : 'muted'} value={noMiss} hint={`Target: ${s.needed} testers`} />
      </div>

      {view.chart.length > 0 && (
        <div className="mb-5 grid gap-5 xl:grid-cols-[3fr_2fr]">
          <Card title="Testers who opened Likho each day">
            <TesterDaysChart data={view.chart} target={s.needed} />
          </Card>
          {running && <NotToday rows={waiting} settings={s} day={b.day} />}
        </div>
      )}

      {b.newAccounts.length > 0 && <NewAccounts accounts={b.newAccounts} testers={b.testers} editable={editable} run={run} />}

      <Card padded={false} title={`Testers (${rows.length})`} action={<Legend />}>
        {rows.length === 0 ? (
          <Empty icon={<UserPlus className="size-5" />} title="No testers yet">
            Add the people you invited in Play Console. Paste them all at once: one per line, name, email and WhatsApp number.
          </Empty>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[940px] text-[13.5px]">
              <thead className="border-b border-line bg-surface-2/60">
                <tr>
                  <Th>Tester</Th>
                  <Th>Likho account</Th>
                  <Th>Days</Th>
                  <Th className="text-right">Used</Th>
                  <Th>Last opened</Th>
                  <Th className="text-right">Levels</Th>
                  <Th />
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {rows.map((r) => (
                  <tr key={r.t.id} className="align-top">
                    <td className="px-4 py-3">
                      <div className="font-medium text-ink">{r.t.name}</div>
                      <div className="text-[12.5px] text-ink-3">{r.t.email || 'No email'}</div>
                      {r.t.note && <div className="mt-0.5 text-[12px] text-ink-3">{r.t.note}</div>}
                    </td>
                    <td className="px-4 py-3">
                      {r.t.accounts.length === 0 ? (
                        <Badge tone="warn">Not signed in yet</Badge>
                      ) : (
                        <ul className="space-y-1.5">
                          {r.t.accounts.map((a) => (
                            <li key={a.parentId} className="flex items-center gap-2">
                              <Link to={`/families/${a.parentId}`} className="min-w-0 hover:underline">
                                <span className="block truncate text-[13px]">{a.email}</span>
                                <span className="block text-[11.5px] text-ink-3">
                                  {platformName[a.platform] ?? (a.platform || 'Unknown device')}
                                  {a.appVersion && ` ${a.appVersion}`} · {a.auto ? 'matched by email' : 'linked by hand'}
                                </span>
                              </Link>
                              {plusActive(a.plusUntil) && (
                                <Badge tone="warn" title={`Likho Plus until ${a.plusUntil?.slice(0, 10)}`}>
                                  <Crown className="size-3" /> Plus
                                </Badge>
                              )}
                              {editable && (
                                <Button
                                  size="sm"
                                  variant="ghost"
                                  aria-label={`Unlink ${a.email}`}
                                  title="Not this tester's account"
                                  icon={<Undo2 className="size-3.5" />}
                                  onClick={() => run(() => del(`/closed-test/accounts/${a.parentId}`), 'Unlinked. It is listed under new accounts.')}
                                />
                              )}
                            </li>
                          ))}
                        </ul>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <DayStrip days={view.testDays} used={r.used} today={b.today} />
                    </td>
                    <td className="tabular px-4 py-3 text-right whitespace-nowrap">
                      {r.usedDays} / {view.elapsed}
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap text-ink-2">
                      {r.today ? <span className="text-good">Today</span> : r.lastSeen ? ago(r.lastSeen) : '—'}
                    </td>
                    <td className="tabular px-4 py-3 text-right">{r.levels}</td>
                    <td className="px-4 py-3">
                      <div className="flex justify-end gap-1">
                        {r.t.phone && (
                          <a href={whatsApp(r.t.phone, fill(s.reminder, r.t.name, Math.max(b.day, 1), s.days))} target="_blank" rel="noopener noreferrer">
                            <Button size="sm" variant="ghost" aria-label={`WhatsApp ${r.t.name}`} title="Remind on WhatsApp" icon={<MessageCircle className="size-4" />} />
                          </a>
                        )}
                        {editable && <Button size="sm" variant="ghost" aria-label={`Edit ${r.t.name}`} icon={<Pencil className="size-4" />} onClick={() => setEditing(r.t)} />}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      {b.notTesters.length > 0 && (
        <Card className="mt-5" padded={false} title={`Not testers (${b.notTesters.length})`}>
          <ul className="divide-y divide-line">
            {b.notTesters.map((a) => (
              <li key={a.parentId} className="flex items-center gap-3 px-4 py-2.5">
                <AccountLine a={a} />
                {editable && (
                  <Button size="sm" variant="ghost" icon={<Undo2 className="size-3.5" />} onClick={() => run(() => del(`/closed-test/accounts/${a.parentId}`))}>
                    Undo
                  </Button>
                )}
              </li>
            ))}
          </ul>
        </Card>
      )}

      <AddTestersModal open={adding} onClose={() => setAdding(false)} />
      {editing && <EditTesterModal tester={editing} onClose={() => setEditing(null)} run={run} />}
      <Modal open={settingsOpen} onClose={() => setSettingsOpen(false)} title="Closed test settings" wide>
        <SettingsForm
          initial={s.startDate ? s : { ...s, startDate: b.today }}
          submit="Save settings"
          onSave={async (v) => {
            if (await run(() => put('/closed-test/settings', v), 'Settings saved.')) setSettingsOpen(false)
          }}
        />
      </Modal>
      <InviteModal open={inviteOpen} onClose={() => setInviteOpen(false)} settings={s} />
    </div>
  )
}

// ------------------------------------------------------------------ pieces

const dayState = {
  used: { cls: 'bg-good', label: 'Used' },
  missed: { cls: 'bg-bad-soft ring-1 ring-inset ring-bad/50', label: 'Not used' },
  today: { cls: 'bg-surface ring-1 ring-inset ring-line-strong', label: 'Today, not yet' },
  future: { cls: 'bg-surface-3', label: 'Coming' },
}

function DayStrip({ days, used, today }: { days: string[]; used: Set<string>; today: string }) {
  if (days.length === 0) return <span className="text-ink-3">—</span>
  return (
    <div className="flex gap-[3px]" role="img" aria-label={`Used on ${days.filter((d) => used.has(d)).length} of ${days.length} days`}>
      {days.map((d) => {
        const st = used.has(d) ? dayState.used : d < today ? dayState.missed : d === today ? dayState.today : dayState.future
        return <span key={d} title={`${shortDay(d)}: ${st.label}`} className={clsx('h-5 w-2.5 rounded-[3px]', st.cls)} />
      })}
    </div>
  )
}

function Legend() {
  return (
    <div className="hidden flex-wrap items-center gap-3 text-[11.5px] text-ink-2 sm:flex">
      {Object.values(dayState).map((s) => (
        <span key={s.label} className="flex items-center gap-1.5">
          <span className={clsx('h-3 w-2 rounded-[2px]', s.cls)} /> {s.label}
        </span>
      ))}
    </div>
  )
}

function NotToday({ rows, settings, day }: { rows: Row[]; settings: ClosedTestSettings; day: number }) {
  const toast = useToast()
  const copy = async () => {
    const text = `Not opened Likho yet today (day ${day} of ${settings.days}): ${rows.map((r) => firstName(r.t.name)).join(', ')}`
    await navigator.clipboard.writeText(text)
    toast('List copied. Paste it in your WhatsApp group.', 'good')
  }
  return (
    <Card
      title={`Not opened today (${rows.length})`}
      action={rows.length > 0 && <Button size="sm" variant="ghost" icon={<Copy className="size-3.5" />} onClick={copy}>Copy list</Button>}
      padded={false}
    >
      {rows.length === 0 ? (
        <Empty icon={<CircleCheck className="size-5" />} title="Everyone opened Likho today" />
      ) : (
        <ul className="max-h-[232px] divide-y divide-line overflow-y-auto">
          {rows.map((r) => (
            <li key={r.t.id} className="flex items-center gap-3 px-4 py-2.5">
              <div className="min-w-0 flex-1">
                <div className="truncate text-[13.5px] font-medium">{r.t.name}</div>
                <div className="text-[12px] text-ink-3">
                  {r.t.accounts.length === 0 ? 'Never signed in' : r.t.days.length ? `Last used ${shortDay(r.t.days[r.t.days.length - 1])}` : 'Signed in, not used yet'}
                </div>
              </div>
              {r.t.phone ? (
                <a href={whatsApp(r.t.phone, fill(settings.reminder, r.t.name, day, settings.days))} target="_blank" rel="noopener noreferrer">
                  <Button size="sm" icon={<MessageCircle className="size-3.5" />}>Remind</Button>
                </a>
              ) : (
                <span className="text-[12px] text-ink-3">No number</span>
              )}
            </li>
          ))}
        </ul>
      )}
    </Card>
  )
}

function AccountLine({ a }: { a: TestAccount }) {
  return (
    <>
      <Avatar src={a.pictureUrl} label={initials(a.name, a.email)} />
      <div className="min-w-0 flex-1">
        <div className="truncate text-[13.5px] font-medium">{a.name || a.email}</div>
        <div className="truncate text-[12px] text-ink-3">
          {a.email} · {platformName[a.platform] ?? (a.platform || 'Unknown device')} · joined {ago(a.createdAt)} · used on {a.days.length} {a.days.length === 1 ? 'day' : 'days'}
        </div>
      </div>
    </>
  )
}

/** A tester made from an account: its Google name (or the email's name)
 *  and email, so the server links the account to them at once. */
const asTester = (a: TestAccount) => ({ name: (a.name || a.email.split('@')[0]).slice(0, 80), email: a.email })

function NewAccounts({ accounts, testers, editable, run }: { accounts: TestAccount[]; testers: Tester[]; editable: boolean; run: Run }) {
  const confirm = useConfirm()
  const addAll = async () => {
    const ok = await confirm({
      title: `Add all ${accounts.length} as testers?`,
      body: 'Each account becomes a tester with its own name and email, and counts from today on the board (with the days it already used Likho). Your own phone or a family account: mark it "Not a tester" afterwards.',
      confirm: `Add ${accounts.length} testers`,
    })
    if (ok) await run(() => post('/closed-test/testers', { testers: accounts.map(asTester) }), `${accounts.length} testers added.`)
  }
  return (
    <Card
      className="mb-5 border-warn/40"
      padded={false}
      title={<span className="flex items-center gap-2">New accounts: whose are they? <Badge tone="warn">{accounts.length}</Badge></span>}
      action={
        editable && accounts.length > 1 ? (
          <Button size="sm" variant="primary" icon={<UserPlus className="size-4" />} onClick={addAll}>
            Add all as testers
          </Button>
        ) : undefined
      }
    >
      <p className="border-b border-line px-4 py-2.5 text-[12.5px] text-ink-2">
        These accounts used Likho during the test, but their email is not on the tester list (testers can sign in with any Google account). Pick who each one is,
        or make them testers: the board counts testers only.
      </p>
      <ul className="divide-y divide-line">
        {accounts.map((a) => (
          <li key={a.parentId} className="flex flex-wrap items-center gap-3 px-4 py-3 sm:flex-nowrap">
            <AccountLine a={a} />
            {editable && (
              <Select
                className="w-full sm:w-56"
                value=""
                aria-label={`Whose is ${a.email}?`}
                onChange={(e) => {
                  const v = e.target.value
                  if (!v) return
                  if (v === 'new') {
                    run(() => post('/closed-test/testers', { testers: [asTester(a)] }), `${asTester(a).name} is a tester now.`)
                    return
                  }
                  run(() => put(`/closed-test/accounts/${a.parentId}`, { testerId: v === 'none' ? null : v }), v === 'none' ? 'Marked as not a tester.' : 'Linked.')
                }}
              >
                <option value="">This is…</option>
                <option value="new">A new tester: {asTester(a).name}</option>
                {testers.map((t) => (
                  <option key={t.id} value={t.id}>
                    {t.name}
                    {t.email ? ` (${t.email})` : ''}
                  </option>
                ))}
                <option value="none">Not a tester (e.g. your own phone)</option>
              </Select>
            )}
          </li>
        ))}
      </ul>
    </Card>
  )
}

// ------------------------------------------------------------------ forms

const zones = ['Asia/Karachi', 'Asia/Dubai', 'Asia/Riyadh', 'Asia/Kolkata', 'Europe/London', 'America/New_York', 'UTC']

function SettingsForm({ initial, submit, onSave }: { initial: ClosedTestSettings; submit: string; onSave: (v: ClosedTestSettings) => Promise<unknown> }) {
  const [v, setV] = useState(initial) // from the settings when the form opens
  const [busy, setBusy] = useState(false)
  const set = (p: Partial<ClosedTestSettings>) => setV({ ...v, ...p })
  return (
    <form
      className="space-y-4"
      onSubmit={async (e) => {
        e.preventDefault()
        setBusy(true)
        try {
          await onSave(v)
        } finally {
          setBusy(false)
        }
      }}
    >
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Field label="First day" hint="The day 12+ testers were opted in.">
          <Input type="date" required value={v.startDate} onChange={(e) => set({ startDate: e.target.value })} />
        </Field>
        <Field label="Days">
          <Input type="number" min={1} max={90} value={v.days} onChange={(e) => set({ days: Number(e.target.value) })} />
        </Field>
        <Field label="Testers needed">
          <Input type="number" min={1} max={500} value={v.needed} onChange={(e) => set({ needed: Number(e.target.value) })} />
        </Field>
        <Field label="Days counted in">
          <Select value={v.timeZone} onChange={(e) => set({ timeZone: e.target.value })}>
            {(zones.includes(v.timeZone) ? zones : [v.timeZone, ...zones]).map((z) => (
              <option key={z} value={z}>
                {z.replace('_', ' ')}
              </option>
            ))}
          </Select>
        </Field>
      </div>
      <Toggle checked={v.plus} onChange={(plus) => set({ plus })} label="Testers get Likho Plus" hint="Every account that uses Likho during the test. Turning this off stops new grants; Plus already given stays until its date." />
      {v.plus && (
        <Field label="Plus until" className="pl-12 sm:max-w-xs" hint="Empty: 30 days after the test.">
          <Input type="date" value={v.plusUntil} onChange={(e) => set({ plusUntil: e.target.value })} />
        </Field>
      )}
      <Toggle checked={v.openLevels} onChange={(openLevels) => set({ openLevels })} label="Every level open for testers" hint="Testers can try any world and boss without playing in order." />
      <Field label="Play opt-in link" hint="Play Console → Closed testing → Testers → copy the join link. Used in the invite message.">
        <Input type="url" placeholder="https://play.google.com/apps/testing/…" value={v.optInUrl} onChange={(e) => set({ optInUrl: e.target.value })} />
      </Field>
      <Field label="WhatsApp reminder" hint="{name}, {day} and {days} are filled in for each tester.">
        <Textarea rows={3} value={v.reminder} onChange={(e) => set({ reminder: e.target.value })} />
      </Field>
      <div className="flex justify-end">
        <Button type="submit" variant="primary" loading={busy} disabled={!v.startDate}>
          {submit}
        </Button>
      </div>
    </form>
  )
}

/** "Name, email, phone" per line (tabs work too, e.g. from a sheet). */
function parseTesters(text: string) {
  return text
    .split('\n')
    .map((line) => line.split(/\t|,/).map((x) => x.trim()))
    .filter((p) => p.some(Boolean))
    .map((p) => {
      const email = p.find((x) => x.includes('@')) ?? ''
      const phone = p.find((x) => !x.includes('@') && /\d{7,}/.test(x.replace(/\D/g, ''))) ?? ''
      const name = p.find((x) => x && x !== email && x !== phone) ?? email.split('@')[0]
      return { name, email, phone }
    })
}

function AddTestersModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const toast = useToast()
  const qc = useQueryClient()
  const [text, setText] = useState('')
  const [busy, setBusy] = useState(false)
  const list = parseTesters(text)
  const add = async () => {
    setBusy(true)
    try {
      const r = await post<{ added: Tester[]; skipped: number }>('/closed-test/testers', { testers: list })
      toast(`Added ${r.added.length}${r.skipped ? `; ${r.skipped} already on the list` : ''}.`, 'good')
      setText('')
      onClose()
    } catch (e) {
      toast((e as Error).message, 'bad')
    } finally {
      setBusy(false)
      qc.invalidateQueries({ queryKey: KEY })
    }
  }
  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Add testers"
      wide
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>Cancel</Button>
          <Button variant="primary" loading={busy} disabled={list.length === 0} onClick={add}>
            Add {list.length || ''} {list.length === 1 ? 'tester' : 'testers'}
          </Button>
        </>
      }
    >
      <Field label="One tester per line: name, email, WhatsApp number" hint="The email you added in Play Console. The number is optional (with the country code, or 03xx for Pakistan). Someone already on the list is skipped.">
        <Textarea rows={8} placeholder={'Ali Khan, ali.khan@gmail.com, 0300 1234567\nSara Ahmed, sara@gmail.com'} value={text} onChange={(e) => setText(e.target.value)} />
      </Field>
      {list.length > 0 && (
        <ul className="mt-3 max-h-40 space-y-1 overflow-y-auto text-[12.5px] text-ink-2">
          {list.map((t, i) => (
            <li key={i} className="flex gap-2">
              <span className="font-medium text-ink">{t.name}</span>
              <span>{t.email || 'no email'}</span>
              {t.phone && <span className="text-ink-3">{t.phone}</span>}
            </li>
          ))}
        </ul>
      )}
    </Modal>
  )
}

function EditTesterModal({ tester, onClose, run }: { tester: Tester; onClose: () => void; run: Run }) {
  const confirm = useConfirm()
  const [v, setV] = useState({ name: tester.name, email: tester.email, phone: tester.phone, note: tester.note })
  const save = async () => {
    if (await run(() => patch(`/closed-test/testers/${tester.id}`, v), 'Tester saved.')) onClose()
  }
  const remove = async () => {
    const ok = await confirm({
      title: `Remove ${tester.name}?`,
      body: 'Their accounts and days stay; the accounts are listed as new again.',
      confirm: 'Remove',
      danger: true,
    })
    if (ok && (await run(() => del(`/closed-test/testers/${tester.id}`), 'Tester removed.'))) onClose()
  }
  return (
    <Modal
      open
      onClose={onClose}
      title="Edit tester"
      footer={
        <>
          <Button variant="danger" className="mr-auto" onClick={remove}>Remove</Button>
          <Button variant="ghost" onClick={onClose}>Cancel</Button>
          <Button variant="primary" disabled={!v.name.trim()} onClick={save}>Save</Button>
        </>
      }
    >
      <div className="space-y-3">
        <Field label="Name"><Input value={v.name} onChange={(e) => setV({ ...v, name: e.target.value })} /></Field>
        <Field label="Email in Play Console"><Input type="email" value={v.email} onChange={(e) => setV({ ...v, email: e.target.value })} /></Field>
        <Field label="WhatsApp number" hint="With the country code, e.g. 923001234567 (03xx works for Pakistan)."><Input inputMode="tel" value={v.phone} onChange={(e) => setV({ ...v, phone: e.target.value })} /></Field>
        <Field label="Note"><Input value={v.note} onChange={(e) => setV({ ...v, note: e.target.value })} /></Field>
      </div>
    </Modal>
  )
}

function InviteModal({ open, onClose, settings }: { open: boolean; onClose: () => void; settings: ClosedTestSettings }) {
  const toast = useToast()
  const text = inviteText(settings)
  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Invite message for testers"
      wide
      footer={
        <Button
          variant="primary"
          icon={<Copy className="size-4" />}
          onClick={async () => {
            await navigator.clipboard.writeText(text)
            toast('Invite copied.', 'good')
          }}
        >
          Copy
        </Button>
      }
    >
      {!settings.optInUrl && <Hint>Add Play's opt-in link in Settings so it goes into the message.</Hint>}
      <pre className="rounded-lg border border-line bg-surface-2 p-3 text-[13px] whitespace-pre-wrap text-ink">{text}</pre>
    </Modal>
  )
}

function Hint({ children }: { children: ReactNode }) {
  return <p className="mb-3 rounded-lg bg-warn-soft px-3 py-2 text-[12.5px] text-warn">{children}</p>
}
