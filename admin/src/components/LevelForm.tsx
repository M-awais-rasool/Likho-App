import clsx from 'clsx'
import { ArrowDown, ArrowUp, Copy, Mic, Plus, Trash2, Volume2 } from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import {
  COLORS,
  DOT_SHAPES,
  LAYOUTS,
  LEVEL_ICONS,
  ROUND_TYPES,
  SHAPES,
  SLOTS,
  STAGES,
  WRITE_MODES,
  blankRound,
  clone,
  getIn,
  setIn,
  withType,
  type Doc,
} from '../lib/level'
import { Badge, Button, Field, Input, Select, Toggle } from './ui'

/* eslint-disable @typescript-eslint/no-explicit-any */

export interface Assets {
  pictures: string[]
  glyphs: string[]
}

type Change = (path: (string | number)[], value: unknown, opts?: { voice?: (string | number)[] }) => void

const pictureUrl = (key: string) => `/media/pictures/${key}.png`

function Section({ title, children, hint }: { title: string; children: ReactNode; hint?: ReactNode }) {
  return (
    <section className="rounded-xl border border-line bg-surface p-4">
      <h3 className="text-[13.5px] font-semibold">{title}</h3>
      {hint && <p className="mt-0.5 text-[12px] text-ink-3">{hint}</p>}
      <div className="mt-3">{children}</div>
    </section>
  )
}

function Opt({ value, onChange, options, none = 'Default' }: { value: string | null | undefined; onChange: (v: string | null) => void; options: string[]; none?: string }) {
  return (
    <Select value={value ?? ''} onChange={(e) => onChange(e.target.value || null)}>
      <option value="">{none}</option>
      {options.map((o) => (
        <option key={o} value={o}>
          {o}
        </option>
      ))}
    </Select>
  )
}

/** A picture key from the app's illustrations, with a thumbnail. */
function PictureField({ value, onChange, assets, label = 'Picture' }: { value: Doc | null | undefined; onChange: (v: Doc | null) => void; assets: Assets; label?: string }) {
  const key = value?.key ?? ''
  const [broken, setBroken] = useState<string>('')
  const id = `pics-${label.replace(/\W/g, '')}`
  return (
    <Field label={label} hint={assets.pictures.length ? `${assets.pictures.length} pictures on the server` : 'A picture key from the media folder (media/pictures)'}>
      <div className="flex items-center gap-2">
        <span className="grid size-9 shrink-0 place-items-center overflow-hidden rounded-lg border border-line bg-surface-2">
          {key && broken !== key ? <img src={pictureUrl(key)} alt="" className="size-8 object-contain" onError={() => setBroken(key)} /> : <span className="text-[10px] text-ink-3">none</span>}
        </span>
        <Input
          list={id}
          value={key}
          placeholder="none"
          onChange={(e) => {
            const k = e.target.value.trim()
            onChange(k ? { key: k, label: value?.label && value.key === key ? value.label : k.replace(/_/g, ' '), url: value?.url ?? null } : null)
          }}
        />
        <datalist id={id}>
          {assets.pictures.map((p) => (
            <option key={p} value={p} />
          ))}
        </datalist>
      </div>
      {key && assets.pictures.length > 0 && !assets.pictures.includes(key) && <span className="mt-1 block text-[11.5px] text-warn">Not a picture on the server: a labelled placeholder shows instead.</span>}
    </Field>
  )
}

function Voice({ audio }: { audio?: string | null }) {
  return audio ? (
    <Badge tone="good" title={audio}>
      <Volume2 className="size-3" /> Recorded voice
    </Badge>
  ) : (
    <Badge title="The phone's text-to-speech voice reads it">
      <Mic className="size-3" /> Phone voice
    </Badge>
  )
}

