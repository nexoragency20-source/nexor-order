import { IsBoolean } from 'class-validator';

export class SetStoreSuspensionDto {
  @IsBoolean()
  isSuspended!: boolean;
}
