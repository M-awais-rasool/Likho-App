import clsx from 'clsx'
import { Map as MapIcon, Play, RotateCcw, Smartphone, TriangleAlert } from 'lucide-react'
import { useCallback, useEffect, useRef, useState } from 'react'
import { localStorageGet, localStorageSet } from '../lib/session'
import { Segmented, Select } from './ui'

// The real Likho app, compiled for the web (app/lib/preview/preview_main.dart,
// built by admin/scripts/build-preview.sh into public/preview), runs in a
// phone-sized frame. The page posts it the course with the level being
// edited; it plays the level exactly as phones do.

const DEVICES = [
  { id: 'iphone-se', label: 'iPhone SE', w: 375, h: 667, radius: 36, notch: false },
  { id: 'iphone-15', label: 'iPhone 15', w: 393, h: 852, radius: 54, notch: true },
  { id: 'iphone-15-pro-max', label: 'iPhone 15 Pro Max', w: 430, h: 932, radius: 58, notch: true },
  { id: 'pixel-7', label: 'Pixel 7 (Android)', w: 412, h: 915, radius: 40, notch: false },
  { id: 'galaxy-a', label: 'Small Android', w: 360, h: 760, radius: 30, notch: false },
  { id: 'ipad-mini', label: 'iPad mini', w: 744, h: 1133, radius: 32, notch: false },
]

export type PreviewScreen = 'level' | 'map'

export function PhonePreview({ course, level, height = 640 }: { course: unknown | null; level: number; height?: number }) {
  const frame = useRef<HTMLIFrameElement>(null)
  const [ready, setReady] = useState(false)
  const [missing, setMissing] = useState(false)
  const [error, setError] = useState('')
  const [screen, setScreen] = useState<PreviewScreen>('level')
  const [deviceId, setDeviceId] = useState(() => localStorageGet('likho.device') ?? 'iphone-15')
  const [nonce, setNonce] = useState(1)
  const device = DEVICES.find((d) => d.id === deviceId) ?? DEVICES[1]

  // is the Flutter build there?
  useEffect(() => {
    fetch('/admin/preview/main.dart.js', { method: 'HEAD' })
      .then((r) => setMissing(!r.ok || !(r.headers.get('content-type') ?? '').includes('javascript')))
      .catch(() => setMissing(true))
  }, [])

  useEffect(() => {
    const onMsg = (e: MessageEvent) => {
      if (e.origin !== location.origin || typeof e.data !== 'string') return
      try {
        const m = JSON.parse(e.data)
        if (m.type === 'likho-preview-ready') setReady(true)
        if (m.type === 'likho-preview-error') setError(m.message)
      } catch {
        /* not ours */
      }
    }
    window.addEventListener('message', onMsg)
    return () => window.removeEventListener('message', onMsg)
  }, [])

  const send = useCallback(() => {
    if (!ready || !course || !frame.current?.contentWindow) return
    setError('')
    frame.current.contentWindow.postMessage(JSON.stringify({ type: 'likho-preview', nonce: Date.now(), screen, level, course }), location.origin)
  }, [ready, course, screen, level])

  // re-send when the level changes (debounced by the editor) or on restart
  useEffect(() => {
    send()
  }, [send, nonce])

  // the device frame scales to fit the column
  const bezel = 12
  const scale = Math.min(1, (height - 2 * bezel) / device.h)

  return (
    <div className="flex flex-col items-center">
      <div className="mb-3 flex w-full flex-wrap items-center justify-between gap-2">
        <Segmented
          value={screen}
          onChange={setScreen}
          options={[
            { value: 'level', label: 'Play level' },
            { value: 'map', label: 'On the map' },
          ]}
        />
        <div className="flex items-center gap-1.5">
          <Select
            value={deviceId}
            onChange={(e) => {
              setDeviceId(e.target.value)
              localStorageSet('likho.device', e.target.value)
            }}
            className="h-8 w-auto text-[12.5px]"
            aria-label="Device"
          >
            {DEVICES.map((d) => (
              <option key={d.id} value={d.id}>
                {d.label} · {d.w}×{d.h}
              </option>
            ))}
          </Select>
          <button onClick={() => setNonce((n) => n + 1)} className="grid size-8 cursor-pointer place-items-center rounded-lg border border-line-strong text-ink-2 hover:bg-surface-2" title="Restart the level" aria-label="Restart">
            <RotateCcw className="size-4" />
          </button>
        </div>
      </div>

      <div
        className="relative bg-[#16171f] shadow-2xl"
        style={{ width: device.w * scale + bezel * 2, height: device.h * scale + bezel * 2, borderRadius: device.radius * scale + bezel, padding: bezel }}
      >
        <div className="relative overflow-hidden bg-white" style={{ width: device.w * scale, height: device.h * scale, borderRadius: device.radius * scale }}>
          {missing ? (
            <div className="flex h-full flex-col items-center justify-center gap-3 bg-surface-2 p-6 text-center text-[13px] text-ink-2">
              <Smartphone className="size-8 text-ink-3" />
              <b className="text-ink">Phone preview not built yet</b>
              <span>Build the app for the preview once (and after app changes):</span>
              <code className="rounded bg-surface px-2 py-1 text-[11.5px]">admin/scripts/build-preview.sh</code>
            </div>
          ) : (
            <iframe
              ref={frame}
              title="Phone preview"
              src="/admin/preview/"
              className="origin-top-left border-0"
              style={{ width: device.w, height: device.h, transform: `scale(${scale})` }}
              allow="autoplay"
            />
          )}
          {device.notch && <div className="pointer-events-none absolute top-[10px] left-1/2 h-[26px] w-[96px] -translate-x-1/2 rounded-full bg-black" style={{ transform: `translateX(-50%) scale(${scale})`, transformOrigin: 'top center' }} />}
          {!missing && !ready && (
            <div className="absolute inset-0 grid place-items-center bg-[#fff8ec] text-[13px] text-ink-3">
              <span className="flex items-center gap-2">
                <Play className="size-4 animate-pulse" /> Starting Likho…
              </span>
            </div>
          )}
        </div>
      </div>
      {error && (
        <div className="mt-3 flex w-full items-start gap-2 rounded-lg bg-bad-soft px-3 py-2 text-[12.5px] text-bad">
          <TriangleAlert className="mt-0.5 size-4 shrink-0" /> The app could not read this level: {error}
        </div>
      )}
      <p className={clsx('mt-3 text-center text-[12px] text-ink-3')}>
        {screen === 'map' ? (
          <span className="inline-flex items-center gap-1">
            <MapIcon className="size-3.5" /> The sample child has finished every level before this one.
          </span>
        ) : (
          'The real app, playing this level with your unsaved changes. Tap and drag like on a phone.'
        )}
      </p>
    </div>
  )
}