export function BasicsForm({ doc, change }: { doc: Doc; change: Change }) {
  return (
    <div className="space-y-4">
      <Section title="Level">
        <div className="grid gap-3 sm:grid-cols-2">
          <Field label="Name" hint="Shown on the map and the intro">
            <Input value={doc.name ?? ''} onChange={(e) => change(['name'], e.target.value)} />
          </Field>
          <Field label="Skill" hint="What the child practises">
            <Input value={doc.skill ?? ''} onChange={(e) => change(['skill'], e.target.value)} />
          </Field>
          <Field label="Map icon">
            <Select value={doc.icon ?? ''} onChange={(e) => change(['icon'], e.target.value)}>
              {!LEVEL_ICONS.includes(doc.icon) && <option value={doc.icon}>{doc.icon}</option>}
              {LEVEL_ICONS.map((i) => (
                <option key={i} value={i}>
                  {i.replace(/_/g, ' ')}
                </option>
              ))}
            </Select>
          </Field>
          <Field label="Level id">
            <Input value={doc.id ?? ''} disabled />
          </Field>
        </div>
        <div className="mt-4 grid gap-3 sm:grid-cols-2">
          <Toggle checked={!!doc.isBoss} onChange={(v) => change(['isBoss'], v)} label="Boss level" hint="Wakes the world's boss at the end" />
          <p className="rounded-lg bg-surface-2 px-3 py-2 text-[12px] text-ink-2">
            <b className="font-medium text-ink">Likho Plus:</b> which levels need Plus is set for the whole course in{' '}
            <Link to="/controls?tab=plus" className="font-medium text-brand hover:underline">
              App controls › Likho Plus
            </Link>
            .
          </p>
        </div>
      </Section>
      <Section title="Look" hint="Empty = the app's default. Rounds can override shape and layout.">
        <div className="grid gap-3 sm:grid-cols-3">
          <Field label="Answer shape">
            <Opt value={doc.presentation?.shape} onChange={(v) => change(['presentation', 'shape'], v)} options={SHAPES} />
          </Field>
          <Field label="Pick layout">
            <Opt value={doc.presentation?.layout} onChange={(v) => change(['presentation', 'layout'], v)} options={LAYOUTS} />
          </Field>
          <Field label="Pick stage">
            <Opt value={doc.presentation?.stage} onChange={(v) => change(['presentation', 'stage'], v)} options={STAGES} none="None" />
          </Field>
          <Field label="Order slots">
            <Opt value={doc.presentation?.slot} onChange={(v) => change(['presentation', 'slot'], v)} options={SLOTS} />
          </Field>
        </div>
      </Section>
    </div>
  )
}

export function IntroForm({ doc, change, assets }: { doc: Doc; change: Change; assets: Assets }) {
  const intro = doc.intro ?? {}
  const voice = { voice: ['intro', 'audio'] }
  return (
    <Section title="Intro card" hint="The first screen: big letters, a picture, and what Pencil says.">
      <div className="grid gap-3 sm:grid-cols-2">
        <Field label="Big text" hint='e.g. "B" or "c-a-t"'>
          <Input value={intro.text ?? ''} onChange={(e) => change(['intro', 'text'], e.target.value, voice)} />
        </Field>
        <Field label="Word" hint="What the picture shows">
          <Input value={intro.word ?? ''} onChange={(e) => change(['intro', 'word'], e.target.value, voice)} />
        </Field>
        <Field label="Pencil says" className="sm:col-span-2" hint={<>Write sounds as {'{shown|IPA}'}, e.g. {'{a|ˈeɪ}'} for the letter name.</>}>
          <Input value={intro.say ?? ''} onChange={(e) => change(['intro', 'say'], e.target.value || null, voice)} />
        </Field>
        <PictureField value={intro.picture} onChange={(p) => change(['intro', 'picture'], p)} assets={assets} />
        <div className="flex items-end pb-1">
          <Voice audio={intro.audio} />
        </div>
      </div>
    </Section>
  )
}

