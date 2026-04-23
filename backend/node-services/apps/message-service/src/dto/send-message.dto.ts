import {
  IsString,
  IsOptional,
  IsEnum,
  IsUUID,
  MaxLength,
} from 'class-validator';
import { MessageType } from '../entities/message.entity';

export class SendMessageDto {
  @IsUUID()
  conversationId: string;

  @IsOptional()
  @IsUUID()
  clientMessageId?: string;

  @IsOptional()
  @IsEnum(MessageType)
  messageType?: MessageType;

  @IsOptional()
  @IsString()
  @MaxLength(5000)
  content?: string;

  // Media fields (set when sending images/files)
  @IsOptional()
  @IsString()
  mediaUrl?: string;

  @IsOptional()
  @IsString()
  mediaThumbnailUrl?: string;

  @IsOptional()
  @IsString()
  mediaMimeType?: string;

  @IsOptional()
  mediaSizeBytes?: number;

  // Reply
  @IsOptional()
  @IsUUID()
  replyToMessageId?: string;

  // Forward
  @IsOptional()
  @IsUUID()
  forwardFromMessageId?: string;

  @IsOptional()
  @IsUUID()
  forwardFromConversationId?: string;
}
