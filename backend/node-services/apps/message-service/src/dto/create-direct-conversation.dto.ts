import { IsUUID, IsNotEmpty } from 'class-validator';

/** Create a direct (1:1) conversation with another user. */
export class CreateDirectConversationDto {
  @IsUUID()
  @IsNotEmpty()
  targetUserId: string;
}
