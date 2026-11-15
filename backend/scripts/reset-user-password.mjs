import 'dotenv/config';
import { createInterface } from 'node:readline/promises';
import { stdin, stdout } from 'node:process';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../dist/src/generated/prisma/client.js';
import { hash } from 'bcryptjs';

const rl = createInterface({ input: stdin, output: stdout });
let prisma;

try {
  const email = (await rl.question('Account email to reset: ')).trim().toLowerCase();
  const password = await rl.question('New password (at least 12 characters): ');
  const confirmation = await rl.question('Confirm new password: ');

  if (!email || !email.includes('@')) {
    throw new Error('Please enter a valid email address.');
  }
  if (password.length < 12 || Buffer.byteLength(password, 'utf8') > 72) {
    throw new Error('Password must be at least 12 characters and no more than 72 UTF-8 bytes.');
  }
  if (password !== confirmation) {
    throw new Error('The passwords do not match. No changes were made.');
  }

  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    throw new Error('DATABASE_URL is missing from backend/.env.');
  }

  prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString }) });
  await prisma.$connect();

  const user = await prisma.user.findUnique({
    where: { email },
    select: { id: true, email: true, isActive: true },
  });

  if (!user) {
    throw new Error('No account was found for that email. No changes were made.');
  }
  if (!user.isActive) {
    throw new Error('This account is inactive. Password was not changed.');
  }

  const passwordHash = await hash(password, 12);
  await prisma.user.update({
    where: { id: user.id },
    data: { passwordHash },
  });

  console.log(`Password reset successfully for ${user.email}.`);
  console.log('You can now sign in using the new password.');
} catch (error) {
  console.error(error instanceof Error ? error.message : 'Password reset failed.');
  process.exitCode = 1;
} finally {
  rl.close();
  if (prisma) await prisma.$disconnect();
}
