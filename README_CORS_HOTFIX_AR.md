# NEXOR CORS Hotfix

هذا التصحيح يعالج CORS عندما تكون قيمة `CORS_ORIGIN="*"` في `backend/.env`.

## الملفات
- `backend/src/main.ts` فقط.

## التركيب
1. أوقف Backend بواسطة `Ctrl+C`.
2. فك ضغط هذا الملف فوق `C:\nexor_orders` مع الحفاظ على المسارات.
3. تأكد أن `backend/.env` يحتوي على `CORS_ORIGIN="*"` كما هو حالياً.
4. شغّل:

```powershell
cd C:\nexor_orders\backend
npm run build
npm run start:dev
```

5. اختبر CORS من نافذة PowerShell أخرى:

```powershell
curl.exe -i -X OPTIONS "http://localhost:3000/api/v1/platform/auth/login" -H "Origin: http://localhost:33086" -H "Access-Control-Request-Method: POST" -H "Access-Control-Request-Headers: content-type"
```

يجب أن ترى في الاستجابة:

`Access-Control-Allow-Origin: *`

إذا تغيّر منفذ Flutter، لا حاجة لتغيير CORS في التطوير المحلي طالما بقي `*` مفعلاً.

ملاحظة: wildcard مناسب للاختبار المحلي فقط. عند نشر النظام، استبدله بعناوين الواجهات الفعلية، ولا تفعّل `credentials: true` مع wildcard.