function PickEditor({ r, at, change, assets }: { r: Doc; at: (string | number)[]; change: Change; assets: Assets }) {
  const p = r.pick ?? {}
  const options: Doc[] = p.options ?? []
  const anyAnswer = p.answer?.kind === 'any'
  const setOptions = (o: Doc[]) => change([...at, 'pick', 'options'], o)
  return (
    <div className="space-y-3">
      <div className="text-[12.5px] font-medium text-ink-2">Answers</div>
      <div className="space-y-2">
        {options.map((o, k) => {
          const correct = !anyAnswer && p.answer?.value === o.label
          return (
            <div key={k} className={clsx('grid items-end gap-2 rounded-lg border p-2 sm:grid-cols-[auto_1fr_1.4fr_auto_auto]', correct ? 'border-good bg-good-soft/40' : 'border-line')}>
              <label className="flex h-9 cursor-pointer items-center gap-1.5 text-[12.5px]" title="The right answer">
                <input type="radio" disabled={anyAnswer} checked={correct} onChange={() => change([...at, 'pick', 'answer'], { kind: 'label', value: o.label })} className="accent-[var(--good)]" />
                Right
              </label>
              <Field label="Label">
                <Input
                  value={o.label}
                  onChange={(e) => {
                    const next = clone(options)
                    next[k].label = e.target.value
                    setOptions(next)
                    if (correct) change([...at, 'pick', 'answer'], { kind: 'label', value: e.target.value })
                  }}
                />
              </Field>
              <PictureField
                label="Picture"
                value={o.picture}
                assets={assets}
                onChange={(pic) => {
                  const next = clone(options)
                  next[k].picture = pic
                  setOptions(next)
                }}
              />
              <Field label="Colour">
                <Select
                  value={o.color ?? ''}
                  onChange={(e) => {
                    const next = clone(options)
                    next[k].color = e.target.value || null
                    setOptions(next)
                  }}
                >
                  <option value="">—</option>
                  {COLORS.map((c) => (
                    <option key={c}>{c}</option>
                  ))}
                </Select>
              </Field>
              <Button variant="ghost" aria-label="Remove answer" disabled={options.length <= 1} onClick={() => setOptions(options.filter((_, i) => i !== k))} icon={<Trash2 className="size-4" />} />
            </div>
          )
        })}
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <Button size="sm" icon={<Plus className="size-3.5" />} onClick={() => setOptions([...options, { id: '', label: '?', picture: null, color: null, hideLabel: false }])}>
          Add answer
        </Button>
        <Toggle
          checked={anyAnswer}
          onChange={(v) => change([...at, 'pick', 'answer'], v ? { kind: 'any', value: null } : { kind: 'label', value: options[0]?.label ?? '' })}
          label="Any answer is right"
          hint="For choices like “who is in your story?”"
        />
      </div>
      <div className="grid gap-3 sm:grid-cols-3">
        <Field label="Shape (this round)">
          <Opt value={p.shape} onChange={(v) => change([...at, 'pick', 'shape'], v)} options={SHAPES} none="Level's" />
        </Field>
        <Field label="Layout (this round)">
          <Opt value={p.layout} onChange={(v) => change([...at, 'pick', 'layout'], v)} options={LAYOUTS} none="Level's" />
        </Field>
        <Field label="Stage (this round)">
          <Opt value={p.stage} onChange={(v) => change([...at, 'pick', 'stage'], v)} options={STAGES} none="Level's" />
        </Field>
        <Field label="Count (count stage)">
          <Input type="number" min={0} value={p.count ?? ''} onChange={(e) => change([...at, 'pick', 'count'], e.target.value === '' ? null : Number(e.target.value))} />
        </Field>
      </div>
    </div>
  )
}

