import { useState } from 'react'
import { Button, Field, Input } from '../components/ui'
import { ApiError } from '../lib/api'
import { useSession } from '../lib/session'

export default function Login() {
  const { login } = useSession()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    setBusy(true)
    setError('')
    try {
      await login(email, password)
    } catch (err) {
      setError(err instanceof ApiError && err.status === 429 ? 'Too many attempts. Wait a minute and try again.' : err instanceof Error ? err.message : 'Sign-in failed')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="grid min-h-screen place-items-center bg-bg px-4">
      <div className="w-full max-w-sm">
        <div className="mb-6 flex flex-col items-center text-center">
          <img src="/admin/favicon.svg" alt="" className="mb-3 size-12" />
          <h1 className="font-display text-[30px] leading-none font-extrabold">Likho Admin</h1>
          <p className="mt-2 text-[13.5px] text-ink-2">Sign in to manage families, levels and content.</p>
        </div>
        <form onSubmit={submit} className="space-y-4 rounded-2xl border border-line bg-surface p-6 shadow-card">
          <Field label="Email">
            <Input type="email" autoComplete="username" required value={email} onChange={(e) => setEmail(e.target.value)} autoFocus />
          </Field>
          <Field label="Password">
            <Input type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} />
          </Field>
          {error && (
            <div role="alert" className="rounded-lg bg-bad-soft px-3 py-2 text-[13px] text-bad">
              {error}
            </div>
          )}
          <Button type="submit" variant="primary" loading={busy} className="w-full">
            Sign in
          </Button>
        </form>
        <p className="mt-4 text-center text-[12px] text-ink-3">Admin accounts are added by an owner in Team.</p>
      </div>
    </div>
  )
}
