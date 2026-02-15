import { IsInt, Min } from 'class-validator';

export class MarkReadDto {
  /** The server_seq of the last message the user has read */
  @IsInt()
  @Min(0)
  lastReadSeq: number;
}
