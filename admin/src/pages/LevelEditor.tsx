import { useQuery, useQueryClient } from '@tanstack/react-query'
import clsx from 'clsx'
import { ArrowLeft, CheckCircle2, CircleAlert, Loader2, MoreHorizontal, Rocket, Save, Undo2 } from 'lucide-react'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { applyChange, BasicsForm, IntroForm, RoundsForm, type Assets } from '../components/LevelForm'
import { PhonePreview } from '../components/PhonePreview'
import { Badge, Button, Card, ErrorBox, Loading, Segmented, Stars, Textarea, useConfirm, useToast } from '../components/ui'
import { ApiError, del, get, post, put, qs, type ContentLevelDetail, type LevelStats } from '../lib/api'
import { ago, duration, num } from '../lib/format'
import { asNewLevel, normalize, pretty, sameJSON, type Doc } from '../lib/level'
import { useSession } from '../lib/session'
import { statusBadge, useContent } from './Content'

type Tab = 'basics' | 'intro' | 'rounds' | 'json'

function useDebounced<T>(value: T, ms: number) {
  const [v, setV] = useState(value)
  useEffect(() => {
    const t = setTimeout(() => setV(value), ms)
    return () => clearTimeout(t)
  }, [value, ms])
  return v
}

export default function LevelEditor() {
  const params = useParams()
  const [sp] = useSearchParams()
  const isNew = !params.number
  const { course, can } = useSession()
  const content = useContent()
  const number = isNew ? (content.data?.nextNumber ?? 0) : Number(params.number)
  const fromNumber = Number(sp.get('from') ?? 0)

  const detail = useQuery({
    queryKey: ['level', course, number],
    queryFn: () => get<ContentLevelDetail>(`/content/courses/${course}/levels/${number}`),
    enabled: !isNew && !!course && number > 0,
  })
  const source = useQuery({
    queryKey: ['level', course, fromNumber],
    queryFn: () => get<ContentLevelDetail>(`/content/courses/${course}/levels/${fromNumber}`),
    enabled: isNew && !!course && fromNumber > 0,
  })

  if (!course || content.isPending || (!isNew && detail.isPending) || (isNew && fromNumber > 0 && source.isPending)) {
    const err = content.error ?? detail.error ?? source.error
    return err ? <ErrorBox error={err} /> : <Loading />
  }
  const err = content.error ?? detail.error ?? source.error
  if (err) return <ErrorBox error={err} />
  if (isNew && !source.data) return <ErrorBox error="Choose a level to start from (Levels & content → Add level)." />
  const world = isNew ? (sp.get('world') ?? '') : detail.data!.world
  const start = isNew ? asNewLevel(JSON.parse(source.data!.doc), number) : normalize(JSON.parse(detail.data!.doc), number)
  return <Editor key={`${course}-${number}-${isNew}`} isNew={isNew} number={number} world={world} initial={start} detail={isNew ? null : detail.data!} editor={can('editor')} />
}

