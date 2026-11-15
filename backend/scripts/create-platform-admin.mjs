import 'dotenv/config';
import { createInterface } from 'node:readline/promises';
import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { stdin, stdout } from 'node:process';
import { hash } from 'bcryptjs';
import { PrismaPg } from '@prisma/adapter-pg';
const scriptDir = dirname(fileURLToPath(import.meta.url));
const generatedClientCandidates = [
  resolve(scriptDir, '../dist/generated/prisma/client.js'),
  resolve(scriptDir, '../dist/src/generated/prisma/client.js'),
];
const generatedClientPath = generatedClientCandidates.find((candidate) => existsSync(candidate));
if (!generatedClientPath) {
  console.error('Prisma Client المترجم غير موجود. نفّذ npm run build بنجاح أولاً، ثم أعد المحاولة.');
  process.exit(1);
}
const { PrismaClient } = await import(pathToFileURL(generatedClientPath).href);

const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  console.error('DATABASE_URL غير موجود. تأكد من إعداد backend/.env');
  process.exit(1);
}

const rl = createInterface({ input: stdin, output: stdout });
const ask = async (label) => (await rl.question(label)).trim();
const email = (process.env.NEXOR_ADMIN_EMAIL || await ask('بريد مدير NEXOR: ')).trim().toLowerCase();
const fullName = (process.env.NEXOR_ADMIN_NAME || await ask('اسم المدير: ')).trim();
const password = process.env.NEXOR_ADMIN_PASSWORD || await ask('كلمة مرور قوية (12 حرفاً على الأقل): ');
rl.close();

if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || !fullName.trim() || password.length < 12 || password.length > 72) {
  console.error('تحقق من البريد والاسم. كلمة المرور يجب أن تكون بين 12 و72 محرفاً.');
  process.exit(1);
}

const adapter = new PrismaPg({ connectionString });
const prisma = new PrismaClient({ adapter });
try {
  const passwordHash = await hash(password, 12);
  const admin = await prisma.platformAdmin.upsert({
    where: { email },
    create: { email, fullName, passwordHash },
    update: { fullName, passwordHash, isActive: true },
    select: { id: true, email: true, fullName: true },
  });
  console.log('تم تجهيز حساب مدير NEXOR بنجاح:');
  console.log(`البريد: ${admin.email}`);
  console.log('احتفظ بكلمة المرور في مكان آمن.');
} catch (error) {
  console.error('تعذر إنشاء حساب مدير NEXOR:', error?.message || error);
  process.exitCode = 1;
} finally {
  await prisma.$disconnect();
}
