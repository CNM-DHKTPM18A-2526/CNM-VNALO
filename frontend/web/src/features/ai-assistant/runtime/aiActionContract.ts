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
  OPEN_CHAT: { command: 'OPEN_CHAT', label: '\u0110i \u0111\u1ebfn cu\u1ed9c tr\u00f2 chuy\u1ec7n', risk: 'low', capability: 'navigate', requiresConfirmation: false },
  COMPOSE_MESSAGE: { command: 'COMPOSE_MESSAGE', label: 'M\u1edf chat v\u00e0 \u0111i\u1ec1n nh\u00e1p', risk: 'low', capability: 'execute', requiresConfirmation: false },
  START_CALL: { command: 'START_CALL', label: 'Chu\u1ea9n b\u1ecb cu\u1ed9c g\u1ecdi', risk: 'medium', capability: 'review', requiresConfirmation: true },
  RECALL_MESSAGE: { command: 'RECALL_MESSAGE', label: 'Thu h\u1ed3i tin nh\u1eafn', risk: 'high', capability: 'execute', requiresConfirmation: true, destructive: true },
  CREATE_GROUP: { command: 'CREATE_GROUP', label: 'T\u1ea1o nh\u00f3m m\u1edbi', risk: 'medium', capability: 'execute', requiresConfirmation: true, minGroupMembers: 2 },
  MUTE_CONVERSATION: { command: 'MUTE_CONVERSATION', label: 'T\u1eaft th\u00f4ng b\u00e1o cu\u1ed9c tr\u00f2 chuy\u1ec7n', risk: 'low', capability: 'unsupported', requiresConfirmation: true },
  UNMUTE_CONVERSATION: { command: 'UNMUTE_CONVERSATION', label: 'B\u1eadt l\u1ea1i th\u00f4ng b\u00e1o cu\u1ed9c tr\u00f2 chuy\u1ec7n', risk: 'low', capability: 'unsupported', requiresConfirmation: true },
  PIN_MESSAGE: { command: 'PIN_MESSAGE', label: 'Ghim tin nh\u1eafn', risk: 'medium', capability: 'execute', requiresConfirmation: true },
  UNPIN_MESSAGE: { command: 'UNPIN_MESSAGE', label: 'B\u1ecf ghim tin nh\u1eafn', risk: 'medium', capability: 'execute', requiresConfirmation: true },
  OPEN_GROUP_SETTINGS: { command: 'OPEN_GROUP_SETTINGS', label: 'M\u1edf c\u00e0i \u0111\u1eb7t nh\u00f3m', risk: 'medium', capability: 'navigate', requiresConfirmation: false },
  OPEN_PROFILE: { command: 'OPEN_PROFILE', label: 'M\u1edf h\u1ed3 s\u01a1', risk: 'low', capability: 'navigate', requiresConfirmation: false },
  SEND_FRIEND_REQUEST: { command: 'SEND_FRIEND_REQUEST', label: 'G\u1eedi l\u1eddi m\u1eddi k\u1ebft b\u1ea1n', risk: 'medium', capability: 'execute', requiresConfirmation: true },
  BLOCK_USER: { command: 'BLOCK_USER', label: 'Ch\u1eb7n ng\u01b0\u1eddi d\u00f9ng', risk: 'high', capability: 'unsupported', requiresConfirmation: true, destructive: true },
  UNBLOCK_USER: { command: 'UNBLOCK_USER', label: 'B\u1ecf ch\u1eb7n ng\u01b0\u1eddi d\u00f9ng', risk: 'high', capability: 'unsupported', requiresConfirmation: true },
  CHANGE_GROUP_NAME: { command: 'CHANGE_GROUP_NAME', label: '\u0110\u1ed5i t\u00ean nh\u00f3m', risk: 'high', capability: 'unsupported', requiresConfirmation: true },
  ADD_GROUP_MEMBER: { command: 'ADD_GROUP_MEMBER', label: 'Th\u00eam th\u00e0nh vi\u00ean', risk: 'high', capability: 'unsupported', requiresConfirmation: true },
  REMOVE_GROUP_MEMBER: { command: 'REMOVE_GROUP_MEMBER', label: 'X\u00f3a th\u00e0nh vi\u00ean', risk: 'high', capability: 'unsupported', requiresConfirmation: true, destructive: true },
  TRANSFER_GROUP_OWNER: { command: 'TRANSFER_GROUP_OWNER', label: 'Chuy\u1ec3n quy\u1ec1n tr\u01b0\u1edfng nh\u00f3m', risk: 'high', capability: 'unsupported', requiresConfirmation: true, destructive: true },
  LEAVE_GROUP: { command: 'LEAVE_GROUP', label: 'R\u1eddi nh\u00f3m', risk: 'high', capability: 'unsupported', requiresConfirmation: true, destructive: true },
  DISBAND_GROUP: { command: 'DISBAND_GROUP', label: 'Gi\u1ea3i t\u00e1n nh\u00f3m', risk: 'high', capability: 'unsupported', requiresConfirmation: true, destructive: true },
  NAVIGATE_TO: { command: 'NAVIGATE_TO', label: '\u0110i \u0111\u1ebfn trang y\u00eau c\u1ea7u', risk: 'low', capability: 'navigate', requiresConfirmation: false },
  NAVIGATE_TO_SETTINGS: { command: 'NAVIGATE_TO_SETTINGS', label: '\u0110i \u0111\u1ebfn C\u00e0i \u0111\u1eb7t', risk: 'low', capability: 'navigate', requiresConfirmation: false },
  NAVIGATE_TO_CHAT: { command: 'NAVIGATE_TO_CHAT', label: '\u0110i \u0111\u1ebfn Chat', risk: 'low', capability: 'navigate', requiresConfirmation: false },
  NAVIGATE_TO_CONTACTS: { command: 'NAVIGATE_TO_CONTACTS', label: '\u0110i \u0111\u1ebfn Danh b\u1ea1', risk: 'low', capability: 'navigate', requiresConfirmation: false },
  NAVIGATE_TO_SCANNER: { command: 'NAVIGATE_TO_SCANNER', label: 'M\u1edf tr\u00ecnh qu\u00e9t', risk: 'low', capability: 'navigate', requiresConfirmation: false },
  NAVIGATE_TO_TIMELINE: { command: 'NAVIGATE_TO_TIMELINE', label: 'M\u1edf nh\u1eadt k\u00fd', risk: 'low', capability: 'navigate', requiresConfirmation: false },
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
    return `M\u00ecnh \u0111\u00e3 nh\u1eadn di\u1ec7n y\u00eau c\u1ea7u: ${definition.label}. Thao t\u00e1c n\u00e0y c\u1ea7n x\u1eed l\u00fd th\u1ee7 c\u00f4ng trong m\u00e0n h\u00ecnh ph\u00f9 h\u1ee3p \u0111\u1ec3 \u0111\u1ea3m b\u1ea3o an to\u00e0n.`
  }
  return `M\u00ecnh \u0111\u00e3 nh\u1eadn di\u1ec7n y\u00eau c\u1ea7u: ${definition.label}. H\u00e3y b\u1ea5m n\u00fat b\u00ean d\u01b0\u1edbi \u0111\u1ec3 m\u00ecnh ki\u1ec3m tra \u0111i\u1ec1u ki\u1ec7n v\u00e0 m\u1edf lu\u1ed3ng an to\u00e0n.`
}
