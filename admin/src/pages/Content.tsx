import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import clsx from 'clsx'
import { AlertTriangle, Crown, Plus, Swords, Trash2, Users } from 'lucide-react'
import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Badge, Button, Card, ErrorBox, Field, Input, Loading, Modal, PageHeader, Select, Stars, useConfirm, useToast } from '../components/ui'
import { del, get, post, qs, type ContentCourse, type ContentLevel, type ContentWorld, type LevelStats } from '../lib/api'
import { num } from '../lib/format'
import { useSession } from '../lib/session'

export const themeNames: Record<string, string> = {
  letterLand: 'Letter Land (green)',
  smallLetterCove: 'Small Letter Cove (teal)',
  phonicsForest: 'Phonics Forest (forest green)',
  wordTown: 'Word Town (orange)',
  sentenceSky: 'Sentence Sky (blue)',
  storySpace: 'Story Space (dark violet)',
  soundMountain: 'Sound Mountain (lavender)',
  blendBeach: 'Blend Beach (orange)',
  sightGarden: 'Sight Word Garden (pink)',
  actionJungle: 'Action Jungle (lime)',
  questionIsland: 'Question Island (gold)',
  readingRiver: 'Reading River (cyan)',
}
export const themeColors: Record<string, string> = {
  letterLand: '#5DAE3B',
  smallLetterCove: '#20A39D',
  phonicsForest: '#3F8F5A',
  wordTown: '#DB7453',
  sentenceSky: '#3B89D2',
  storySpace: '#7A63D4',
  soundMountain: '#8A6FD1',
  blendBeach: '#EE9A32',
  sightGarden: '#DD5E8C',
  actionJungle: '#86A321',
  questionIsland: '#D4A20A',
  readingRiver: '#1897B9',
}
export const bossNames: Record<string, string> = {
  snail: 'Snail',
  fish: 'Fish',
  bear: 'Bear',
  robotBus: 'Robot bus',
  cloud: 'Cloud',
  moon: 'Moon',
  goat: 'Goat',
  crab: 'Crab',
  ladybug: 'Ladybug',
  monkey: 'Monkey',
  turtle: 'Turtle',
  frog: 'Frog',
}

export const statusBadge = (l: Pick<ContentLevel, 'status' | 'source'>) =>
  l.status === 'draft' ? (
    <Badge tone="info">Draft</Badge>
  ) : l.status === 'changed' ? (
    <Badge tone="warn">Unpublished changes</Badge>
  ) : (
    <Badge tone="good">Live</Badge>
  )

export function useContent() {
  const { course } = useSession()
  return useQuery({ queryKey: ['content', course], queryFn: () => get<ContentCourse>(`/content/courses/${course}`), enabled: !!course })
}