function WriteEditor({ r, at, change, assets }: { r: Doc; at: (string | number)[]; change: Change; assets: Assets }) {
  const w = r.write ?? {}
  const needsGuide = w.mode === 'trace' || w.mode === 'dots'
  return (
    <div className="grid gap-3 sm:grid-cols-2">
      <Field label="Mode">
        <Select value={w.mode} onChange={(e) => change([...at, 'write', 'mode'], e.target.value)}>
          {WRITE_MODES.map((m) => (
            <option key={m.value} value={m.value}>
              {m.label}
            </option>
          ))}
        </Select>
      </Field>
      <Field label="What to write" hint="Letter, word or sentence">
        <Input value={w.target ?? ''} onChange={(e) => change([...at, 'write', 'target'], e.target.value || null)} />
      </Field>
      {needsGuide && (
        <Field label="Guide" hint="Letter strokes to follow (glyphs.json)">
          <Select value={w.guide ?? ''} onChange={(e) => change([...at, 'write', 'guide'], e.target.value || null)}>
            <option value="">None</option>
            {assets.glyphs.map((g) => (
              <option key={g} value={g}>
                {g}
              </option>
            ))}
          </Select>
        </Field>
      )}
      {(w.mode === 'missing' || w.mode === 'spell') && (
        <>
          <Field label="Word (letter boxes)">
            <Input value={w.word ?? ''} onChange={(e) => change([...at, 'write', 'word'], e.target.value || null)} />
          </Field>
          {w.mode === 'missing' && (
            <Field label="Missing letter (position, from 0)">
              <Input type="number" min={0} value={w.missingIndex ?? ''} onChange={(e) => change([...at, 'write', 'missingIndex'], e.target.value === '' ? null : Number(e.target.value))} />
            </Field>
          )}
        </>
      )}
      {w.mode === 'free' && (
        <div className="flex flex-col gap-2 sm:col-span-2">
          <Toggle checked={!!w.sentence} onChange={(v) => change([...at, 'write', 'sentence'], v)} label="A sentence (wide pad)" />
          <Toggle checked={!!w.story} onChange={(v) => change([...at, 'write', 'story'], v)} label="Story ending (uses earlier choices)" />
        </div>
      )}
    </div>
  )
}

/** A list of rows with add and remove (fix items, sort bins and items, match pairs). */
function Rows({ rows, onChange, blank, render, min = 1, add }: { rows: Doc[]; onChange: (rows: Doc[]) => void; blank: Doc; render: (row: Doc, set: (row: Doc) => void, k: number) => ReactNode; min?: number; add: string }) {
  return (
    <div className="space-y-2">
      {rows.map((row, k) => (
        <div key={k} className="flex items-end gap-2 rounded-lg border border-line p-2">
          <div className="grid flex-1 items-end gap-2 sm:grid-cols-3">
            {render(
              row,
              (next) => {
                const all = clone(rows)
                all[k] = next
                onChange(all)
              },
              k,
            )}
          </div>
          <Button variant="ghost" aria-label="Remove" disabled={rows.length <= min} onClick={() => onChange(rows.filter((_, i) => i !== k))} icon={<Trash2 className="size-4" />} />
        </div>
      ))}
      <Button size="sm" icon={<Plus className="size-3.5" />} onClick={() => onChange([...rows, clone(blank)])}>
        {add}
      </Button>
    </div>
  )
}

const csv = (v: string) => v.split(',').map((s) => s.trim()).filter(Boolean)

