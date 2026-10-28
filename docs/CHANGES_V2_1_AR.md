# ADNANLOAD Mobile 2.1 — إصلاح مسار بناء Android

الأساس: ADNANLOAD Mobile V2.0 Ultimate (الحزمة التي قدمها المستخدم).

التغييرات المثبتة في الشيفرة:
1. إظهار الأخطاء وعدم إغلاق نافذة Windows عند الفشل، مع حفظ سجلات بناء مؤرخة.
2. مشغل PowerShell لا يحتاج Python على Windows، مع إبقاء أداة Python القديمة لـGitHub CI.
3. التحقق من نسخة Dart >=3.13.0 اللازمة لإصدارات مكتبات التنزيل الحديثة.
4. فحص وجود Android SDK وFlutter، ومسارات العثور على Flutter محليًا.
5. حفظ أسماء APK وأحجامها الفعلية وSHA256 بعد نجاح التجميع.
6. بناء Debug APK منفصل، وإضافته إلى حزمة Artifacts في GitHub Actions.
7. إضافة متطلبات FOREGROUND_SERVICE_DATA_SYNC الخاصة بتنزيلات Android الحديثة.
8. تحديث اسم النسخة الظاهر في التشخيصات والإعدادات وتثبيت CI على Flutter 3.47.8.

الميزات الموروثة: جميع المكتبات والصفحات والاختبارات الخاصة بـV2.0 محفوظة.

الاختبارات المنفذة محليًا: أدوات Python لتدقيق شجرة المشروع وترجمات الواجهة وManifest.
الاختبارات **غير المنفذة**: Windows PowerShell الفعلي، Flutter analyze/test، Gradle APK/AAB، التشغيل على Android. لا ترفع أي ادعاء بوجود APK معتمد قبل نجاح GitHub CI أو بناء Windows.
