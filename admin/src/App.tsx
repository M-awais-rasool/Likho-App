import { lazy, Suspense } from 'react'
import { Navigate, Route, Routes } from 'react-router-dom'
import { Layout } from './components/Layout'
import { Loading } from './components/ui'
import { useSession } from './lib/session'
import Login from './pages/Login'

const Overview = lazy(() => import('./pages/Overview'))
const Families = lazy(() => import('./pages/Families'))
const FamilyDetail = lazy(() => import('./pages/FamilyDetail'))
const Learners = lazy(() => import('./pages/Learners'))
const ActivityPage = lazy(() => import('./pages/Activity'))
const Alerts = lazy(() => import('./pages/Alerts'))
const Content = lazy(() => import('./pages/Content'))
const LevelEditor = lazy(() => import('./pages/LevelEditor'))
const Insights = lazy(() => import('./pages/Insights'))
const Team = lazy(() => import('./pages/Team'))
const Audit = lazy(() => import('./pages/Audit'))
const Settings = lazy(() => import('./pages/Settings'))
const System = lazy(() => import('./pages/System'))
const ClosedTest = lazy(() => import('./pages/ClosedTest'))

export default function App() {
  const { admin, loading, can } = useSession()
  if (loading) return <Loading label="Starting…" />
  if (!admin) return <Login />
  return (
    <Suspense fallback={<Loading />}>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<Overview />} />
          <Route path="closed-test" element={<ClosedTest />} />
          <Route path="families" element={<Families />} />
          <Route path="families/:id" element={<FamilyDetail />} />
          <Route path="learners" element={<Learners />} />
          <Route path="activity" element={<ActivityPage />} />
          <Route path="alerts" element={<Alerts />} />
          <Route path="content" element={<Content />} />
          <Route path="content/levels/new" element={<LevelEditor />} />
          <Route path="content/levels/:number" element={<LevelEditor />} />
          <Route path="insights" element={<Insights />} />
          {can('owner') && <Route path="team" element={<Team />} />}
          <Route path="audit" element={<Audit />} />
          <Route path="settings" element={<Settings />} />
          <Route path="system" element={<System />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </Suspense>
  )
}
