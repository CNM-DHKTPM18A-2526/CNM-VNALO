import { IsOptional, IsInt, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';

export class PaginationDto {
  /** Cursor-based: fetch messages with server_seq less than this value */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  before?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 50;
}
