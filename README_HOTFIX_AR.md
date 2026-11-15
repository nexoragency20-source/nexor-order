# NEXOR Super Admin — Hotfix 1

هذا التحديث يصلح مشكلتين ظهرتا بعد تطبيق Migration:

1. نوع `CreateStoreDto.plan` كان يُستنتج على أنه `string`، بينما Prisma يتطلب `SubscriptionPlan`. أصبح الآن اتحاداً حرفياً مطابقاً لقيم enum.
2. سكربت إنشاء مدير NEXOR كان يستورد `client.js` من مجلد `src`، لكن Prisma 7 `prisma-client` يولّد TypeScript هناك. السكربت يستورد الآن JavaScript المترجم من `dist`، ويدعم مساري إخراج Nest الشائعين.

## التركيب

1. فك الضغط فوق `C:\nexor_orders` مع الحفاظ على المجلدات واستبدال الملفات.
2. افتح PowerShell:

```powershell
cd C:\nexor_orders\backend
npm run db:generate
npm run build
```

3. **فقط إذا انتهى `npm run build` بنجاح** نفّذ:

```powershell
npm run platform:admin:create
```

4. بعد إنشاء المدير:

```powershell
npm run start:dev
```

لا تعِد تشغيل `npm run db:migrate`؛ الترحيلات نجحت بالفعل حسب سجل التنفيذ الذي أرسله المستخدم.

إذا فشل `npm run build` مرة أخرى، أرسل كامل أول رسالة `error TS...` مع اسم الملف ورقم السطر. لا ترسل ملف `.env` أو كلمات المرور أو بيانات الاتصال.
