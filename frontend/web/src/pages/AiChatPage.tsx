import { useEffect, useMemo, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Send, Sparkles, Trash2, X } from "lucide-react";

import { extractMessage } from "../api.client";
import { useAuth } from "../features/auth/useAuth";
import { fetchInbox, sendAiChatMessage } from "../features/chat/chat.api";
import type { ConversationSummary } from "../features/chat/chat.types";

type ProviderStatus =
  | "LIVE_PROVIDER_ACTIVE"
  | "FALLBACK_PROVIDER_ACTIVE"
  | "AI_PROVIDER_TIMEOUT"
  | "AI_NETWORK_UNAVAILABLE"
  | "AI_ENDPOINT_NOT_FOUND"
  | "AI_AUTH_REQUIRED"
  | "AI_RATE_LIMITED"
  | "AI_REQUEST_FAILED"
  | "AI_PROVIDER_UNAVAILABLE"
  | null;

type AiActionCommand =
  | "OPEN_CHAT"
  | "COMPOSE_MESSAGE"
  | "START_CALL"
  | "RECALL_MESSAGE"
  | "CREATE_GROUP"
  | "MUTE_CONVERSATION"
  | "UNMUTE_CONVERSATION"
  | "PIN_MESSAGE"
  | "UNPIN_MESSAGE"
  | "OPEN_GROUP_SETTINGS"
  | "OPEN_PROFILE"
  | "SEND_FRIEND_REQUEST"
  | "BLOCK_USER"
  | "UNBLOCK_USER"
  | "CHANGE_GROUP_NAME"
  | "ADD_GROUP_MEMBER"
  | "REMOVE_GROUP_MEMBER"
  | "TRANSFER_GROUP_OWNER"
  | "LEAVE_GROUP"
  | "DISBAND_GROUP"
  | "NAVIGATE_TO"
  | "NAVIGATE_TO_SETTINGS"
  | "NAVIGATE_TO_CHAT"
  | "NAVIGATE_TO_CONTACTS"
  | "NAVIGATE_TO_SCANNER"
  | "NAVIGATE_TO_TIMELINE";

type AiMessage = {
  role: "user" | "assistant";
  content: string;
  timestamp: string;
  degraded?: boolean;
  providerStatus?: ProviderStatus;
  actionCommand?: AiActionCommand | null;
  actionParams?: Record<string, unknown> | null;
};

type PendingActionResolution = {
  candidates: ConversationSummary[];
  draft: string;
  command: AiActionCommand;
  targetLabel?: string;
};

type PendingActionReview = {
  title: string;
  description: string;
  confirmLabel: string;
  path?: string;
  feedback: string;
  preview?: AiActionPreview;
};

type AiActionPreview = {
  targetLabel?: string;
  draft?: string;
  risk: "low" | "medium" | "high";
};

type ActionFeedbackState = {
  tone: "info" | "success" | "warning" | "error";
  message: string;
};
const STORAGE_KEY = "vnalo_ai_chat_history";
const DRAFT_KEY_PREFIX = "vnalo_ai_web_compose_draft:";
const MAX_API_HISTORY = 20;

const PRESET_PROMPTS = [
  "Tóm tắt nhanh các tính năng chính của VNALO",
  "Giúp tôi soạn một tin nhắn từ chối lịch hẹn lịch sự",
  "Mở cuộc trò chuyện với một người trong danh bạ",
];

const INITIAL_ASSISTANT_MESSAGE: AiMessage = {
  role: "assistant",
  content:
    "Xin chào! Mình là Trợ lý AI VNALO. Mình có thể trả lời câu hỏi và gợi ý thao tác an toàn trong hệ thống.",
  timestamp: new Date().toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
  }),
};

const KNOWN_ACTION_COMMANDS = new Set<AiActionCommand>([
  "OPEN_CHAT",
  "COMPOSE_MESSAGE",
  "START_CALL",
  "RECALL_MESSAGE",
  "CREATE_GROUP",
  "MUTE_CONVERSATION",
  "UNMUTE_CONVERSATION",
  "PIN_MESSAGE",
  "UNPIN_MESSAGE",
  "OPEN_GROUP_SETTINGS",
  "OPEN_PROFILE",
  "SEND_FRIEND_REQUEST",
  "BLOCK_USER",
  "UNBLOCK_USER",
  "CHANGE_GROUP_NAME",
  "ADD_GROUP_MEMBER",
  "REMOVE_GROUP_MEMBER",
  "TRANSFER_GROUP_OWNER",
  "LEAVE_GROUP",
  "DISBAND_GROUP",
  "NAVIGATE_TO",
  "NAVIGATE_TO_SETTINGS",
  "NAVIGATE_TO_CHAT",
  "NAVIGATE_TO_CONTACTS",
  "NAVIGATE_TO_SCANNER",
  "NAVIGATE_TO_TIMELINE",
]);

const KNOWN_PROVIDER_STATUSES = new Set<Exclude<ProviderStatus, null>>([
  "LIVE_PROVIDER_ACTIVE",
  "FALLBACK_PROVIDER_ACTIVE",
  "AI_PROVIDER_TIMEOUT",
  "AI_NETWORK_UNAVAILABLE",
  "AI_ENDPOINT_NOT_FOUND",
  "AI_AUTH_REQUIRED",
  "AI_RATE_LIMITED",
  "AI_REQUEST_FAILED",
  "AI_PROVIDER_UNAVAILABLE",
]);

function normalizeProviderStatus(value: unknown): ProviderStatus {
  return typeof value === "string" &&
    KNOWN_PROVIDER_STATUSES.has(value as Exclude<ProviderStatus, null>)
    ? (value as Exclude<ProviderStatus, null>)
    : null;
}

