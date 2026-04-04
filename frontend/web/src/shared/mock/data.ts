export type ChatConversation = {
  id: string
  name: string
  lastMessage: string
  unreadCount: number
  online: boolean
}

export type ChatMessage = {
  id: string
  conversationId: string
  sender: 'me' | 'other'
  text: string
  timestamp: string
}

export type AppNotification = {
  id: string
  title: string
  content: string
  createdAt: string
  isRead: boolean
}

export const CURRENT_USER = {
  id: 'u-me',
  name: 'Trần Minh',
  avatarFallback: 'TM',
}

export const conversations: ChatConversation[] = [
  {
    id: 'c-1',
    name: 'Nguyễn An',
    lastMessage: 'Tôi đã cập nhật giao diện bản mới rồi nha.',
    unreadCount: 2,
    online: true,
  },
  {
    id: 'c-2',
    name: 'Team VNALO FE',
    lastMessage: 'Mai 9h demo sprint nhé mọi người.',
    unreadCount: 0,
    online: false,
  },
  {
    id: 'c-3',
    name: 'Lê Hương',
    lastMessage: 'Đã gửi file Figma cho bạn.',
    unreadCount: 1,
    online: true,
  },
]

export const messages: ChatMessage[] = [
  {
    id: 'm-1',
    conversationId: 'c-1',
    sender: 'other',
    text: 'Chào bạn, mình vừa xem nhánh mới.',
    timestamp: '09:02',
  },
  {
    id: 'm-2',
    conversationId: 'c-1',
    sender: 'me',
    text: 'Ok bạn, tôi sẽ merge sau khi test.',
    timestamp: '09:05',
  },
  {
    id: 'm-3',
    conversationId: 'c-1',
    sender: 'other',
    text: 'Tôi đã cập nhật giao diện bản mới rồi nha.',
    timestamp: '09:08',
  },
  {
    id: 'm-4',
    conversationId: 'c-2',
    sender: 'other',
    text: 'Mai 9h demo sprint nhé mọi người.',
    timestamp: '08:50',
  },
  {
    id: 'm-5',
    conversationId: 'c-3',
    sender: 'other',
    text: 'Đã gửi file Figma cho bạn.',
    timestamp: '07:18',
  },
]

export const notifications: AppNotification[] = [
  {
    id: 'n-1',
    title: 'Lời mời kết bạn',
    content: 'Phạm Long đã gửi lời mời kết bạn.',
    createdAt: '2 phút trước',
    isRead: false,
  },
  {
    id: 'n-2',
    title: 'Tin nhắn mới',
    content: 'Nguyễn An đã gửi 2 tin nhắn mới.',
    createdAt: '10 phút trước',
    isRead: false,
  },
  {
    id: 'n-3',
    title: 'Bảo trì hệ thống',
    content: 'Hệ thống sẽ bảo trì lúc 01:00 AM.',
    createdAt: '1 giờ trước',
    isRead: true,
  },
]