export default function Content() {
  const { course, can } = useSession()
  const q = useContent()
  const stats = useQuery({ queryKey: ['levelstats', course], queryFn: () => get<LevelStats>('/levels/stats' + qs({ course })), enabled: !!course })
  const [addLevel, setAddLevel] = useState(false)
  const [addWorld, setAddWorld] = useState(false)
  const qc = useQueryClient()
  const toast = useToast()
  const confirm = useConfirm()

  if (q.isLoading) return <Loading />
  if (q.error) return <ErrorBox error={q.error} retry={() => q.refetch()} />
  const c = q.data!
  const byNumber = new Map(stats.data?.levels.map((s) => [s.level, s]))
  const pending = c.levels.filter((l) => l.status !== 'live').length
  const editor = can('editor')

  const removeWorld = async (w: ContentWorld) => {
    if (!(await confirm({ title: `Delete world “${w.name}”?`, body: 'It has no levels yet, so nothing changes for phones.', confirm: 'Delete world', danger: true }))) return
    try {
      await del(`/content/courses/${course}/worlds/${w.folder}`)
      qc.invalidateQueries({ queryKey: ['content'] })
    } catch (e) {
      toast((e as Error).message, 'bad')
    }
  }

  return (
    <div>
      <PageHeader
        title="Levels & content"
        subtitle={
          <>
            {c.title}: {c.liveLevels} levels in {c.worlds.filter((w) => w.live).length} worlds are live on phones
            {pending > 0 && <> · {pending} with unpublished work</>} · version <code className="text-[12px]">{c.version}</code>
          </>
        }
        actions={
          editor && (
            <>
              <Button icon={<Plus className="size-4" />} onClick={() => setAddWorld(true)}>
                New world
              </Button>
              <Button variant="primary" icon={<Plus className="size-4" />} onClick={() => setAddLevel(true)}>
                Add level
              </Button>
            </>
          )
        }
      />

      {c.problems.length > 0 && (
        <div className="mb-5 rounded-xl border border-bad/30 bg-bad-soft p-4 text-[13px] text-bad">
          <div className="mb-1 flex items-center gap-2 font-semibold">
            <AlertTriangle className="size-4" /> Published content has problems; phones still get the last good version.
          </div>
          <ul className="list-disc pl-5">
            {c.problems.map((p) => (
              <li key={p}>{p}</li>
            ))}
          </ul>
        </div>
      )}

      <div className="space-y-5">
        {c.worlds.map((w) => (
          <Card
            key={w.folder}
            padded={false}
            title={
              <span className="flex flex-wrap items-center gap-2">
                <span className="size-3 rounded-full" style={{ background: themeColors[w.themeId] }} />
                World {w.order} · {w.name}
                <span className="font-normal text-ink-3">
                  · {w.skill} · boss: {w.bossName}
                </span>
                {w.source === 'admin' && <Badge tone="brand">Added in panel</Badge>}
                {!w.live && <Badge tone="info">Not live yet</Badge>}
              </span>
            }
            action={<span className="text-[12px] text-ink-3">{w.levels.length} levels</span>}
          >
            <div className="grid gap-px bg-line sm:grid-cols-2 xl:grid-cols-3">
              {c.levels
                .filter((l) => l.world === w.folder)
                .map((l) => {
                  const s = byNumber.get(l.number)
                  return (
                    <Link key={l.number} to={`/content/levels/${l.number}`} className="group flex items-start gap-3 bg-surface p-3.5 hover:bg-surface-2/70">
                      <span className={clsx('tabular grid size-9 shrink-0 place-items-center rounded-full text-[13px] font-bold text-white')} style={{ background: themeColors[w.themeId] }}>
                        {l.number}
                      </span>
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-1.5">
                          <span className="truncate font-medium group-hover:text-brand-ink">{l.name}</span>
                          {l.isBoss && <Swords className="size-3.5 shrink-0 text-ink-3" aria-label="Boss level" />}
                          {l.requiresSubscription && <Crown className="size-3.5 shrink-0 text-star" aria-label="Likho Plus" />}
                        </div>
                        <div className="truncate text-[12px] text-ink-3">
                          {l.skill} · {l.rounds} rounds
                        </div>
                        <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
                          {statusBadge(l)}
                          {l.source !== 'builtin' && <Badge>{l.source === 'new' ? 'New' : 'Edited'}</Badge>}
                          {s && s.children > 0 && (
                            <span className="flex items-center gap-1 text-[12px] text-ink-3" title={`${s.children} children finished it, average ${s.avgStars.toFixed(1)} stars`}>
                              <Users className="size-3" /> {num(s.children)} · <Stars n={Math.round(s.avgStars)} size={10} />
                            </span>
                          )}
                          {s && s.current > 0 && <span className="text-[12px] text-brand-ink">{s.current} playing</span>}
                        </div>
                      </div>
                    </Link>
                  )
                })}
            </div>
          </Card>
        ))}
        {c.emptyWorlds.map((w) => (
          <Card
            key={w.folder}
            title={
              <span className="flex items-center gap-2">
                <span className="size-3 rounded-full" style={{ background: themeColors[w.themeId] }} />
                World {w.order} · {w.name} <Badge tone="info">No levels yet</Badge>
              </span>
            }
            action={
              editor && (
                <Button size="sm" variant="ghost" icon={<Trash2 className="size-3.5" />} onClick={() => removeWorld(w)}>
                  Delete
                </Button>
              )
            }
          >
            <p className="text-[13px] text-ink-2">Add its first level with “Add level”. The world shows on the map once one of its levels is published.</p>
          </Card>
        ))}
      </div>

      <AddLevel open={addLevel} onClose={() => setAddLevel(false)} content={c} />
      <WorldForm open={addWorld} onClose={() => setAddWorld(false)} content={c} />
    </div>
  )
}

