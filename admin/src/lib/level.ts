// A level document (backend/content/schema/level.schema.json) and the
// helpers the editor uses on it. Unknown fields are kept as they are.

/* eslint-disable @typescript-eslint/no-explicit-any */
export type Doc = Record<string, any>

export const SHAPES = ['card', 'balloon', 'bubble', 'kite', 'fish', 'mushroom', 'shell', 'pad', 'basket', 'jar', 'bucket', 'cloud', 'planet']
export const SLOTS = ['wagon', 'plank', 'stripe', 'panel']
export const LAYOUTS = ['field', 'patient', 'flow', 'alien']
export const STAGES = ['house', 'count', 'stars']
export const WRITE_MODES: { value: string; label: string }[] = [
  { value: 'trace', label: 'Trace the guide' },
  { value: 'dots', label: 'Join the dots' },
  { value: 'free', label: 'Write it freely' },
  { value: 'flash', label: 'Look, then write from memory' },
  { value: 'missing', label: 'Fill the missing letter' },
  { value: 'spell', label: 'Spell the word' },
]
export const COLORS = ['red', 'blue', 'yellow', 'green', 'purple']
export const ROUND_TYPES: { value: string; label: string; hint: string }[] = [
  { value: 'pick', label: 'Pick', hint: 'Tap the right answer' },
  { value: 'write', label: 'Write', hint: 'Write on the pad' },
  { value: 'order', label: 'Order', hint: 'Put tiles in order' },
  { value: 'hunt', label: 'Letter hunt', hint: 'Tap every matching letter' },
  { value: 'pop', label: 'Bubble pop', hint: 'Pop the bubbles that say it' },
  { value: 'fix', label: "Fix Pencil's mistakes", hint: 'Tap what is written backwards' },
  { value: 'sort', label: 'Sort', hint: 'Feed the monster, or fill the baskets' },
  { value: 'match', label: 'Memory match', hint: 'Find the pairs' },
  { value: 'truth', label: 'True or silly', hint: 'Is the sentence true?' },
  { value: 'sounds', label: 'Sound buttons', hint: 'Tap each sound, read the word, pick its picture' },
  { value: 'beats', label: 'Clap the beats', hint: 'Tap the drum once for every beat' },
  { value: 'connect', label: 'Connect the dots', hint: 'Join the letters in ABC order' },
]

/** Round types with a payload object of the same name. */
export const PAYLOADS = ['pick', 'write', 'order', 'hunt', 'pop', 'fix', 'sort', 'match', 'truth', 'sounds', 'beats', 'connect']

/** Connect-the-dots outlines (tools/curriculum/build_levels.py SHAPES): each
 *  has a picture of the same name; x, y from 0 to 100. */
export const DOT_SHAPES: Record<string, [number, number][]> = { "star": [[50, 4], [62, 36], [96, 37], [69, 58], [78, 91], [50, 72], [22, 91], [31, 58], [4, 37], [38, 36]], "sun": [[50, 3], [66, 22], [91, 27], [82, 50], [91, 74], [66, 78], [50, 97], [34, 78], [9, 74], [18, 50], [9, 26], [34, 22]], "house": [[50, 4], [95, 42], [80, 94], [50, 94], [20, 94], [5, 42]], "boat": [[50, 4], [82, 50], [98, 64], [80, 94], [20, 94], [2, 64], [50, 64]], "crown": [[6, 28], [30, 54], [50, 10], [70, 54], [94, 28], [84, 88], [16, 88]], "kite": [[50, 3], [88, 38], [69, 68], [50, 97], [31, 68], [12, 38]], "cup": [[8, 8], [78, 8], [78, 30], [98, 30], [98, 66], [78, 66], [72, 94], [14, 94]], "cake": [[8, 44], [40, 44], [40, 10], [60, 10], [60, 44], [92, 44], [92, 94], [8, 94]], "fish": [[6, 50], [30, 24], [56, 22], [76, 36], [96, 16], [96, 84], [76, 64], [56, 78], [30, 76]], "moon": [[62, 4], [30, 10], [10, 36], [8, 64], [28, 88], [62, 96], [44, 74], [36, 50], [44, 26]], "tree": [[50, 2], [80, 36], [60, 36], [88, 66], [60, 66], [60, 96], [40, 96], [40, 66], [12, 66], [40, 36], [20, 36]], "umbrella": [[50, 4], [88, 20], [98, 50], [64, 46], [50, 96], [36, 46], [2, 50], [12, 20]], "balloon": [[50, 4], [76, 14], [88, 38], [78, 62], [60, 78], [66, 96], [34, 96], [40, 78], [22, 62], [12, 38], [24, 14]], "apple": [[50, 22], [66, 12], [86, 22], [92, 48], [82, 76], [68, 94], [50, 84], [32, 94], [18, 76], [8, 48], [14, 22], [34, 12]] }

