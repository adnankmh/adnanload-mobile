> **لإنشاء Release APK عبر GitHub Actions:** راجع `GITHUB_ACTIONS_AR.md`، وشغّل `UPLOAD_TO_GITHUB.bat` من Windows بعد تثبيت Git وGitHub CLI.

# ADNANLOAD MOBILE v2.1.3 — برنامج تنزيل شامل لهواتف Android / Flutter

## ما الجديد في النسخة المصححة؟

هذه نسخة مصدر **حقيقية** مكملة لملف V2.0 الأصلي. لم نحذف محرك التنزيل أو الصفحات أو الاختبارات السابقة.

- **حل مشكلة إغلاق `BUILD_ANDROID.bat` فورًا:** النافذة تبقى مفتوحة في النجاح والفشل؛ ورسالة خطأ عربية/إنجليزية مفهومة وسجل `build_logs/android_*.txt` لكل محاولة.
- **إلغاء الحاجة إلى Python على Windows** بواسطة `tools/build_android.ps1` و`tools/configure_android.ps1`؛ بقيت أدوات Python الأصلية لتشغيل البناء داخل GitHub Actions.
- **اكتشاف Flutter** من متغير PATH أو أماكن تثبيت شائعة، وفحص نسخة Dart ووجود Android SDK قبل الشروع في البناء.
- **تصحيح التوافق**: Dart 3.13+ / Flutter 3.47+ متوافق مع `background_downloader 9.6.4`.
- **إضافة زر بناء Debug APK** (`BUILD_DEBUG_APK.bat`) لإنتاج نسخة اختبار؛ الملف الرئيسي يبني Release APK ARM64 + AAB للتحقق من التجميع.
- **إضافة سجل تفصيلي وSHA-256 والحجم الحقيقي** لكل APK/AAB يتم إنشاؤه على Windows، مع تحذير واضح بشأن توقيع Play Store.
- **إضافة Permissions ملائمة لخدمة بيانات Android**، وفحص جاف ثابت للعقد البرمجي وملفات المشروع.
- **تثبيت Flutter 3.47.8 في GitHub Actions** مع إضافة Debug APK كملف تنزيل منفصل بجانب Release/APK وAAB.

## كيفية البناء باستخدام Windows — خطوة بخطوة

1. فك ضغط ملف ZIP إلى مجلد بسيط، على سبيل المثال `C:\ADNANLOAD`؛ لا تشغله من داخل ZIP.
2. إن لم يكن Flutter مثبتًا: ثبّت **Flutter stable 3.47 أو أحدث** (يتضمن Dart 3.13 أو أحدث) من https://docs.flutter.dev/get-started/install/windows/mobile .
3. ثبّت **Android Studio** وأداة Android SDK وSDK Platform + Build Tools، واستخدم JDK 17 أو النسخة التي يدعمها إصدار Flutter/Android Gradle الحالي. شغّل `flutter doctor -v` ووافق على التراخيص عند طلبها بواسطة `flutter doctor --android-licenses`.
4. اضغط مرتين على **`BUILD_ANDROID.bat`**. سيُنشئ مجلد `android/` تلقائيًا إذا لم يوجد، ويجهز الـManifest والأيقونات والترجمات وGradle، ثم ينفذ `flutter pub get` و`flutter analyze` و`flutter test` وبناء Android.
5. لإنتاج نسخة اختبار أسرع، اضغط **`BUILD_DEBUG_APK.bat`**. الناتج يكون في `build\app\outputs\flutter-apk\app-debug.apk`.
6. ناتج الإصدار العادي يكون عادةً `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`؛ وتوجد حزمة AAB في `build\app\outputs\bundle\release\`.
7. **النافذة لن تختفي**، وتجد سبب أي خطأ في `build_logs\android_release_YYYYMMDD_HHMMSS.txt` أو سجل Debug المماثل.

> **مهم:** لا يمكن لأي ملف BAT تجميع تطبيق Flutter على جهاز لا يحتوي على Flutter وAndroid SDK وملفات البناء اللازمة. الملف الجديد يكتشف النقص ويشرحه بدلاً من الإغلاق الصامت. إذا لا ترغب في تثبيت هذه الأدوات، استخدم GitHub Actions أدناه.

## بناء Release APK عبر GitHub بدون Flutter على Windows

- **استخدم الدليل المحدث `GITHUB_ACTIONS_AR.md`**؛ يشرح الرفع الآلي للمستودع الخاص عبر `UPLOAD_TO_GITHUB.bat` أو GitHub Desktop، ثم تشغيل Actions وتنزيل ملف `ADNANLOAD-v2.1.3-RELEASE-APK`.
- المسار الافتراضي يبني `app-release.apk` لمعمارية **ARM64 فقط** لتفادي نفاد مساحة GitHub Runner. ويمكن إنتاج نسخ معماريات أخرى عبر خيار `split_apks` يدويًا، وقد تحتاج مساحة بناء أكبر.
- من دون أسرار التوقيع الأربع، يكون ملف Release mode موقّعًا بمفتاح اختبار Debug، وليس مفتاح توزيع ثابت. تفاصيل التوقيع في الدليل.

## الميزات المحفوظة

- إدارة ملفات HTTP/HTTPS المباشرة، الطابور، إيقاف/استئناف/إلغاء، التنزيل المتوازي الجزئي عندما يدعم الخادم Range، تحكم في Wi-Fi والبطارية، وجدولة Android للملفات المباشرة.
- تنزيل الوسائط (فيديو وصوت) من المواقع المدعومة قانونيًا بمحرك `extractor`، اختيار الجودة، القوائم الكاملة أو عناصر مختارة، ومعاينة بعض القوائم العامة بمكتبة `yt_extractor`.
- تحويل الصوت والفيديو محليًا بـFFmpeg، مشاركة الروابط، التنزيل الجماعي حتى 100 رابط، تصدير الملفات إلى مجلد التنزيلات، البحث في الملفات، المتصفح الداخلي، الخصوصية، الرقم السري، النسخ الاحتياطي والاستعادة، التشخيص.
- واجهة تكيفية Android، تنقل أسفل الشاشة، RTL العربية/LTR الإنجليزية، 8 أنماط لونية منها Neon وGold وAMOLED وLight.

## قيود موثقة

- **ليست كل المواقع مضمونة**؛ DRM والمحتوى المحمي والروابط المقيدة والواجهات التي تتغير خارج نطاق الضمان.
- عمل تنزيلات الوسائط عند قتل التطبيق قسريًا ليس مضمونًا. جدولة Android تقريبية وليست دقيقة بالدقيقة.
- محرك FFmpeg Native يزيد حجم APK؛ الحجم **لا يقاس** إلا بعد التجميع الفعلي.
- الفحوص الثابتة لا تعني نجاح `flutter analyze` أو Gradle أو اختبار التحميل على هاتف. تفاصيل الاختبار تتطلب Android SDK وجهازًا أو محاكيًا.
- لا يوجد دعم iOS مقصود في هذا المشروع.

صنع بواسطة م. عدنان حمدان — ADNANLOAD.