function StarEditor({ r, at, change, assets }: { r: Doc; at: (string | number)[]; change: Change; assets: Assets }) {
  switch (r.type) {
    case 'pop':
      return (
        <div className="grid gap-3 sm:grid-cols-3">
          <Field label="Pop the bubbles that say">
            <Input value={r.pop?.target ?? ''} onChange={(e) => change([...at, 'pop', 'target'], e.target.value)} />
          </Field>
          <Field label="Other bubbles say" hint="Separated by commas">
            <Input value={(r.pop?.others ?? []).join(', ')} onChange={(e) => change([...at, 'pop', 'others'], csv(e.target.value))} />
          </Field>
          <Field label="How many to pop" hint="1 to 10">
            <Input type="number" min={1} max={10} value={r.pop?.count ?? 5} onChange={(e) => change([...at, 'pop', 'count'], Number(e.target.value) || 1)} />
          </Field>
        </div>
      )
    case 'fix':
      return (
        <Field label="Pencil's notebook" hint="3 to 12 items; at least one written wrong and one written right">
          <Rows
            rows={r.fix?.items ?? []}
            min={3}
            add="Add item"
            blank={{ text: '?', wrong: null, at: null }}
            onChange={(items) => change([...at, 'fix', 'items'], items)}
            render={(it, set) => (
              <>
                <Field label="Written">
                  <Input value={it.text} onChange={(e) => set({ ...it, text: e.target.value })} />
                </Field>
                <Field label="Wrong?">
                  <Select value={it.wrong ?? ''} onChange={(e) => set({ ...it, wrong: e.target.value || null })}>
                    <option value="">Right</option>
                    <option value="mirror">Backwards</option>
                    <option value="upside">Upside down</option>
                  </Select>
                </Field>
                <Field label="Only letter (from 0)" hint="Empty = all of it">
                  <Input type="number" min={0} value={it.at ?? ''} onChange={(e) => set({ ...it, at: e.target.value === '' ? null : Number(e.target.value) })} />
                </Field>
              </>
            )}
          />
        </Field>
      )
    case 'sort': {
      const bins: Doc[] = r.sort?.bins ?? []
      return (
        <div className="space-y-3">
          <Field label="Bins" hint="One bin = the hungry monster (things without a bin are not its food); two or three = baskets">
            <Rows
              rows={bins}
              add="Add bin"
              blank={{ label: '?', picture: null, bin: null }}
              onChange={(next) => change([...at, 'sort', 'bins'], next.slice(0, 3))}
              render={(b, set) => (
                <>
                  <Field label="Sign">
                    <Input value={b.label} onChange={(e) => set({ ...b, label: e.target.value })} />
                  </Field>
                  <PictureField label="Sign picture" value={b.picture} assets={assets} onChange={(pic) => set({ ...b, picture: pic })} />
                </>
              )}
            />
          </Field>
          <Field label="Things to sort" hint="A thing shows its picture, or its label when it has none">
            <Rows
              rows={r.sort?.items ?? []}
              min={2}
              add="Add thing"
              blank={{ label: '?', picture: null, bin: 0 }}
              onChange={(items) => change([...at, 'sort', 'items'], items)}
              render={(it, set) => (
                <>
                  <Field label="Label">
                    <Input value={it.label} onChange={(e) => set({ ...it, label: e.target.value })} />
                  </Field>
                  <PictureField label="Picture" value={it.picture} assets={assets} onChange={(pic) => set({ ...it, picture: pic })} />
                  <Field label="Goes in">
                    <Select value={it.bin ?? ''} onChange={(e) => set({ ...it, bin: e.target.value === '' ? null : Number(e.target.value) })}>
                      {bins.length === 1 && <option value="">Not food</option>}
                      {bins.map((b, k) => (
                        <option key={k} value={k}>
                          {b.label || `Bin ${k + 1}`}
                        </option>
                      ))}
                    </Select>
                  </Field>
                </>
              )}
            />
          </Field>
        </div>
      )
    }
    case 'match':
      return (
        <Field label="Pairs" hint="2 to 6 pairs; each card shows its text, or its picture">
          <Rows
            rows={r.match?.pairs ?? []}
            min={2}
            add="Add pair"
            blank={{ a: { text: '?', picture: null }, b: { text: '?', picture: null } }}
            onChange={(pairs) => change([...at, 'match', 'pairs'], pairs.slice(0, 6))}
            render={(pr, set) => (
              <>
                <Field label="Card 1 text">
                  <Input value={pr.a?.text ?? ''} onChange={(e) => set({ ...pr, a: { ...pr.a, text: e.target.value || null } })} />
                </Field>
                <Field label="Card 2 text">
                  <Input value={pr.b?.text ?? ''} onChange={(e) => set({ ...pr, b: { ...pr.b, text: e.target.value || null } })} />
                </Field>
                <PictureField label="Card 2 picture" value={pr.b?.picture} assets={assets} onChange={(pic) => set({ ...pr, b: { ...pr.b, picture: pic } })} />
              </>
            )}
          />
        </Field>
      )
    case 'truth':
      return (
        <div className="grid gap-3 sm:grid-cols-3">
          <Field label="Sentence">
            <Input value={r.truth?.text ?? ''} onChange={(e) => change([...at, 'truth', 'text'], e.target.value)} />
          </Field>
          <PictureField label="Picture" value={r.truth?.picture} assets={assets} onChange={(pic) => change([...at, 'truth', 'picture'], pic)} />
          <Field label="The answer">
            <Select value={r.truth?.answer ? 'true' : 'false'} onChange={(e) => change([...at, 'truth', 'answer'], e.target.value === 'true')}>
              <option value="true">True</option>
              <option value="false">Silly</option>
            </Select>
          </Field>
        </div>
      )
    case 'sounds': {
      const s = r.sounds ?? {}
      const parts: Doc[] = s.parts ?? []
      const choices: Doc[] = s.choices ?? []
      return (
        <div className="space-y-3">
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="Word">
              <Input value={s.word ?? ''} onChange={(e) => change([...at, 'sounds', 'word'], e.target.value)} />
            </Field>
            <Field label="Pencil reads it" hint="When the child slides under the word">
              <Input value={s.blend?.say ?? s.blend?.text ?? ''} onChange={(e) => change([...at, 'sounds', 'blend'], { text: s.word ?? e.target.value, say: e.target.value })} />
            </Field>
          </div>
          <Field label="Sounds, in order" hint="Their letters spell the word (sh, ee and doubled letters are one sound). Pencil says each: write it {/sh/|ʃːː}, then record it with tools/voice.">
            <Rows
              rows={parts}
              min={1}
              add="Add sound"
              blank={{ text: '?', say: null }}
              onChange={(next) => change([...at, 'sounds', 'parts'], next.slice(0, 6))}
              render={(pt, set) => (
                <>
                  <Field label="Letters">
                    <Input value={pt.text} onChange={(e) => set({ ...pt, text: e.target.value })} />
                  </Field>
                  <Field label="Pencil says">
                    <Input value={pt.say ?? ''} placeholder="{/c/|kʌ}" onChange={(e) => set({ ...pt, say: e.target.value || null })} />
                  </Field>
                </>
              )}
            />
          </Field>
          <Field label="Pictures to choose from" hint="2 to 4; the word's picture is one of them">
            <Rows
              rows={choices}
              min={2}
              add="Add picture"
              blank={{ label: '?', picture: null }}
              onChange={(next) => change([...at, 'sounds', 'choices'], next.slice(0, 4))}
              render={(c, set) => (
                <>
                  <Field label="Word">
                    <Input value={c.label} onChange={(e) => set({ ...c, label: e.target.value })} />
                  </Field>
                  <PictureField label="Picture" value={c.picture} assets={assets} onChange={(pic) => set({ ...c, picture: pic })} />
                </>
              )}
            />
          </Field>
          <Field label="The right picture">
            <Select value={s.answer ?? 0} onChange={(e) => change([...at, 'sounds', 'answer'], Number(e.target.value))}>
              {choices.map((c, i) => (
                <option key={i} value={i}>
                  {c.label || `Picture ${i + 1}`}
                </option>
              ))}
            </Select>
          </Field>
        </div>
      )
    }
    case 'beats': {
      const b = r.beats ?? {}
      return (
        <div className="grid gap-3 sm:grid-cols-2">
          <Field label="Word or sentence">
            <Input value={b.text ?? ''} onChange={(e) => change([...at, 'beats', 'text'], e.target.value)} />
          </Field>
          <Field label="Beats" hint="Syllables (ap-ple) or words, separated by - or spaces; 1 to 8">
            <Input
              value={(b.parts ?? []).join(b.unit === 'word' ? ' ' : '-')}
              onChange={(e) => change([...at, 'beats', 'parts'], e.target.value.split(b.unit === 'word' ? /\s+/ : /[-\s]+/).map((x) => x.trim()).filter(Boolean))}
            />
          </Field>
          <Field label="A beat for each">
            <Select value={b.unit ?? 'syllable'} onChange={(e) => change([...at, 'beats', 'unit'], e.target.value)}>
              <option value="syllable">Syllable (ap-ple)</option>
              <option value="word">Word (I see a cat)</option>
            </Select>
          </Field>
          <PictureField label="Picture" value={b.picture} assets={assets} onChange={(pic) => change([...at, 'beats', 'picture'], pic)} />
          <Field label="Hint after a wrong count" hint="What Pencil says, e.g. Apple. Two beats!">
            <Input
              value={b.hint?.say ?? b.hint?.text ?? ''}
              onChange={(e) => change([...at, 'beats', 'hint'], e.target.value ? { text: (b.parts ?? []).join('-') || e.target.value, say: e.target.value } : null)}
            />
          </Field>
        </div>
      )
    }
    case 'connect': {
      const c = r.connect ?? {}
      const labels: string[] = c.labels ?? []
      const shape = Object.keys(DOT_SHAPES).find((k) => JSON.stringify(DOT_SHAPES[k]) === JSON.stringify(c.points)) ?? ''
      const pickShape = (k: string) => {
        const pts = DOT_SHAPES[k]
        const abc = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        const start = Math.max(0, Math.min(abc.indexOf(labels[0] ?? 'A'), 26 - pts.length))
        const lower = labels[0] != null && labels[0] === labels[0].toLowerCase()
        const next = abc.slice(start, start + pts.length).split('').map((x) => (lower ? x.toLowerCase() : x))
        const art = /^[aeiou]/.test(k) ? 'an' : 'a'
        change([...at, 'connect'], { ...c, labels: next, points: pts, picture: { key: k, label: k, url: null }, done: { text: `${art[0].toUpperCase()}${art.slice(1)} ${k}!`, say: `It's ${art} ${k}!` } })
      }
      return (
        <div className="grid gap-3 sm:grid-cols-2">
          <Field label="Picture the dots make" hint="Sets the dots, their letters (from the first label) and the picture">
            <Select value={shape} onChange={(e) => pickShape(e.target.value)}>
              {!shape && <option value="">Custom (JSON)</option>}
              {Object.keys(DOT_SHAPES).map((k) => (
                <option key={k} value={k}>
                  {k} ({DOT_SHAPES[k].length} dots)
                </option>
              ))}
            </Select>
          </Field>
          <Field label="Letters, in order" hint={`One per dot (${(c.points ?? []).length}), separated by commas`}>
            <Input value={labels.join(', ')} onChange={(e) => change([...at, 'connect', 'labels'], csv(e.target.value))} />
          </Field>
          <Field label="Pencil says when it is done">
            <Input value={c.done?.say ?? c.done?.text ?? ''} onChange={(e) => change([...at, 'connect', 'done'], e.target.value ? { text: e.target.value, say: e.target.value } : null)} />
          </Field>
        </div>
      )
    }
    default:
      return null
  }
}

