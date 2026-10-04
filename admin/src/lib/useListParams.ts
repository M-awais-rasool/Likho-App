import { useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'

/** List filters kept in the URL (shareable, survive reloads). The search
 *  box is debounced. */
export function useListParams(defaults: { sort: string; desc?: boolean }) {
  const [sp, setSp] = useSearchParams()
  const q = sp.get('q') ?? ''
  const [draft, setDraft] = useState(q)
  useEffect(() => {
    const t = setTimeout(() => {
      if (draft !== q) set({ q: draft, page: '' })
    }, 300)
    return () => clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [draft])

  function set(values: Record<string, string>) {
    const next = new URLSearchParams(sp)
    for (const [k, v] of Object.entries(values)) {
      if (v) next.set(k, v)
      else next.delete(k)
    }
    setSp(next, { replace: true })
  }

  const sort = sp.get('sort') ?? defaults.sort
  const desc = sp.has('desc') ? sp.get('desc') !== 'false' : (defaults.desc ?? true)
  return {
    q,
    draft,
    setDraft,
    country: sp.get('country') ?? '',
    filter: sp.get('filter') ?? '',
    sort,
    desc,
    page: Number(sp.get('page') ?? 1) || 1,
    set,
    onSort: (s: string) => set({ sort: s, desc: s === sort ? String(!desc) : 'true', page: '' }),
  }
}
