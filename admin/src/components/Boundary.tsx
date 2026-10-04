import { Component, type ReactNode } from 'react'
import { useLocation } from 'react-router-dom'
import { Button } from './ui'

/** A page that crashes shows a message instead of a blank panel; moving to
 *  another page clears it. */
export function PageBoundary({ children }: { children: ReactNode }) {
  const loc = useLocation()
  return <Boundary key={loc.pathname}>{children}</Boundary>
}

class Boundary extends Component<{ children: ReactNode }, { error: Error | null }> {
  state = { error: null as Error | null }
  static getDerivedStateFromError(error: Error) {
    return { error }
  }
  render() {
    if (!this.state.error) return this.props.children
    return (
      <div className="mx-auto mt-24 max-w-md rounded-xl border border-line bg-surface p-6 text-center shadow-card">
        <div className="text-[15px] font-semibold">Something went wrong on this page</div>
        <p className="mt-1 text-[13px] text-ink-2">{this.state.error.message}</p>
        <Button className="mt-4" onClick={() => location.reload()}>
          Reload
        </Button>
      </div>
    )
  }
}
