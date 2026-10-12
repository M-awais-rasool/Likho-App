import { useState } from 'react'
import QrCode from '../components/QrCode'
import { Button, Field, Input } from '../components/ui'
import { ApiError, type LoginStep } from '../lib/api'
import { useSession } from '../lib/session'

/** What a failed step says to the admin. */
function message(err: unknown) {
  if (err instanceof ApiError) {
    if (err.code === 'login_locked') return 'Too many wrong tries. This account is locked for 15 minutes.'
    if (err.code === 'invalid_code') return 'That code is wrong or expired. Check that the time on your phone is set automatically, then try the new code.'
    if (err.status === 429) return 'Too many attempts. Wait a minute and try again.'
  }
  return err instanceof Error ? err.message : 'Sign-in failed'
}

export default function Login() {
  const { login, verify } = useSession()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [step, setStep] = useState<LoginStep | null>(null)
  const [code, setCode] = useState('')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)

  const restart = (why = '') => {
    setStep(null)
    setCode('')
    setPassword('')
    setError(why)
  }

  const submitPassword = async (e: React.FormEvent) => {
    e.preventDefault()
    setBusy(true)
    setError('')
    try {
      setStep(await login(email, password))
      setCode('')
    } catch (err) {
      setError(message(err))
    } finally {
      setBusy(false)
    }
  }

  const submitCode = async (digits = code) => {
    if (!step || busy) return
    setBusy(true)
    setError('')
    try {
      await verify(step.ticket, digits)
    } catch (err) {
      if (err instanceof ApiError && (err.code === 'login_expired' || err.code === 'login_locked')) {
        restart(err.code === 'login_expired' ? 'That took too long. Sign in again.' : message(err))
      } else {
        setError(message(err))
        setCode('')
      }
    } finally {
      setBusy(false)
    }
  }

  const typed = (v: string) => {
    const digits = v.replace(/\D/g, '').slice(0, 6)
    setCode(digits)
    if (digits.length === 6) void submitCode(digits) // apps fill all six at once
  }

  const alert = error && (
    <div role="alert" className="rounded-lg bg-bad-soft px-3 py-2 text-[13px] text-bad">
      {error}
    </div>
  )

  return (
    <div className="grid min-h-screen place-items-center bg-bg px-4 py-10">
      <div className="w-full max-w-sm">
        <div className="mb-6 flex flex-col items-center text-center">
          <img src="/admin/favicon.svg" alt="" className="mb-3 size-12" />
          <h1 className="font-display text-[30px] leading-none font-extrabold">Likho Admin</h1>
          <p className="mt-2 text-[13.5px] text-ink-2">
            {!step ? 'Sign in to manage families, levels and content.' : step.next === 'setup' ? 'Set up two-step sign-in (once).' : 'Two-step sign-in'}
          </p>
        </div>

        {!step && (
          <form onSubmit={submitPassword} className="space-y-4 rounded-2xl border border-line bg-surface p-6 shadow-card">
            <Field label="Email">
              <Input type="email" autoComplete="username" required value={email} onChange={(e) => setEmail(e.target.value)} autoFocus />
            </Field>
            <Field label="Password">
              <Input type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} />
            </Field>
            {alert}
            <Button type="submit" variant="primary" loading={busy} className="w-full">
              Continue
            </Button>
          </form>
        )}

        {step && (
          <form
            onSubmit={(e) => {
              e.preventDefault()
              void submitCode()
            }}
            className="space-y-4 rounded-2xl border border-line bg-surface p-6 shadow-card"
          >
            {step.next === 'setup' && step.otpauthUrl && step.secret && (
              <div className="space-y-3 text-[13px] text-ink-2">
                <p>
                  <b className="text-ink">1.</b> Install an authenticator app on your phone: Google Authenticator, Microsoft Authenticator or 1Password.
                </p>
                <p>
                  <b className="text-ink">2.</b> In the app, add an account and scan this code:
                </p>
                <div className="flex justify-center">
                  <QrCode text={step.otpauthUrl} label="QR code for the authenticator app" />
                </div>
                <details className="rounded-lg border border-line px-3 py-2">
                  <summary className="cursor-pointer text-[12.5px]">Can't scan? Type this key instead</summary>
                  <code className="mt-2 block font-mono text-[13px] tracking-wider break-all text-ink select-all">{step.secret.match(/.{1,4}/g)!.join(' ')}</code>
                </details>
                <p>
                  <b className="text-ink">3.</b> Type the 6-digit code the app shows:
                </p>
              </div>
            )}
            {step.next === 'code' && <p className="text-[13px] text-ink-2">Open your authenticator app and type the 6-digit code for Likho Admin ({email}).</p>}
            <Field label="Code">
              <Input
                inputMode="numeric"
                autoComplete="one-time-code"
                pattern="[0-9]{6}"
                maxLength={7}
                placeholder="123456"
                required
                value={code}
                onChange={(e) => typed(e.target.value)}
                autoFocus
                className="text-center font-mono text-[20px] tracking-[0.3em]"
              />
            </Field>
            {alert}
            <Button type="submit" variant="primary" loading={busy} disabled={code.length !== 6} className="w-full">
              {step.next === 'setup' ? 'Turn on and sign in' : 'Sign in'}
            </Button>
            <button type="button" onClick={() => restart()} className="block w-full text-center text-[12.5px] text-ink-3 hover:text-ink-2">
              Use another account
            </button>
          </form>
        )}

        <p className="mt-4 text-center text-[12px] text-ink-3">
          {step ? 'Lost your phone? An owner can reset two-step sign-in in Team.' : 'Admin accounts are added by an owner in Team.'}
        </p>
      </div>
    </div>
  )
}
