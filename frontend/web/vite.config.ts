import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      tslib: 'tslib/tslib.es6.js',
    },
  },
  optimizeDeps: {
    include: ['react-easy-crop', 'tslib'],
  },
})
