// App controls (GET/PUT /controls): what the team switches on and off in
// the app. Mirrors backend/internal/domain/controls.go.

export type Mode = 'off' | 'on' | 'plus' | 'chosen'

export type ItemControl = { hidden: boolean; price: number }
export type Notice = { on: boolean; title: string; text: string }

export type TabId = 'map' | 'stories' | 'games' | 'parents'
export type TabStyle = 'candy' | 'jelly' | 'island'
export type TabAnimation = 'bounce' | 'slide' | 'pop' | 'none'
export type TabSpeed = 'slow' | 'normal' | 'fast'
export type TabSurface = 'white' | 'glass' | 'colour'
export type TabControl = { id: TabId; shown: boolean; label: string; color: string; badge: boolean }
export type TabBar = {
  style: TabStyle
  animation: TabAnimation
  speed: TabSpeed
  wiggle: boolean
  surface: TabSurface
  barColor: string
  floating: boolean
  roundness: number
  labels: boolean
  start: TabId
  tabs: TabControl[]
}

export type Controls = {
  features: Record<string, Mode>
  stories: { comingSoon: boolean; episodes: Record<string, Mode> }
  room: { items: Record<string, ItemControl> }
  games: Record<string, boolean>
  pencilColors: string[]
  billing: {
    enabled: boolean
    freeLevels: number
    guestLevels: number
    trialLevels: number
    serverTrial: boolean
    trialDays: number
    monthly: boolean
    yearly: boolean
    bestValue: '' | 'monthly' | 'yearly'
    benefits: string[]
    freeForAllUntil: string
  }
  app: { minVersion: string; maintenance: Notice; parentMessage: Notice }
  tabBar: TabBar
}

export type SavedControls = { controls: Controls; revision: number; updatedAt: string | null; updatedBy: string }

export type ControlsMeta = {
  features: { id: string; modes: Mode[] }[]
  episodes: { ID: string; Letter: string; Title: string }[]
  items: { id: string; price: number; wear: boolean }[]
  games: string[]
  colors: string[]
  lastLevel: number
  defaults: Controls
  families: { key: string; on: boolean; count: number }[]
}

export type FamilySwitch = { key: string; mode: Mode; own: boolean | null }

// ------------------------------------------------------------ words

export const modeInfo: Record<Mode, { label: string; short: string; hint: string }> = {
  off: { label: 'Off', short: 'Off', hint: 'Nobody sees it' },
  on: { label: 'Everyone', short: 'On', hint: 'Every family' },
  plus: { label: 'Likho Plus', short: 'Plus', hint: 'Families with Plus; others see the paywall' },
  chosen: { label: 'Chosen families', short: 'Chosen', hint: "Only families you turn it on for (on a family's page)" },
}

export type FeatureInfo = { title: string; text: string; tone: Tone; warn?: string }
export type Tone = 'violet' | 'blue' | 'green' | 'amber' | 'pink' | 'teal' | 'slate'

export const featureInfo: Record<string, FeatureInfo> = {
  stories: { title: 'Stories', text: 'The Stories button on the map and the story episodes.', tone: 'blue' },
  games: { title: 'Games', text: 'The Games button on the map: Monster Defense, practising the letters and words the child has learned.', tone: 'violet' },
  room: { title: "Pencil's room", text: 'The Mascot Room: spend stars on clothes and furniture.', tone: 'amber' },
  stickers: { title: 'Sticker book', text: 'The sticker book on the child’s profile.', tone: 'pink' },
  certificate: { title: 'Certificate', text: 'The certificate after the last level of the course.', tone: 'violet' },
  placement: { title: 'Warm-up', text: 'The short warm-up after adding a child and on “Try it first”.', tone: 'teal' },
  guest: { title: 'Try it first', text: 'Playing without an account (“Not now, try it first” on Welcome).', tone: 'green' },
  sfx: { title: 'Sound effects', text: 'Taps, stars, cheers and game sounds. Parents can still turn them off for their family.', tone: 'blue' },
  voice: {
    title: "Pencil's voice",
    text: 'Pencil reads the instructions out loud. Off: he only shows speech bubbles.',
    tone: 'violet',
    warn: 'Children who cannot read yet need the voice to know what to do.',
  },
  haptics: { title: 'Vibration', text: 'Little buzzes for answers and rewards. Parents can still turn it off.', tone: 'slate' },
}

export const gameInfo: Record<string, { title: string; text: string }> = {
  pick: { title: 'Pick', text: 'Tap the right answer' },
  order: { title: 'Order', text: 'Put letters in order' },
  sounds: { title: 'Sounds', text: 'Hear a sound, find its letter' },
  beats: { title: 'Beats', text: 'Clap the parts of a word' },
  connect: { title: 'Connect', text: 'Join the dots' },
  hunt: { title: 'Hunt', text: 'Find letters in a picture' },
  fix: { title: 'Fix it', text: 'Mend mirrored letters' },
  sort: { title: 'Sort', text: 'Sort into baskets' },
  match: { title: 'Match', text: 'Match the pairs' },
  pop: { title: 'Pop', text: 'Pop the right bubbles' },
  truth: { title: 'True or false', text: 'Is it right?' },
}

