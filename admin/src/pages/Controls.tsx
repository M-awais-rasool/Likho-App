import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import clsx from 'clsx'
import {
  Armchair,
  Award,
  BookOpen,
  CalendarClock,
  Check,
  CircleAlert,
  Crown,
  DoorOpen,
  Eye,
  EyeOff,
  Gamepad2,
  Lock,
  Megaphone,
  Mic,
  Palette,
  Plus,
  RotateCcw,
  Smartphone,
  Sparkles,
  Star,
  Sticker,
  Trash2,
  TriangleAlert,
  Users,
  Vibrate,
  Volume2,
  Wrench,
  type LucideIcon,
} from 'lucide-react'
import { useEffect, useMemo, useState, type ReactNode } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { PhonePreview } from '../components/PhonePreview'
import { Badge, Button, Card, ErrorBox, Field, Input, Loading, Modal, PageHeader, Segmented, Select, Textarea, Toggle, useToast } from '../components/ui'
import { ApiError, get, put, type KeyCount } from '../lib/api'
import {
  changedParts,
  clone,
  colorNames,
  featureInfo,
  gameInfo,
  itemInfo,
  modeInfo,
  resolveForPreview,
  type Controls as Ctl,
  type ControlsMeta,
  type Mode,
  type SavedControls,
  type Tone,
} from '../lib/controls'
import { ago } from '../lib/format'
import { useSession } from '../lib/session'

type Page = { saved: SavedControls; meta: ControlsMeta }

const tabs = [
  { id: 'features', label: 'Features', icon: Sparkles },
  { id: 'stories', label: 'Stories', icon: BookOpen },
  { id: 'room', label: 'Room & Pencil', icon: Armchair },
  { id: 'sound', label: 'Sound & games', icon: Gamepad2 },
  { id: 'plus', label: 'Likho Plus', icon: Crown },
  { id: 'app', label: 'App status', icon: Smartphone },
] as const
type TabId = (typeof tabs)[number]['id']

const featureIcon: Record<string, LucideIcon> = {
  stories: BookOpen,
  games: Gamepad2,
  room: Armchair,
  stickers: Sticker,
  certificate: Award,
  placement: Sparkles,
  guest: DoorOpen,
  sfx: Volume2,
  voice: Mic,
  haptics: Vibrate,
}

const toneTile: Record<Tone, string> = {
  violet: 'bg-brand-soft text-brand-ink',
  blue: 'bg-info-soft text-info',
  green: 'bg-good-soft text-good',
  amber: 'bg-warn-soft text-warn',
  pink: 'bg-bad-soft text-bad',
  teal: 'bg-good-soft text-good',
  slate: 'bg-surface-2 text-ink-2',
}

const screens = [
  { value: 'map', label: 'World map' },
  { value: 'stories', label: 'Stories' },
  { value: 'room', label: "Pencil's room" },
  { value: 'profile', label: 'Child profile' },
  { value: 'dashboard', label: 'Parents' },
  { value: 'settings', label: 'Parent settings' },
  { value: 'paywall', label: 'Likho Plus' },
  { value: 'welcome', label: 'Welcome' },
  { value: 'maintenance', label: 'Maintenance' },
  { value: 'update', label: 'Please update' },
]

const tabScreen: Record<TabId, string> = { features: 'map', stories: 'stories', room: 'room', sound: 'map', plus: 'paywall', app: 'dashboard' }