function AddLevel({ open, onClose, content }: { open: boolean; onClose: () => void; content: ContentCourse }) {
  const lastWorld = content.worlds[content.worlds.length - 1]
  const options = [...(lastWorld ? [lastWorld] : []), ...content.emptyWorlds]
  const [world, setWorld] = useState('')
  const [from, setFrom] = useState('')
  const navigate = useNavigate()
  const chosen = world || content.emptyWorlds[0]?.folder || lastWorld?.folder || ''
  const template = from || String(content.levels[content.levels.length - 1]?.number ?? '')
  return (
    <Modal
      open={open}
      onClose={onClose}
      title={`Add level ${content.nextNumber}`}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" disabled={!chosen} onClick={() => navigate(`/content/levels/new?world=${encodeURIComponent(chosen)}&from=${template}`)}>
            Open editor
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        <p className="text-[13px] text-ink-2">
          New levels go after the last one (numbers never change, because children's progress is saved by level number). Add it to the last world, or to a new world you created.
        </p>
        <Field label="World">
          <Select value={chosen} onChange={(e) => setWorld(e.target.value)}>
            {options.map((w) => (
              <option key={w.folder} value={w.folder}>
                World {w.order} · {w.name}
              </option>
            ))}
          </Select>
        </Field>
        <Field label="Start from" hint="A copy of a level of the same kind is the quickest start; you then change its words, pictures and rounds. Recordings are not copied: the phone's voice reads the new words.">
          <Select value={template} onChange={(e) => setFrom(e.target.value)}>
            {content.levels.map((l) => (
              <option key={l.number} value={l.number}>
                Copy of level {l.number}: {l.name} ({l.skill})
              </option>
            ))}
          </Select>
        </Field>
      </div>
    </Modal>
  )
}

function WorldForm({ open, onClose, content }: { open: boolean; onClose: () => void; content: ContentCourse }) {
  const { course } = useSession()
  const qc = useQueryClient()
  const toast = useToast()
  const [f, setF] = useState({ name: '', skill: '', icon: 'public', themeId: 'storySpace', bossId: 'moon', bossName: '' })
  const set = (k: keyof typeof f) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => setF({ ...f, [k]: e.target.value })
  const m = useMutation({
    mutationFn: () => post<ContentWorld>(`/content/courses/${course}/worlds`, f),
    onSuccess: (w) => {
      toast(`World “${w.name}” added. Now add its first level.`, 'good')
      qc.invalidateQueries({ queryKey: ['content'] })
      onClose()
    },
    onError: (e) => toast(e.message, 'bad'),
  })
  return (
    <Modal
      open={open}
      onClose={onClose}
      title={`New world ${content.worlds.length + content.emptyWorlds.length + 1}`}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" loading={m.isPending} disabled={!f.name || !f.bossName} onClick={() => m.mutate()}>
            Add world
          </Button>
        </>
      }
    >
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Name" className="sm:col-span-2">
          <Input value={f.name} onChange={set('name')} placeholder="Ocean Deep" />
        </Field>
        <Field label="Skill" className="sm:col-span-2">
          <Input value={f.skill} onChange={set('skill')} placeholder="Reading short stories" />
        </Field>
        <Field label="Look (colours and decorations)">
          <Select value={f.themeId} onChange={set('themeId')}>
            {content.themes.map((t) => (
              <option key={t} value={t}>
                {themeNames[t] ?? t}
              </option>
            ))}
          </Select>
        </Field>
        <Field label="Map icon" hint="A Material Symbols name the app knows">
          <Input value={f.icon} onChange={set('icon')} />
        </Field>
        <Field label="Boss">
          <Select value={f.bossId} onChange={set('bossId')}>
            {content.bosses.map((b) => (
              <option key={b} value={b}>
                {bossNames[b] ?? b}
              </option>
            ))}
          </Select>
        </Field>
        <Field label="Boss name">
          <Input value={f.bossName} onChange={set('bossName')} placeholder="Sleepy Whale" />
        </Field>
      </div>
    </Modal>
  )
}
