import {
  IsBoolean,
  IsIn,
  IsString,
  MaxLength,
  MinLength,
} from "class-validator";

export class SendConversationMessageDto {
  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  text!: string;
}

export class UpdateConversationStatusDto {
  @IsString()
  @IsIn(["OPEN", "CLOSED"])
  status!: "OPEN" | "CLOSED";
}

export class ToggleChannelAutomationDto {
  @IsBoolean()
  enabled!: boolean;
}

export class ToggleConversationAutomationDto {
  @IsBoolean()
  paused!: boolean;
}
