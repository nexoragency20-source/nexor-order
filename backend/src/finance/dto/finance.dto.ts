import { Type } from 'class-transformer';
import {
  IsDateString,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

const TRANSACTION_TYPES = [
  'INCOME',
  'EXPENSE',
  'DEPOSIT',
  'WITHDRAWAL',
  'OPENING_BALANCE',
] as const;
const CURRENCIES = ['USD', 'SYP'] as const;

export class FinanceTransactionDto {
  @IsIn(TRANSACTION_TYPES)
  type!: (typeof TRANSACTION_TYPES)[number];

  @IsIn(CURRENCIES)
  currency!: (typeof CURRENCIES)[number];

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 6 })
  @Min(0.000001)
  amount!: number;

  @IsString()
  @MinLength(2)
  @MaxLength(100)
  category!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(250)
  description!: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  note?: string;

  @IsOptional()
  @IsDateString()
  occurredAt?: string;
}

export class FinanceTransferDto {
  @IsIn(CURRENCIES)
  fromCurrency!: (typeof CURRENCIES)[number];

  @IsIn(CURRENCIES)
  toCurrency!: (typeof CURRENCIES)[number];

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 6 })
  @Min(0.000001)
  fromAmount!: number;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 6 })
  @Min(0.000001)
  toAmount!: number;

  @IsString()
  @MinLength(2)
  @MaxLength(250)
  description!: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  note?: string;

  @IsOptional()
  @IsDateString()
  occurredAt?: string;
}