function tryDecodeEmbeddedAiPayload(rawTextReply: unknown) {
  if (typeof rawTextReply !== "string") return null;
  const normalized = rawTextReply.trim();
  if (!normalized.startsWith("{") || !normalized.endsWith("}")) return null;

  try {
    const decoded = JSON.parse(normalized);
    if (!decoded || typeof decoded !== "object" || !("textReply" in decoded)) {
      return null;
    }
    return decoded as Record<string, unknown>;
  } catch {
    return null;
  }
}

function summarizeStructuredCollection(value: unknown) {
  if (!Array.isArray(value) || value.length === 0) return null;

  const normalizedItems = value
    .slice(0, 3)
    .map((item) => {
      if (typeof item === "string") return item.trim();
      if (item && typeof item === "object") {
        const record = item as Record<string, unknown>;
        for (const key of ["name", "label", "text", "title", "value"]) {
          const candidate = record[key];
          if (typeof candidate === "string" && candidate.trim()) {
            return candidate.trim();
          }
        }
      }
      return String(item ?? "").trim();
    })
    .filter(Boolean);

  if (!normalizedItems.length) return null;
  return `${normalizedItems.join(", ")}${value.length > normalizedItems.length ? "…" : ""}`;
}

function coerceAssistantDisplayText(rawTextReply: unknown) {
  if (typeof rawTextReply !== "string") return "";
  const normalized = rawTextReply.trim();
  if (!normalized) return "";

  const structured =
    tryDecodeEmbeddedAiPayload(normalized) ??
    (() => {
      if (!normalized.startsWith("{") || !normalized.endsWith("}")) return null;
      try {
        const decoded = JSON.parse(normalized);
        return decoded && typeof decoded === "object"
          ? (decoded as Record<string, unknown>)
          : null;
      } catch {
        return null;
      }
    })();

  if (!structured) {
    return normalized;
  }

  const embeddedText = [
    structured.textReply,
    structured.summary,
    structured.message,
    structured.description,
    structured.result,
  ].find((value) => typeof value === "string" && value.trim());

  if (
    typeof embeddedText === "string" &&
    embeddedText.trim() &&
    embeddedText.trim() !== normalized
  ) {
    return embeddedText.trim();
  }

  const scalarLabelMap: Array<[string, string]> = [
    ["intent", "Ý định"],
    ["sentiment", "Cảm xúc"],
    ["language", "Ngôn ngữ"],
    ["ocrText", "Văn bản nhận diện"],
    ["caption", "Mô tả"],
    ["scene", "Bối cảnh"],
  ];
  const lines: string[] = [];
  for (const [key, label] of scalarLabelMap) {
    const value = structured[key];
    if (typeof value === "string" && value.trim()) {
      lines.push(`- ${label}: ${value.trim()}`);
    }
  }

  const collectionLabelMap: Array<[string, string]> = [
    ["objects", "Đối tượng"],
    ["labels", "Nhãn"],
    ["faces", "Khuôn mặt"],
    ["texts", "Văn bản"],
    ["keywords", "Từ khóa"],
  ];
  for (const [key, label] of collectionLabelMap) {
    const summary = summarizeStructuredCollection(structured[key]);
    if (summary) {
      lines.push(`- ${label}: ${summary}`);
    }
  }

  if (!lines.length) {
    return normalized;
  }

  return `Kết quả phân tích:\n${lines.join("\n")}`;
}

function normalizeAiReplyPayload(
  payload: Record<string, unknown>,
): Record<string, unknown> {
  const embeddedPayload = tryDecodeEmbeddedAiPayload(payload.textReply);
  const embeddedText =
    embeddedPayload && typeof embeddedPayload.textReply === "string"
      ? embeddedPayload.textReply.trim()
      : "";
  const normalizedText = coerceAssistantDisplayText(payload.textReply);
  const normalizedPayload: Record<string, unknown> = {
    ...payload,
    ...(normalizedText ? { textReply: normalizedText } : {}),
  };
  if (!embeddedPayload) return normalizedPayload;

  const normalized = { ...normalizedPayload };
  for (const key of [
    "textReply",
    "actionCommand",
    "actionParams",
    "providerStatus",
    "degraded",
  ]) {
    const currentValue = normalized[key];
    const embeddedValue = embeddedPayload[key];
    const isBlankString =
      typeof currentValue === "string" && !currentValue.trim();
    const isTextReplyRewrittenFromEmbedded =
      key === "textReply" &&
      typeof currentValue === "string" &&
      embeddedText.length > 0 &&
      currentValue.trim() === embeddedText;
    if (
      (currentValue == null ||
        isBlankString ||
        isTextReplyRewrittenFromEmbedded) &&
      embeddedValue != null
    ) {
      normalized[key] = embeddedValue;
    }
  }

  return normalized;
}

function resolveFailureProviderStatus(error: unknown): ProviderStatus {
  const maybeResponse = error as { response?: { status?: number } };
  const statusCode = maybeResponse.response?.status;
  if (statusCode === 401 || statusCode === 403) return "AI_AUTH_REQUIRED";
  if (statusCode === 404) return "AI_ENDPOINT_NOT_FOUND";
  if (statusCode === 429) return "AI_RATE_LIMITED";
  if (typeof statusCode === "number" && statusCode >= 500)
    return "AI_PROVIDER_UNAVAILABLE";

  const message = String(
    (error as { message?: unknown })?.message ?? "",
  ).toLowerCase();
  if (message.includes("timeout") || message.includes("timed out"))
    return "AI_PROVIDER_TIMEOUT";
  if (
    message.includes("network") ||
    message.includes("socket") ||
    message.includes("client error")
  )
    return "AI_NETWORK_UNAVAILABLE";

  return "AI_REQUEST_FAILED";
}

