import { Navigate, Route, Routes } from 'react-router-dom'

import { ProtectedRoute } from './features/auth/ProtectedRoute'
import { useAuth } from './features/auth/useAuth'
import { MainLayout } from './layouts/MainLayout'
import { LoginPage } from './pages/LoginPage'
import { RegisterPage } from './pages/RegisterPage'
import { ForgotPasswordPage } from './pages/ForgotPasswordPage'
import { ChatPage } from './pages/ChatPage'
import { ContactsPage } from './pages/ContactsPage'
import { ProfilePage } from './pages/ProfilePage'
import './styles/app.css'

function App() {
  const { isAuthenticated } = useAuth()

  return (
    <Routes>
      <Route path='/login' element={isAuthenticated ? <Navigate replace to='/chat' /> : <LoginPage />} />
      <Route path='/register' element={isAuthenticated ? <Navigate replace to='/chat' /> : <RegisterPage />} />
      <Route path='/forgot-password' element={isAuthenticated ? <Navigate replace to='/chat' /> : <ForgotPasswordPage />} />
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
        <Route path='contacts' element={<ContactsPage />} />
        <Route path='profile' element={<ProfilePage />} />
      </Route>
      <Route path='*' element={<Navigate replace to='/chat' />} />
    </Routes>
  )
}

export default App
