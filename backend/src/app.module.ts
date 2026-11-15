import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { CustomersModule } from './customers/customers.module.js';
import { AuthModule } from './auth/auth.module.js';
import { HealthModule } from './health/health.module.js';
import { OrdersModule } from './orders/orders.module.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { ProductsModule } from './products/products.module.js';
import { ProcurementModule } from './procurement/procurement.module.js';
import { FinanceModule } from './finance/finance.module.js';
import { ReturnsModule } from './returns/returns.module.js';
import { DashboardModule } from './dashboard/dashboard.module.js';
import { SettingsModule } from './settings/settings.module.js';
import { ConversationsModule } from './conversations/conversations.module.js';
import { PlatformModule } from './platform/platform.module.js';
import { AiModule } from './ai/ai.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    HealthModule,
    AuthModule,
    ProductsModule,
    ProcurementModule,
    OrdersModule,
    CustomersModule,
    FinanceModule,
    ReturnsModule,
    DashboardModule,
    SettingsModule,
    ConversationsModule,
    PlatformModule,
    AiModule,
  ],
})
export class AppModule {}