export default function Controls() {
  const { can, course } = useSession()
  const editable = can('editor')
  const qc = useQueryClient()
  const toast = useToast()
  const [params, setParams] = useSearchParams()
  const tab = (tabs.some((t) => t.id === params.get('tab')) ? params.get('tab') : 'features') as TabId

  const q = useQuery({ queryKey: ['controls'], queryFn: () => get<Page>('/controls') })
  const doc = useQuery({ queryKey: ['document', course], queryFn: () => get<unknown>(`/content/courses/${course}/document`), enabled: !!course })
  const overview = useQuery({ queryKey: ['overview', course, 30], queryFn: () => get<{ versions: KeyCount[] }>(`/overview?course=${course}&days=30`), enabled: !!course, staleTime: 60_000 })

  // the admin's unsaved changes (null: none, the saved controls show)
  const [edit, setEdit] = useState<Ctl | null>(null)
  const [confirming, setConfirming] = useState(false)
  const saved = q.data?.saved
  const draft = edit ?? saved?.controls ?? null
  const changed = useMemo(() => (draft && saved ? changedParts(saved.controls, draft) : new Set<string>()), [draft, saved])
  const dirty = changed.size > 0

  // leaving with unsaved changes asks first
  useEffect(() => {
    if (!dirty) return
    const warn = (e: BeforeUnloadEvent) => e.preventDefault()
    window.addEventListener('beforeunload', warn)
    return () => window.removeEventListener('beforeunload', warn)
  }, [dirty])

  // the phone: the page picks the screen for the tab; the admin can change it
  const [screen, setScreen] = useState<string>(tabScreen[tab])
  const [plus, setPlus] = useState(false)
  const [chosen, setChosen] = useState(false)
  const pickTab = (t: TabId) => {
    setParams({ tab: t }, { replace: true })
    setScreen(t === 'app' && draft?.app.maintenance.on ? 'maintenance' : tabScreen[t])
  }
  const previewDraft = useDebounced(draft, 500)
  const extra = useMemo(
    () => (previewDraft ? { controls: resolveForPreview(previewDraft, saved?.revision ?? 0, chosen), plus } : undefined),
    [previewDraft, saved?.revision, chosen, plus],
  )

  const save = useMutation({
    mutationFn: () => put<SavedControls>('/controls', { controls: draft, revision: saved?.revision ?? 0 }),
    onSuccess: (out) => {
      qc.setQueryData<Page>(['controls'], (p) => (p ? { ...p, saved: out } : p))
      qc.invalidateQueries({ queryKey: ['controls'] })
      setEdit(null)
      setConfirming(false)
      toast('Saved. Phones pick it up within 2 minutes (or when the app opens).', 'good')
    },
    onError: (e) => {
      setConfirming(false)
      toast(e instanceof ApiError && e.code === 'controls_changed' ? 'Someone else saved meanwhile. Reload the page to see their changes, then make yours again.' : e.message, 'bad')
    },
  })

  if (q.isLoading) return <Loading />
  if (q.error) return <ErrorBox error={q.error} retry={() => q.refetch()} />
  const { meta } = q.data!
  const d = draft!
  const set = (f: (c: Ctl) => void) => {
    if (!editable) return
    const next = clone(d)
    f(next)
    setEdit(next)
  }
  const risky = riskyChanges(saved!.controls, d)
  const chosenCount = (key: string) => meta.families.filter((x) => x.key === key && x.on).reduce((n, x) => n + x.count, 0)
  const offCount = (key: string) => meta.families.filter((x) => x.key === key && !x.on).reduce((n, x) => n + x.count, 0)
  const modesOf = (id: string) => meta.features.find((f) => f.id === id)?.modes ?? ['off', 'on']
  const feature = (id: string) => (
    <FeatureRow
      key={id}
      id={id}
      mode={d.features[id] ?? 'on'}
      modes={modesOf(id)}
      changed={changed.has(`feature:${id}`)}
      chosen={chosenCount(id)}
      excluded={offCount(id)}
      billingOn={d.billing.enabled}
      disabled={!editable}
      onChange={(m) => set((c) => void (c.features[id] = m))}
    />
  )
  const dot = (t: TabId) =>
    ({
      features: ['stories', 'games', 'room', 'stickers', 'certificate', 'placement', 'guest'].some((f) => changed.has(`feature:${f}`)),
      stories: changed.has('stories') || changed.has('feature:stories'),
      room: changed.has('room') || changed.has('colors') || changed.has('feature:room'),
      sound: changed.has('games') || ['sfx', 'voice', 'haptics'].some((f) => changed.has(`feature:${f}`)),
      plus: changed.has('billing'),
      app: changed.has('app'),
    })[t]

  return (
    <div className={clsx(dirty && 'pb-20')}>
      <PageHeader
        title="App controls"
        subtitle="Switch parts of the Likho app on and off, for everyone or for chosen families. Phones follow within about 2 minutes."
        actions={
          <span className="inline-flex items-center gap-2 rounded-lg border border-line bg-surface px-3 py-1.5 text-[12.5px] text-ink-2 shadow-card">
            <span className="relative flex size-2">
              <span className="absolute inline-flex size-full animate-ping rounded-full bg-good opacity-60" />
              <span className="relative inline-flex size-2 rounded-full bg-good" />
            </span>
            Live · version {saved!.revision}
            {saved!.updatedAt && (
              <span className="text-ink-3">
                · {saved!.updatedBy} {ago(saved!.updatedAt)}
              </span>
            )}
          </span>
        }
      />

      {!editable && (
        <div className="mb-4 flex items-center gap-2 rounded-xl border border-line bg-surface-2 px-4 py-3 text-[13px] text-ink-2">
          <Lock className="size-4" /> You can look; editors and owners can change the controls.
        </div>
      )}
      {(d.app.maintenance.on || !d.billing.enabled) && (
        <div className="mb-4 flex items-start gap-2 rounded-xl border border-warn/30 bg-warn-soft px-4 py-3 text-[13px] text-warn">
          <TriangleAlert className="mt-0.5 size-4 shrink-0" />
          <span>
            {d.app.maintenance.on && <b>Maintenance is on: nobody can use the app. </b>}
            {!d.billing.enabled && <span>Likho Plus is off: every level is free and the paywall is hidden.</span>}
          </span>
        </div>
      )}

      <div className="grid items-start gap-5 xl:grid-cols-[minmax(0,1fr)_420px]">
        <div className="min-w-0">
          <nav className="mb-4 flex flex-wrap gap-1 rounded-xl border border-line bg-surface p-1 shadow-card" aria-label="Sections">
            {tabs.map((t) => (
              <button
                key={t.id}
                onClick={() => pickTab(t.id)}
                aria-current={tab === t.id}
                className={clsx(
                  'relative inline-flex h-9 shrink-0 cursor-pointer items-center gap-2 rounded-lg px-3 text-[13px] font-medium transition-colors',
                  tab === t.id ? 'bg-brand text-white shadow-card' : 'text-ink-2 hover:bg-surface-2 hover:text-ink',
                )}
              >
                <t.icon className="size-4" />
                {t.label}
                {dot(t.id) && <span className={clsx('size-1.5 rounded-full', tab === t.id ? 'bg-white' : 'bg-warn')} title="Unsaved changes" />}
              </button>
            ))}
          </nav>

          {tab === 'features' && (
            <div className="space-y-5">
              <Section title="In the children's app" hint="Turn a part off and it disappears from the app. “Likho Plus” keeps it for paying families; others are shown the paywall.">
                {['stories', 'games', 'room', 'stickers', 'certificate'].map(feature)}
              </Section>
              <Section title="Getting started" hint="What a new family goes through.">
                {['placement', 'guest'].map(feature)}
              </Section>
              <Legend />
            </div>
          )}

          {tab === 'stories' && (
            <div className="space-y-5">
              <Section title="Stories" hint="The Stories button shows on the map only when Stories is on and at least one episode is.">
                {feature('stories')}
              </Section>
              <Section title="Episodes" hint="Each letter's story on its own. A family on a Plus-only episode without Plus sees the paywall.">
                {meta.episodes.map((e) => (
                  <Row key={e.ID} changed={changed.has('stories')}>
                    <div className="grid size-11 shrink-0 place-items-center rounded-xl bg-good text-[20px] font-bold text-white shadow-card">{e.Letter}</div>
                    <div className="min-w-0 flex-1">
                      <div className="text-[14px] font-semibold text-ink">{e.Title}</div>
                      <div className="text-[12.5px] text-ink-3">
                        Story {e.Letter} · {e.Letter} is for apple
                        {chosenCount(`story.${e.ID}`) > 0 && <> · {chosenCount(`story.${e.ID}`)} chosen families</>}
                      </div>
                    </div>
                    <ModePicker value={d.stories.episodes[e.ID] ?? 'on'} modes={['off', 'on', 'plus', 'chosen']} billingOn={d.billing.enabled} disabled={!editable} onChange={(m) => set((c) => void (c.stories.episodes[e.ID] = m))} />
                  </Row>
                ))}
                <Row changed={false}>
                  <div className="grid size-11 shrink-0 place-items-center rounded-xl bg-surface-2 text-[13px] font-bold tracking-wider text-ink-3">B–Z</div>
                  <div className="min-w-0 flex-1">
                    <Toggle disabled={!editable} checked={d.stories.comingSoon} onChange={(v) => set((c) => void (c.stories.comingSoon = v))} label="Show the letters still to come" hint="The grey “Coming soon” letters under the episodes." />
                  </div>
                </Row>
              </Section>
            </div>
          )}

          {tab === 'room' && (
            <div className="space-y-5">
              <Section title="Pencil's room" hint="Where children spend their stars.">
                {feature('room')}
              </Section>
              <RoomItems meta={meta} c={d} editable={editable} set={set} />
              <Colors meta={meta} c={d} editable={editable} set={set} changed={changed.has('colors')} />
            </div>
          )}

          {tab === 'sound' && (
            <div className="space-y-5">
              <Section title="Sound" hint="These switch it off for everyone (or chosen families). Parents can still turn sound effects and vibration off for their own family.">
                {['sfx', 'voice', 'haptics'].map(feature)}
              </Section>
              <Games meta={meta} c={d} editable={editable} set={set} changed={changed.has('games')} />
            </div>
          )}

          {tab === 'plus' && <Billing meta={meta} c={d} editable={editable} set={set} changed={changed.has('billing')} />}

          {tab === 'app' && (
            <AppStatus
              c={d}
              editable={editable}
              set={set}
              versions={overview.data?.versions ?? []}
              onPreview={(s) => setScreen(s)}
            />
          )}
        </div>

        <div className="xl:sticky xl:top-4">
          <Card padded={false}>
            <div className="flex flex-wrap items-center justify-between gap-2 border-b border-line px-4 py-3">
              <h2 className="text-[13.5px] font-semibold">Phone preview</h2>
              <Segmented
                value={plus ? 'plus' : 'free'}
                onChange={(v) => setPlus(v === 'plus')}
                options={[
                  { value: 'free', label: 'Free family' },
                  { value: 'plus', label: 'Plus family' },
                ]}
              />
            </div>
            <div className="p-4">
              <PhonePreview
                course={doc.data ?? null}
                level={Math.min(8, meta.lastLevel)}
                height={680}
                screens={screens}
                screen={screen}
                onScreen={setScreen}
                extra={extra}
                note={
                  <span className="flex flex-col items-center gap-2">
                    <span>The real app with your unsaved changes.</span>
                    <label className="inline-flex cursor-pointer items-center gap-1.5">
                      <input type="checkbox" checked={chosen} onChange={(e) => setChosen(e.target.checked)} className="accent-[var(--brand)]" />
                      Show it as one of the chosen families
                    </label>
                  </span>
                }
              />
            </div>
          </Card>
        </div>
      </div>

      {dirty && editable && (
        <div className="fixed inset-x-0 bottom-0 z-40 border-t border-line bg-surface/95 backdrop-blur lg:left-60">
          <div className="mx-auto flex max-w-[1400px] flex-wrap items-center justify-between gap-3 px-4 py-3 lg:px-8">
            <div className="flex items-center gap-2 text-[13px] text-ink-2">
              <span className="grid size-6 place-items-center rounded-full bg-warn-soft text-warn">
                <CircleAlert className="size-3.5" />
              </span>
              <span>
                <b className="text-ink">Unsaved changes</b> in {changedNames(changed).join(', ')}. Phones still have the saved version.
              </span>
            </div>
            <div className="flex gap-2">
              <Button variant="ghost" icon={<RotateCcw className="size-4" />} onClick={() => setEdit(null)}>
                Discard
              </Button>
              <Button variant="primary" icon={<Check className="size-4" />} loading={save.isPending} onClick={() => (risky.length ? setConfirming(true) : save.mutate())}>
                Save & publish
              </Button>
            </div>
          </div>
        </div>
      )}

      <Modal
        open={confirming}
        onClose={() => setConfirming(false)}
        title="Publish these changes?"
        footer={
          <>
            <Button onClick={() => setConfirming(false)}>Cancel</Button>
            <Button variant="primary" loading={save.isPending} onClick={() => save.mutate()}>
              Publish
            </Button>
          </>
        }
      >
        <p className="mb-3 text-[13.5px] text-ink-2">Every phone will follow these within about 2 minutes:</p>
        <ul className="space-y-2">
          {risky.map((r) => (
            <li key={r} className="flex items-start gap-2 rounded-lg bg-warn-soft px-3 py-2 text-[13px] text-warn">
              <TriangleAlert className="mt-0.5 size-4 shrink-0" /> {r}
            </li>
          ))}
        </ul>
      </Modal>
    </div>
  )
}

