import {
  IsString,
  IsOptional,
  IsEnum,
  MaxLength,
  IsBoolean,
} from 'class-validator';
import { JoinMode } from '../entities/conversation.entity';

export class UpdateConversationDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  title?: string;

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

  @IsOptional()
  @IsBoolean()
  allowMemberInvite?: boolean;

  @IsOptional()
  @IsBoolean()
  allowMemberPin?: boolean;

  @IsOptional()
  @IsBoolean()
  allowMemberEditInfo?: boolean;

  @IsOptional()
  @IsBoolean()
  onlyAdminCanPost?: boolean;
}
