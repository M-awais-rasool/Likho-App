import { Area, AreaChart, Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis, type TooltipContentProps } from "recharts"
import type { NameType, ValueType } from "recharts/types/component/DefaultTooltipContent"
import { num, pct, shortDay } from '../lib/format'

// Charts follow one system: one series per chart (no dual axes), thin
// marks, recessive grid, a hover tooltip on every mark, text in ink tokens.

const axis = { fontSize: 11, fill: 'var(--ink-3)' }

function TipBox({ title, rows }: { title: string; rows: { label: string; value: string; color?: string }[] }) {
  return (
    <div className="rounded-lg border border-line bg-surface px-3 py-2 text-[12px] shadow-lg">
      <div className="mb-1 font-semibold text-ink">{title}</div>
      {rows.map((r) => (
        <div key={r.label} className="flex items-center gap-2 text-ink-2">
          {r.color && <span className="size-2 rounded-full" style={{ background: r.color }} />}
          <span className="flex-1">{r.label}</span>
          <span className="tabular font-semibold text-ink">{r.value}</span>
        </div>
      ))}
    </div>
  )
}

/** One metric over days (area + line, crosshair tooltip). */
export function TrendChart({ data, dataKey, label, color = 'var(--series-1)', height = 240 }: { data: Record<string, unknown>[]; dataKey: string; label: string; color?: string; height?: number }) {
  const id = `fill-${dataKey}`
  return (
    <div style={{ height }} role="img" aria-label={`${label} per day`}>
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={data} margin={{ top: 8, right: 8, bottom: 0, left: -18 }}>
          <defs>
            <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={color} stopOpacity={0.22} />
              <stop offset="100%" stopColor={color} stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid vertical={false} stroke="var(--grid)" />
          <XAxis dataKey="day" tickFormatter={shortDay} tick={axis} tickLine={false} axisLine={false} minTickGap={28} />
          <YAxis allowDecimals={false} tick={axis} tickLine={false} axisLine={false} width={44} />
          <Tooltip
            cursor={{ stroke: 'var(--ink-3)', strokeDasharray: '3 3' }}
            content={(p: TooltipContentProps<ValueType, NameType>) =>
              p.active && p.payload?.length ? <TipBox title={shortDay(String(p.label))} rows={[{ label, value: num(Number(p.payload[0].value)), color }]} /> : null
            }
          />
          <Area type="monotone" dataKey={dataKey} stroke={color} strokeWidth={2} fill={`url(#${id})`} activeDot={{ r: 4, strokeWidth: 2, stroke: 'var(--surface)' }} />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  )
}

/** Children who finished each level (drop-off along the course). */
export function FunnelChart({ data, total, height = 220, onLevel }: { data: { level: number; children: number; current: number }[]; total: number; height?: number; onLevel?: (n: number) => void }) {
  return (
    <div style={{ height }} role="img" aria-label="Children who finished each level">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data} margin={{ top: 8, right: 8, bottom: 0, left: -18 }} barCategoryGap={2}>
          <CartesianGrid vertical={false} stroke="var(--grid)" />
          <XAxis dataKey="level" tick={axis} tickLine={false} axisLine={false} interval="preserveStartEnd" minTickGap={8} />
          <YAxis allowDecimals={false} tick={axis} tickLine={false} axisLine={false} width={44} />
          <Tooltip
            cursor={{ fill: 'var(--surface-2)' }}
            content={(p: TooltipContentProps<ValueType, NameType>) => {
              if (!p.active || !p.payload?.length) return null
              const d = p.payload[0].payload as { level: number; children: number; current: number }
              return (
                <TipBox
                  title={`Level ${d.level}`}
                  rows={[
                    { label: 'Finished it', value: `${num(d.children)} (${pct(d.children, total)})`, color: 'var(--series-1)' },
                    { label: 'On it now', value: num(d.current) },
                  ]}
                />
              )
            }}
          />
          <Bar dataKey="children" fill="var(--series-1)" radius={[4, 4, 0, 0]} onClick={(d) => onLevel?.((d as unknown as { level: number }).level)} className={onLevel ? 'cursor-pointer' : ''} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  )
}

/** Ranked shares as labelled horizontal bars (countries, versions…). */
export function ShareBars({ items, total, render }: { items: { key: string; n: number }[]; total: number; render: (key: string) => React.ReactNode }) {
  const max = Math.max(1, ...items.map((i) => i.n))
  return (
    <ul className="space-y-2.5">
      {items.map((i) => (
        <li key={i.key || '?'} title={`${i.n} (${pct(i.n, total)})`}>
          <div className="mb-1 flex items-center justify-between gap-2 text-[13px]">
            <span className="min-w-0 truncate text-ink">{render(i.key)}</span>
            <span className="tabular shrink-0 text-ink-2">
              {num(i.n)} <span className="text-ink-3">· {pct(i.n, total)}</span>
            </span>
          </div>
          <div className="h-1.5 overflow-hidden rounded-full bg-surface-2">
            <div className="h-full rounded-full bg-[var(--series-1)]" style={{ width: `${(i.n / max) * 100}%` }} />
          </div>
        </li>
      ))}
    </ul>
  )
}

const slots = ['var(--series-1)', 'var(--series-2)', 'var(--series-3)', 'var(--ink-3)']

/** Parts of a whole in one bar with a legend (platforms). Up to three
 *  named parts; the rest fold into "Other". */
export function SplitBar({ items, render }: { items: { key: string; n: number }[]; render: (key: string) => string }) {
  const total = items.reduce((s, i) => s + i.n, 0)
  const top = items.slice(0, 3)
  const other = items.slice(3).reduce((s, i) => s + i.n, 0)
  const parts = [...top.map((i) => ({ label: render(i.key), n: i.n })), ...(other ? [{ label: 'Other', n: other }] : [])]
  if (!total) return <div className="text-[13px] text-ink-3">No data yet</div>
  return (
    <div>
      <div className="flex h-3 gap-[2px] overflow-hidden rounded-full">
        {parts.map((p, i) => (
          <div key={p.label} title={`${p.label}: ${p.n} (${pct(p.n, total)})`} style={{ width: `${(p.n / total) * 100}%`, background: slots[i] }} />
        ))}
      </div>
      <ul className="mt-3 space-y-1.5">
        {parts.map((p, i) => (
          <li key={p.label} className="flex items-center gap-2 text-[13px]">
            <span className="size-2.5 rounded-sm" style={{ background: slots[i] }} />
            <span className="flex-1 text-ink">{p.label}</span>
            <span className="tabular text-ink-2">
              {num(p.n)} · {pct(p.n, total)}
            </span>
          </li>
        ))}
      </ul>
    </div>
  )
}