// ------------------------------------------------------------ pieces

function Section({ title, hint, children, action }: { title: string; hint?: ReactNode; children: ReactNode; action?: ReactNode }) {
  return (
    <section className="overflow-hidden rounded-xl border border-line bg-surface shadow-card">
      <div className="flex flex-wrap items-start justify-between gap-3 border-b border-line px-4 py-3">
        <div>
          <h2 className="text-[14px] font-semibold text-ink">{title}</h2>
          {hint && <p className="mt-0.5 max-w-2xl text-[12.5px] text-ink-3">{hint}</p>}
        </div>
        {action}
      </div>
      <div className="divide-y divide-line">{children}</div>
    </section>
  )
}

function Row({ children, changed }: { children: ReactNode; changed: boolean }) {
  return (
    <div className={clsx('relative flex flex-wrap items-center gap-x-4 gap-y-3 px-4 py-3.5 transition-colors', changed && 'bg-warn-soft/40')}>
      {changed && <span className="absolute inset-y-0 left-0 w-[3px] bg-warn" />}
      {children}
    </div>
  )
}

function FeatureRow(props: {
  id: string
  mode: Mode
  modes: Mode[]
  changed: boolean
  chosen: number
  excluded: number
  billingOn: boolean
  disabled: boolean
  onChange: (m: Mode) => void
}) {
  const info = featureInfo[props.id] ?? { title: props.id, text: '', tone: 'slate' as Tone }
  const Icon = featureIcon[props.id] ?? Sparkles
  return (
    <Row changed={props.changed}>
      <div className={clsx('grid size-11 shrink-0 place-items-center rounded-xl', toneTile[info.tone], props.mode === 'off' && 'opacity-50 grayscale')}>
        <Icon className="size-5" />
      </div>
      <div className="min-w-[200px] flex-1">
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-[14px] font-semibold text-ink">{info.title}</span>
          {props.mode === 'chosen' && (
            <Badge tone="brand">
              <Users className="size-3" /> {props.chosen} {props.chosen === 1 ? 'family' : 'families'}
            </Badge>
          )}
          {props.excluded > 0 && props.mode !== 'off' && (
            <Badge title="Families with this switched off on their page">{props.excluded} switched off</Badge>
          )}
        </div>
        <p className="mt-0.5 text-[12.5px] text-ink-3">{info.text}</p>
        {info.warn && props.mode !== 'on' && (
          <p className="mt-1 flex items-center gap-1 text-[12px] text-warn">
            <TriangleAlert className="size-3.5" /> {info.warn}
          </p>
        )}
        {props.mode === 'chosen' && (
          <p className="mt-1 text-[12px] text-ink-3">
            Choose families on their page:{' '}
            <Link to="/families" className="font-medium text-brand hover:underline">
              Families
            </Link>{' '}
            › a family › Features.
          </p>
        )}
      </div>
      <ModePicker value={props.mode} modes={props.modes} billingOn={props.billingOn} disabled={props.disabled} onChange={props.onChange} />
    </Row>
  )
}

