export type AiActionCommand =
  | 'OPEN_CHAT'
  | 'COMPOSE_MESSAGE'
  | 'START_CALL'
  | 'RECALL_MESSAGE'
  | 'CREATE_GROUP'
  | 'MUTE_CONVERSATION'
  | 'UNMUTE_CONVERSATION'
  | 'PIN_MESSAGE'
  | 'UNPIN_MESSAGE'
  | 'OPEN_GROUP_SETTINGS'
  | 'OPEN_PROFILE'
  | 'SEND_FRIEND_REQUEST'
  | 'BLOCK_USER'
  | 'UNBLOCK_USER'
  | 'CHANGE_GROUP_NAME'
  | 'ADD_GROUP_MEMBER'
  | 'REMOVE_GROUP_MEMBER'
  | 'TRANSFER_GROUP_OWNER'
  | 'LEAVE_GROUP'
  | 'DISBAND_GROUP'
  | 'NAVIGATE_TO'
  | 'NAVIGATE_TO_SETTINGS'
  | 'NAVIGATE_TO_CHAT'
  | 'NAVIGATE_TO_CONTACTS'
  | 'NAVIGATE_TO_SCANNER'
  | 'NAVIGATE_TO_TIMELINE'

export type AiActionRisk = 'low' | 'medium' | 'high'

export type AiActionParams = Record<string, unknown>

export type AiActionPreview = {
  targetLabel?: string
  draft?: string
  risk: AiActionRisk
}

export type AiActionCapability = 'execute' | 'review' | 'navigate' | 'unsupported'

export type AiActionDefinition = {
  command: AiActionCommand
  label: string
  risk: AiActionRisk
  capability: AiActionCapability
  requiresConfirmation: boolean
  destructive?: boolean
  minGroupMembers?: number
}