function RoundCard({ r, i, count, change, move, remove, duplicate, assets }: { r: Doc; i: number; count: number; change: Change; move: (d: number) => void; remove: () => void; duplicate: () => void; assets: Assets }) {
  const at = ['rounds', i]
  const voice = { voice: [...at, 'prompt', 'audio'] }
  return (
    <section className="rounded-xl border border-line bg-surface">
      <div className="flex flex-wrap items-center gap-2 border-b border-line px-4 py-2.5">
        <span className="tabular grid size-6 place-items-center rounded-full bg-brand-soft text-[12px] font-bold text-brand-ink">{i + 1}</span>
        <Select value={r.type} onChange={(e) => change(at, withType(r, e.target.value))} className="h-8 w-auto text-[12.5px]" aria-label="Round type">
          {ROUND_TYPES.map((t) => (
            <option key={t.value} value={t.value}>
              {t.label}: {t.hint}
            </option>
          ))}
        </Select>
        <span className="flex-1 truncate text-[12px] text-ink-3">{r.id}</span>
        <Button size="sm" variant="ghost" aria-label="Move up" disabled={i === 0} onClick={() => move(-1)} icon={<ArrowUp className="size-4" />} />
        <Button size="sm" variant="ghost" aria-label="Move down" disabled={i === count - 1} onClick={() => move(1)} icon={<ArrowDown className="size-4" />} />
        <Button size="sm" variant="ghost" aria-label="Duplicate round" onClick={duplicate} icon={<Copy className="size-4" />} />
        <Button size="sm" variant="ghost" aria-label="Delete round" disabled={count <= 1} onClick={remove} icon={<Trash2 className="size-4" />} />
      </div>
      <div className="space-y-4 p-4">
        <div className="grid gap-3 sm:grid-cols-2">
          <Field label="Instruction on screen">
            <Input value={r.prompt?.text ?? ''} onChange={(e) => change([...at, 'prompt', 'text'], e.target.value, voice)} />
          </Field>
          <Field label="Pencil says (if different)" hint={<Voice audio={r.prompt?.audio} />}>
            <Input value={r.prompt?.say ?? ''} placeholder="Same as the instruction" onChange={(e) => change([...at, 'prompt', 'say'], e.target.value || null, voice)} />
          </Field>
          <Field label="Card text" hint="Shown on the white card next to Pencil">
            <Input value={r.card?.text ?? ''} onChange={(e) => change([...at, 'card', 'text'], e.target.value || null)} />
          </Field>
          <PictureField label="Card picture" value={r.card?.picture} onChange={(p) => change([...at, 'card', 'picture'], p)} assets={assets} />
          <Toggle checked={!!r.card?.listen} onChange={(v) => change([...at, 'card', 'listen'], v)} label="Listen button on the card" />
        </div>
        <div className="border-t border-line pt-4">
          {r.type === 'pick' && <PickEditor r={r} at={at} change={change} assets={assets} />}
          {r.type === 'write' && <WriteEditor r={r} at={at} change={change} assets={assets} />}
          {r.type === 'order' && (
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label="Tiles, in the right order" hint="Separated by commas; the app shuffles them">
                <Input value={(r.order?.tiles ?? []).join(', ')} onChange={(e) => change([...at, 'order', 'tiles'], e.target.value.split(',').map((s) => s.trim()).filter(Boolean))} />
              </Field>
              <Field label="Slots (this round)">
                <Opt value={r.order?.slot} onChange={(v) => change([...at, 'order', 'slot'], v)} options={SLOTS} none="Level's" />
              </Field>
            </div>
          )}
          {r.type === 'hunt' && (
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label="Letter to find">
                <Input value={r.hunt?.target ?? ''} onChange={(e) => change([...at, 'hunt', 'target'], e.target.value)} />
              </Field>
              <Field label="Grid, in reading order" hint="4 to 16 letters separated by commas; include the letter at least once">
                <Input value={(r.hunt?.grid ?? []).join(', ')} onChange={(e) => change([...at, 'hunt', 'grid'], e.target.value.split(',').map((s) => s.trim()).filter(Boolean))} />
              </Field>
            </div>
          )}
          <StarEditor r={r} at={at} change={change} assets={assets} />
        </div>
      </div>
    </section>
  )
}

