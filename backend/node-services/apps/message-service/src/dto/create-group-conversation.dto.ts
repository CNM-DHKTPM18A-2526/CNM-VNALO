import { IsString, IsOptional, IsArray, IsUUID, IsEnum, MaxLength, ArrayMinSize, ArrayMaxSize } from 'class-validator';
import { JoinMode } from '../entities/conversation.entity';

export class CreateGroupConversationDto {
  @IsString()
  @MaxLength(100)
  title: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @IsOptional()
  @IsString()
  avatarUrl?: string;

  @IsOptional()
  @IsEnum(JoinMode)
  joinMode?: JoinMode;

  /** Initial member UUIDs (excluding the creator who is auto-added as OWNER). Min 1 other member required. */
  @IsArray()
  @IsUUID('4', { each: true })
  @ArrayMinSize(1)
  @ArrayMaxSize(999)
  memberIds: string[];
}