function normalizeStoredMessages(payload: unknown): AiMessage[] {
  if (!Array.isArray(payload)) return [INITIAL_ASSISTANT_MESSAGE];

  const normalized = payload
    .map<AiMessage | null>((item): AiMessage | null => {
      if (!item || typeof item !== "object") return null;
      const value = item as Record<string, unknown>;
      const role =
        value.role === "assistant"
          ? "assistant"
          : value.role === "user"
            ? "user"
            : null;
      const content =
        typeof value.content === "string" ? value.content.trim() : "";
      const timestamp =
        typeof value.timestamp === "string" && value.timestamp.trim()
          ? value.timestamp
          : new Date().toLocaleTimeString([], {
              hour: "2-digit",
              minute: "2-digit",
            });
      if (!role || !content) return null;

      return {
        role,
        content,
        timestamp,
        degraded: Boolean(value.degraded),
        providerStatus: normalizeProviderStatus(value.providerStatus),
        actionCommand:
          typeof value.actionCommand === "string" &&
          KNOWN_ACTION_COMMANDS.has(value.actionCommand as AiActionCommand)
            ? (value.actionCommand as AiActionCommand)
            : null,
        actionParams:
          value.actionParams && typeof value.actionParams === "object"
            ? (value.actionParams as Record<string, unknown>)
            : null,
      };
    })
    .filter((item): item is AiMessage => item !== null);

  return normalized.length > 0 ? normalized : [INITIAL_ASSISTANT_MESSAGE];
}
function resolveProviderPresentation(messages: AiMessage[]) {
  const latestAssistantMessage = [...messages]
    .reverse()
    .find((message) => message.role === "assistant");
  const providerStatus = latestAssistantMessage?.providerStatus ?? null;
  const degraded = Boolean(latestAssistantMessage?.degraded);

  if (providerStatus === "AI_PROVIDER_UNAVAILABLE") {
    return {
      providerStatus,
      degraded: true,
      badgeClassName: "ai-header-status ai-header-status-warning",
      label: "AI đang bảo trì",
      helper: "Một số phản hồi AI có thể tạm thời bị giới hạn.",
      banner:
        "AI đang bảo trì. Hãy thử lại sau hoặc tiếp tục thao tác thủ công.",
      bannerClassName: "ai-runtime-banner ai-runtime-banner-warning",
    };
  }

  if (providerStatus === "AI_ENDPOINT_NOT_FOUND") {
    return {
      providerStatus,
      degraded: true,
      badgeClassName: "ai-header-status ai-header-status-warning",
      label: "Sai cấu hình AI",
      helper: "Endpoint AI trên web đang cấu hình sai hoặc chưa bật.",
      banner:
        "Không tìm thấy endpoint AI. Hãy kiểm tra cấu hình môi trường web.",
      bannerClassName: "ai-runtime-banner ai-runtime-banner-warning",
    };
  }

  if (providerStatus === "AI_AUTH_REQUIRED") {
    return {
      providerStatus,
      degraded: true,
      badgeClassName: "ai-header-status ai-header-status-warning",
      label: "Cần đăng nhập lại",
      helper: "Phiên làm việc đã hết hạn.",
      banner:
        "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để tiếp tục dùng AI.",
      bannerClassName: "ai-runtime-banner ai-runtime-banner-warning",
    };
  }

  if (providerStatus === "AI_PROVIDER_TIMEOUT") {
    return {
      providerStatus,
      degraded: true,
      badgeClassName: "ai-header-status ai-header-status-warning",
      label: "Phản hồi chậm",
      helper: "AI đang phản hồi chậm hơn bình thường.",
      banner: "AI đang phản hồi chậm. Vui lòng thử lại sau vài giây.",
      bannerClassName: "ai-runtime-banner ai-runtime-banner-warning",
    };
  }

  if (providerStatus === "AI_NETWORK_UNAVAILABLE") {
    return {
      providerStatus,
      degraded: true,
      badgeClassName: "ai-header-status ai-header-status-warning",
      label: "Mất kết nối",
      helper: "Web chưa kết nối được tới dịch vụ AI.",
      banner: "Không kết nối được tới AI. Hãy kiểm tra mạng rồi thử lại.",
      bannerClassName: "ai-runtime-banner ai-runtime-banner-warning",
    };
  }

  if (providerStatus === "AI_RATE_LIMITED") {
    return {
      providerStatus,
      degraded: true,
      badgeClassName: "ai-header-status ai-header-status-warning",
      label: "Gửi quá nhanh",
      helper: "Bạn đang gửi yêu cầu quá nhanh.",
      banner:
        "Bạn đang gửi yêu cầu quá nhanh. Vui lòng chờ vài giây rồi thử lại.",
      bannerClassName: "ai-runtime-banner ai-runtime-banner-warning",
    };
  }

  if (providerStatus === "AI_REQUEST_FAILED") {
    return {
      providerStatus,
      degraded: true,
      badgeClassName: "ai-header-status ai-header-status-warning",
      label: "Yêu cầu lỗi",
      helper: "Hệ thống chưa hoàn tất yêu cầu AI vừa rồi.",
      banner: "Yêu cầu AI chưa hoàn tất. Vui lòng thử lại.",
      bannerClassName: "ai-runtime-banner ai-runtime-banner-warning",
    };
  }

  if (providerStatus === "FALLBACK_PROVIDER_ACTIVE" || degraded) {
    return {
      providerStatus,
      degraded: true,
      badgeClassName: "ai-header-status ai-header-status-degraded",
      label: "Chế độ dự phòng",
      helper: "Hệ thống đang dùng tuyến phản hồi thay thế.",
      banner:
        "AI đang chạy ở chế độ dự phòng, chất lượng phản hồi có thể giảm.",
      bannerClassName: "ai-runtime-banner ai-runtime-banner-info",
    };
  }

  return {
    providerStatus,
    degraded: false,
    badgeClassName: "ai-header-status",
    label: "Sẵn sàng hỗ trợ",
    helper: "Trợ lý AI có thể trả lời và gợi ý thao tác an toàn trong VNALO.",
    banner: "",
    bannerClassName: "ai-runtime-banner",
  };
}

