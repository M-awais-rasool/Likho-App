import { encode } from 'uqr'

/** A QR code as SVG, always dark on white (phone cameras need the contrast, in dark mode too). */
export default function QrCode({ text, size = 184, label }: { text: string; size?: number; label: string }) {
  const qr = encode(text, { ecc: 'M', border: 2 })
  let d = ''
  qr.data.forEach((row, y) =>
    row.forEach((dark, x) => {
      if (dark) d += `M${x} ${y}h1v1h-1z`
    }),
  )
  return (
    <svg role="img" aria-label={label} viewBox={`0 0 ${qr.size} ${qr.size}`} width={size} height={size} shapeRendering="crispEdges" className="rounded-lg">
      <rect width={qr.size} height={qr.size} fill="#fff" />
      <path d={d} fill="#111" />
    </svg>
  )
}
