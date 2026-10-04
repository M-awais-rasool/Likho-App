import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import App from './App'
import { ConfirmProvider, ToastProvider } from './components/ui'
import './index.css'
import { ApiError } from './lib/api'
import { SessionProvider } from './lib/session'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 15_000,
      refetchOnWindowFocus: true,
      retry: (n, e) => !(e instanceof ApiError && e.status > 0 && e.status < 500) && n < 2,
    },
  },
})

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter basename="/admin">
        <ToastProvider>
          <ConfirmProvider>
            <SessionProvider>
              <App />
            </SessionProvider>
          </ConfirmProvider>
        </ToastProvider>
      </BrowserRouter>
    </QueryClientProvider>
  </StrictMode>,
)
