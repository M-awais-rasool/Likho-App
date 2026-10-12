import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { UserPlus } from 'lucide-react'
import { useState } from 'react'
import { Avatar, Badge, Button, Card, ErrorBox, Field, Input, Loading, Modal, PageHeader, Select, useConfirm, useToast } from '../components/ui'
import { del, get, patch, post, type Admin, type Role } from '../lib/api'
import { ago } from '../lib/format'
import { useSession } from '../lib/session'

const roleText: Record<Role, string> = {
  owner: 'Everything, including the team and deleting accounts',
  editor: 'Edit and publish levels, help families (Plus, stars, sign-out)',
  viewer: 'Read only',
}

export default function Team() {
  const { admin: me } = useSession()
  const qc = useQueryClient()
  const toast = useToast()
  const confirm = useConfirm()
  const [adding, setAdding] = useState(false)
  const q = useQuery({ queryKey: ['team'], queryFn: () => get<{ items: Admin[] }>('/team').then((r) => r.items) })
  const update = useMutation({
    mutationFn: ({ id, body }: { id: string; body: Record<string, unknown> }) => patch(`/team/${id}`, body),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['team'] }),
    onError: (e) => toast(e.message, 'bad'),
  })
  if (q.isLoading) return <Loading />
  if (q.error) return <ErrorBox error={q.error} />
  return (
    <div>
      <PageHeader title="Team" subtitle="Who can sign in to this panel, and what they can do." actions={<Button variant="primary" icon={<UserPlus className="size-4" />} onClick={() => setAdding(true)}>Add admin</Button>} />
      <Card padded={false}>
        <ul className="divide-y divide-line">
          {q.data!.map((a) => (
            <li key={a.id} className="flex flex-wrap items-center gap-3 px-4 py-3">
              <Avatar label={(a.name || a.email)[0].toUpperCase()} />
              <div className="min-w-0 flex-1">
                <div className="font-medium">
                  {a.name || a.email} {a.id === me?.id && <Badge tone="brand">You</Badge>} {a.disabled && <Badge tone="bad">Disabled</Badge>}{' '}
                  {a.twoFactor ? <Badge tone="good">2-step on</Badge> : <Badge tone="warn">Sets up 2-step at next sign-in</Badge>}
                </div>
                <div className="text-[12.5px] text-ink-3">{a.email} · last sign-in {ago(a.lastLoginAt)}</div>
              </div>
              <Select value={a.role} disabled={a.id === me?.id} onChange={(e) => update.mutate({ id: a.id, body: { role: e.target.value } })} className="w-32" aria-label="Role">
                <option value="owner">Owner</option>
                <option value="editor">Editor</option>
                <option value="viewer">Viewer</option>
              </Select>
              {a.id !== me?.id && (
                <>
                  <Button size="sm" variant="ghost" onClick={() => update.mutate({ id: a.id, body: { disabled: !a.disabled } })}>{a.disabled ? 'Enable' : 'Disable'}</Button>
                  {a.twoFactor && (
                    <Button size="sm" variant="ghost" onClick={async () => {
                      if (!(await confirm({ title: `Reset two-step sign-in for ${a.email}?`, body: 'For a lost or new phone: they are signed out and scan a new QR code at their next sign-in.', confirm: 'Reset' }))) return
                      update.mutate({ id: a.id, body: { resetTwoFactor: true } }, { onSuccess: () => toast(`${a.email} sets up two-step sign-in again at the next sign-in.`, 'good') })
                    }}>Reset 2-step</Button>
                  )}
                  <Button size="sm" variant="ghost" className="text-bad" onClick={async () => {
                    if (!(await confirm({ title: `Remove ${a.email}?`, body: 'They can no longer sign in. The audit log keeps what they did.', confirm: 'Remove', danger: true }))) return
                    try {
                      await del(`/team/${a.id}`)
                      qc.invalidateQueries({ queryKey: ['team'] })
                    } catch (e) {
                      toast((e as Error).message, 'bad')
                    }
                  }}>Remove</Button>
                </>
              )}
            </li>
          ))}
        </ul>
      </Card>
      <div className="mt-4 grid gap-2 text-[12.5px] text-ink-2 sm:grid-cols-3">
        {(Object.keys(roleText) as Role[]).map((r) => (
          <div key={r} className="rounded-lg border border-line bg-surface px-3 py-2"><b className="capitalize">{r}</b>: {roleText[r]}</div>
        ))}
      </div>
      <AddAdmin open={adding} onClose={() => setAdding(false)} />
    </div>
  )
}

function AddAdmin({ open, onClose }: { open: boolean; onClose: () => void }) {
  const qc = useQueryClient()
  const toast = useToast()
  const [f, setF] = useState({ email: '', name: '', role: 'editor', password: '' })
  const m = useMutation({
    mutationFn: () => post('/team', f),
    onSuccess: () => {
      toast(`${f.email} can sign in now: they set up an authenticator app at the first sign-in. Share the first password safely; they can change it in Settings.`, 'good')
      qc.invalidateQueries({ queryKey: ['team'] })
      setF({ email: '', name: '', role: 'editor', password: '' })
      onClose()
    },
    onError: (e) => toast(e.message, 'bad'),
  })
  return (
    <Modal open={open} onClose={onClose} title="Add admin" footer={<><Button onClick={onClose}>Cancel</Button><Button variant="primary" loading={m.isPending} onClick={() => m.mutate()}>Add</Button></>}>
      <div className="space-y-3">
        <Field label="Email"><Input type="email" value={f.email} onChange={(e) => setF({ ...f, email: e.target.value })} /></Field>
        <Field label="Name"><Input value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} /></Field>
        <Field label="Role">
          <Select value={f.role} onChange={(e) => setF({ ...f, role: e.target.value })}>
            <option value="viewer">Viewer</option>
            <option value="editor">Editor</option>
            <option value="owner">Owner</option>
          </Select>
        </Field>
        <Field label="First password" hint="At least 10 characters"><Input type="password" autoComplete="new-password" value={f.password} onChange={(e) => setF({ ...f, password: e.target.value })} /></Field>
      </div>
    </Modal>
  )
}
