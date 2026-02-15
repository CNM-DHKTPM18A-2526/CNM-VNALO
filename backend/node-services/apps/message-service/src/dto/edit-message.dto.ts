import { IsString, MaxLength } from 'class-validator';

export class EditMessageDto {
  @IsString()
  @MaxLength(5000)
  content: string;
}
