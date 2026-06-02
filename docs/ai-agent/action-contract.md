# AI Assistant Action Contract

> The AI service returns action proposals. Clients execute only after schema validation, entity resolution, precondition checks, confirmation when needed, and backend success.

## Chat Request Contract

`POST /api/v1/ai/chat`

Required behavior for action-aware clients:

```json
{
  "prompt": "create group with An and Binh",
  "contextId": "conversation-id-or-null",
  "analyzeIntent": true,
  "enableDeepSummary": false,
  "history": [],
  "clientUserEntryId": "uuid",
  "clientAssistantEntryId": "uuid"
}
```

## Chat Response Contract

```json
{
  "textReply": "Human-readable assistant reply",
  "actionCommand": "CREATE_GROUP",
  "actionParams": {},
  "requiresConfirmation": true,
  "riskLevel": "medium",
  "conversationId": "uuid",
  "userEntryId": "uuid",
  "assistantEntryId": "uuid",
  "providerStatus": "LIVE_PROVIDER_ACTIVE"
}
```

## Canonical Commands

| Command | Risk | Confirmation | Primary executor |
| --- | --- | --- | --- |
| `OPEN_PROFILE` | low | no, unless private profile | web/mobile navigation |
| `COMPOSE_MESSAGE` | medium | yes before sending | message service or compose UI |
| `START_CALL` | medium | yes | call runtime |
| `SEND_FRIEND_REQUEST` | medium | yes | core/contact API |
| `CREATE_GROUP` | medium | yes | message service create group |
| `CHANGE_GROUP_NAME` | medium | yes | message service group API |
| `ADD_GROUP_MEMBER` | medium | yes | message service group API |
| `PIN_MESSAGE` | medium | yes | message service message API |
| `UNPIN_MESSAGE` | medium | yes | message service message API |
| `MUTE_CONVERSATION` | low | optional | notification/message settings |
| `UNMUTE_CONVERSATION` | low | optional | notification/message settings |
| `RECALL_MESSAGE` | high | yes | message service message API |
| `REMOVE_GROUP_MEMBER` | high | yes | message service group API |
| `TRANSFER_GROUP_OWNER` | high | strong yes | message service group API |
| `LEAVE_GROUP` | high | yes | message service group API |
| `DISBAND_GROUP` | high | strong yes | message service group API |
| `BLOCK_USER` | high | yes | core/contact API |
| `UNBLOCK_USER` | medium | yes | core/contact API |

## Common Parameter Names

| Concept | Preferred fields | Accepted aliases |
| --- | --- | --- |
| User names | `targetName`, `memberNames`, `targetUserName` | `name`, `userName`, `friendName`, `members` |
| User ids | `targetUserId`, `memberIds` | `userId`, `friendId`, `ids` |
| Conversation | `conversationId`, `conversationName` | `chatId`, `targetConversationId` |
| Message | `messageId`, `messageRef` | `targetMessageId`, `lastMessage` |
| Group name | `groupName` | `title`, `name` |
| Message draft | `content`, `draft` | `message`, `text` |
| Call type | `callType` | `type`, `mode` |

## Alias Normalization

| Alias | Canonical command |
| --- | --- |
| `SEND_MESSAGE` | `COMPOSE_MESSAGE` |
| `ADD_FRIEND` | `SEND_FRIEND_REQUEST` |
| `OPEN_USER_PROFILE` | `OPEN_PROFILE` |
| `PIN_LAST_MESSAGE` | `PIN_MESSAGE` |
| `UNPIN_LAST_MESSAGE` | `UNPIN_MESSAGE` |
| `ADD_MEMBER` | `ADD_GROUP_MEMBER` |
| `REMOVE_MEMBER` | `REMOVE_GROUP_MEMBER` |
| `TRANSFER_OWNER` | `TRANSFER_GROUP_OWNER` |
| `RENAME_GROUP` | `CHANGE_GROUP_NAME` |
| `DELETE_GROUP` | `DISBAND_GROUP` |
| `RECALL_LAST_MESSAGE` | `RECALL_MESSAGE` |
| `UNDO_LAST_MESSAGE` | `RECALL_MESSAGE` |

## Failure Contract

When an action cannot execute, the client must append a normal assistant message that states the exact blocker. Examples:

- `Không tìm thấy người dùng "Cơ Như Tuyết" trong danh bạ/bạn bè của bạn.`
- `Cần ít nhất 2 thành viên khác ngoài bạn để tạo nhóm.`
- `Mình tìm thấy nhiều người tên "An". Hãy chọn đúng người trước khi tạo nhóm.`
- `Bạn cần quyền quản trị nhóm để thực hiện thao tác này.`

The assistant must not say the action is prepared or completed when preconditions failed.
