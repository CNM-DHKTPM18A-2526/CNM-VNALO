import { IsOptional, IsBoolean, IsInt, IsString } from 'class-validator';

export class UpdateInboxSettingsDto {
  @IsOptional()
  @IsBoolean()
  isPinned?: boolean;

  @IsOptional()
  @IsBoolean()
  isMuted?: boolean;

  @IsOptional()
  @IsBoolean()
  isHidden?: boolean;

  @IsOptional()
  @IsBoolean()
  isFavorite?: boolean;

  @IsOptional()
  @IsInt()
  autoDeleteSeconds?: number;

  @IsOptional()
  @IsBoolean()
  notifyCall?: boolean;

  @IsOptional()
  @IsString()
  wallpaperUrl?: string;
}
