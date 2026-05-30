import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Change 'iet-estimation-tool' to match your GitHub repository name exactly
export default defineConfig({
  plugins: [react()],
  base: '/iet-estimation-tool/',
})
