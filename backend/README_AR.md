# NEXOR Orders — المرحلة 2: التسجيل وتسجيل الدخول

هذه الحزمة تضيف وحدة Auth إلى NestJS الحالي اعتماداً على جداول `User` و`Organization` و`Membership` و`Store` الموجودة في `schema.prisma`. لا تحتاج إلى تعديل Prisma schema أو إنشاء migration جديدة.

## 1) تثبيت الحزم

من PowerShell داخل `C:\nexor_orders\backend`:

```powershell
npm install @nestjs/jwt bcryptjs
```

## 2) نسخ الملفات

انسخ مجلد `src\auth` من الحزمة إلى `C:\nexor_orders\backend\src\auth`.
واستبدل `src\app.module.ts` بالنسخة الموجودة في الحزمة.

لا تستبدل `prisma.service.ts` أو `prisma.module.ts`؛ تظل كما هي.

## 3) إعداد سر JWT

ولّد سراً قوياً محلياً:

```powershell
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

أضف إلى `backend\.env`:

```env
JWT_SECRET="ضع_الناتج_هنا"
```

لا ترسل قيمة `JWT_SECRET` لأحد ولا تضعها في Git.

## 4) بناء وفحص Backend

أوقف NestJS بـ `Ctrl+C` ثم نفّذ:

```powershell
cd C:\nexor_orders\backend
npm run build
npm run start:dev
```

## 5) اختبار إنشاء حساب ومتجر

في PowerShell آخر:

```powershell
$body = @{
  email = "owner@example.com"
  fullName = "Store Owner"
  password = "ChangeThisPassword123!"
  organizationName = "NEXOR Demo Organization"
  storeName = "NEXOR Demo Store"
} | ConvertTo-Json

$result = Invoke-RestMethod `
  -Uri "http://localhost:3000/api/v1/auth/register" `
  -Method Post `
  -ContentType "application/json" `
  -Body $body

$result | Select-Object tokenType, expiresIn, role
$result.accessToken
```

استخدم بريداً لم يُسجّل من قبل. هذا ينشئ User وOrganization وMembership بدور OWNER وStore في معاملة واحدة.

## 6) اختبار الحساب الحالي

```powershell
$headers = @{ Authorization = "Bearer $($result.accessToken)" }
Invoke-RestMethod `
  -Uri "http://localhost:3000/api/v1/auth/me" `
  -Headers $headers
```

## 7) اختبار تسجيل الدخول

```powershell
$loginBody = @{
  email = "owner@example.com"
  password = "ChangeThisPassword123!"
} | ConvertTo-Json

$login = Invoke-RestMethod `
  -Uri "http://localhost:3000/api/v1/auth/login" `
  -Method Post `
  -ContentType "application/json" `
  -Body $loginBody

$login | Select-Object tokenType, expiresIn, role
```

## المسارات الجديدة

- `POST /api/v1/auth/register` — إنشاء مستخدم ومؤسسة ومتجر وعضوية OWNER.
- `POST /api/v1/auth/login` — تسجيل الدخول وإرجاع JWT.
- `GET /api/v1/auth/me` — يعرض الحساب والمؤسسة والمتجر الحاليين ويتطلب Bearer Token.

## ملاحظات مهمة

- لا توجد migration جديدة لأن الجداول المطلوبة موجودة بالفعل في المخطط الحالي.
- كل JWT يحمل `sub` و`organizationId` و`storeId` و`role`. أي endpoint خاص بالبيانات يجب أن يأخذ `storeId` و`organizationId` من المستخدم الموثّق، لا من Body أو Query المرسل من العميل.
- هذه مرحلة الأساس للمصادقة؛ لم نضف بعد اختيار متجر بين عدة متاجر، تجديد Refresh Tokens، استعادة كلمة المرور، تأكيد البريد، حدود محاولات الدخول أو صلاحيات Roles Guards. لا تعتبرها إعداد إنتاج نهائياً قبل إضافة هذه الطبقات ومراجعتها.
- لا تشارك `.env` أو JWT_SECRET أو روابط Neon في المحادثة أو Git.

## ربط مساعد NEXOR AI

لإعداد مساعد الذكاء الاصطناعي وبياناته وحدود الخصوصية وطريقة اختبار المسارات الجديدة، راجع `README_AI_AR.md`. مفتاح مزود الذكاء الاصطناعي يُحفظ في `backend/.env` على الخادم فقط، ولا يوضع داخل Flutter.