const modeOn: Record<Mode, string> = {
  off: 'bg-surface text-ink shadow-card',
  on: 'bg-good text-white shadow-card',
  plus: 'bg-star text-[#3a2a00] shadow-card',
  chosen: 'bg-brand text-white shadow-card',
}

function ModePicker({ value, modes, onChange, disabled, billingOn }: { value: Mode; modes: Mode[]; onChange: (m: Mode) => void; disabled?: boolean; billingOn: boolean }) {
  return (
    <div className="inline-flex shrink-0 rounded-lg border border-line bg-surface-2 p-0.5" role="radiogroup">
      {modes.map((m) => (
        <button
          key={m}
          role="radio"
          aria-checked={m === value}
          disabled={disabled}
          title={m === 'plus' && !billingOn ? 'Likho Plus is off: Plus-only parts are open to everyone' : modeInfo[m].hint}
          onClick={() => onChange(m)}
          className={clsx(
            'h-7 cursor-pointer rounded-md px-2.5 text-[12.5px] font-medium whitespace-nowrap transition-all disabled:cursor-not-allowed',
            m === value ? modeOn[m] : 'text-ink-2 hover:text-ink',
          )}
        >
          {m === 'plus' && <Crown className="mr-1 -mt-0.5 inline size-3" />}
          {modeInfo[m].label}
        </button>
      ))}
    </div>
  )
}

function Legend() {
  return (
    <div className="grid gap-2 rounded-xl border border-dashed border-line-strong p-4 text-[12.5px] text-ink-2 sm:grid-cols-2">
      {(['off', 'on', 'plus', 'chosen'] as Mode[]).map((m) => (
        <div key={m} className="flex items-start gap-2">
          <span className={clsx('mt-0.5 inline-flex h-5 shrink-0 items-center rounded px-1.5 text-[11px] font-semibold', modeOn[m])}>{modeInfo[m].label}</span>
          <span>{modeInfo[m].hint}</span>
        </div>
      ))}
    </div>
  )
}

type SectionProps = { meta: ControlsMeta; c: Ctl; editable: boolean; set: (f: (c: Ctl) => void) => void; changed?: boolean }

