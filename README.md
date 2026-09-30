# Konj Planner

Flutter offline personal planner.

- Application ID: `com.konj.planner`
- Display name: `Konj Planner`
- Android home-screen widget: `KonjWidgetProvider`
- Launcher icon: `logo.png`
Konj Planner
نسخه نهایی آفلاین برنامه‌ریز شخصی کُنج.
امکانات
کارها با سه بخش «نیاز به انجام»، «عقب‌افتاده» و «انجام‌شده»
ستاره‌دار کردن و زیرمجموعه برای کارها
یادآوری کارها و برنامه‌های تقویم
پیام‌های امیدبخش هفتگی
تقویم شمسی / میلادی
اهداف با ددلاین و درصد پیشرفت
مدیریت درآمد و هزینه با عنوان، دسته و توضیحات/یادداشت
جستجو در تراکنش‌ها، شامل توضیحات
پشتیبان‌گیری و بازیابی
تم و رنگ‌بندی
ویجت واقعی صفحه اصلی اندروید
ذخیره اطلاعات با SharedPreferences و مهاجرت افزایشی داده‌ها
نام برنامه: Konj Planner
Build
Workflow موجود در `.github/workflows/android-build.yml` با Flutter Stable، Java 17 و تنظیمات سازگار با AGP 9، APK را می‌سازد.
Update safety
برای حفظ اطلاعات هنگام آپدیت:
package باید `com.konj.planner` بماند.
versionCode باید در هر نسخه افزایش پیدا کند.
برنامه را برای آپدیت حذف (Uninstall) نکنید.
APK نسخه جدید باید با همان signing key نسخه قبلی منتشر شود.