const pic = (key: string) => ({ key, label: key, url: null })

/** Icons the app has (app/lib/design/icon_registry.dart); others show a star. */
export const LEVEL_ICONS = [
  'celebration', 'train', 'directions_railway', 'route', 'phishing', 'bedtime', 'spa', 'beach_access', 'bubble_chart', 'shopping_basket', 'mail', 'pets',
  'linear_scale', 'visibility', 'emoji_objects', 'format_paint', 'directions_bus', 'medical_services', 'cake', 'photo_library', 'air', 'flutter_dash', 'looks',
  'edit', 'public', 'record_voice_over', 'view_carousel', 'auto_awesome', 'auto_stories', 'dark_mode', 'self_improvement', 'grass', 'waves', 'forest',
  'location_city', 'cloud', 'rocket_launch',
  'landscape', 'local_florist', 'directions_run', 'help', 'menu_book', 'graphic_eq', 'sailing', 'restaurant', 'backpack', 'space_bar', 'fiber_manual_record', 'filter_none', 'edit_note', 'sports_soccer', 'zoom_out_map', 'swap_horiz', 'person', 'category', 'place', 'calendar_month', 'question_answer', 'check_circle', 'music_note', 'format_list_numbered', 'map', 'face', 'family_restroom', 'wb_sunny', 'egg',
]

export const pad2 = (n: number) => String(n).padStart(2, '0')

export function clone<T>(v: T): T {
  return JSON.parse(JSON.stringify(v))
}

/** Ids follow the content's pattern: <level>-r<n> for rounds and
 *  <round>-o<n> for options (unique across the course). */
export function normalize(doc: Doc, number: number, levelId?: string): Doc {
  const d = clone(doc)
  delete d.$schema
  d.number = number
  if (levelId) d.id = levelId
  d.rounds = (d.rounds ?? []).map((r: Doc, i: number) => {
    const id = `${d.id}-r${i + 1}`
    const out: Doc = { ...r, id }
    if (out.pick?.options) out.pick = { ...out.pick, options: out.pick.options.map((o: Doc, k: number) => ({ ...o, id: `${id}-o${k + 1}` })) }
    return out
  })
  return d
}

/** A copy of [source] as a new level: new number and ids, no recordings
 *  (they say the old words). */
export function asNewLevel(source: Doc, number: number): Doc {
  const d = clone(source)
  d.name = `${d.name} (new)`
  d.isBoss = false
  stripAudio(d)
  return normalize(d, number, `level-${pad2(number)}`)
}

export function stripAudio(d: Doc) {
  if (d.intro) delete d.intro.audio
  for (const r of d.rounds ?? []) {
    // the prompt and the lines said inside a game
    for (const line of [r.prompt, ...(r.sounds?.parts ?? []), r.sounds?.blend, r.beats?.hint, r.connect?.done]) if (line) delete line.audio
  }
}