function RoomItems({ meta, c, editable, set }: SectionProps) {
  const groups = [
    { title: 'Clothes Pencil wears', items: meta.items.filter((i) => i.wear) },
    { title: 'Things for the room', items: meta.items.filter((i) => !i.wear) },
  ]
  const hidden = meta.items.filter((i) => c.room.items[i.id]?.hidden).length
  return (
    <Section
      title="Shop items"
      hint="A hidden item leaves the shop, and Pencil and the room stop showing it for children who bought it (they keep it if you show it again). Stars are not given back."
      action={
        editable && (
          <div className="flex gap-1.5">
            <Button size="sm" variant="ghost" icon={<Eye className="size-3.5" />} onClick={() => set((x) => meta.items.forEach((i) => (x.room.items[i.id] = { ...x.room.items[i.id], hidden: false })))}>
              Show all
            </Button>
            <Button size="sm" variant="ghost" icon={<RotateCcw className="size-3.5" />} onClick={() => set((x) => meta.items.forEach((i) => (x.room.items[i.id] = { ...x.room.items[i.id], price: i.price })))}>
              Reset prices
            </Button>
          </div>
        )
      }
    >
      {groups.map((g) => (
        <div key={g.title} className="p-4">
          <div className="mb-3 flex items-center justify-between text-[12px] font-semibold tracking-wide text-ink-3 uppercase">
            {g.title}
            {g.title.startsWith('Clothes') && hidden > 0 && <Badge tone="warn">{hidden} hidden</Badge>}
          </div>
          <div className="grid grid-cols-[repeat(auto-fill,minmax(150px,1fr))] gap-3">
            {g.items.map((it) => {
              const ctl = c.room.items[it.id] ?? { hidden: false, price: it.price }
              const info = itemInfo[it.id] ?? { name: it.id, emoji: '🎁' }
              return (
                <div
                  key={it.id}
                  className={clsx(
                    'group relative flex flex-col items-center rounded-xl border p-3 text-center transition-all',
                    ctl.hidden ? 'border-dashed border-line-strong bg-surface-2' : 'border-line bg-surface hover:border-brand/40 hover:shadow-card',
                  )}
                >
                  <button
                    disabled={!editable}
                    onClick={() => set((x) => void (x.room.items[it.id] = { ...ctl, hidden: !ctl.hidden }))}
                    className={clsx(
                      'absolute top-2 right-2 grid size-7 cursor-pointer place-items-center rounded-lg transition-colors disabled:cursor-not-allowed',
                      ctl.hidden ? 'bg-ink text-surface' : 'text-ink-3 hover:bg-surface-2 hover:text-ink',
                    )}
                    title={ctl.hidden ? 'Hidden: show it again' : 'Hide it'}
                    aria-label={ctl.hidden ? `Show ${info.name}` : `Hide ${info.name}`}
                  >
                    {ctl.hidden ? <EyeOff className="size-3.5" /> : <Eye className="size-3.5" />}
                  </button>
                  <div className={clsx('mt-1 grid size-14 place-items-center rounded-2xl bg-warn-soft text-[30px]', ctl.hidden && 'opacity-40 grayscale')}>{info.emoji}</div>
                  <div className={clsx('mt-2 text-[13px] font-semibold', ctl.hidden ? 'text-ink-3 line-through' : 'text-ink')}>{info.name}</div>
                  <label className="mt-2 flex h-8 items-center gap-1 rounded-lg border border-line-strong bg-surface px-2 focus-within:border-brand">
                    <Star className="size-3.5 fill-star text-star" />
                    <input
                      type="number"
                      min={1}
                      max={999}
                      disabled={!editable}
                      value={ctl.price}
                      onChange={(e) => set((x) => void (x.room.items[it.id] = { ...ctl, price: Math.max(0, Math.round(Number(e.target.value) || 0)) }))}
                      className="tabular w-12 bg-transparent text-center text-[13px] font-semibold text-ink outline-none"
                      aria-label={`${info.name} price in stars`}
                    />
                  </label>
                  {ctl.price !== it.price && (
                    <button disabled={!editable} onClick={() => set((x) => void (x.room.items[it.id] = { ...ctl, price: it.price }))} className="mt-1 cursor-pointer text-[11px] text-ink-3 hover:text-brand">
                      was {it.price}
                    </button>
                  )}
                </div>
              )
            })}
          </div>
        </div>
      ))}
    </Section>
  )
}

function Colors({ meta, c, editable, set, changed }: SectionProps) {
  return (
    <Section title="Pencil's colours" hint="The colours a parent can pick when adding a child. Children who already have a colour keep it.">
      <Row changed={!!changed}>
        <Palette className="size-5 text-ink-3" />
        <div className="flex flex-wrap gap-3">
          {meta.colors.map((col) => {
            const on = c.pencilColors.includes(col)
            const last = on && c.pencilColors.length === 1
            return (
              <button
                key={col}
                disabled={!editable || last}
                title={last ? 'Keep at least one colour' : colorNames[col]}
                onClick={() => set((x) => void (x.pencilColors = on ? x.pencilColors.filter((y) => y !== col) : meta.colors.filter((y) => y === col || x.pencilColors.includes(y))))}
                className={clsx('group flex cursor-pointer flex-col items-center gap-1.5 disabled:cursor-not-allowed', !on && 'opacity-50')}
              >
                <span className={clsx('relative grid size-12 place-items-center rounded-full ring-offset-2 ring-offset-surface transition-all', on ? 'ring-2 ring-ink' : 'ring-1 ring-line-strong')} style={{ background: col }}>
                  {on ? <Check className="size-5 text-white drop-shadow" strokeWidth={3} /> : <EyeOff className="size-4 text-white/90" />}
                </span>
                <span className="text-[11.5px] text-ink-2">{colorNames[col] ?? col}</span>
              </button>
            )
          })}
        </div>
      </Row>
    </Section>
  )
}

function Games({ meta, c, editable, set, changed }: SectionProps) {
  const off = meta.games.filter((g) => c.games[g] === false).length
  return (
    <Section
      title="Games in the levels"
      hint="A game type switched off is skipped in every level. Writing always stays, and a level never ends up empty."
      action={off > 0 ? <Badge tone="warn">{off} off</Badge> : <Badge tone="good">All on</Badge>}
    >
      <div className={clsx('grid grid-cols-[repeat(auto-fill,minmax(190px,1fr))] gap-2.5 p-4', changed && 'bg-warn-soft/30')}>
        <div className="flex items-center gap-3 rounded-xl border border-line bg-surface-2 p-3">
          <span className="grid size-9 place-items-center rounded-lg bg-brand-soft text-brand-ink">✍️</span>
          <span className="min-w-0 flex-1">
            <span className="block text-[13px] font-semibold text-ink">Writing</span>
            <span className="block text-[11.5px] text-ink-3">Always on</span>
          </span>
          <Lock className="size-4 text-ink-3" />
        </div>
        {meta.games.map((g) => {
          const on = c.games[g] !== false
          const info = gameInfo[g] ?? { title: g, text: '' }
          return (
            <button
              key={g}
              disabled={!editable}
              onClick={() => set((x) => void (x.games[g] = !on))}
              className={clsx(
                'flex cursor-pointer items-center gap-3 rounded-xl border p-3 text-left transition-all disabled:cursor-not-allowed',
                on ? 'border-good/40 bg-good-soft/50 hover:border-good' : 'border-dashed border-line-strong bg-surface hover:border-ink-3',
              )}
              aria-pressed={on}
            >
              <span className={clsx('grid size-9 shrink-0 place-items-center rounded-lg', on ? 'bg-good text-white' : 'bg-surface-2 text-ink-3')}>
                {on ? <Check className="size-4" strokeWidth={3} /> : <EyeOff className="size-4" />}
              </span>
              <span className="min-w-0 flex-1">
                <span className={clsx('block text-[13px] font-semibold', on ? 'text-ink' : 'text-ink-3')}>{info.title}</span>
                <span className="block truncate text-[11.5px] text-ink-3">{info.text}</span>
              </span>
            </button>
          )
        })}
      </div>
    </Section>
  )
}

