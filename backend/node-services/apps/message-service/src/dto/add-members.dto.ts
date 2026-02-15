import { IsArray, IsUUID, ArrayMinSize, ArrayMaxSize } from 'class-validator';

export class AddMembersDto {
  @IsArray()
  @IsUUID('4', { each: true })
  @ArrayMinSize(1)
  @ArrayMaxSize(100)
  memberIds: string[];
}
