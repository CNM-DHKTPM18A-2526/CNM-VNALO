import { Navigate, Route, Routes } from 'react-router-dom'

import { ProtectedRoute } from './features/auth/ProtectedRoute'
import { useAuth } from './features/auth/useAuth'
import { MainLayout } from './layouts/MainLayout'
import { LoginPage } from './pages/LoginPage'
import { ChatPage } from './pages/ChatPage'
import { NotificationsPage } from './pages/NotificationsPage'
import { ProfilePage } from './pages/ProfilePage'
import { SettingsPage } from './pages/SettingsPage'
import './styles/app.css'

function App() {
  const { isAuthenticated } = useAuth()

  return (
    <Routes>
      <Route path='/login' element={isAuthenticated ? <Navigate replace to='/chat' /> : <LoginPage />} />
      <Route
        path='/'
        element={
          <ProtectedRoute>
            <MainLayout />
          </ProtectedRoute>
        }
      >
        <Route index element={<Navigate replace to='/chat' />} />
        <Route path='chat' element={<ChatPage />} />
        <Route path='notifications' element={<NotificationsPage />} />
        <Route path='profile' element={<ProfilePage />} />
        <Route path='settings' element={<SettingsPage />} />
      </Route>
      <Route path='*' element={<Navigate replace to='/chat' />} />
    </Routes>
  )
}

export default App