export const AI_ACTION_DEFINITIONS: Record<AiActionCommand, AiActionDefinition> = {
  OPEN_CHAT: { command: 'OPEN_CHAT', label: 'Mở cuộc trò chuyện', risk: 'low', capability: 'navigate', requiresConfirmation: false },
  COMPOSE_MESSAGE: { command: 'COMPOSE_MESSAGE', label: 'Mở chat và điền nháp', risk: 'low', capability: 'execute', requiresConfirmation: false },
  START_CALL: { command: 'START_CALL', label: 'Chuẩn bị cuộc gọi', risk: 'medium', capability: 'review', requiresConfirmation: true },
  RECALL_MESSAGE: { command: 'RECALL_MESSAGE', label: 'Thu hồi tin nhắn', risk: 'high', capability: 'execute', requiresConfirmation: true, destructive: true },
  CREATE_GROUP: { command: 'CREATE_GROUP', label: 'Tạo nhóm mới', risk: 'medium', capability: 'execute', requiresConfirmation: true, minGroupMembers: 2 },
  MUTE_CONVERSATION: { command: 'MUTE_CONVERSATION', label: 'Tắt thông báo cuộc trò chuyện', risk: 'low', capability: 'unsupported', requiresConfirmation: true },
  UNMUTE_CONVERSATION: { command: 'UNMUTE_CONVERSATION', label: 'Bật lại thông báo cuộc trò chuyện', risk: 'low', capability: 'unsupported', requiresConfirmation: true },
  PIN_MESSAGE: { command: 'PIN_MESSAGE', label: 'Ghim tin nhắn', risk: 'medium', capability: 'execute', requiresConfirmation: true },
  UNPIN_MESSAGE: { command: 'UNPIN_MESSAGE', label: 'Bỏ ghim tin nhắn', risk: 'medium', capability: 'execute', requiresConfirmation: true },
  OPEN_GROUP_SETTINGS: { command: 'OPEN_GROUP_SETTINGS', label: 'Mở cài đặt nhóm', risk: 'medium', capability: 'navigate', requiresConfirmation: false },
  OPEN_PROFILE: { command: 'OPEN_PROFILE', label: 'Mở hồ sơ', risk: 'low', capability: 'navigate', requiresConfirmation: false },
  SEND_FRIEND_REQUEST: { command: 'SEND_FRIEND_REQUEST', label: 'Gửi lời mời kết bạn', risk: 'medium', capability: 'execute', requiresConfirmation: true },
  BLOCK_USER: { command: 'BLOCK_USER', label: 'Chặn người dùng', risk: 'high', capability: 'unsupported', requiresConfirmation: true, destructive: true },
  UNBLOCK_USER: { command: 'UNBLOCK_USER', label: 'Bỏ chặn người dùng', risk: 'high', capability: 'unsupported', requiresConfirmation: true },
  CHANGE_GROUP_NAME: { command: 'CHANGE_GROUP_NAME', label: 'Đổi tên nhóm', risk: 'high', capability: 'unsupported', requiresConfirmation: true },
  ADD_GROUP_MEMBER: { command: 'ADD_GROUP_MEMBER', label: 'Thêm thành viên', risk: 'high', capability: 'unsupported', requiresConfirmation: true },
  REMOVE_GROUP_MEMBER: { command: 'REMOVE_GROUP_MEMBER', label: 'Xóa thành viên', risk: 'high', capability: 'unsupported', requiresConfirmation: true, destructive: true },
  TRANSFER_GROUP_OWNER: { command: 'TRANSFER_GROUP_OWNER', label: 'Chuyển quyền trưởng nhóm', risk: 'high', capability: 'unsupported', requiresConfirmation: true, destructive: true },
  LEAVE_GROUP: { command: 'LEAVE_GROUP', label: 'Rời nhóm', risk: 'high', capability: 'unsupported', requiresConfirmation: true, destructive: true },
  DISBAND_GROUP: { command: 'DISBAND_GROUP', label: 'Giải tán nhóm', risk: 'high', capability: 'unsupported', requiresConfirmation: true, destructive: true },
  NAVIGATE_TO: { command: 'NAVIGATE_TO', label: 'Đi đến trang yêu cầu', risk: 'low', capability: 'navigate', requiresConfirmation: false },
  NAVIGATE_TO_SETTINGS: { command: 'NAVIGATE_TO_SETTINGS', label: 'Đi đến Cài đặt', risk: 'low', capability: 'navigate', requiresConfirmation: false },
  NAVIGATE_TO_CHAT: { command: 'NAVIGATE_TO_CHAT', label: 'Đi đến Chat', risk: 'low', capability: 'navigate', requiresConfirmation: false },
  NAVIGATE_TO_CONTACTS: { command: 'NAVIGATE_TO_CONTACTS', label: 'Đi đến Danh bạ', risk: 'low', capability: 'navigate', requiresConfirmation: false },
  NAVIGATE_TO_SCANNER: { command: 'NAVIGATE_TO_SCANNER', label: 'Mở trình quét', risk: 'low', capability: 'navigate', requiresConfirmation: false },
  NAVIGATE_TO_TIMELINE: { command: 'NAVIGATE_TO_TIMELINE', label: 'Mở nhật ký', risk: 'low', capability: 'navigate', requiresConfirmation: false },
}

export const KNOWN_AI_ACTION_COMMANDS = new Set<AiActionCommand>(Object.keys(AI_ACTION_DEFINITIONS) as AiActionCommand[])

export function getAiActionDefinition(command: AiActionCommand): AiActionDefinition {
  return AI_ACTION_DEFINITIONS[command]
}

export function isKnownAiActionCommand(value: unknown): value is AiActionCommand {
  return typeof value === 'string' && KNOWN_AI_ACTION_COMMANDS.has(value as AiActionCommand)
}

export function getAiActionRisk(command: AiActionCommand): AiActionRisk {
  return getAiActionDefinition(command).risk
}

export function getAiActionLabel(command: AiActionCommand): string {
  return getAiActionDefinition(command).label
}

export function buildAiDeferredActionReply(command: AiActionCommand): string {
  const definition = getAiActionDefinition(command)
  if (definition.capability === 'unsupported') {
    return `Mình đã nhận diện yêu cầu: ${definition.label}. Thao tác này cần xử lý thủ công trong màn hình phù hợp để đảm bảo an toàn.`
  }
  return `Mình đã nhận diện yêu cầu: ${definition.label}. Hãy bấm nút bên dưới để mình kiểm tra điều kiện và mở luồng an toàn.`
}
