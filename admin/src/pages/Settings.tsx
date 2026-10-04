import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { BellRing, KeyRound } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Button, Card, ErrorBox, Field, Input, Loading, PageHeader, Select, Toggle, useToast } from '../components/ui'
import { get, post, put, type AlertRules } from '../lib/api'
import { localStorageGet, localStorageSet, useSession } from '../lib/session'

export default function Settings() {
  const { can } = useSession()
  return (
    <div>
      <PageHeader title="Settings" />
      <div className="grid gap-5 xl:grid-cols-2">
        <AlertRulesCard editable={can('editor')} />
        <div className="space-y-5">
          <NotificationsCard />
          <PasswordCard />
        </div>
      </div>
    </div>
  )
}

function AlertRulesCard({ editable }: { editable: boolean }) {
  const qc = useQueryClient()
  const toast = useToast()
  const q = useQuery({ queryKey: ['alert-rules'], queryFn: () => get<AlertRules>('/settings/alerts') })
  const [r, setR] = useState<AlertRules | null>(null)
  useEffect(() => {
    if (q.data) setR(q.data)
  }, [q.data])
  const m = useMutation({
    mutationFn: (next: AlertRules) => put<AlertRules>('/settings/alerts', next),
    onSuccess: (next) => {
      qc.setQueryData(['alert-rules'], next)
      toast('Alert rules saved.', 'good')
    },
    onError: (e) => toast(e.message, 'bad'),
  })
  if (q.isLoading || !r) return <Card title="Alert rules"><Loading /></Card>
  if (q.error) return <ErrorBox error={q.error} />
  const set = (patch: Partial<AlertRules>) => setR({ ...r, ...patch })
  return (
    <Card title={<span className="flex items-center gap-2"><BellRing className="size-4" /> Alert rules</span>}>
      <div className="space-y-4">
        <Toggle disabled={!editable} checked={r.reachedEnd} onChange={(v) => set({ reachedEnd: v })} label="A child is close to the end of the course" hint="So you can add levels before they run out. Once per child and level." />
        {r.reachedEnd && (
          <Field label="Alert when" className="pl-12">
            <Select disabled={!editable} value={r.levelsBeforeEnd} onChange={(e) => set({ levelsBeforeEnd: Number(e.target.value) })} className="w-auto">
              <option value={1}>they reach the last level</option>
              {[2, 3, 5, 10].map((n) => <option key={n} value={n}>{n} levels are left</option>)}
            </Select>
          </Field>
        )}
        <Toggle disabled={!editable} checked={r.courseCompleted} onChange={(v) => set({ courseCompleted: v })} label="A child finished every level" />
        <Toggle disabled={!editable} checked={r.newSignup} onChange={(v) => set({ newSignup: v })} label="A new family signed up" />
        <Toggle disabled={!editable} checked={r.trialStarted} onChange={(v) => set({ trialStarted: v })} label="A family started the Likho Plus trial" />
        {editable && <div className="flex justify-end"><Button variant="primary" loading={m.isPending} onClick={() => m.mutate(r)}>Save rules</Button></div>}
      </div>
    </Card>
  )
}

function NotificationsCard() {
  const [perm, setPerm] = useState(() => ('Notification' in window ? Notification.permission : 'denied'))
  const [sound, setSound] = useState(() => localStorageGet('likho.sound') !== 'off')
  return (
    <Card title="On this computer">
      <div className="space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <div className="text-[13.5px]">Browser notifications</div>
            <div className="text-[12px] text-ink-3">
              {perm === 'granted' ? 'On: new alerts pop up even when this tab is in the background.' : perm === 'denied' ? 'Blocked in the browser settings for this site.' : 'Get a pop-up for new alerts while the panel is open.'}
            </div>
          </div>
          {perm === 'default' && <Button onClick={async () => setPerm(await Notification.requestPermission())}>Turn on</Button>}
        </div>
        <Toggle checked={sound} onChange={(v) => { setSound(v); localStorageSet('likho.sound', v ? 'on' : 'off') }} label="Play a sound for new alerts" />
      </div>
    </Card>
  )
}

function PasswordCard() {
  const toast = useToast()
  const qc = useQueryClient()
  const [cur, setCur] = useState('')
  const [next, setNext] = useState('')
  const m = useMutation({
    mutationFn: () => post('/auth/password', { current: cur, next }),
    onSuccess: () => {
      toast('Password changed. Sign in again with the new one.', 'good')
      qc.setQueryData(['me'], null)
    },
    onError: (e) => toast(e.message, 'bad'),
  })
  return (
    <Card title={<span className="flex items-center gap-2"><KeyRound className="size-4" /> Change your password</span>}>
      <form className="space-y-3" onSubmit={(e) => { e.preventDefault(); m.mutate() }}>
        <Field label="Current password"><Input type="password" autoComplete="current-password" value={cur} onChange={(e) => setCur(e.target.value)} /></Field>
        <Field label="New password" hint="At least 10 characters. Signs you out everywhere."><Input type="password" autoComplete="new-password" value={next} onChange={(e) => setNext(e.target.value)} /></Field>
        <div className="flex justify-end"><Button type="submit" loading={m.isPending} disabled={!cur || next.length < 10}>Change password</Button></div>
      </form>
    </Card>
  )
}