function Editor({ isNew, number, world, initial, detail, editor }: { isNew: boolean; number: number; world: string; initial: Doc; detail: ContentLevelDetail | null; editor: boolean }) {
  const { course } = useSession()
  const content = useContent()
  const qc = useQueryClient()
  const toast = useToast()
  const confirm = useConfirm()
  const navigate = useNavigate()
  const [doc, setDoc] = useState<Doc>(initial)
  const [tab, setTab] = useState<Tab>('rounds')
  const [jsonText, setJsonText] = useState(() => pretty(initial))
  const [jsonError, setJsonError] = useState('')
  const [busy, setBusy] = useState('')
  const [check, setCheck] = useState<{ state: 'idle' | 'checking' | 'ok' | 'bad'; problems: string[] }>({ state: 'idle', problems: [] })
  const [menu, setMenu] = useState(false)

  const saved = detail?.doc ?? null
  const savedDoc = useMemo(() => (saved ? normalize(JSON.parse(saved), number) : null), [saved, number])
  const dirty = isNew || !sameJSON(savedDoc, doc)
  const status = detail?.status

  const change = useCallback((path: (string | number)[], value: unknown, opts?: { voice?: (string | number)[] }) => {
    setDoc((d) => {
      const next = normalize(applyChange(d, path, value, opts?.voice), number)
      setJsonText(pretty(next))
      return next
    })
  }, [number])

  // warn before leaving with unsaved work
  useEffect(() => {
    const f = (e: BeforeUnloadEvent) => {
      if (dirty) e.preventDefault()
    }
    window.addEventListener('beforeunload', f)
    return () => window.removeEventListener('beforeunload', f)
  }, [dirty])

  // check against the whole course while typing
  const debounced = useDebounced(doc, 600)
  const checkRun = useRef(0)
  useEffect(() => {
    const run = ++checkRun.current
    setCheck((c) => ({ ...c, state: 'checking' }))
    post(`/content/courses/${course}/levels/validate`, { number, world: isNew ? world : '', doc: JSON.stringify(debounced) })
      .then(() => run === checkRun.current && setCheck({ state: 'ok', problems: [] }))
      .catch((e) => run === checkRun.current && setCheck({ state: 'bad', problems: e instanceof ApiError && e.problems.length ? e.problems : [e.message] }))
  }, [debounced, course, number, world, isNew])

  // the preview gets the course with this level in it
  const staged = useQuery({ queryKey: ['document', course], queryFn: () => get<Doc>(`/content/courses/${course}/document`) })
  // the pictures on the server (its media folder, GET /v1/media)
  const assets = useQuery({
    queryKey: ['media'],
    queryFn: () =>
      fetch('/v1/media')
        .then((r) => (r.ok ? r.json() : { files: {} }))
        .then((m: { files: Record<string, string> }) => ({
          pictures: Object.keys(m.files)
            .filter((p) => p.startsWith('pictures/') && p.endsWith('.png'))
            .map((p) => p.slice('pictures/'.length, -'.png'.length))
            .sort(),
        }))
        .catch(() => ({ pictures: [] as string[] })),
    staleTime: 5 * 60_000,
  })
  const assetList: Assets = useMemo(() => ({ pictures: assets.data?.pictures ?? [], glyphs: Object.keys(staged.data?.glyphs ?? {}).sort() }), [assets.data, staged.data])
  const previewDoc = useDebounced(doc, 700)
  const previewCourse = useMemo(() => {
    const c = staged.data
    const cc = content.data
    if (!c || !cc) return null
    const w = [...cc.worlds, ...cc.emptyWorlds].find((x) => x.folder === world)
    const worlds = [...(c.worlds as Doc[])]
    if (w && !worlds.some((x) => x.id === w.id))
      worlds.push({ id: w.id, order: w.order, name: w.name, skill: w.skill, icon: w.icon, themeId: w.themeId, boss: { id: w.bossId, name: w.bossName } })
    const level: Doc = { ...previewDoc, worldId: w?.id ?? null, placement: false }
    const levels = [...(c.levels as Doc[]).filter((l) => l.placement || l.number !== number), level].sort((a, b) => (a.placement ? -1 : b.placement ? 1 : a.number - b.number))
    return { ...c, worlds, levels }
  }, [staged.data, content.data, previewDoc, world, number])

  const stats = useQuery({ queryKey: ['levelstats', course], queryFn: () => get<LevelStats>('/levels/stats' + qs({ course })), enabled: !isNew })
  const stat = stats.data?.levels.find((s) => s.level === number)

  const refresh = () => {
    qc.invalidateQueries({ queryKey: ['content'] })
    qc.invalidateQueries({ queryKey: ['level', course, number] })
    qc.invalidateQueries({ queryKey: ['document', course] })
  }

  const run = async (label: string, f: () => Promise<unknown>, done: string) => {
    setBusy(label)
    try {
      await f()
      toast(done, 'good')
      return true
    } catch (e) {
      if (e instanceof ApiError && e.problems.length) {
        setCheck({ state: 'bad', problems: e.problems })
        toast('The level has problems; see the checks list.', 'bad')
      } else toast((e as Error).message, 'bad')
      return false
    } finally {
      setBusy('')
    }
  }

  const save = async () => {
    if (isNew) {
      const ok = await run('save', () => post(`/content/courses/${course}/levels`, { number, world, doc: pretty(doc) }), `Level ${number} saved as a draft.`)
      if (ok) {
        refresh()
        navigate(`/content/levels/${number}`, { replace: true })
      }
      return ok
    }
    const ok = await run('save', () => put(`/content/courses/${course}/levels/${number}`, { doc: pretty(doc) }), 'Saved. Phones do not see it until you publish.')
    if (ok) refresh()
    return ok
  }

  const publish = async () => {
    const yes = await confirm({
      title: `Publish level ${number}?`,
      body: (
        <>
          Phones get <b>{doc.name}</b> the next time the app opens (the course downloads again only when it changed). Children already playing keep their progress.
        </>
      ),
      confirm: 'Publish to phones',
    })
    if (!yes) return
    if (dirty && !(await save())) return
    if (await run('publish', () => post(`/content/courses/${course}/levels/${number}/publish`), `Level ${number} is live on phones.`)) refresh()
  }

  const action = async (name: 'discard' | 'unpublish' | 'delete') => {
    setMenu(false)
    const texts = {
      discard: { title: 'Discard unpublished changes?', body: 'The level goes back to what phones have now.', confirm: 'Discard changes', done: 'Changes discarded.' },
      unpublish: { title: `Take level ${number} off phones?`, body: 'Only possible while no child has finished it. It stays here as a draft.', confirm: 'Unpublish', done: 'Unpublished. It is a draft again.' },
      delete: {
        title: detail?.source === 'edited' ? 'Revert to the original level?' : `Delete level ${number}?`,
        body: detail?.source === 'edited' ? 'Your edits are removed and phones get the original level again.' : 'The draft is deleted for good.',
        confirm: detail?.source === 'edited' ? 'Revert' : 'Delete',
        done: detail?.source === 'edited' ? 'Back to the original level.' : 'Level deleted.',
      },
    }[name]
    if (!(await confirm({ ...texts, danger: name !== 'discard' }))) return
    const ok = await run(name, () => (name === 'delete' ? del(`/content/courses/${course}/levels/${number}`) : post(`/content/courses/${course}/levels/${number}/${name}`)), texts.done)
    if (!ok) return
    refresh()
    if (name === 'delete' && detail?.source === 'new') {
      navigate('/content')
      return
    }
    const fresh = await qc.fetchQuery({ queryKey: ['level', course, number], queryFn: () => get<ContentLevelDetail>(`/content/courses/${course}/levels/${number}`) })
    const back = normalize(JSON.parse(fresh.doc), number)
    setDoc(back)
    setJsonText(pretty(back))
  }

  const worldInfo = [...(content.data?.worlds ?? []), ...(content.data?.emptyWorlds ?? [])].find((w) => w.folder === world)

  return (
    <div>
      <Link to="/content" className="mb-4 inline-flex items-center gap-1.5 text-[13px] text-ink-2 hover:text-ink">
        <ArrowLeft className="size-4" /> Levels & content
      </Link>

      <div className="sticky top-14 z-10 -mx-4 mb-5 flex flex-wrap items-center gap-3 border-b border-line bg-bg/90 px-4 py-3 backdrop-blur lg:-mx-8 lg:px-8">
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <h1 className="truncate text-[19px] font-semibold">
              Level {number}: {doc.name || 'Untitled'}
            </h1>
            {isNew ? <Badge tone="info">New, not saved</Badge> : detail && statusBadge(detail)}
            {detail?.source === 'edited' && <Badge>Edited built-in level</Badge>}
            {dirty && !isNew && <Badge tone="warn">Unsaved</Badge>}
          </div>
          <div className="mt-0.5 text-[12.5px] text-ink-3">
            World {worldInfo?.order} · {worldInfo?.name}
            {detail?.updatedAt && detail.updatedBy && ` · edited ${ago(detail.updatedAt)} by ${detail.updatedBy}`}
            {stat && stat.children > 0 && (
              <>
                {' · '}
                {num(stat.children)} finished · <Stars n={Math.round(stat.avgStars)} size={11} /> avg · {duration(stat.avgSeconds)}
              </>
            )}
          </div>
        </div>
        {editor && (
          <div className="flex items-center gap-2">
            <Button icon={<Save className="size-4" />} onClick={save} loading={busy === 'save'} disabled={!dirty || check.state === 'bad' || !!busy}>
              {isNew ? 'Save draft' : 'Save'}
            </Button>
            <Button variant="primary" icon={<Rocket className="size-4" />} onClick={publish} loading={busy === 'publish'} disabled={check.state === 'bad' || !!busy || (!dirty && status === 'live')}>
              Publish
            </Button>
            {!isNew && (
              <div className="relative">
                <Button variant="ghost" aria-label="More actions" onClick={() => setMenu(!menu)} icon={<MoreHorizontal className="size-4" />} />
                {menu && (
                  <div className="animate-pop absolute right-0 z-30 mt-1 w-60 rounded-xl border border-line bg-surface p-1.5 shadow-xl">
                    {dirty && (
                      <button className="flex w-full cursor-pointer items-center gap-2 rounded-md px-2.5 py-2 text-left text-[13px] hover:bg-surface-2" onClick={() => {
                        setMenu(false)
                        const back = normalize(JSON.parse(saved!), number)
                        setDoc(back)
                        setJsonText(pretty(back))
                      }}>
                        <Undo2 className="size-4" /> Undo unsaved edits
                      </button>
                    )}
                    {status === 'changed' && detail?.liveDoc && (
                      <button className="w-full cursor-pointer rounded-md px-2.5 py-2 text-left text-[13px] hover:bg-surface-2" onClick={() => action('discard')}>
                        Discard unpublished changes
                      </button>
                    )}
                    {detail?.source === 'new' && status !== 'draft' && (
                      <button className="w-full cursor-pointer rounded-md px-2.5 py-2 text-left text-[13px] hover:bg-surface-2" onClick={() => action('unpublish')}>
                        Unpublish (take off phones)
                      </button>
                    )}
                    {detail?.source === 'edited' && (
                      <button className="w-full cursor-pointer rounded-md px-2.5 py-2 text-left text-[13px] text-bad hover:bg-bad-soft" onClick={() => action('delete')}>
                        Revert to the original level
                      </button>
                    )}
                    {detail?.source === 'new' && status === 'draft' && (
                      <button className="w-full cursor-pointer rounded-md px-2.5 py-2 text-left text-[13px] text-bad hover:bg-bad-soft" onClick={() => action('delete')}>
                        Delete draft
                      </button>
                    )}
                    {detail?.source === 'builtin' && <div className="px-2.5 py-2 text-[12px] text-ink-3">Built-in level: edits are saved as a copy you can revert.</div>}
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </div>

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_470px]">
        <div className="min-w-0 space-y-4">
          <Checks check={check} />
          <Segmented
            value={tab}
            onChange={setTab}
            options={[
              { value: 'basics', label: 'Level' },
              { value: 'intro', label: 'Intro' },
              { value: 'rounds', label: `Rounds (${doc.rounds?.length ?? 0})` },
              { value: 'json', label: 'JSON' },
            ]}
          />
          <fieldset disabled={!editor} className="min-w-0">
            {tab === 'basics' && <BasicsForm doc={doc} change={change} />}
            {tab === 'intro' && <IntroForm doc={doc} change={change} assets={assetList} />}
            {tab === 'rounds' && <RoundsForm doc={doc} change={change} assets={assetList} />}
            {tab === 'json' && (
              <Card title="Level JSON" action={<span className="text-[12px] text-ink-3">Every field, as phones get it</span>}>
                <Textarea
                  value={jsonText}
                  spellCheck={false}
                  rows={28}
                  className="font-mono text-[12px] leading-relaxed"
                  onChange={(e) => {
                    setJsonText(e.target.value)
                    try {
                      const parsed = JSON.parse(e.target.value)
                      setJsonError('')
                      setDoc(normalize(parsed, number, doc.id))
                    } catch (err) {
                      setJsonError((err as Error).message)
                    }
                  }}
                />
                {jsonError && <div className="mt-2 text-[12.5px] text-bad">{jsonError}</div>}
              </Card>
            )}
          </fieldset>
        </div>
        <div className="xl:sticky xl:top-36 xl:self-start">
          <Card>
            <PhonePreview course={previewCourse} level={number} height={720} />
          </Card>
        </div>
      </div>
    </div>
  )
}

function Checks({ check }: { check: { state: string; problems: string[] } }) {
  if (check.state === 'checking' || check.state === 'idle')
    return (
      <div className="flex items-center gap-2 rounded-xl border border-line bg-surface px-4 py-2.5 text-[13px] text-ink-3">
        <Loader2 className="size-4 animate-spin" /> Checking the level against the whole course…
      </div>
    )
  if (check.state === 'ok')
    return (
      <div className="flex items-center gap-2 rounded-xl border border-good/30 bg-good-soft px-4 py-2.5 text-[13px] text-good">
        <CheckCircle2 className="size-4" /> All checks passed: ready to save and publish.
      </div>
    )
  return (
    <div className={clsx('rounded-xl border border-bad/30 bg-bad-soft px-4 py-3 text-[13px] text-bad')} role="alert">
      <div className="mb-1 flex items-center gap-2 font-semibold">
        <CircleAlert className="size-4" /> Fix {check.problems.length === 1 ? 'this' : `these ${check.problems.length}`} before saving
      </div>
      <ul className="list-disc space-y-0.5 pl-5">
        {check.problems.map((p) => (
          <li key={p}>{p}</li>
        ))}
      </ul>
    </div>
  )
}
