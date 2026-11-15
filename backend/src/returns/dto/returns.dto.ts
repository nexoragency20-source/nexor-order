import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';

export class SalesReturnLineDto {
  @IsUUID()
  orderItemId!: string;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 3 })
  @Min(0.001)
  @Max(1000000000)
  quantity!: number;
}

export class CreateSalesReturnDto {
  @IsUUID()
  orderId!: string;

  @IsIn(['CASH', 'CUSTOMER_CREDIT'])
  settlementType!: 'CASH' | 'CUSTOMER_CREDIT';

  @IsIn(['USD', 'SYP'])
  currency!: 'USD' | 'SYP';

  @IsOptional()
  @IsString()
  reason?: string;

  @IsOptional()
  @IsString()
  notes?: string;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => SalesReturnLineDto)
  items!: SalesReturnLineDto[];
}

export class ReceiveSalesReturnDto {
  @IsOptional()
  @IsDateString()
  receivedAt?: string;

  @IsOptional()
  @IsString()
  note?: string;
}

export class RejectSalesReturnDto {
  @IsOptional()
  @IsString()
  reason?: string;
}
