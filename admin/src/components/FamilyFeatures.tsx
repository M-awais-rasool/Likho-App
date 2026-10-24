import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import clsx from 'clsx'
import { SlidersHorizontal } from 'lucide-react'
import { Link } from 'react-router-dom'
import { get, patch } from '../lib/api'
import { featureInfo, gameTitles, modeInfo, type FamilySwitch, type Mode } from '../lib/controls'
import { Card, ErrorBox, Spinner, useToast } from './ui'

/** A family's own switches (App controls): each part of the app as the
 *  controls say, or on / off for this family only. */
export function FamilyFeatures({ parentId, editable }: { parentId: string; editable: boolean }) {
  const qc = useQueryClient()
  const toast = useToast()
  const q = useQuery({ queryKey: ['family-features', parentId], queryFn: () => get<FamilySwitch[]>(`/families/${parentId}/features`) })
  const m = useMutation({
    mutationFn: (change: Record<string, boolean | null>) => patch<FamilySwitch[]>(`/families/${parentId}/features`, change),
    onSuccess: (out) => {
      qc.setQueryData(['family-features', parentId], out)
      qc.invalidateQueries({ queryKey: ['controls'] })
      toast('Saved. Their phone follows within 2 minutes.', 'good')
    },
    onError: (e) => toast(e.message, 'bad'),
  })
  const own = (q.data ?? []).filter((s) => s.own !== null).length
  return (
    <Card
      title={
        <span className="flex items-center gap-2">
          <SlidersHorizontal className="size-4" /> Features for this family
        </span>
      }
      action={own > 0 ? <span className="text-[12px] text-brand">{own} set here</span> : undefined}
      padded={false}
    >
      {q.isLoading && (
        <div className="flex justify-center py-6">
          <Spinner />
        </div>
      )}
      {q.error && (
        <div className="p-4">
          <ErrorBox error={q.error} retry={() => q.refetch()} />
        </div>
      )}
      <div className="divide-y divide-line">
        {(q.data ?? []).map((s) => {
          const title = s.key.startsWith('story.')
            ? `Story ${s.key.slice(6).toUpperCase()}`
            : s.key.startsWith('game.')
              ? `Game: ${gameTitles[s.key.slice(5)] ?? s.key.slice(5)}`
              : (featureInfo[s.key]?.title ?? s.key)
          const value = s.own === null ? 'default' : s.own ? 'on' : 'off'
          return (
            <div key={s.key} className={clsx('flex items-center justify-between gap-3 px-4 py-2.5', s.own !== null && 'bg-brand-soft/40')}>
              <div className="min-w-0">
                <div className="truncate text-[13px] font-medium text-ink">{title}</div>
                <div className="text-[11.5px] text-ink-3">App controls: {modeInfo[s.mode as Mode]?.label ?? s.mode}</div>
              </div>
              <div className="inline-flex shrink-0 rounded-lg border border-line bg-surface-2 p-0.5">
                {(['default', 'on', 'off'] as const).map((v) => (
                  <button
                    key={v}
                    disabled={!editable || m.isPending}
                    onClick={() => v !== value && m.mutate({ [s.key]: v === 'default' ? null : v === 'on' })}
                    className={clsx(
                      'h-6 cursor-pointer rounded-md px-2 text-[11.5px] font-medium transition-colors disabled:cursor-not-allowed',
                      v === value ? (v === 'on' ? 'bg-good text-white' : v === 'off' ? 'bg-ink text-surface' : 'bg-surface text-ink shadow-card') : 'text-ink-2 hover:text-ink',
                    )}
                    title={v === 'default' ? 'As the App controls say' : `${v === 'on' ? 'On' : 'Off'} for this family, whatever the App controls say`}
                  >
                    {v === 'default' ? 'Default' : v === 'on' ? 'On' : 'Off'}
                  </button>
                ))}
              </div>
            </div>
          )
        })}
      </div>
      <div className="border-t border-line px-4 py-2.5 text-[11.5px] text-ink-3">
        “Chosen families” switches are on only for families set to On here.{' '}
        <Link to="/controls" className="font-medium text-brand hover:underline">
          App controls
        </Link>
      </div>
    </Card>
  )
}
