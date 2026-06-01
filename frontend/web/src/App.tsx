import { Navigate, Route, Routes } from 'react-router-dom'

import { ProtectedRoute } from './features/auth/ProtectedRoute'
import { useAuth } from './features/auth/useAuth'
import { MainLayout } from './layouts/MainLayout'
import { AdminLayout } from './layouts/AdminLayout'
import { LoginPage } from './pages/LoginPage'
import { QrLoginPage } from './pages/QrLoginPage'
import { RegisterPage } from './pages/RegisterPage'
import { ForgotPasswordPage } from './pages/ForgotPasswordPage'
import { LegalPage } from './pages/LegalPage'
import { AdminMonitoringPage } from './pages/AdminMonitoringPage'
import ChatPage from './pages/ChatPage'
import CallPage from './pages/CallPage'
import { ContactsPage } from './pages/ContactsPage'
import { ProfilePage } from './pages/ProfilePage'
import { AiChatPage } from './pages/AiChatPage'
import SocialPage from './features/social/pages/SocialPage'
import CreateStoryPage from './features/social/pages/CreateStoryPage'
import StoryViewerPage from './features/social/pages/StoryViewerPage'
import { UserStoreProvider } from './features/chat/context/UserStoreContext'
import { NotificationProvider } from './features/notifications/NotificationContext'
import './styles/app.css'

function App() {
  const { isAuthenticated } = useAuth()

  return (
    <UserStoreProvider>
      <NotificationProvider>
        <Routes>
          <Route path='/login' element={isAuthenticated ? <Navigate replace to='/chat' /> : <LoginPage />} />
          <Route path='/login/qr' element={isAuthenticated ? <Navigate replace to='/chat' /> : <QrLoginPage />} />
          <Route path='/register' element={isAuthenticated ? <Navigate replace to='/chat' /> : <RegisterPage />} />
          <Route path='/legal/terms' element={<LegalPage kind='terms' />} />
          <Route path='/legal/privacy' element={<LegalPage kind='privacy' />} />
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
            <Route path='chat/:conversationId?' element={<ChatPage />} />
            <Route path='contacts' element={<ContactsPage />} />
            <Route path='profile' element={<ProfilePage />} />
            <Route path='chat-ai' element={<AiChatPage />} />
            <Route path='social' element={<SocialPage />} />

            <Route path='stories/create' element={<CreateStoryPage />} />
            <Route path='stories/:storyId' element={<StoryViewerPage />} />
          </Route>
          
          <Route
            path='/admin'
            element={
              <ProtectedRoute>
                <AdminLayout />
              </ProtectedRoute>
            }
          >
            <Route index element={<Navigate replace to='/admin/monitoring' />} />
            <Route path='monitoring' element={<AdminMonitoringPage />} />
          </Route>

          <Route path='/call/:callId' element={<ProtectedRoute><CallPage /></ProtectedRoute>} />
          <Route path='*' element={<Navigate replace to='/chat' />} />
        </Routes>
      </NotificationProvider>
    </UserStoreProvider>
  )
}

export default App