function Billing({ meta, c, editable, set, changed }: SectionProps) {
  const b = c.billing
  const last = meta.lastLevel
  const n = (v: string, lo: number, hi: number) => Math.min(hi, Math.max(lo, Math.round(Number(v) || 0)))
  const promo = b.freeForAllUntil !== ''
  return (
    <div className="space-y-5">
      <Section title="Likho Plus" hint="Prices are set in Google Play Console; the app shows Google's prices.">
        <Row changed={!!changed}>
          <div className={clsx('grid size-11 shrink-0 place-items-center rounded-xl', b.enabled ? 'bg-warn-soft text-warn' : 'bg-surface-2 text-ink-3')}>
            <Crown className="size-5" />
          </div>
          <div className="min-w-[200px] flex-1">
            <Toggle
              disabled={!editable}
              checked={b.enabled}
              onChange={(v) => set((x) => void (x.billing.enabled = v))}
              label="Sell Likho Plus"
              hint={b.enabled ? 'Levels after the free ones need Plus.' : 'Off: every level is free and the app shows no paywall.'}
            />
          </div>
        </Row>
      </Section>

      <Section title="Which levels are open" hint="Children always play the levels in order.">
        <div className="space-y-5 p-4">
          <LevelBar b={b} last={last} />
          <div className="grid gap-4 sm:grid-cols-3">
            <Field label="Free levels" hint={`Levels 1 to ${b.freeLevels} need no Plus.`}>
              <Input type="number" min={0} max={last} disabled={!editable || !b.enabled} value={b.freeLevels} onChange={(e) => set((x) => void (x.billing.freeLevels = n(e.target.value, 0, last)))} />
            </Field>
            <Field label="Without an account" hint={b.guestLevels === 0 ? 'Guests only play the warm-up.' : `“Try it first” plays levels 1 to ${b.guestLevels}.`}>
              <Input type="number" min={0} max={b.enabled ? b.freeLevels : last} disabled={!editable} value={b.guestLevels} onChange={(e) => set((x) => void (x.billing.guestLevels = n(e.target.value, 0, x.billing.enabled ? x.billing.freeLevels : last)))} />
            </Field>
            <Field label="Free trial opens up to" hint={b.trialLevels === 0 ? 'The trial opens every level.' : `Trial families play up to level ${b.trialLevels}; the rest open once they pay.`}>
              <div className="flex gap-2">
                <Select
                  disabled={!editable || !b.enabled}
                  value={b.trialLevels === 0 ? 'all' : 'some'}
                  onChange={(e) => set((x) => void (x.billing.trialLevels = e.target.value === 'all' ? 0 : Math.min(last, Math.max(x.billing.freeLevels + 15, x.billing.freeLevels + 1))))}
                  className="w-auto"
                >
                  <option value="all">Every level</option>
                  <option value="some">Level…</option>
                </Select>
                {b.trialLevels > 0 && (
                  <Input type="number" min={b.freeLevels + 1} max={last} disabled={!editable || !b.enabled} value={b.trialLevels} onChange={(e) => set((x) => void (x.billing.trialLevels = n(e.target.value, 1, last)))} />
                )}
              </div>
            </Field>
          </div>
          {problems(c, last).map((p) => (
            <p key={p} className="flex items-center gap-1.5 text-[12.5px] text-bad">
              <CircleAlert className="size-4" /> {p}
            </p>
          ))}
        </div>
      </Section>

      <Section title="Free trial" hint="On Android, Google Play runs the free trial (its length is set in Play Console). Where there is no Google Play, Likho gives its own trial.">
        <Row changed={false}>
          <CalendarClock className="size-5 text-ink-3" />
          <div className="min-w-[200px] flex-1">
            <Toggle disabled={!editable || !b.enabled} checked={b.serverTrial} onChange={(v) => set((x) => void (x.billing.serverTrial = v))} label="Likho's own free trial" hint="Once per family, without paying." />
          </div>
          <label className="flex items-center gap-2 text-[13px] text-ink-2">
            <Input type="number" min={1} max={90} className="w-20" disabled={!editable || !b.enabled || !b.serverTrial} value={b.trialDays} onChange={(e) => set((x) => void (x.billing.trialDays = n(e.target.value, 1, 90)))} />
            days
          </label>
        </Row>
      </Section>

      <Section title="Plans on the paywall">
        <Row changed={false}>
          <div className="flex flex-wrap gap-3">
            {(['yearly', 'monthly'] as const).map((p) => {
              const on = b[p]
              const best = b.bestValue === p
              return (
                <div key={p} className={clsx('flex w-56 flex-col gap-2 rounded-xl border p-3', on ? 'border-info/40 bg-info-soft/40' : 'border-dashed border-line-strong opacity-70')}>
                  <div className="flex items-center justify-between">
                    <span className="text-[14px] font-semibold capitalize">{p}</span>
                    {best && on && <Badge tone="good">Best value</Badge>}
                  </div>
                  <Toggle
                    disabled={!editable || !b.enabled || (on && !b[p === 'yearly' ? 'monthly' : 'yearly'])}
                    checked={on}
                    onChange={(v) => set((x) => void ((x.billing[p] = v), !v && x.billing.bestValue === p && (x.billing.bestValue = '')))}
                    label="Offer it"
                  />
                  <button
                    disabled={!editable || !on || !b.enabled}
                    onClick={() => set((x) => void (x.billing.bestValue = best ? '' : p))}
                    className={clsx('cursor-pointer self-start text-[12px] font-medium disabled:cursor-not-allowed disabled:opacity-50', best ? 'text-ink-3 hover:text-ink' : 'text-brand hover:underline')}
                  >
                    {best ? 'Remove “Best value”' : 'Mark as best value'}
                  </button>
                </div>
              )
            })}
          </div>
        </Row>
        <div className="p-4">
          <div className="mb-2 flex items-center justify-between">
            <span className="text-[12.5px] font-medium text-ink-2">What Plus gives (the paywall's list)</span>
            {editable && b.benefits.length < 5 && (
              <Button size="sm" variant="ghost" icon={<Plus className="size-3.5" />} onClick={() => set((x) => void x.billing.benefits.push(''))}>
                Add a line
              </Button>
            )}
          </div>
          <div className="space-y-2">
            {b.benefits.map((line, i) => (
              <div key={i} className="flex items-center gap-2">
                <span className="grid size-7 shrink-0 place-items-center rounded-lg bg-good-soft text-good">
                  <Check className="size-3.5" strokeWidth={3} />
                </span>
                <Input maxLength={60} disabled={!editable} value={line} placeholder="e.g. Every world and every level" onChange={(e) => set((x) => void (x.billing.benefits[i] = e.target.value))} />
                {editable && (
                  <button onClick={() => set((x) => void x.billing.benefits.splice(i, 1))} className="grid size-8 shrink-0 cursor-pointer place-items-center rounded-lg text-ink-3 hover:bg-bad-soft hover:text-bad" aria-label="Remove line">
                    <Trash2 className="size-4" />
                  </button>
                )}
              </div>
            ))}
            {b.benefits.length === 0 && <p className="text-[12.5px] text-ink-3">No lines: the app shows its own list.</p>}
          </div>
        </div>
      </Section>

      <Section title="Free for everyone (promotion)" hint="Every level open for every family until the end of the day you pick (UTC), e.g. a launch week. The paywall is hidden meanwhile.">
        <Row changed={false}>
          <Sparkles className="size-5 text-ink-3" />
          <div className="min-w-[200px] flex-1">
            <Toggle
              disabled={!editable || !b.enabled}
              checked={promo}
              onChange={(v) => set((x) => void (x.billing.freeForAllUntil = v ? isoDay(7) : ''))}
              label={promo ? `Free until the end of ${b.freeForAllUntil}` : 'Run a promotion'}
            />
          </div>
          {promo && <Input type="date" className="w-44" disabled={!editable} value={b.freeForAllUntil} min={isoDay(0)} onChange={(e) => set((x) => void (x.billing.freeForAllUntil = e.target.value))} />}
        </Row>
      </Section>
    </div>
  )
}

/** Levels 1..last as a bar: guests, free, trial, Plus. */
function LevelBar({ b, last }: { b: Ctl['billing']; last: number }) {
  const parts = !b.enabled
    ? [{ label: 'Free for everyone', from: 1, to: last, cls: 'bg-good' }]
    : [
        { label: 'Guests too', from: 1, to: b.guestLevels, cls: 'bg-info' },
        { label: 'Free', from: b.guestLevels + 1, to: b.freeLevels, cls: 'bg-good' },
        ...(b.trialLevels > 0
          ? [
              { label: 'Trial & Plus', from: b.freeLevels + 1, to: b.trialLevels, cls: 'bg-star' },
              { label: 'Paid Plus only', from: b.trialLevels + 1, to: last, cls: 'bg-brand' },
            ]
          : [{ label: 'Trial & Plus', from: b.freeLevels + 1, to: last, cls: 'bg-star' }]),
      ]
  const shown = parts.filter((p) => p.to >= p.from)
  return (
    <div>
      <div className="flex h-9 overflow-hidden rounded-lg ring-1 ring-line">
        {shown.map((p) => (
          <div key={p.label} className={clsx('flex min-w-[3px] items-center justify-center overflow-hidden text-[11.5px] font-semibold whitespace-nowrap transition-all', p.cls, p.cls === 'bg-star' ? 'text-[#3a2a00]' : 'text-white')} style={{ flexGrow: p.to - p.from + 1 }} title={`${p.label}: levels ${p.from}–${p.to}`}>
            {(p.to - p.from + 1) / last > 0.08 && `${p.from}–${p.to}`}
          </div>
        ))}
      </div>
      <div className="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-[12px] text-ink-2">
        {shown.map((p) => (
          <span key={p.label} className="inline-flex items-center gap-1.5">
            <span className={clsx('size-2.5 rounded-sm', p.cls)} />
            {p.label} <span className="tabular text-ink-3">({p.from === p.to ? p.from : `${p.from}–${p.to}`})</span>
          </span>
        ))}
      </div>
    </div>
  )
}

function AppStatus({ c, editable, set, versions, onPreview }: { c: Ctl; editable: boolean; set: (f: (c: Ctl) => void) => void; versions: KeyCount[]; onPreview: (s: string) => void }) {
  const a = c.app
  const older = (v: string) => a.minVersion !== '' && compareVersions(v, a.minVersion) < 0
  const blocked = versions.filter((v) => older(v.key)).reduce((n, v) => n + v.n, 0)
  return (
    <div className="space-y-5">
      <Section title="Please update" hint="Phones with an older app see a full-screen “Time for an update!” with a button to Google Play.">
        <div className="space-y-3 p-4">
          <div className="flex flex-wrap items-end gap-3">
            <Field label="Oldest app version allowed" className="w-56" hint="Empty: every version works.">
              <Input disabled={!editable} value={a.minVersion} placeholder="e.g. 0.1.0+7" onChange={(e) => set((x) => void (x.app.minVersion = e.target.value.trim()))} />
            </Field>
            <Button size="sm" variant="ghost" icon={<Eye className="size-3.5" />} onClick={() => onPreview('update')}>
              Preview
            </Button>
          </div>
          {versions.length > 0 && (
            <div>
              <div className="mb-1.5 text-[12px] text-ink-3">Versions families use (tap to require it):</div>
              <div className="flex flex-wrap gap-1.5">
                {versions.map((v) => (
                  <button
                    key={v.key}
                    disabled={!editable}
                    onClick={() => set((x) => void (x.app.minVersion = v.key))}
                    className={clsx('cursor-pointer rounded-md border px-2 py-1 text-[12px] disabled:cursor-not-allowed', older(v.key) ? 'border-bad/30 bg-bad-soft text-bad' : a.minVersion === v.key ? 'border-brand bg-brand-soft text-brand-ink' : 'border-line bg-surface-2 text-ink-2 hover:border-ink-3')}
                  >
                    {v.key} <span className="opacity-70">· {v.n}</span>
                  </button>
                ))}
              </div>
              {blocked > 0 && (
                <p className="mt-2 flex items-center gap-1.5 text-[12.5px] text-bad">
                  <TriangleAlert className="size-4" /> {blocked} {blocked === 1 ? 'family is' : 'families are'} on an older version and will be asked to update.
                </p>
              )}
            </div>
          )}
        </div>
      </Section>

      <Section title="Maintenance" hint="For server work: the whole app shows a friendly “We'll be right back” screen with a Try again button. Nobody can play meanwhile.">
        <NoticeEditor
          n={a.maintenance}
          icon={Wrench}
          editable={editable}
          label="Show the maintenance screen"
          onChange={(f) => set((x) => f(x.app.maintenance))}
          onPreview={() => onPreview('maintenance')}
          danger
        />
      </Section>

      <Section title="Message to parents" hint="A card at the top of the Parents page. A parent can close it; a new message shows again.">
        <NoticeEditor n={a.parentMessage} icon={Megaphone} editable={editable} label="Show the message" onChange={(f) => set((x) => f(x.app.parentMessage))} onPreview={() => onPreview('dashboard')} />
      </Section>
    </div>
  )
}

function NoticeEditor({ n, icon: Icon, editable, label, onChange, onPreview, danger }: { n: Ctl['app']['maintenance']; icon: LucideIcon; editable: boolean; label: string; onChange: (f: (n: Ctl['app']['maintenance']) => void) => void; onPreview: () => void; danger?: boolean }) {
  return (
    <div className="space-y-3 p-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <span className={clsx('grid size-10 place-items-center rounded-xl', n.on ? (danger ? 'bg-bad-soft text-bad' : 'bg-info-soft text-info') : 'bg-surface-2 text-ink-3')}>
            <Icon className="size-5" />
          </span>
          <Toggle disabled={!editable} checked={n.on} onChange={(v) => onChange((x) => void (x.on = v))} label={label} />
        </div>
        <Button size="sm" variant="ghost" icon={<Eye className="size-3.5" />} onClick={onPreview}>
          Preview
        </Button>
      </div>
      <div className="grid gap-3 sm:grid-cols-[1fr_2fr]">
        <Field label="Title" hint={`${n.title.length}/60`}>
          <Input maxLength={60} disabled={!editable} value={n.title} onChange={(e) => onChange((x) => void (x.title = e.target.value))} />
        </Field>
        <Field label="Text" hint={`${n.text.length}/300`}>
          <Textarea rows={3} maxLength={300} disabled={!editable} value={n.text} onChange={(e) => onChange((x) => void (x.text = e.target.value))} />
        </Field>
      </div>
      {n.on && !n.text.trim() && (
        <p className="flex items-center gap-1.5 text-[12.5px] text-bad">
          <CircleAlert className="size-4" /> Write the text before you publish.
        </p>
      )}
    </div>
  )
}

// ------------------------------------------------------------ rules

/** Mistakes the server would refuse, shown while typing. */
function problems(c: Ctl, last: number): string[] {
  const b = c.billing
  const out: string[] = []
  if (b.enabled && b.guestLevels > b.freeLevels) out.push('Guests can only play free levels.')
  if (b.trialLevels !== 0 && b.trialLevels <= b.freeLevels) out.push('The trial must open more levels than the free ones.')
  if (b.freeLevels > last || b.trialLevels > last) out.push(`The course has ${last} levels.`)
  return out
}

/** Changes worth a second look before they go to every phone. */
function riskyChanges(before: Ctl, after: Ctl): string[] {
  const out: string[] = []
  if (after.app.maintenance.on && !before.app.maintenance.on) out.push('Maintenance goes on: nobody can use the app until you turn it off.')
  if (after.app.minVersion && after.app.minVersion !== before.app.minVersion) out.push(`Apps older than ${after.app.minVersion} must update before they can be used.`)
  if (!after.billing.enabled && before.billing.enabled) out.push('Likho Plus goes off: every level becomes free.')
  if (after.billing.enabled && after.billing.freeLevels < before.billing.freeLevels) out.push(`Free levels go down from ${before.billing.freeLevels} to ${after.billing.freeLevels}: some free families lose levels (their stars stay).`)
  if (after.features.voice === 'off' && before.features.voice !== 'off') out.push("Pencil's voice goes off for everyone.")
  return out
}

function changedNames(changed: Set<string>): string[] {
  const names = new Set<string>()
  for (const k of changed) {
    if (k.startsWith('feature:')) names.add(featureInfo[k.slice(8)]?.title ?? k.slice(8))
    else names.add({ stories: 'Stories', room: 'Shop items', games: 'Games', colors: "Pencil's colours", billing: 'Likho Plus', app: 'App status' }[k] ?? k)
  }
  return [...names]
}

function compareVersions(a: string, b: string): number {
  const parts = (v: string) => {
    const [main, build = '0'] = v.split('+')
    const p = main.split('.').map((x) => Number(x) || 0)
    while (p.length < 3) p.push(0)
    return [...p.slice(0, 3), Number(build) || 0]
  }
  const pa = parts(a)
  const pb = parts(b)
  for (let i = 0; i < 4; i++) if (pa[i] !== pb[i]) return pa[i] - pb[i]
  return 0
}

function isoDay(plusDays: number) {
  const d = new Date(Date.now() + plusDays * 86_400_000)
  return d.toISOString().slice(0, 10)
}

function useDebounced<T>(v: T, ms: number): T {
  const [out, setOut] = useState(v)
  useEffect(() => {
    const t = setTimeout(() => setOut(v), ms)
    return () => clearTimeout(t)
  }, [v, ms])
  return out
}

