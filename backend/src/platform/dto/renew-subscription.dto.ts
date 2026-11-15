import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class RenewSubscriptionDto {
  @IsIn(['MONTHLY', 'THREE_MONTHS', 'SIX_MONTHS', 'YEARLY', 'CUSTOM'])
  plan!: 'MONTHLY' | 'THREE_MONTHS' | 'SIX_MONTHS' | 'YEARLY' | 'CUSTOM';

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(1095)
  durationDays?: number;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  amount!: number;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  paidAmount!: number;

  @IsIn(['SYP', 'USD'])
  currency!: 'SYP' | 'USD';

  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;
}