function normalizeLookupText(value: string) {
  return value
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function tokenizeLookupText(value: string) {
  const normalized = normalizeLookupText(value);
  return normalized ? normalized.split(" ") : [];
}

function computeConversationMatchScore(
  conversationName: string,
  target: string,
) {
  const normalizedName = normalizeLookupText(conversationName);
  const normalizedTarget = normalizeLookupText(target);
  if (!normalizedName || !normalizedTarget) return -1;
  if (normalizedName === normalizedTarget) return 1000;
  if (normalizedName.startsWith(`${normalizedTarget} `)) return 930;
  if (normalizedName.endsWith(` ${normalizedTarget}`)) return 920;
  if (normalizedName.includes(normalizedTarget))
    return 870 + normalizedTarget.length;

  const nameTokens = tokenizeLookupText(normalizedName);
  const targetTokens = tokenizeLookupText(normalizedTarget);
  if (
    !nameTokens.length ||
    !targetTokens.length ||
    targetTokens.length > nameTokens.length
  )
    return -1;

  let cursor = 0;
  let score = 700 + targetTokens.length * 25;
  for (const targetToken of targetTokens) {
    let foundIndex = -1;
    for (let index = cursor; index < nameTokens.length; index += 1) {
      const nameToken = nameTokens[index];
      if (nameToken === targetToken || nameToken.startsWith(targetToken)) {
        foundIndex = index;
        break;
      }
    }
    if (foundIndex < 0) return -1;
    score -= (foundIndex - cursor) * 8;
    cursor = foundIndex + 1;
  }

  if (nameTokens[0] === targetTokens[0]) score += 30;
  if (
    nameTokens[nameTokens.length - 1] === targetTokens[targetTokens.length - 1]
  )
    score += 45;
  score -= Math.max(0, nameTokens.length - targetTokens.length) * 6;
  return score;
}

function extractActionTarget(params?: Record<string, unknown> | null) {
  if (!params) return "";
  const raw =
    params.target ??
    params.recipient ??
    params.contactName ??
    params.displayName ??
    params.conversationName ??
    params.groupName ??
    params.groupTitle ??
    params.chatName ??
    params.name ??
    "";
  return String(raw).trim();
}

function extractComposeContent(params?: Record<string, unknown> | null) {
  if (!params) return "";
  const raw =
    params.content ?? params.messageText ?? params.prefilledText ?? "";
  return String(raw).trim();
}

function buildConversationSubtitle(conversation: ConversationSummary) {
  if (conversation.isGroup) {
    const count = conversation.memberCount ?? conversation.members?.length ?? 0;
    return count > 0 ? `${count} thành viên` : "Cuộc trò chuyện nhóm";
  }

  return "Cuộc trò chuyện 1-1";
}

function buildRiskLabel(risk: AiActionPreview["risk"]) {
  if (risk === "high") return "Rủi ro cao";
  if (risk === "medium") return "Cần xác nhận";
  return "An toàn";
}

function buildActionRisk(command: AiActionCommand): AiActionPreview["risk"] {
  if (HIGH_RISK_ACTION_COMMANDS.has(command)) return "high";
  if (
    command === "CREATE_GROUP" ||
    command === "SEND_FRIEND_REQUEST" ||
    command === "START_CALL"
  )
    return "medium";
  return "low";
}

function resolveNavigatePath(
  command: AiActionCommand,
  params?: Record<string, unknown> | null,
) {
  if (command === "NAVIGATE_TO_CHAT") return "/chat";
  if (command === "NAVIGATE_TO_CONTACTS") return "/contacts";
  if (command === "OPEN_PROFILE") return "/profile";
  if (command === "NAVIGATE_TO_SETTINGS") return "/profile";
  if (command !== "NAVIGATE_TO") return null;

  const page = String(
    params?.page ?? params?.destination ?? params?.screen ?? "",
  )
    .trim()
    .toLowerCase();
  if (page === "chat") return "/chat";
  if (page === "contacts") return "/contacts";
  if (page === "profile" || page === "settings") return "/profile";
  return null;
}

const CONVERSATION_ACTION_COMMANDS = new Set<AiActionCommand>([
  "OPEN_CHAT",
  "COMPOSE_MESSAGE",
  "START_CALL",
  "OPEN_GROUP_SETTINGS",
  "MUTE_CONVERSATION",
  "UNMUTE_CONVERSATION",
  "CHANGE_GROUP_NAME",
  "ADD_GROUP_MEMBER",
  "REMOVE_GROUP_MEMBER",
  "TRANSFER_GROUP_OWNER",
  "LEAVE_GROUP",
  "DISBAND_GROUP",
]);

const HIGH_RISK_ACTION_COMMANDS = new Set<AiActionCommand>([
  "BLOCK_USER",
  "UNBLOCK_USER",
  "REMOVE_GROUP_MEMBER",
  "TRANSFER_GROUP_OWNER",
  "LEAVE_GROUP",
  "DISBAND_GROUP",
  "RECALL_MESSAGE",
]);

function isConversationAction(command: AiActionCommand) {
  return CONVERSATION_ACTION_COMMANDS.has(command);
}

function buildActionLabel(command: AiActionCommand) {
  switch (command) {
    case "OPEN_CHAT":
      return "Mở cuộc trò chuyện";
    case "COMPOSE_MESSAGE":
      return "Mở chat và điền nháp";
    case "NAVIGATE_TO_CHAT":
      return "Mở Chat";
    case "NAVIGATE_TO_CONTACTS":
      return "Mở Danh bạ";
    case "OPEN_PROFILE":
      return "Mở hồ sơ";
    case "NAVIGATE_TO":
      return "Mở màn hình đích";
    case "START_CALL":
      return "Mở chat để gọi";
    default:
      return "Thử thao tác này";
  }
}

function getFocusableElements(container: HTMLElement) {
  return Array.from(
    container.querySelectorAll<HTMLElement>(
      'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
    ),
  ).filter((element) => !element.hasAttribute("hidden"));
}

export function AiChatPage() {
  const { accessToken, user } = useAuth();
  const navigate = useNavigate();
  const [messages, setMessages] = useState<AiMessage[]>([]);
  const [inputValue, setInputValue] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [actionBusyIndex, setActionBusyIndex] = useState<number | null>(null);
  const [activeActionLabel, setActiveActionLabel] = useState<string>("");
  const [actionFeedback, setActionFeedback] =
    useState<ActionFeedbackState | null>(null);
  const [pendingResolution, setPendingResolution] =
    useState<PendingActionResolution | null>(null);
  const [pendingActionReview, setPendingActionReview] =
    useState<PendingActionReview | null>(null);
  const [retryPrompt, setRetryPrompt] = useState<string>("");
  const messagesEndRef = useRef<HTMLDivElement | null>(null);
  const inputRef = useRef<HTMLTextAreaElement | null>(null);
  const actionReviewDialogRef = useRef<HTMLDivElement | null>(null);
  const resolutionDialogRef = useRef<HTMLDivElement | null>(null);
  const lastFocusedElementRef = useRef<HTMLElement | null>(null);
  const isUnmountedRef = useRef(false);
  const inFlightRequestRef = useRef(false);

  useEffect(() => {
    return () => {
      isUnmountedRef.current = true;
    };
  }, []);

  useEffect(() => {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (!saved) {
      setMessages([INITIAL_ASSISTANT_MESSAGE]);
      return;
    }

    try {
      const parsed = JSON.parse(saved);
      setMessages(normalizeStoredMessages(parsed));
    } catch (error) {
      console.warn("Failed to parse AI chat history", error);
      setMessages([INITIAL_ASSISTANT_MESSAGE]);
    }
  }, []);

  const saveMessages = (nextMessages: AiMessage[]) => {
    const normalized = normalizeStoredMessages(nextMessages);
    setMessages(normalized);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(normalized));
  };

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, isLoading, actionFeedback]);

  const runtimeState = useMemo(
    () => resolveProviderPresentation(messages),
    [messages],
  );
  const isAssistantBusy =
    isLoading ||
    actionBusyIndex !== null ||
    pendingActionReview !== null ||
    pendingResolution !== null;

  useEffect(() => {
    const input = inputRef.current;
    if (!input) return;

    input.style.height = "0px";
    input.style.height = `${Math.min(input.scrollHeight, 132)}px`;
  }, [inputValue]);

  useEffect(() => {
    const activeDialog = pendingActionReview
      ? actionReviewDialogRef.current
      : pendingResolution
        ? resolutionDialogRef.current
        : null;

    if (!activeDialog) {
      if (lastFocusedElementRef.current) {
        lastFocusedElementRef.current.focus();
        lastFocusedElementRef.current = null;
      }
      document.body.style.overflow = "";
      return;
    }

    lastFocusedElementRef.current =
      document.activeElement as HTMLElement | null;
    document.body.style.overflow = "hidden";

    const focusables = getFocusableElements(activeDialog);
    const preferred = focusables[0] ?? activeDialog;
    window.requestAnimationFrame(() => {
      preferred.focus();
    });

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setPendingActionReview(null);
        setPendingResolution(null);
        return;
      }

      if (event.key !== "Tab") {
        return;
      }

      const currentFocusables = getFocusableElements(activeDialog);
      if (!currentFocusables.length) {
        event.preventDefault();
        activeDialog.focus();
        return;
      }

      const first = currentFocusables[0];
      const last = currentFocusables[currentFocusables.length - 1];
      const activeElement = document.activeElement as HTMLElement | null;

      if (event.shiftKey) {
        if (
          !activeElement ||
          activeElement === first ||
          !activeDialog.contains(activeElement)
        ) {
          event.preventDefault();
          last.focus();
        }
        return;
      }

      if (
        !activeElement ||
        activeElement === last ||
        !activeDialog.contains(activeElement)
      ) {
        event.preventDefault();
        first.focus();
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = "";
    };
  }, [pendingActionReview, pendingResolution]);

  const handleSend = async (textToSend?: string) => {
    const query = (textToSend ?? inputValue).trim();
    if (!query || isAssistantBusy || inFlightRequestRef.current) {
      return;
    }

    if (!accessToken) {
      const authError: AiMessage = {
        role: "assistant",
        content: "Bạn cần đăng nhập lại để dùng Trợ lý AI trên web.",
        timestamp: new Date().toLocaleTimeString([], {
          hour: "2-digit",
          minute: "2-digit",
        }),
        degraded: true,
        providerStatus: "AI_AUTH_REQUIRED",
      };
      saveMessages([...messages, authError]);
      return;
    }

    if (!textToSend) {
      setInputValue("");
    }

    const userMessage: AiMessage = {
      role: "user",
      content: query,
      timestamp: new Date().toLocaleTimeString([], {
        hour: "2-digit",
        minute: "2-digit",
      }),
    };

    const updatedMessages = [...messages, userMessage];
    saveMessages(updatedMessages);
    setRetryPrompt(query);
    setActionFeedback(null);
    inFlightRequestRef.current = true;
    setIsLoading(true);

    try {
      const apiHistory = updatedMessages
        .slice(-MAX_API_HISTORY)
        .map((message) => ({
          role: message.role,
          content: message.content,
        }));

      const rawResponse = await sendAiChatMessage(
        accessToken,
        query,
        apiHistory,
      );
      const aiResponse = normalizeAiReplyPayload(
        rawResponse as unknown as Record<string, unknown>,
      );
      const responseActionCommand =
        (aiResponse.actionCommand as AiActionCommand | undefined) ?? null;
      const safeActionCommand =
        responseActionCommand &&
        KNOWN_ACTION_COMMANDS.has(responseActionCommand)
          ? responseActionCommand
          : null;
      const assistantMessage: AiMessage = {
        role: "assistant",
        content:
          typeof aiResponse.textReply === "string" &&
          aiResponse.textReply.trim()
            ? aiResponse.textReply
            : "Mình chưa xử lý được yêu cầu này ngay lúc này. Vui lòng thử lại sau.",
        timestamp: new Date().toLocaleTimeString([], {
          hour: "2-digit",
          minute: "2-digit",
        }),
        degraded: Boolean(aiResponse.degraded),
        providerStatus: normalizeProviderStatus(aiResponse.providerStatus),
        actionCommand: safeActionCommand,
        actionParams:
          aiResponse.actionParams && typeof aiResponse.actionParams === "object"
            ? (aiResponse.actionParams as Record<string, unknown>)
            : null,
      };

      if (!isUnmountedRef.current) {
        saveMessages([...updatedMessages, assistantMessage]);
      }
    } catch (error) {
      console.error("AI chat failed:", error);
      const fallbackText =
        extractMessage(
          (error as { response?: { data?: unknown } })?.response?.data,
        ) ||
        extractMessage(error) ||
        "Đã xảy ra lỗi khi kết nối tới Trợ lý AI. Vui lòng thử lại sau.";

      const errorMessage: AiMessage = {
        role: "assistant",
        content: fallbackText,
        timestamp: new Date().toLocaleTimeString([], {
          hour: "2-digit",
          minute: "2-digit",
        }),
        degraded: true,
        providerStatus: resolveFailureProviderStatus(error),
      };

      if (!isUnmountedRef.current) {
        saveMessages([...updatedMessages, errorMessage]);
      }
    } finally {
      if (!isUnmountedRef.current) {
        inFlightRequestRef.current = false;
        setIsLoading(false);
      } else {
        inFlightRequestRef.current = false;
      }
    }
  };

  const handleAction = async (message: AiMessage, index: number) => {
    if (
      !accessToken ||
      !message.actionCommand ||
      actionBusyIndex !== null ||
      isLoading
    ) {
      return;
    }

    setActionBusyIndex(index);
    setActiveActionLabel(buildActionLabel(message.actionCommand));
    setActionFeedback(null);

    try {
      const command = message.actionCommand;
      const params = message.actionParams ?? {};
      const directPath = resolveNavigatePath(command, params);

      if (directPath) {
        navigate(directPath);
        setActionFeedback({
          tone: "success",
          message: "Đã mở đúng màn hình bạn yêu cầu trong VNALO.",
        });
        return;
      }

      if (command === "CREATE_GROUP") {
        setPendingActionReview({
          title: "Mở luồng tạo nhóm",
          description:
            "AI sẽ mở màn hình tạo nhóm. Bạn vẫn cần kiểm tra thành viên và xác nhận tạo nhóm thủ công.",
          confirmLabel: "Mở tạo nhóm",
          path: "/chat?createGroup=true",
          feedback:
            "Đã mở luồng tạo nhóm. Hãy kiểm tra tên nhóm và danh sách thành viên trước khi tạo.",
          preview: {
            risk: "medium",
            targetLabel: String(params.title ?? params.groupName ?? "Nhóm mới"),
          },
        });
        return;
      }

      if (command === "SEND_FRIEND_REQUEST") {
        setPendingActionReview({
          title: "Mở danh bạ để gửi kết bạn",
          description:
            "Trợ lý web sẽ không tự gửi lời mời kết bạn. Mình sẽ mở Danh bạ để bạn kiểm tra đúng người rồi tự gửi.",
          confirmLabel: "Mở Danh bạ",
          path: "/contacts",
          feedback:
            "Đã mở Danh bạ. Hãy xác nhận đúng người trước khi gửi lời mời kết bạn.",
          preview: {
            risk: "medium",
            targetLabel: extractActionTarget(params) || "Chưa rõ liên hệ",
          },
        });
        return;
      }

      if (
        HIGH_RISK_ACTION_COMMANDS.has(command) &&
        !isConversationAction(command)
      ) {
        setPendingActionReview({
          title: "Cần xác nhận thủ công",
          description:
            "Thao tác này có thể ảnh hưởng đến tài khoản, tin nhắn hoặc thành viên nhóm. Trợ lý web sẽ chỉ mở đúng luồng để bạn tự xác nhận.",
          confirmLabel: "Mở Chat",
          path: "/chat",
          feedback:
            "Đã mở Chat. Hãy kiểm tra đúng đối tượng rồi tự thực hiện thao tác nhạy cảm này.",
          preview: {
            risk: "high",
            targetLabel: extractActionTarget(params) || command,
          },
        });
        return;
      }

      if (isConversationAction(command)) {
        const target = extractActionTarget(params);
        if (!target) {
          navigate("/chat");
          setActionFeedback({
            tone: "warning",
            message:
              "AI chưa xác định được cuộc trò chuyện cụ thể. Mình đã mở Chat để bạn tự chọn.",
          });
          return;
        }

        const inbox = await fetchInbox(accessToken, user?.id);
        const matches = inbox
          .map((conversation) => {
            return {
              conversation,
              normalizedName: normalizeLookupText(conversation.name),
              score: computeConversationMatchScore(conversation.name, target),
            };
          })
          .filter((item) => item.score >= 0)
          .sort((left, right) => right.score - left.score);

        const normalizedTarget = normalizeLookupText(target);
        const exactMatches = matches.filter(
          (item) => item.normalizedName === normalizedTarget,
        );
        const candidateConversations = (
          exactMatches.length > 0 ? exactMatches : matches
        ).map((item) => item.conversation);

        if (candidateConversations.length > 1) {
          setPendingResolution({
            candidates: candidateConversations.slice(0, 8),
            draft:
              command === "COMPOSE_MESSAGE"
                ? extractComposeContent(params)
                : "",
            command,
            targetLabel: target,
          });
          setActionFeedback({
            tone: "info",
            message: `Mình tìm thấy ${candidateConversations.length} cuộc trò chuyện khớp với "${target}". Hãy chọn đúng đối tượng trước khi tiếp tục.`,
          });
          return;
        }

        const matched = candidateConversations[0];

        if (!matched) {
          setActionFeedback({
            tone: "warning",
            message: `Chưa tìm thấy cuộc trò chuyện phù hợp với "${target}".`,
          });
          return;
        }

        if (command === "COMPOSE_MESSAGE") {
          const draft = extractComposeContent(params);
          if (draft) {
            localStorage.setItem(`${DRAFT_KEY_PREFIX}${matched.id}`, draft);
          }
        }

        navigate(`/chat/${matched.id}`);
        if (command === "START_CALL") {
          setActionFeedback({
            tone: "success",
            message:
              "Đã mở cuộc trò chuyện. Hãy bấm nút gọi để xác nhận cuộc gọi trên web.",
          });
        } else if (HIGH_RISK_ACTION_COMMANDS.has(command)) {
          setActionFeedback({
            tone: "warning",
            message:
              "Đã mở đúng cuộc trò chuyện. Hãy tự xác nhận trước khi thực hiện thao tác nhạy cảm.",
          });
        } else {
          setActionFeedback({
            tone: "success",
            message: "Đã mở đúng cuộc trò chuyện đích.",
          });
        }
        return;
      }

      setPendingActionReview({
        title: "Web chưa hỗ trợ tự động thao tác này",
        description:
          "Trợ lý đã nhận ra ý định của bạn, nhưng web hiện chưa có executor an toàn cho thao tác này.",
        confirmLabel: "Mở Chat",
        path: "/chat",
        feedback:
          "Đã mở Chat. Bạn có thể tiếp tục thủ công hoặc dùng mobile để thực hiện thao tác này.",
        preview: { risk: "medium", targetLabel: command },
      });
    } catch (error) {
      console.error("AI action execution failed:", error);
      setActionFeedback({
        tone: "error",
        message:
          "Chưa thể thực thi thao tác AI trên web lúc này. Vui lòng thử lại hoặc thao tác thủ công.",
      });
    } finally {
      setActionBusyIndex(null);
      setActiveActionLabel("");
    }
  };

  const renderActionPreview = (preview?: AiActionPreview) => {
    if (!preview) return null;

    return (
      <div className={`ai-action-preview ai-action-preview-${preview.risk}`}>
        <span className="ai-action-preview-risk">
          {buildRiskLabel(preview.risk)}
        </span>
        {preview.targetLabel ? (
          <div className="ai-action-preview-row">
            <span>Đối tượng</span>
            <strong>{preview.targetLabel}</strong>
          </div>
        ) : null}
        {preview.draft ? (
          <div className="ai-action-preview-row ai-action-preview-draft">
            <span>Nội dung nháp</span>
            <p>{preview.draft}</p>
          </div>
        ) : null}
      </div>
    );
  };

  const confirmPendingActionReview = () => {
    if (!pendingActionReview) {
      return;
    }

    if (pendingActionReview.path) {
      navigate(pendingActionReview.path);
    }
    setActionFeedback({ tone: "info", message: pendingActionReview.feedback });
    setPendingActionReview(null);
  };

  const executeResolvedConversationAction = (
    conversation: ConversationSummary,
    resolution: PendingActionResolution,
  ) => {
    if (resolution.command === "COMPOSE_MESSAGE" && resolution.draft) {
      localStorage.setItem(
        `${DRAFT_KEY_PREFIX}${conversation.id}`,
        resolution.draft,
      );
    }

    setPendingResolution(null);
    navigate(`/chat/${conversation.id}`);
  };

  const handleRetry = () => {
    if (!retryPrompt || isAssistantBusy) {
      return;
    }

    void handleSend(retryPrompt);
  };

  const handleClearHistory = () => {
    setActionFeedback(null);
    setRetryPrompt("");
    setPendingActionReview(null);
    setPendingResolution(null);
    saveMessages([
      {
        role: "assistant",
        content: "Đã dọn lịch sử AI chat. Mình có thể hỗ trợ gì tiếp theo?",
        timestamp: new Date().toLocaleTimeString([], {
          hour: "2-digit",
          minute: "2-digit",
        }),
      },
    ]);
  };

  return (
    <div className="ai-chat-layout">
      <aside className="ai-chat-sidebar">
        <div className="ai-assistant-card">
          <div className="ai-avatar-glow">
            <Sparkles size={28} />
          </div>
          <h3>VNALO AI Assistant</h3>
          <p>
            Hỗ trợ trả lời câu hỏi, giải thích nhanh và gợi ý thao tác an toàn
            trong VNALO.
          </p>
        </div>

        <div className="ai-presets-container">
          <span className="ai-presets-title">Gợi ý câu hỏi</span>
          {PRESET_PROMPTS.map((prompt) => (
            <button
              key={prompt}
              type="button"
              className="ai-preset-btn"
              onClick={() => void handleSend(prompt)}
              disabled={isAssistantBusy}
            >
              {prompt}
            </button>
          ))}
        </div>

        <div className="flex-grow" style={{ flexGrow: 1 }} />

        <button
          type="button"
          className="ai-clear-btn flex items-center justify-center gap-2"
          onClick={handleClearHistory}
          disabled={isAssistantBusy}
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: "8px",
          }}
        >
          <Trash2 size={14} />
          Clear history
        </button>
      </aside>

      <main className="ai-chat-main">
        <header className="ai-chat-header">
          <div className="ai-header-stack">
            <div className="ai-header-info">
              <div className={runtimeState.badgeClassName} />
              <strong className="text-[15px] font-semibold">
                {runtimeState.label}
              </strong>
            </div>
            <span className="ai-header-helper">{runtimeState.helper}</span>
          </div>
        </header>

        <div className="ai-chat-messages">
          {runtimeState.degraded && (
            <div className={runtimeState.bannerClassName}>
              {runtimeState.banner}
            </div>
          )}
          {actionFeedback ? (
            <div
              className={`ai-runtime-banner ai-runtime-banner-${actionFeedback.tone}`}
            >
              <span>{actionFeedback.message}</span>
              {actionFeedback.tone === "error" && retryPrompt ? (
                <button
                  type="button"
                  className="ai-banner-action"
                  onClick={handleRetry}
                  disabled={isAssistantBusy}
                >
                  Retry
                </button>
              ) : null}
            </div>
          ) : null}

          {messages.map((message, index) => (
            <div
              key={`${message.role}-${message.timestamp}-${index}`}
              className={
                message.role === "assistant"
                  ? "ai-msg-bubble-ai"
                  : "ai-msg-bubble-user"
              }
            >
              <p
                className="text-[14.5px] whitespace-pre-wrap"
                style={{ margin: 0 }}
              >
                {message.content}
              </p>
              {message.role === "assistant" && message.actionCommand ? (
                <div className="ai-action-row">
                  <button
                    type="button"
                    className="ai-action-btn"
                    onClick={() => void handleAction(message, index)}
                    disabled={
                      isLoading ||
                      actionBusyIndex !== null ||
                      pendingActionReview !== null ||
                      pendingResolution !== null
                    }
                  >
                    {actionBusyIndex === index
                      ? "Processing..."
                      : buildActionLabel(message.actionCommand)}
                  </button>
                </div>
              ) : null}
              <div
                className="text-[10px] opacity-60 text-right mt-1.5"
                style={{ marginTop: "6px" }}
              >
                {message.timestamp}
              </div>
            </div>
          ))}

          {isLoading && (
            <div className="ai-typing-indicator">
              <span className="ai-typing-label">
                {activeActionLabel
                  ? `${activeActionLabel} đang được chuẩn bị`
                  : "Trợ lý AI đang soạn phản hồi"}
              </span>
              <div className="ai-typing-dot" />
              <div className="ai-typing-dot" />
              <div className="ai-typing-dot" />
            </div>
          )}
          <div ref={messagesEndRef} />
        </div>

        <footer className="ai-chat-footer">
          <form
            className="ai-input-wrapper"
            onSubmit={(event) => {
              event.preventDefault();
              void handleSend();
            }}
          >
            <textarea
              ref={inputRef}
              className="ai-input-field"
              placeholder="Nhắn điều bạn cần cho Trợ lý AI..."
              value={inputValue}
              onChange={(event) => setInputValue(event.target.value)}
              disabled={
                pendingActionReview !== null || pendingResolution !== null
              }
              rows={1}
              onKeyDown={(event) => {
                if (event.key === "Enter" && !event.shiftKey) {
                  event.preventDefault();
                  void handleSend();
                }
              }}
            />
            <button
              type="submit"
              className="ai-send-btn"
              disabled={isAssistantBusy || !inputValue.trim()}
            >
              <Send size={18} />
            </button>
            <span className="ai-input-hint">
              Enter để gửi, Shift + Enter để xuống dòng
            </span>
          </form>
        </footer>
      </main>

      {pendingActionReview ? (
        <div
          className="modal-overlay"
          role="dialog"
          aria-modal="true"
          aria-labelledby="ai-action-review-title"
          onClick={() => setPendingActionReview(null)}
        >
          <div
            className="modal-card ai-resolution-modal"
            ref={actionReviewDialogRef}
            tabIndex={-1}
            onClick={(event) => event.stopPropagation()}
          >
            <div className="modal-header">
              <div>
                <h3 id="ai-action-review-title">{pendingActionReview.title}</h3>
                <p>{pendingActionReview.description}</p>
                {renderActionPreview(pendingActionReview.preview)}
              </div>
              <button
                className="modal-close-btn"
                type="button"
                onClick={() => setPendingActionReview(null)}
                aria-label="Close"
              >
                <X size={18} />
              </button>
            </div>
            <div className="modal-footer">
              <button
                className="btn btn-subtle"
                type="button"
                onClick={() => setPendingActionReview(null)}
              >
                Hủy
              </button>
              <button
                className="btn btn-primary"
                type="button"
                onClick={confirmPendingActionReview}
              >
                {pendingActionReview.confirmLabel}
              </button>
            </div>
          </div>
        </div>
      ) : null}

      {pendingResolution ? (
        <div
          className="modal-overlay"
          role="dialog"
          aria-modal="true"
          aria-labelledby="ai-resolution-title"
          onClick={() => setPendingResolution(null)}
        >
          <div
            className="modal-card ai-resolution-modal"
            ref={resolutionDialogRef}
            tabIndex={-1}
            onClick={(event) => event.stopPropagation()}
          >
            <div className="modal-header">
              <div>
                <h3 id="ai-resolution-title">Chọn đúng cuộc trò chuyện</h3>
                <p>
                  Hãy xác nhận đúng đối tượng để tránh mở nhầm cuộc trò chuyện
                  hoặc điền nháp sai người.
                </p>
                {renderActionPreview({
                  risk: buildActionRisk(pendingResolution.command),
                  targetLabel: pendingResolution.targetLabel,
                  draft: pendingResolution.draft,
                })}
              </div>
              <button
                className="modal-close-btn"
                type="button"
                onClick={() => setPendingResolution(null)}
                aria-label="Close"
              >
                <X size={18} />
              </button>
            </div>
            <div className="modal-body ai-resolution-list">
              {pendingResolution.candidates.map((conversation) => (
                <button
                  key={conversation.id}
                  type="button"
                  className="ai-resolution-option"
                  onClick={() =>
                    executeResolvedConversationAction(
                      conversation,
                      pendingResolution,
                    )
                  }
                >
                  <span className="ai-resolution-avatar">
                    {conversation.name.charAt(0).toUpperCase()}
                  </span>
                  <span className="ai-resolution-meta">
                    <strong>{conversation.name}</strong>
                    <small>{buildConversationSubtitle(conversation)}</small>
                  </span>
                </button>
              ))}
            </div>
            <div className="modal-footer">
              <button
                className="btn btn-subtle"
                type="button"
                onClick={() => setPendingResolution(null)}
              >
                Hủy
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
