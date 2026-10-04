import { CheckCircle2, Gift, LogIn, ShoppingBag, Sparkles, Trash2, Trophy, UserMinus, UserPlus, Baby } from 'lucide-react'
import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import type { ActivityEvent } from '../lib/api'
import { ago, dateTime, duration, eventMeta, flag } from '../lib/format'
import { Badge, Stars } from './ui'

const icons: Record<string, ReactNode> = {
  signed_up: <UserPlus className="size-4" />,
  signed_in: <LogIn className="size-4" />,
  child_added: <Baby className="size-4" />,
  child_removed: <UserMinus className="size-4" />,
  level_completed: <CheckCircle2 className="size-4" />,
  course_completed: <Trophy className="size-4" />,
  item_bought: <ShoppingBag className="size-4" />,
  trial_started: <Gift className="size-4" />,
  account_deleted: <Trash2 className="size-4" />,
}

const toneClass: Record<string, string> = {
  brand: 'bg-brand-soft text-brand-ink',
  good: 'bg-good-soft text-good',
  warn: 'bg-warn-soft text-warn',
  bad: 'bg-bad-soft text-bad',
  info: 'bg-info-soft text-info',
  muted: 'bg-surface-2 text-ink-2',
}

/** One line of the activity feed: who did what, when. */
export function EventRow({ e, showFamily = true }: { e: ActivityEvent; showFamily?: boolean }) {
  const meta = eventMeta[e.type] ?? { label: e.type, tone: 'muted' as const }
  const d = e.detail ?? {}
  const who = e.childName ? (
    <b className="font-semibold text-ink">{e.childName}</b>
  ) : e.parentName || e.parentEmail ? (
    <b className="font-semibold text-ink">{e.parentName || e.parentEmail}</b>
  ) : (
    <span className="text-ink-3">A family</span>
  )
  let what: ReactNode = meta.label.toLowerCase()
  if (e.type === 'level_completed')
    what = (
      <>
        finished level <b className="text-ink">{e.level}</b> <Stars n={e.stars} size={12} />
        {d.firstTime === false && <Badge className="ml-1">replay</Badge>}
      </>
    )
  if (e.type === 'course_completed') what = <>finished the whole course 🎉</>
  if (e.type === 'item_bought') what = <>bought “{String(d.item ?? 'an item')}” for the room</>
  if (e.type === 'child_added') what = <>was added as a learner{d.age ? ` (age ${d.age})` : ''}</>
  return (
    <li className="flex items-start gap-3 px-4 py-3">
      <span className={`mt-0.5 grid size-8 shrink-0 place-items-center rounded-full ${toneClass[meta.tone]}`}>{icons[e.type] ?? <Sparkles className="size-4" />}</span>
      <div className="min-w-0 flex-1">
        <div className="text-[13.5px] leading-snug text-ink-2">
          {who} {what}
          {e.seconds > 0 && <span className="text-ink-3"> · {duration(e.seconds)}</span>}
        </div>
        {showFamily && (e.parentEmail || e.country) && (
          <div className="mt-0.5 truncate text-[12px] text-ink-3">
            {e.country && <span className="mr-1">{flag(e.country)}</span>}
            {e.parentId ? (
              <Link to={`/families/${e.parentId}`} className="hover:text-brand-ink hover:underline">
                {e.parentEmail}
              </Link>
            ) : (
              e.parentEmail
            )}
          </div>
        )}
      </div>
      <time className="shrink-0 text-[12px] whitespace-nowrap text-ink-3" title={dateTime(e.at)} dateTime={e.at}>
        {ago(e.at)}
      </time>
    </li>
  )
}
