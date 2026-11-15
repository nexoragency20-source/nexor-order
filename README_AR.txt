إصلاح 403 لنافذة محادثة الموقع في NEXOR

الملف:
backend/src/conversations/conversations.controller.ts

سبب الإصلاح:
المتصفح لا يرسل Origin في بعض طلبات GET من نفس الموقع.
كان Controller يمرر Origin فقط، فيرفض فحص النطاق الطلب.
أصبح يمرر Referer كبديل عند غياب Origin. الخدمة تستخرج منه Origin
عبر new URL(...).origin وتقارنه بقائمة النطاقات المسموحة.

طريقة التركيب:
1) أوقف Backend عبر Ctrl+C.
2) انسخ الملف الموجود داخل backend/src/conversations إلى المسار نفسه في مشروعك واستبدله.
3) من مجلد backend نفّذ:
   npm run build
   npm run start:dev
4) أعد تحميل صفحة المتجر التجريبية Ctrl+Shift+R.

هذا الإصلاح يعالج رفض 403 الناتج عن غياب Origin فقط.
لا يعالج أخطاء اتصال قاعدة بيانات Neon (P1001/P1017) ولا أخطاء اتصال Gemini
(fetch failed) الظاهرة في السجل؛ لها فحوص مستقلة.
