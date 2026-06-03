import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: [
      {
        find: /^es-toolkit\/compat\/(.+)$/,
        replacement: path.resolve(__dirname, 'src/shims/es-toolkit/compat/$1.js'),
      },
      {
        find: 'tslib',
        replacement: 'tslib/tslib.es6.js',
      },
    ],
  },
  optimizeDeps: {
    include: ['react-easy-crop', 'tslib'],
  },
})

