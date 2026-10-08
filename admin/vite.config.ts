import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// The panel lives at /admin/ (the Go API serves the build there in
// production). In development the API runs on :8080 and Vite forwards
// /admin/api (and the media) to it, so the session cookie stays same-origin.
export default defineConfig({
  base: '/admin/',
  plugins: [react(), tailwindcss()],
  server: {
    port: 5173,
    proxy: {
      '/admin/api': { target: process.env.LIKHO_API ?? 'http://localhost:8080', changeOrigin: false },
      // the course's pictures and recordings (and their manifest)
      '/media': { target: process.env.LIKHO_API ?? 'http://localhost:8080', changeOrigin: false },
      '/v1/media': { target: process.env.LIKHO_API ?? 'http://localhost:8080', changeOrigin: false },
    },
  },
  build: { chunkSizeWarningLimit: 1200 },
})
