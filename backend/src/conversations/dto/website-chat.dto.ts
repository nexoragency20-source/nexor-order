import { ArrayMaxSize, ArrayMinSize, IsArray, IsOptional, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

export class SetupWebsiteChatDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(20)
  @IsString({ each: true })
  allowedOrigins!: string[];
}

export class WebsiteChatMessageDto {
  @IsString()
  @MinLength(8)
  @MaxLength(120)
  visitorId!: string;

  @IsOptional()
  @IsUUID()
  conversationId?: string;

  @IsOptional()
  @IsString()
  @MinLength(32)
  @MaxLength(200)
  sessionToken?: string;

  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  text!: string;
}
