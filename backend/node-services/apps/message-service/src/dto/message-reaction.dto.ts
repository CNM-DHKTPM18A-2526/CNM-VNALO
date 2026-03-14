import { IsString, MaxLength, IsNotEmpty } from 'class-validator';

export class MessageReactionDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(20)
  emoji: string;
}
