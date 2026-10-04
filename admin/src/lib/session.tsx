import { useQuery, useQueryClient } from '@tanstack/react-query'
import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { ApiError, get, post, setSignedOutHandler, type Admin, type CourseSummary, type Role } from './api'

interface Session {
  admin: Admin | null
  loading: boolean // until the admin (and, once signed in, the courses) are known
  can: (role: Role) => boolean
  login: (email: string, password: string) => Promise<void>
  logout: () => Promise<void>
  course: string
  setCourse: (id: string) => void
  courses: CourseSummary[]
}

const Ctx = createContext<Session | null>(null)
const rank: Record<Role, number> = { viewer: 1, editor: 2, owner: 3 }

export function SessionProvider({ children }: { children: ReactNode }) {
  const qc = useQueryClient()
  const me = useQuery({
    queryKey: ['me'],
    queryFn: async () => {
      try {
        return (await get<{ admin: Admin }>('/auth/me')).admin
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) return null
        throw e
      }
    },
    staleTime: 60_000,
    retry: false,
  })
  const [course, setCourseState] = useState(() => localStorageGet('likho.course') ?? '')
  const courses = useQuery({
    queryKey: ['courses'],
    queryFn: () => get<{ courses: CourseSummary[] }>('/courses').then((r) => r.courses),
    enabled: !!me.data,
    staleTime: 60_000,
  })

  useEffect(() => {
    setSignedOutHandler(() => qc.setQueryData(['me'], null))
  }, [qc])

  // the chosen course, or the first one served
  const list = courses.data ?? []
  const current = list.some((c) => c.id === course) ? course : (list[0]?.id ?? '')

  // drop the previous admin's data (but keep the session query observed)
  const forgetData = () => qc.removeQueries({ predicate: (q) => q.queryKey[0] !== 'me' })

  const value: Session = {
    admin: me.data ?? null,
    loading: me.isLoading || (!!me.data && courses.isPending && !courses.error),
    can: (role) => !!me.data && rank[me.data.role] >= rank[role],
    login: async (email, password) => {
      const r = await post<{ admin: Admin }>('/auth/login', { email, password })
      forgetData()
      qc.setQueryData(['me'], r.admin)
    },
    logout: async () => {
      await post('/auth/logout').catch(() => {})
      forgetData()
      qc.setQueryData(['me'], null)
    },
    course: current,
    setCourse: (id) => {
      setCourseState(id)
      localStorageSet('likho.course', id)
    },
    courses: courses.data ?? [],
  }
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>
}

export function useSession() {
  const s = useContext(Ctx)
  if (!s) throw new Error('useSession outside SessionProvider')
  return s
}

export function localStorageGet(key: string) {
  try {
    return localStorage.getItem(key)
  } catch {
    return null
  }
}

export function localStorageSet(key: string, value: string) {
  try {
    localStorage.setItem(key, value)
  } catch {
    /* private mode: fine */
  }
}