export const itemInfo: Record<string, { name: string; emoji: string }> = {
  party: { name: 'Party hat', emoji: '🥳' },
  cap: { name: 'Cap', emoji: '🧢' },
  wizard: { name: 'Wizard hat', emoji: '🧙' },
  round: { name: 'Round glasses', emoji: '👓' },
  stars: { name: 'Star glasses', emoji: '🤩' },
  scarf: { name: 'Scarf', emoji: '🧣' },
  cape: { name: 'Cape', emoji: '🦸' },
  crown: { name: 'Crown', emoji: '👑' },
  phones: { name: 'Headphones', emoji: '🎧' },
  bow: { name: 'Bow', emoji: '🎀' },
  lamp: { name: 'Lamp', emoji: '💡' },
  poster: { name: 'Poster', emoji: '🖼️' },
  plant: { name: 'Plant', emoji: '🪴' },
  rug: { name: 'Rug', emoji: '🟣' },
}

export const tabInfo: Record<TabId, { title: string; art: string; text: string }> = {
  map: { title: 'Map', art: '🪧', text: 'The level path. Always in the bar.' },
  stories: { title: 'Stories', art: '🍎', text: 'Shows while the Stories switch is on.' },
  games: { title: 'Games', art: '👾', text: 'Shows while the Games switch is on.' },
  parents: { title: 'Parents', art: '🔒', text: 'Opens the parent gate, then the dashboard.' },
}

/** Colours to pick from for the tabs and the bar (the app's own). */
export const tabSwatches = ['#FFC83D', '#FF8A5B', '#FF6FA8', '#7C5CFF', '#4D9DE0', '#2EC4B6', '#3BB273', '#2B2D42']

export const colorNames: Record<string, string> = {
  '#FFC83D': 'Sunny yellow',
  '#4D9DE0': 'Sky blue',
  '#3BB273': 'Leaf green',
  '#FF8A5B': 'Coral',
  '#B79CED': 'Lilac',
  '#FF9EB5': 'Pink',
}

// ------------------------------------------------------------ helpers

export const clone = <T,>(v: T): T => JSON.parse(JSON.stringify(v)) as T

/** Which parts differ (the save bar and tab dots). */
export function changedParts(a: Controls, b: Controls): Set<string> {
  const out = new Set<string>()
  const diff = (x: unknown, y: unknown) => JSON.stringify(x) !== JSON.stringify(y)
  for (const id of new Set([...Object.keys(a.features), ...Object.keys(b.features)])) {
    if (a.features[id] !== b.features[id]) out.add(`feature:${id}`)
  }
  if (diff(a.stories, b.stories)) out.add('stories')
  if (diff(a.room, b.room)) out.add('room')
  if (diff(a.games, b.games)) out.add('games')
  if (diff(a.pencilColors, b.pencilColors)) out.add('colors')
  if (diff(a.billing, b.billing)) out.add('billing')
  if (diff(a.app, b.app)) out.add('app')
  if (diff(a.tabBar, b.tabBar)) out.add('tabBar')
  return out
}

/** What GET /v1/config would send to a family, for the phone preview.
 *  [chosen]: the family is one of the chosen families. */
export function resolveForPreview(c: Controls, revision: number, chosen: boolean) {
  const now = new Date()
  const until = c.billing.freeForAllUntil ? new Date(c.billing.freeForAllUntil + 'T23:59:59Z') : null
  const freeForAll = !!until && now <= until
  const plusFree = !c.billing.enabled || freeForAll
  const resolve = (m: Mode): string => {
    if (m === 'chosen') return chosen ? 'on' : 'off'
    if (m === 'plus' && plusFree) return 'on'
    return m
  }
  return {
    revision,
    features: Object.fromEntries(Object.entries(c.features).map(([k, m]) => [k, resolve(m)])),
    stories: { comingSoon: c.stories.comingSoon, episodes: Object.fromEntries(Object.entries(c.stories.episodes).map(([k, m]) => [k, resolve(m)])) },
    room: c.room,
    games: c.games,
    pencilColors: c.pencilColors,
    billing: { ...c.billing, plusFree, freeForAll },
    app: {
      minVersion: c.app.minVersion,
      maintenance: { ...c.app.maintenance, id: 'preview' },
      parentMessage: { ...c.app.parentMessage, id: 'preview' },
    },
    tabBar: c.tabBar,
  }
}