export function RoundsForm({ doc, change, assets }: { doc: Doc; change: Change; assets: Assets }) {
  const rounds: Doc[] = doc.rounds ?? []
  const [adding, setAdding] = useState('pick')
  const set = (next: Doc[]) => change(['rounds'], next)
  return (
    <div className="space-y-3">
      {rounds.map((r, i) => (
        <RoundCard
          key={i}
          r={r}
          i={i}
          count={rounds.length}
          assets={assets}
          change={change}
          move={(d) => {
            const next = clone(rounds)
            ;[next[i], next[i + d]] = [next[i + d], next[i]]
            set(next)
          }}
          remove={() => set(rounds.filter((_, k) => k !== i))}
          duplicate={() => {
            const copy = clone(r)
            if (copy.prompt) delete copy.prompt.audio
            set([...rounds.slice(0, i + 1), copy, ...rounds.slice(i + 1)])
          }}
        />
      ))}
      <div className="flex items-center gap-2 rounded-xl border border-dashed border-line-strong p-3">
        <Select value={adding} onChange={(e) => setAdding(e.target.value)} className="w-auto" aria-label="New round type">
          {ROUND_TYPES.map((t) => (
            <option key={t.value} value={t.value}>
              {t.label}: {t.hint}
            </option>
          ))}
        </Select>
        <Button icon={<Plus className="size-4" />} onClick={() => set([...rounds, blankRound(adding)])}>
          Add round
        </Button>
        <span className="ml-auto text-[12px] text-ink-3">{rounds.length} rounds</span>
      </div>
    </div>
  )
}

/** Applies a form change; changing spoken words drops the old recording
 *  (it says the old words), so the phone's voice reads the new ones. */
export function applyChange(doc: Doc, path: (string | number)[], value: unknown, voice?: (string | number)[]): Doc {
  let d = setIn(doc, path, value)
  if (voice && getIn(d, voice)) {
    const parent = getIn(d, voice.slice(0, -1)) as any
    if (parent) {
      d = clone(d)
      delete (getIn(d, voice.slice(0, -1)) as any)[voice[voice.length - 1]]
    }
  }
  return d
}
