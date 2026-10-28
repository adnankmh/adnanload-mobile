# ADNANLOAD Mobile V2.1 — إنشاء Release APK عبر GitHub Actions

## الطريقة الأولى: تشغيل ملف رفع المشروع على Windows (بدون Flutter)

1. فك ضغط الحزمة كاملة، وادخل إلى مجلد المشروع. **لا ترفع ملف ZIP وحده إلى المستودع**.
2. ثبّت فقط [Git for Windows](https://git-scm.com/downloads/win) و[GitHub CLI](https://cli.github.com/) ثم أغلق وافتح النافذة من جديد.
3. شغّل **`UPLOAD_TO_GITHUB.bat`**، وسجّل الدخول إلى GitHub عند مطالبتك، ثم وافق على الاسم المقترح `adnanload-mobile`.
4. ينشئ السكربت مستودعًا **خاصًا Private** ويرفع ملفات المشروع بما فيها `.github/workflows/android-ci.yml`. لا يحتاج إلى Flutter أو Android Studio.
5. عند كل تعديل مستقبلي يمكن استخدام الملف مرة أخرى لرفع تحديثات المشروع (بعد التحقق من مستودع `origin`).

## الطريقة الثانية: GitHub Desktop

إذا لا ترغب في استخدام GitHub CLI، ثبّت [GitHub Desktop](https://desktop.github.com/)، وسجّل الدخول. اختر **File > Add local repository** وحدد مجلد المشروع المفكوك. اختر **Create a repository here** إذا ظهر الاقتراح، ثم **Publish repository** مع إبقاء خيار **Keep this code private** مفعّلًا.

## طريقة بناء الـAPK

1. افتح مستودع `adnanload-mobile` في حساب GitHub.
2. من أعلى الصفحة افتح **Actions**. إن ظهر طلب السماح بالـWorkflows وافق عليه.
3. اختر **ADNANLOAD - Release APK** من القائمة الجانبية.
4. يمكنك الضغط **Run workflow**، واختيار فرع `main`، ثم الضغط على **Run workflow**. يبدأ البناء أيضًا تلقائيًا عند رفع الملفات إلى `main`.
5. اترك `split_apks` غير مفعل لإنتاج ملف `app-release.apk` شامل للمعماريات المدعومة. يمكن تفعيله لإنشاء APKs إضافية أصغر، مثل `app-arm64-v8a-release.apk`.
6. بعد ظهور علامة النجاح الخضراء، افتح التشغيل ثم **Artifacts** ونزّل **ADNANLOAD-v2.1-RELEASE-APK**.
7. فك ضغط الـArtifact وستجد ملف APK وملفات فحص `SHA256SUMS.txt` و`FILES.txt`.
8. في حالة الفشل افتح أول خطوة حمراء داخل التشغيل وانسخ **نص رسالة الخطأ**؛ من دون نجاح البناء لن يظهر APK.

## مهم: توقيع النشر (Production Signing)

بدون مفتاح خاص، يُنتج Flutter ملف APK **Release mode** لكنه موقّع بمفتاح Debug مؤقت على خادم GitHub، مناسب للاختبار فقط. لن تستطيع تحديث نسخة ثبتها بهذا المفتاح من تشغيل لاحق يستخدم مفتاحًا مختلفًا.

للحصول على توقيع ثابت، أنشئ مفتاح JKS على جهاز به Java/JDK، واحفظ نسخة احتياطية آمنة منه، ثم أضف الأسرار التالية من **Repository > Settings > Secrets and variables > Actions > New repository secret**:

- `ADNANLOAD_KEYSTORE_BASE64`: ملف JKS مشفر بترميز Base64.
- `ADNANLOAD_STORE_PASSWORD`: كلمة مرور مخزن المفاتيح.
- `ADNANLOAD_KEY_PASSWORD`: كلمة مرور المفتاح.
- `ADNANLOAD_KEY_ALIAS`: اسم المفتاح داخل المخزن.

مثال لإنشاء مخزن مفاتيح من PowerShell (يحتاج Java JDK):

```powershell
keytool -genkeypair -v -keystore adnanload-release.jks -storetype PKCS12 -keyalg RSA -keysize 3072 -validity 10000 -alias adnanload
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path './adnanload-release.jks'))) | Set-Clipboard
```

الصق محتويات الحافظة في Secret الأول فقط. **لا ترفع ملف JKS أو كلمات المرور إلى المستودع أو المحادثة**. تتوقف الـWorkflow إذا كانت بعض الأسرار موجودة وبعضها مفقود. عند اكتمالها، يضيف السكربت إعدادات التوقيع إلى Gradle وقت البناء فقط.

## ملاحظات تقنية

- Flutter `3.47.8` وJava `17` ينصّبهما GitHub Actions تلقائيًا على Ubuntu، وليس على جهازك.
- تولَّد ملفات `android/` خلال البناء بواسطة `flutter create`، ثم تُضاف إعدادات Android الخاصة بالمشروع من `tools/configure_android.py`.
- تتم مراجعة التبعيات بـ`flutter pub get`، وفحص الكود بـ`flutter analyze`، وتشغيل اختبارات Flutter قبل تجميع APK.
- **لم يُنفّذ تجميع APK فعلي داخل هذه البيئة**. قد تكشف أول محاولة على GitHub أخطاء في التبعيات أو Gradle أو Flutter؛ عندها يلزم تحليل سجل Actions وتعديل المصدر.