export function blankRound(type: string): Doc {
  const base: Doc = { id: '', type, prompt: { text: '' }, card: { text: null, picture: null, listen: false } }
  switch (type) {
    case 'pick':
      return {
        ...base,
        prompt: { text: 'Find B!' },
        card: { text: 'B', picture: null, listen: false },
        pick: {
          options: ['B', 'D', 'P'].map((label) => ({ id: '', label, picture: null, color: null, hideLabel: false })),
          answer: { kind: 'label', value: 'B' },
          shape: null,
          layout: null,
          count: null,
          choiceKey: null,
          fixCapital: false,
        },
      }
    case 'write':
      return { ...base, prompt: { text: 'Trace B!' }, card: { text: 'B', picture: null, listen: false }, write: { mode: 'trace', target: 'B', guide: 'B', word: null, missingIndex: null, sentence: false, story: false } }
    case 'order':
      return { ...base, prompt: { text: 'Put the letters in order!' }, card: { text: null, picture: null, listen: false }, order: { tiles: ['c', 'a', 't'] } }
    case 'hunt':
      return { ...base, prompt: { text: 'Find every B!' }, card: { text: 'B', picture: null, listen: false }, hunt: { target: 'B', grid: ['B', 'D', 'P', 'B', 'R', 'E', 'B', 'D', 'P'] } }
    case 'pop':
      return { ...base, prompt: { text: 'Pop every B!' }, card: { text: 'B', picture: null, listen: false }, pop: { target: 'B', others: ['D', 'P', 'R'], count: 5 } }
    case 'fix':
      return {
        ...base,
        prompt: { text: "Fix Pencil's mistakes!" },
        card: { text: 'B', picture: null, listen: false },
        fix: { items: ['B', 'B', 'B', 'B', 'B', 'B'].map((text, i) => ({ text, wrong: i === 1 || i === 4 ? 'mirror' : null, at: null })) },
      }
    case 'sort':
      return {
        ...base,
        prompt: { text: 'Feed it /b/!' },
        card: { text: 'b', picture: null, listen: false },
        sort: {
          bins: [{ label: 'b', picture: null, bin: null }],
          items: [
            { label: 'ball', picture: { key: 'ball', label: 'ball', url: null }, bin: 0 },
            { label: 'bed', picture: { key: 'bed', label: 'bed', url: null }, bin: 0 },
            { label: 'sun', picture: { key: 'sun', label: 'sun', url: null }, bin: null },
          ],
        },
      }
    case 'match':
      return {
        ...base,
        prompt: { text: 'Find the pairs!' },
        card: { text: null, picture: null, listen: false },
        match: { pairs: ['A', 'B', 'C'].map((c) => ({ a: { text: c, picture: null }, b: { text: c.toLowerCase(), picture: null } })) },
      }
    case 'truth':
      return { ...base, prompt: { text: 'True or silly?' }, card: { text: null, picture: null, listen: true }, truth: { text: 'The cat can fly.', picture: { key: 'cat', label: 'cat', url: null }, answer: false } }
    case 'sounds':
      return {
        ...base,
        prompt: { text: 'Tap each sound, then read!' },
        card: { text: null, picture: null, listen: false },
        sounds: {
          word: 'cat',
          parts: [
            { text: 'c', say: '{/c/|kʌ}' },
            { text: 'a', say: '{/a/|æ}' },
            { text: 't', say: '{/t/|tʌ}' },
          ],
          blend: { text: 'cat', say: 'cat!' },
          choices: [{ label: 'cat', picture: pic('cat') }, { label: 'dog', picture: pic('dog') }, { label: 'sun', picture: pic('sun') }],
          answer: 0,
        },
      }
    case 'beats':
      return {
        ...base,
        prompt: { text: 'Clap the beats!', say: 'Apple! Tap the drum for every beat in apple.' },
        card: { text: null, picture: null, listen: true },
        beats: { text: 'apple', parts: ['ap', 'ple'], unit: 'syllable', picture: pic('apple'), hint: { text: 'ap-ple', say: 'Apple. Two beats!' } },
      }
    case 'connect':
      return {
        ...base,
        prompt: { text: 'Join A to J!', say: 'Join the dots, from {A|ˈeɪ} to {J|ʤˈeɪ}. What will it be?' },
        card: { text: null, picture: null, listen: false },
        connect: { labels: 'ABCDEFGHIJ'.split(''), points: DOT_SHAPES.star, picture: pic('star'), done: { text: 'A star!', say: "It's a star!" } },
      }
    default:
      return blankRound('pick')
  }
}

/** Changing a round's type keeps its prompt and card. */
export function withType(r: Doc, type: string): Doc {
  const fresh = blankRound(type)
  const out: Doc = { ...r, type }
  for (const t of PAYLOADS) delete out[t]
  out[type] = fresh[type]
  return out
}

/** Sets a value at a dotted path, creating objects on the way. */
export function setIn(doc: Doc, path: (string | number)[], value: unknown): Doc {
  const d = clone(doc)
  let cur: any = d
  for (let i = 0; i < path.length - 1; i++) {
    if (cur[path[i]] == null) cur[path[i]] = typeof path[i + 1] === 'number' ? [] : {}
    cur = cur[path[i]]
  }
  cur[path[path.length - 1]] = value
  return d
}

export function getIn(doc: Doc, path: (string | number)[]): any {
  return path.reduce<any>((cur, k) => (cur == null ? undefined : cur[k]), doc)
}

/** Same level, whatever the key order (and without the editor-only
 *  "$schema" line). */
export function sameJSON(a: string | Doc | null | undefined, b: string | Doc | null | undefined) {
  const canon = (v: unknown): unknown =>
    Array.isArray(v) ? v.map(canon) : v && typeof v === 'object' ? Object.fromEntries(Object.keys(v).filter((k) => k !== '$schema').sort().map((k) => [k, canon((v as Doc)[k])])) : v
  const norm = (x: string | Doc | null | undefined) => {
    if (x == null) return ''
    try {
      return JSON.stringify(canon(typeof x === 'string' ? JSON.parse(x) : x))
    } catch {
      return String(x)
    }
  }
  return norm(a) === norm(b)
}

export function pretty(d: Doc) {
  return JSON.stringify(d, null, 2) + '\n'
}
