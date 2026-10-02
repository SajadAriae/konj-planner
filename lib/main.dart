importimport 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:timezone/data/latest.dart' as tzd;
import 'package:timezone/timezone.dart' as tz;

// ───────────────────────── تنظیمات و ثابت‌ها ─────────────────────────
const kVer = 5; // نسخه‌ی ساختار داده؛ با تغییر ساختار بالا ببر و در D.load مهاجرت بنویس
final notif = FlutterLocalNotificationsPlugin();
late SharedPreferences prefs;
final look = ValueNotifier<int>(0); // با هر تغییر ظاهر (رنگ/حالت تیره) زیاد می‌شود
bool jal = true;

// ───────────────────────── صدای محیط برنامه ─────────────────────────
final _sfxPlayer = AudioPlayer();
Future<void> sfx(String name) async {
  try {
    if (!(prefs.getBool('sfx') ?? true)) return;
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource('sounds/$name.wav'));
  } catch (_) {}
}

const gmn = ['ژانویه', 'فوریه', 'مارس', 'آوریل', 'مه', 'ژوئن', 'ژوئیه', 'اوت', 'سپتامبر', 'اکتبر', 'نوامبر', 'دسامبر'];

class Pal {
  final String name;
  final Color c;
  final Color? darkBg;
  const Pal(this.name, this.c, [this.darkBg]);
}

const pals = [
  Pal('فیروزه‌ای', Colors.teal),
  Pal('آبی سرمه‌ای', Colors.indigo),
  Pal('صورتی', Colors.pink),
  Pal('نارنجی (خاکستری تیره در حالت شب)', Colors.orange, Color(0xFF1E1E1E)),
  Pal('بنفش', Colors.purple),
  Pal('خاکستری آبی', Colors.blueGrey),
  Pal('خاکستری تیره', Colors.grey, Color(0xFF161616)),
];

ThemeData mk(Pal p, Brightness b) {
  var s = ColorScheme.fromSeed(seedColor: p.c, brightness: b);
  final bg = b == Brightness.dark ? p.darkBg : null;
  if (bg != null) {
    Color up(double a) => Color.lerp(bg, Colors.white, a)!;
    s = s.copyWith(
        primary: p.c == Colors.grey ? Colors.orange : p.c,
        onPrimary: Colors.black,
        surface: bg,
        surfaceContainerLowest: bg,
        surfaceContainerLow: up(.05),
        surfaceContainer: up(.08),
        surfaceContainerHigh: up(.11),
        surfaceContainerHighest: up(.14));
  }
  return ThemeData(useMaterial3: true, colorScheme: s, scaffoldBackgroundColor: bg);
}

const wdn = {6: 'شنبه', 7: 'یکشنبه', 1: 'دوشنبه', 2: 'سه‌شنبه', 3: 'چهارشنبه', 4: 'پنجشنبه', 5: 'جمعه'};
const wdo = [6, 7, 1, 2, 3, 4, 5];
const jmn = ['فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', 'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'];
const hope = [
  'امروز لازم نیست کامل باشی؛ یک قدم کوچیک هم حساب می‌شه.',
  'هر کاری که امروز انجام دادی، از دیروز جلوترت می‌بره.',
  'خسته شدن یعنی تلاش کردی. کمی نفس بکش و ادامه بده.',
  'کارهای بزرگ از همین قدم‌های کوچیک ساخته می‌شن.',
  'روزهای سخت‌تر از این رو هم رد کردی؛ این روز هم رد می‌شه.',
  'نتیجه‌ی امروزت ممکنه فردا معلوم بشه. به مسیر اعتماد کن.',
  'هر روز یه شروع تازه‌ست. همین الان یه کار کوچیک رو شروع کن.',
  'پیشرفت یعنی هر روز یه کم بهتر، نه یه روز عالی.',
  'تو از چیزی که فکر می‌کنی تواناتری.',
  'اگه امروز فقط یه کار رو انجام بدی، باز هم امروزت بی‌ثمر نبوده.',
  'اشتباه کردن یعنی در حال یادگرفتنی.',
  'آروم برو، ولی نایست.',
  'امروز با خودت مهربون باش؛ تو دقیقاً داری تمام تلاشت رو می‌کنی.',
  'مسیرت رو دوست داشته باش، نه فقط مقصدت رو.',
  'کار سخت امروز، آرامش فردای توئه.',
  'هیچ زنجیره‌ای یک‌شبه ساخته نشده؛ حلقه‌ی امروز رو اضافه کن.',
  'تمرکز یعنی انتخاب یک کار و دادن همه‌ی توجهت به اون.',
  'نگران همه‌ی پله‌ها نباش، فقط پله‌ی بعدی رو ببین.',
  'یه نفس عمیق بکش. هنوز خیلی چیزها دست خودته.',
  'امروز یه کار برای آینده‌ی خودت انجام بده.',
  'پایداری از استعداد مهم‌تره.',
  'کم‌کم و هر روز، قوی‌ترین راه رسیدنه.',
  'افتادن مهم نیست؛ بلند شدن مهمه.',
  'یادت باشه چقدر راه اومدی، نه فقط چقدر مونده.',
  'بزرگ‌ترین قدم، همونیه که الان برمی‌داری.',
  'ذهنت رو سبک کن: بنویس، بسپار، ادامه بده.',
  'هر ساعت تمرکز، یه سرمایه‌گذاری برای خودته.',
  'استراحت هم بخشی از کاره؛ بدون عذاب وجدان.',
  'امروز رو برای خودت بساز، نه برای ثابت‌کردن به بقیه.',
  'تو لایق روزی هستی که ازش راضی باشی.',
  'هدف‌های بزرگ با عادت‌های کوچیک نزدیک می‌شن.',
  'اگه سخته، یعنی داری رشد می‌کنی.',
  'لبخند بزن؛ امروز هم یه فرصت جدیده.',
  'خودت رو با دیروزِ خودت مقایسه کن، نه با دیگران.',
  'یه کار کوچیک رو همین الان تموم کن و حالش رو ببر.',
];

String hopeFor(DateTime d) => hope[(DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000) % hope.length];

// ───────────────────────── قهرمان، سکه و جایزه ─────────────────────────
class GAnimal {
  final String id, name, emoji, love;
  const GAnimal(this.id, this.name, this.emoji, this.love);
}

const gAnimals = [
  GAnimal('cat', 'گربه', '🐱', 'fish'),
  GAnimal('dog', 'سگ', '🐶', 'meat'),
  GAnimal('dragon', 'اژدها', '🐲', 'spicy'),
  GAnimal('crow', 'کلاغ', '🐦', 'cookie'),
  GAnimal('snake', 'مار', '🐍', 'egg'),
];

class GItem {
  final String id, name, emoji, slot, love, how;
  final int price, xp;
  const GItem(this.id, this.name, this.emoji, this.slot, {this.price = 0, this.xp = 0, this.love = '', this.how = ''});
}

const slotNames = {'food': 'غذا', 'hat': 'کلاه', 'face': 'عینک و صورت', 'neck': 'گردن', 'back': 'پشت', 'hand': 'دست'};

const gItems = [
  GItem('fd_apple', 'سیب', '🍎', 'food', price: 8, xp: 15),
  GItem('fd_fish', 'ماهی', '🐟', 'food', price: 18, xp: 30, love: 'fish'),
  GItem('fd_meat', 'گوشت', '🍖', 'food', price: 18, xp: 30, love: 'meat'),
  GItem('fd_pepper', 'فلفل آتشین', '🌶️', 'food', price: 18, xp: 30, love: 'spicy'),
  GItem('fd_cookie', 'کلوچه', '🍪', 'food', price: 18, xp: 30, love: 'cookie'),
  GItem('fd_egg', 'تخم‌مرغ', '🥚', 'food', price: 18, xp: 30, love: 'egg'),
  GItem('fd_cake', 'کیک', '🍰', 'food', price: 45, xp: 70),
  GItem('fd_feast', 'سفره‌ی ویژه', '🍲', 'food', price: 90, xp: 150),
  GItem('h_cap', 'کپ', '🧢', 'hat', price: 30),
  GItem('h_straw', 'کلاه حصیری', '👒', 'hat', price: 50),
  GItem('h_top', 'کلاه سیلندر', '🎩', 'hat', price: 60),
  GItem('h_grad', 'کلاه فارغ‌التحصیلی', '🎓', 'hat', price: 90),
  GItem('h_helm', 'کلاه‌خود', '🪖', 'hat', price: 120),
  GItem('h_crown', 'تاج سلطنتی', '👑', 'hat', price: 250),
  GItem('f_glass', 'عینک طبی', '👓', 'face', price: 25),
  GItem('f_sun', 'عینک آفتابی', '🕶️', 'face', price: 45),
  GItem('f_gog', 'عینک غواصی', '🥽', 'face', price: 60),
  GItem('n_ribbon', 'پاپیون', '🎀', 'neck', price: 20),
  GItem('n_scarf', 'شال گردن', '🧣', 'neck', price: 30),
  GItem('n_pearl', 'گردنبند', '📿', 'neck', price: 80),
  GItem('n_medal', 'مدال', '🏅', 'neck', price: 100),
  GItem('b_bag', 'کوله‌پشتی', '🎒', 'back', price: 40),
  GItem('b_umb', 'چتر', '☂️', 'back', price: 50),
  GItem('b_wing', 'بال', '🪽', 'back', price: 180),
  GItem('a_tea', 'چای', '☕', 'hand', price: 20),
  GItem('a_book', 'کتاب', '📚', 'hand', price: 45),
  GItem('a_guitar', 'گیتار', '🎸', 'hand', price: 70),
  GItem('a_shield', 'سپر', '🛡️', 'hand', price: 80),
  GItem('a_sword', 'شمشیر', '⚔️', 'hand', price: 100),
  GItem('a_wand', 'عصای جادویی', '🪄', 'hand', price: 130),
  GItem('a_orb', 'گوی جادویی', '🔮', 'hand', price: 160),
  // جایزه‌های ویژه (فقط با دستاورد باز می‌شن)
  GItem('sp_streak7', 'شعله‌ی ثبات', '🔥', 'neck', how: 'نگه‌داشتن زنجیره‌ی یک عادت به مدت ۷ روز'),
  GItem('sp_streak30', 'جام ثابت‌قدم', '🏆', 'hand', how: 'نگه‌داشتن زنجیره‌ی یک عادت به مدت ۳۰ روز'),
  GItem('sp_streak100', 'نشان ستاره‌ای', '🌟', 'hat', how: 'نگه‌داشتن زنجیره‌ی یک عادت به مدت ۱۰۰ روز'),
  GItem('sp_goal1', 'نشان هدف‌گذار', '🎯', 'neck', how: 'رسیدن به اولین هدف'),
  GItem('sp_goal5', 'کمان طلایی', '🏹', 'hand', how: 'رسیدن به ۵ هدف'),
  GItem('sp_focus10', 'هاله‌ی تمرکز', '🌀', 'back', how: 'جمع شدن ۱۰ ساعت تمرکز'),
  GItem('sp_lvl10', 'الماس قهرمانی', '💎', 'neck', how: 'رسیدن یکی از قهرمان‌ها به سطح ۱۰'),
];

GItem? itemById(String id) => gItems.where((i) => i.id == id).firstOrNull;
GAnimal animalById(String id) => gAnimals.firstWhere((a) => a.id == id, orElse: () => gAnimals.first);
bool hDoneG(Map h, String d) => (h['log'] as List).contains(d);

int streakG(Map h) {
  final now = DateTime.now();
  var d = DateTime(now.year, now.month, now.day), c = 0;
  if (!hDoneG(h, ds(d))) d = DateTime(d.year, d.month, d.day - 1);
  while (hDoneG(h, ds(d))) {
    c++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return c;
}

Map<String, dynamic> readMoods() {
  try {
    return Map<String, dynamic>.from(jsonDecode(prefs.getString('moods') ?? '{}') as Map);
  } catch (_) {
    return {};
  }
}

int focusCoins(int min) => (min * 0.4).round();

class Gm {
  static int coins = 0, active = 0, focusTotal = 0, pool = 0;
  static List<Map> heroes = [];
  static Map<String, int> inv = {};
  static Set<String> rw = {};
  static void Function(String msg, bool big)? onEvent;

  static int need(int lv) => 100 + 60 * (lv - 1);
  static void say(String m, [bool big = false]) => onEvent?.call(m, big);

  static void load() {
    heroes = [];
    inv = {};
    rw = {};
    coins = 0;
    active = 0;
    focusTotal = 0;
    pool = 0;
    try {
      final raw = prefs.getString('hero');
      if (raw != null && raw.isNotEmpty) {
        final m = jsonDecode(raw) as Map;
        coins = (m['coins'] as num?)?.toInt() ?? 0;
        active = (m['active'] as num?)?.toInt() ?? 0;
        focusTotal = (m['focus'] as num?)?.toInt() ?? 0;
        pool = (m['pool'] as num?)?.toInt() ?? 0;
        heroes = (m['heroes'] as List? ?? []).map<Map>((e) => Map<String, dynamic>.from(e as Map)).toList();
        inv = {for (final e in (m['inv'] as Map? ?? {}).entries) '${e.key}': (e.value as num).toInt()};
        rw = {for (final e in (m['rw'] as List? ?? [])) '$e'};
      }
    } catch (_) {}
    for (final h in heroes) {
      h['eq'] = Map<String, dynamic>.from((h['eq'] as Map?) ?? {});
      h['lv'] ??= 1;
      h['xp'] ??= 0;
    }
    active = heroes.isEmpty ? 0 : active.clamp(0, heroes.length - 1).toInt();
  }

  static Future<void> save() async {
    final cut = ds(DateTime.now().subtract(const Duration(days: 45)));
    rw.removeWhere((k) => k.startsWith('h:') && k.split(':').last.compareTo(cut) < 0);
    await prefs.setString('hero', jsonEncode({'coins': coins, 'active': active, 'focus': focusTotal, 'pool': pool, 'heroes': heroes, 'inv': inv, 'rw': rw.toList()}));
  }

  static void addXp(int x) {
    if (heroes.isEmpty) {
      pool += x;
      return;
    }
    final h = heroes[active];
    h['xp'] = (h['xp'] as int) + x;
    while ((h['xp'] as int) >= need(h['lv'] as int)) {
      h['xp'] = (h['xp'] as int) - need(h['lv'] as int);
      h['lv'] = (h['lv'] as int) + 1;
      final bonus = (h['lv'] as int) * 5;
      coins += bonus;
      say('🎉 ${h['n']} به سطح ${h['lv']} رسید!\nجایزه‌ی ارتقا: $bonus سکه', true);
    }
    checkSpecials();
  }

  static void earn(int c, int x, [String? msg]) {
    coins += c;
    addXp(x);
    save();
    if (msg != null) say(msg);
  }

  static void grant(String id) {
    if ((inv[id] ?? 0) > 0) return;
    inv[id] = 1;
    final it = itemById(id);
    say('🎁 جایزه‌ی ویژه!\n${it?.emoji ?? ''} ${it?.name ?? id}\nاز بخش «قهرمان ← جوایز» بپوشونش.', true);
  }

  static void checkSpecials() {
    if (rw.where((k) => k.startsWith('g:')).isNotEmpty) grant('sp_goal1');
    if (rw.where((k) => k.startsWith('g:')).length >= 5) grant('sp_goal5');
    if (focusTotal >= 600) grant('sp_focus10');
    if (heroes.any((h) => (h['lv'] as int) >= 10)) grant('sp_lvl10');
  }

  static void taskDone(Map k) {
    if (k['rw'] == true) return;
    k['rw'] = true;
    final c = k['star'] == true ? 8 : 5;
    earn(c, c * 2, '+$c سکه 🪙');
  }

  static void habitDone(Map h, String day) {
    final key = 'h:${h['id']}:$day';
    if (!rw.add(key)) return;
    earn(4, 8, '+۴ سکه 🪙');
    final s = streakG(h);
    const ms = {7: 40, 14: 80, 30: 200, 60: 400, 100: 800, 365: 3000};
    for (final e in ms.entries) {
      if (s >= e.key && rw.add('s:${h['id']}:${e.key}')) {
        coins += e.value;
        say('🔥 زنجیره‌ی ${e.key} روزه‌ی «${h['t']}»!\nجایزه: ${e.value} سکه', true);
        if (e.key == 7) grant('sp_streak7');
        if (e.key == 30) grant('sp_streak30');
        if (e.key == 100) grant('sp_streak100');
        save();
      }
    }
  }

  static void goalDone(Map g) {
    if (!rw.add('g:${g['id']}')) return;
    coins += 150;
    addXp(100);
    say('🏁 به هدف «${g['t']}» رسیدی!\nجایزه: ۱۵۰ سکه و ۱۰۰ تجربه', true);
    checkSpecials();
    save();
  }

  static void focusDone(int min) {
    focusTotal += min;
    final c = focusCoins(min);
    coins += c;
    addXp(min);
    say('🧠 $min دقیقه تمرکز کامل شد!\n+$c سکه و +$min تجربه', true);
    checkSpecials();
    save();
  }

  static void checkin(String day) {
    if (!rw.add('m:$day')) return;
    earn(5, 10, '+۵ سکه برای ثبت حال روز 🪙');
  }

  static bool buy(GItem it) {
    if (coins < it.price) return false;
    if (it.slot != 'food' && (inv[it.id] ?? 0) > 0) return false;
    coins -= it.price;
    inv[it.id] = (inv[it.id] ?? 0) + 1;
    save();
    return true;
  }

  static void equip(Map h, GItem it) {
    final eq = h['eq'] as Map;
    if (eq[it.slot] == it.id) {
      eq.remove(it.slot);
    } else {
      eq[it.slot] = it.id;
    }
    save();
  }

  static String feed(Map h, GItem it) {
    if ((inv[it.id] ?? 0) <= 0) return '';
    inv[it.id] = inv[it.id]! - 1;
    final loved = it.love.isNotEmpty && animalById('${h['a']}').love == it.love;
    final x = loved ? (it.xp * 1.5).round() : it.xp;
    final wasActive = heroes[active] == h;
    if (!wasActive) {
      // غذا همیشه به قهرمان فعال می‌رسد
    }
    addXp(x);
    save();
    return loved ? '${h['n']} عاشق ${it.name} بود! +$x تجربه 😍' : '+$x تجربه برای ${h['n']}';
  }

  static Map create(String animal, String name) {
    final h = <String, dynamic>{'id': DateTime.now().microsecondsSinceEpoch, 'a': animal, 'n': name, 'lv': 1, 'xp': 0, 'eq': <String, dynamic>{}};
    heroes.add(h);
    active = heroes.length - 1;
    if (pool > 0) {
      final p = pool;
      pool = 0;
      addXp(p);
    }
    save();
    return h;
  }
}

Widget heroView(Map h, {double size = 110}) {
  final a = animalById('${h['a']}');
  final eq = Map<String, dynamic>.from((h['eq'] as Map?) ?? {});
  String? e(String slot) => eq[slot] == null ? null : itemById('${eq[slot]}')?.emoji;
  Widget at(double x, double y, String t, double f) => Align(alignment: Alignment(x, y), child: Text(t, style: TextStyle(fontSize: size * f)));
  return SizedBox(
      width: size * 1.7,
      height: size * 1.5,
      child: Stack(alignment: Alignment.center, children: [
        if (e('back') != null) at(-.8, -.05, e('back')!, .5),
        Text(a.emoji, style: TextStyle(fontSize: size)),
        if (e('face') != null) at(0, -.12, e('face')!, .42),
        if (e('neck') != null) at(0, .62, e('neck')!, .36),
        if (e('hat') != null) at(0, -.92, e('hat')!, .46),
        if (e('hand') != null) at(.85, .4, e('hand')!, .42),
      ]));
}

final checkinReq = ValueNotifier<int>(0);
const shakeCh = MethodChannel('konj/shake');

// ───────────────────────── ابزارهای عمومی ─────────────────────────
String ds(DateTime d) => d.toIso8601String().substring(0, 10);
String hm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
// جداکننده‌ی سه‌رقمی با نقطه
String n(num v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
// تبدیل ارقام فارسی/عربی به انگلیسی و حذف جداکننده‌ها
String en(String s) => s
    .replaceAllMapped(RegExp('[۰-۹٠-٩]'), (m) {
      final u = m[0]!.codeUnitAt(0);
      return '${u >= 0x06F0 ? u - 0x06F0 : u - 0x0660}';
    })
    .replaceAll(RegExp(r'[.,٬،/\s]'), '');
int byStart(Map a, Map b) => (a['s'] as int).compareTo(b['s'] as int);
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class ThousandFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue v) {
    var d = en(v.text).replaceAll(RegExp(r'\D'), '');
    if (d.length > 15) d = d.substring(0, 15);
    if (d.isEmpty) return const TextEditingValue(text: '');
    final t = n(int.parse(d));
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

// ───────────────────────── تقویم شمسی ─────────────────────────
List<int> g2j(int gy, int gm, int gd) {
  const gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final gy2 = gm > 2 ? gy + 1 : gy;
  var days = 355666 + 365 * gy + (gy2 + 3) ~/ 4 - (gy2 + 99) ~/ 100 + (gy2 + 399) ~/ 400 + gd + gdm[gm - 1];
  var jy = -1595 + 33 * (days ~/ 12053);
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  final jm = days < 186 ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
  final jd = 1 + (days < 186 ? days % 31 : (days - 186) % 30);
  return [jy, jm, jd];
}

List<int> j2g(int jy, int jm, int jd) {
  jy += 1595;
  var days = -355668 + 365 * jy + (jy ~/ 33) * 8 + ((jy % 33) + 3) ~/ 4 + jd + (jm < 7 ? (jm - 1) * 31 : (jm - 7) * 30 + 186);
  var gy = 400 * (days ~/ 146097);
  days %= 146097;
  if (days > 36524) {
    days--;
    gy += 100 * (days ~/ 36524);
    days %= 36524;
    if (days >= 365) days++;
  }
  gy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    gy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  var gd = days + 1;
  final sal = [0, 31, (gy % 4 == 0 && gy % 100 != 0) || gy % 400 == 0 ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  var gm = 0;
  while (gm < 12 && gd > sal[gm]) {
    gd -= sal[gm];
    gm++;
  }
  return [gy, gm, gd];
}

int jmLen(int y, int m) {
  if (m <= 6) return 31;
  if (m <= 11) return 30;
  final g = j2g(y, 12, 30);
  final b = g2j(g[0], g[1], g[2]);
  return (b[0] == y && b[1] == 12 && b[2] == 30) ? 30 : 29;
}

DateTime jDate(int y, int m, int d) {
  final g = j2g(y, m, d);
  return DateTime(g[0], g[1], g[2]);
}

String fd(String iso) {
  if (!jal) return iso.substring(0, 10);
  final p = iso.substring(0, 10).split('-').map(int.parse).toList();
  final j = g2j(p[0], p[1], p[2]);
  return '${j[0]}/${j[1].toString().padLeft(2, '0')}/${j[2].toString().padLeft(2, '0')}';
}

// تاریخ بلند: «شنبه 7 مهر 1405»
String fdl(DateTime d) {
  if (!jal) return ds(d);
  final j = g2j(d.year, d.month, d.day);
  return '${wdn[d.weekday]} ${j[2]} ${jmn[j[1] - 1]} ${j[0]}';
}

String monthStart(DateTime now) {
  if (!jal) return ds(DateTime(now.year, now.month));
  final j = g2j(now.year, now.month, now.day);
  return ds(jDate(j[0], j[1], 1));
}

// شبکه‌ی ماه شمسی (هم در انتخاب تاریخ و هم در تقویم برنامه)
Widget monthGrid(BuildContext c, int jy, int jm,
    {DateTime? sel, int Function(DateTime)? mark, bool Function(DateTime)? ok, required void Function(DateTime) onTap}) {
  final cs = Theme.of(c).colorScheme;
  final first = jal ? jDate(jy, jm, 1) : DateTime(jy, jm, 1);
  final len = jal ? jmLen(jy, jm) : DateTime(jy, jm + 1, 0).day;
  final off = (first.weekday + 1) % 7;
  final today = DateTime.now();
  final cells = <Widget>[for (var i = 0; i < off; i++) const SizedBox()];
  for (var d = 1; d <= len; d++) {
    final dt = jal ? jDate(jy, jm, d) : DateTime(jy, jm, d);
    final enabled = ok?.call(dt) ?? true;
    final isSel = sel != null && sameDay(dt, sel);
    final isToday = sameDay(dt, today);
    final m = mark?.call(dt) ?? 0;
    final fg = isSel ? cs.onPrimary : (!enabled ? cs.outline.withOpacity(.5) : (dt.weekday == 5 ? Colors.red : null));
    cells.add(InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? () => onTap(dt) : null,
        child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSel ? cs.primary : null,
                border: isToday && !isSel ? Border.all(color: cs.primary) : null),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$d', style:btract(const Duration(days: 45)));
    rw.removeWhere((k) => k.startsWith('h:') && k.split(':').last.compareTo(cut) < 0);
    await prefs.setString('hero', jsonEncode({'coins': coins, 'active': active, 'focus': focusTotal, 'pool': pool, 'heroes': heroes, 'inv': inv, 'rw': rw.toList()}));
  }

  static void addXp(int x) {
    if (heroes.isEmpty) {
      pool += x;
      return;
    }
    final h = heroes[active];
    h['xp'] = (h['xp'] as int) + x;
    while ((h['xp'] as int) >= need(h['lv'] as int)) {
      h['xp'] = (h['xp'] as int) - need(h['lv'] as int);
      h['lv'] = (h['lv'] as int) + 1;
      final bonus = (h['lv'] as int) * 5;
      coins += bonus;
      say('🎉 ${h['n']} به سطح ${h['lv']} رسید!\nجایزه‌ی ارتقا: $bonus سکه', true);
    }
    checkSpecials();
  }

  static void earn(int c, int x, [String? msg]) {
    coins += c;
    addXp(x);
    save();
    if (msg != null) say(msg);
  }

  static void grant(String id) {
    if ((inv[id] ?? 0) > 0) return;
    inv[id] = 1;
    final it = itemById(id);
    say('🎁 جایزه‌ی ویژه!\n${it?.emoji ?? ''} ${it?.name ?? id}\nاز بخش «قهرمان ← جوایز» بپوشونش.', true);
  }

  static void checkSpecials() {
    if (rw.where((k) => k.startsWith('g:')).isNotEmpty) grant('sp_goal1');
    if (rw.where((k) => k.startsWith('g:')).length >= 5) grant('sp_goal5');
    if (focusTotal >= 600) grant('sp_focus10');
    if (heroes.any((h) => (h['lv'] as int) >= 10)) grant('sp_lvl10');
  }

  static void taskDone(Map k) {
    if (k['rw'] == true) return;
    k['rw'] = true;
    final c = k['star'] == true ? 8 : 5;
    earn(c, c * 2, '+$c سکه 🪙');
  }

  static void habitDone(Map h, String day) {
    final key = 'h:${h['id']}:$day';
    if (!rw.add(key)) return;
    earn(4, 8, '+۴ سکه 🪙');
    final s = streakG(h);
    const ms = {7: 40, 14: 80, 30: 200, 60: 400, 100: 800, 365: 3000};
    for (final e in ms.entries) {
      if (s >= e.key && rw.add('s:${h['id']}:${e.key}')) {
        coins += e.value;
        say('🔥 زنجیره‌ی ${e.key} روزه‌ی «${h['t']}»!\nجایزه: ${e.value} سکه', true);
        if (e.key == 7) grant('sp_streak7');
        if (e.key == 30) grant('sp_streak30');
        if (e.key == 100) grant('sp_streak100');
        save();
      }
    }
  }

  static void goalDone(Map g) {
    if (!rw.add('g:${g['id']}')) return;
    coins += 150;
    addXp(100);
    say('🏁 به هدف «${g['t']}» رسیدی!\nجایزه: ۱۵۰ سکه و ۱۰۰ تجربه', true);
    checkSpecials();
    save();
  }

  static void focusDone(int min) {
    focusTotal += min;
    final c = focusCoins(min);
    coins += c;
    addXp(min);
    say('🧠 $min دقیقه تمرکز کامل شد!\n+$c سکه و +$min تجربه', true);
    checkSpecials();
    save();
  }

  static void checkin(String day) {
    if (!rw.add('m:$day')) return;
    earn(5, 10, '+۵ سکه برای ثبت حال روز 🪙');
  }

  static bool buy(GItem it) {
    if (coins < it.price) return false;
    if (it.slot != 'food' && (inv[it.id] ?? 0) > 0) return false;
    coins -= it.price;
    inv[it.id] = (inv[it.id] ?? 0) + 1;
    save();
    return true;
  }

  static void equip(Map h, GItem it) {
    final eq = h['eq'] as Map;
    if (eq[it.slot] == it.id) {
      eq.remove(it.slot);
    } else {
      eq[it.slot] = it.id;
    }
    save();
  }

  static String feed(Map h, GItem it) {
    if ((inv[it.id] ?? 0) <= 0) return '';
    inv[it.id] = inv[it.id]! - 1;
    final loved = it.love.isNotEmpty && animalById('${h['a']}').love == it.love;
    final x = loved ? (it.xp * 1.5).round() : it.xp;
    final wasActive = heroes[active] == h;
    if (!wasActive) {
      // غذا همیشه به قهرمان فعال می‌رسد
    }
    addXp(x);
    save();
    return loved ? '${h['n']} عاشق ${it.name} بود! +$x تجربه 😍' : '+$x تجربه برای ${h['n']}';
  }

  static Map create(String animal, String name) {
    final h = <String, dynamic>{'id': DateTime.now().microsecondsSinceEpoch, 'a': animal, 'n': name, 'lv': 1, 'xp': 0, 'eq': <String, dynamic>{}};
    heroes.add(h);
    active = heroes.length - 1;
    if (pool > 0) {
      final p = pool;
      pool = 0;
      addXp(p);
    }
    save();
    return h;
  }
}

Widget heroView(Map h, {double size = 110}) {
  final a = animalById('${h['a']}');
  final eq = Map<String, dynamic>.from((h['eq'] as Map?) ?? {});
  String? e(String slot) => eq[slot] == null ? null : itemById('${eq[slot]}')?.emoji;
  Widget at(double x, double y, String t, double f) => Align(alignment: Alignment(x, y), child: Text(t, style: TextStyle(fontSize: size * f)));
  return SizedBox(
      width: size * 1.7,
      height: size * 1.5,
      child: Stack(alignment: Alignment.center, children: [
        if (e('back') != null) at(-.8, -.05, e('back')!, .5),
        Text(a.emoji, style: TextStyle(fontSize: size)),
        if (e('face') != null) at(0, -.12, e('face')!, .42),
        if (e('neck') != null) at(0, .62, e('neck')!, .36),
        if (e('hat') != null) at(0, -.92, e('hat')!, .46),
        if (e('hand') != null) at(.85, .4, e('hand')!, .42),
      ]));
}

final checkinReq = ValueNotifier<int>(0);
const shakeCh = MethodChannel('konj/shake');

// ───────────────────────── ابزارهای عمومی ─────────────────────────
String ds(DateTime d) => d.toIso8601String().substring(0, 10);
String hm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
// جداکننده‌ی سه‌رقمی با نقطه
String n(num v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
// تبدیل ارقام فارسی/عربی به انگلیسی و حذف جداکننده‌ها
String en(String s) => s
    .replaceAllMapped(RegExp('[۰-۹٠-٩]'), (m) {
      final u = m[0]!.codeUnitAt(0);
      return '${u >= 0x06F0 ? u - 0x06F0 : u - 0x0660}';
    })
    .replaceAll(RegExp(r'[.,٬،/\s]'), '');
int byStart(Map a, Map b) => (a['s'] as int).compareTo(b['s'] as int);
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class ThousandFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue v) {
    var d = en(v.text).replaceAll(RegExp(r'\D'), '');
    if (d.length > 15) d = d.substring(0, 15);
    if (d.isEmpty) return const TextEditingValue(text: '');
    final t = n(int.parse(d));
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

// ───────────────────────── تقویم شمسی ─────────────────────────
List<int> g2j(int gy, int gm, int gd) {
  const gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final gy2 = gm > 2 ? gy + 1 : gy;
  var days = 355666 + 365 * gy + (gy2 + 3) ~/ 4 - (gy2 + 99) ~/ 100 + (gy2 + 399) ~/ 400 + gd + gdm[gm - 1];
  var jy = -1595 + 33 * (days ~/ 12053);
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  final jm = days < 186 ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
  final jd = 1 + (days < 186 ? days % 31 : (days - 186) % 30);
  return [jy, jm, jd];
}

List<int> j2g(int jy, int jm, int jd) {
  jy += 1595;
  var days = -355668 + 365 * jy + (jy ~/ 33) * 8 + ((jy % 33) + 3) ~/ 4 + jd + (jm < 7 ? (jm - 1) * 31 : (jm - 7) * 30 + 186);
  var gy = 400 * (days ~/ 146097);
  days %= 146097;
  if (days > 36524) {
    days--;
    gy += 100 * (days ~/ 36524);
    days %= 36524;
    if (days >= 365) days++;
  }
  gy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    gy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  var gd = days + 1;
  final sal = [0, 31, (gy % 4 == 0 && gy % 100 != 0) || gy % 400 == 0 ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  var gm = 0;
  while (gm < 12 && gd > sal[gm]) {
    gd -= sal[gm];
    gm++;
  }
  return [gy, gm, gd];
}

int jmLen(int y, int m) {
  if (m <= 6) return 31;
  if (m <= 11) return 30;
  final g = j2g(y, 12, 30);
  final b = g2j(g[0], g[1], g[2]);
  return (b[0] == y && b[1] == 12 && b[2] == 30) ? 30 : 29;
}

DateTime jDate(int y, int m, int d) {
  final g = j2g(y, m, d);
  return DateTime(g[0], g[1], g[2]);
}

String fd(String iso) {
  if (!jal) return iso.substring(0, 10);
  final p = iso.substring(0, 10).split('-').map(int.parse).toList();
  final j = g2j(p[0], p[1], p[2]);
  return '${j[0]}/${j[1].toString().padLeft(2, '0')}/${j[2].toString().padLeft(2, '0')}';
}

// تاریخ بلند: «شنبه 7 مهر 1405»
String fdl(DateTime d) {
  if (!jal) return ds(d);
  final j = g2j(d.year, d.month, d.day);
  return '${wdn[d.weekday]} ${j[2]} ${jmn[j[1] - 1]} ${j[0]}';
}

String monthStart(DateTime now) {
  if (!jal) return ds(DateTime(now.year, now.month));
  final j = g2j(now.year, now.month, now.day);
  return ds(jDate(j[0], j[1], 1));
}

// شبکه‌ی ماه شمسی (هم در انتخاب تاریخ و هم در تقویم برنامه)
Widget monthGrid(BuildContext c, int jy, int jm,
    {DateTime? sel, int Function(DateTime)? mark, bool Function(DateTime)? ok, required void Function(DateTime) onTap}) {
  final cs = Theme.of(c).colorScheme;
  final first = jal ? jDate(jy, jm, 1) : DateTime(jy, jm, 1);
  final len = jal ? jmLen(jy, jm) : DateTime(jy, jm + 1, 0).day;
  final off = (first.weekday + 1) % 7;
  final today = DateTime.now();
  final cells = <Widget>[for (var i = 0; i < off; i++) const SizedBox()];
  for (var d = 1; d <= len; d++) {
    final dt = jal ? jDate(jy, jm, d) : DateTime(jy, jm, d);
    final enabled = ok?.call(dt) ?? true;
    final isSel = sel != null && sameDay(dt, sel);
    final isToday = sameDay(dt, today);
    final m = mark?.call(dt) ?? 0;
    final fg = isSel ? cs.onPrimary : (!enabled ? cs.outline.withOpacity(.5) : (dt.weekday == 5 ? Colors.red : null));
    cells.add(InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? () => onTap(dt) : null,
        child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSel ? cs.primary : null,
                border: isToday && !isSel ? Border.all(color: cs.primary) : null),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$d', style:&& k.split(':').last.compareTo(cut) < 0);
    await prefs.setString('hero', jsonEncode({'coins': coins, 'active': active, 'focus': focusTotal, 'pool': pool, 'heroes': heroes, 'inv': inv, 'rw': rw.toList()}));
  }

  static void addXp(int x) {
    if (heroes.isEmpty) {
      pool += x;
      return;
    }
    final h = heroes[active];
    h['xp'] = (h['xp'] as int) + x;
    while ((h['xp'] as int) >= need(h['lv'] as int)) {
      h['xp'] = (h['xp'] as int) - need(h['lv'] as int);
      h['lv'] = (h['lv'] as int) + 1;
      final bonus = (h['lv'] as int) * 5;
      coins += bonus;
      say('🎉 ${h['n']} به سطح ${h['lv']} رسید!\nجایزه‌ی ارتقا: $bonus سکه', true);
    }
    checkSpecials();
  }

  static void earn(int c, int x, [String? msg]) {
    coins += c;
    addXp(x);
    save();
    if (msg != null) say(msg);
  }

  static void grant(String id) {
    if ((inv[id] ?? 0) > 0) return;
    inv[id] = 1;
    final it = itemById(id);
    say('🎁 جایزه‌ی ویژه!\n${it?.emoji ?? ''} ${it?.name ?? id}\nاز بخش «قهرمان ← جوایز» بپوشونش.', true);
  }

  static void checkSpecials() {
    if (rw.where((k) => k.startsWith('g:')).isNotEmpty) grant('sp_goal1');
    if (rw.where((k) => k.startsWith('g:')).length >= 5) grant('sp_goal5');
    if (focusTotal >= 600) grant('sp_focus10');
    if (heroes.any((h) => (h['lv'] as int) >= 10)) grant('sp_lvl10');
  }

  static void taskDone(Map k) {
    if (k['rw'] == true) return;
    k['rw'] = true;
    final c = k['star'] == true ? 8 : 5;
    earn(c, c * 2, '+$c سکه 🪙');
  }

  static void habitDone(Map h, String day) {
    final key = 'h:${h['id']}:$day';
    if (!rw.add(key)) return;
    earn(4, 8, '+۴ سکه 🪙');
    final s = streakG(h);
    const ms = {7: 40, 14: 80, 30: 200, 60: 400, 100: 800, 365: 3000};
    for (final e in ms.entries) {
      if (s >= e.key && rw.add('s:${h['id']}:${e.key}')) {
        coins += e.value;
        say('🔥 زنجیره‌ی ${e.key} روزه‌ی «${h['t']}»!\nجایزه: ${e.value} سکه', true);
        if (e.key == 7) grant('sp_streak7');
        if (e.key == 30) grant('sp_streak30');
        if (e.key == 100) grant('sp_streak100');
        save();
      }
    }
  }

  static void goalDone(Map g) {
    if (!rw.add('g:${g['id']}')) return;
    coins += 150;
    addXp(100);
    say('🏁 به هدف «${g['t']}» رسیدی!\nجایزه: ۱۵۰ سکه و ۱۰۰ تجربه', true);
    checkSpecials();
    save();
  }

  static void focusDone(int min) {
    focusTotal += min;
    final c = focusCoins(min);
    coins += c;
    addXp(min);
    say('🧠 $min دقیقه تمرکز کامل شد!\n+$c سکه و +$min تجربه', true);
    checkSpecials();
    save();
  }

  static void checkin(String day) {
    if (!rw.add('m:$day')) return;
    earn(5, 10, '+۵ سکه برای ثبت حال روز 🪙');
  }

  static bool buy(GItem it) {
    if (coins < it.price) return false;
    if (it.slot != 'food' && (inv[it.id] ?? 0) > 0) return false;
    coins -= it.price;
    inv[it.id] = (inv[it.id] ?? 0) + 1;
    save();
    return true;
  }

  static void equip(Map h, GItem it) {
    final eq = h['eq'] as Map;
    if (eq[it.slot] == it.id) {
      eq.remove(it.slot);
    } else {
      eq[it.slot] = it.id;
    }
    save();
  }

  static String feed(Map h, GItem it) {
    if ((inv[it.id] ?? 0) <= 0) return '';
    inv[it.id] = inv[it.id]! - 1;
    final loved = it.love.isNotEmpty && animalById('${h['a']}').love == it.love;
    final x = loved ? (it.xp * 1.5).round() : it.xp;
    final wasActive = heroes[active] == h;
    if (!wasActive) {
      // غذا همیشه به قهرمان فعال می‌رسد
    }
    addXp(x);
    save();
    return loved ? '${h['n']} عاشق ${it.name} بود! +$x تجربه 😍' : '+$x تجربه برای ${h['n']}';
  }

  static Map create(String animal, String name) {
    final h = <String, dynamic>{'id': DateTime.now().microsecondsSinceEpoch, 'a': animal, 'n': name, 'lv': 1, 'xp': 0, 'eq': <String, dynamic>{}};
    heroes.add(h);
    active = heroes.length - 1;
    if (pool > 0) {
      final p = pool;
      pool = 0;
      addXp(p);
    }
    save();
    return h;
  }
}

Widget heroView(Map h, {double size = 110}) {
  final a = animalById('${h['a']}');
  final eq = Map<String, dynamic>.from((h['eq'] as Map?) ?? {});
  String? e(String slot) => eq[slot] == null ? null : itemById('${eq[slot]}')?.emoji;
  Widget at(double x, double y, String t, double f) => Align(alignment: Alignment(x, y), child: Text(t, style: TextStyle(fontSize: size * f)));
  return SizedBox(
      width: size * 1.7,
      height: size * 1.5,
      child: Stack(alignment: Alignment.center, children: [
        if (e('back') != null) at(-.8, -.05, e('back')!, .5),
        Text(a.emoji, style: TextStyle(fontSize: size)),
        if (e('face') != null) at(0, -.12, e('face')!, .42),
        if (e('neck') != null) at(0, .62, e('neck')!, .36),
        if (e('hat') != null) at(0, -.92, e('hat')!, .46),
        if (e('hand') != null) at(.85, .4, e('hand')!, .42),
      ]));
}

final checkinReq = ValueNotifier<int>(0);
const shakeCh = MethodChannel('konj/shake');

// ───────────────────────── ابزارهای عمومی ─────────────────────────
String ds(DateTime d) => d.toIso8601String().substring(0, 10);
String hm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
// جداکننده‌ی سه‌رقمی با نقطه
String n(num v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
// تبدیل ارقام فارسی/عربی به انگلیسی و حذف جداکننده‌ها
String en(String s) => s
    .replaceAllMapped(RegExp('[۰-۹٠-٩]'), (m) {
      final u = m[0]!.codeUnitAt(0);
      return '${u >= 0x06F0 ? u - 0x06F0 : u - 0x0660}';
    })
    .replaceAll(RegExp(r'[.,٬،/\s]'), '');
int byStart(Map a, Map b) => (a['s'] as int).compareTo(b['s'] as int);
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class ThousandFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue v) {
    var d = en(v.text).replaceAll(RegExp(r'\D'), '');
    if (d.length > 15) d = d.substring(0, 15);
    if (d.isEmpty) return const TextEditingValue(text: '');
    final t = n(int.parse(d));
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

// ───────────────────────── تقویم شمسی ─────────────────────────
List<int> g2j(int gy, int gm, int gd) {
  const gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final gy2 = gm > 2 ? gy + 1 : gy;
  var days = 355666 + 365 * gy + (gy2 + 3) ~/ 4 - (gy2 + 99) ~/ 100 + (gy2 + 399) ~/ 400 + gd + gdm[gm - 1];
  var jy = -1595 + 33 * (days ~/ 12053);
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  final jm = days < 186 ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
  final jd = 1 + (days < 186 ? days % 31 : (days - 186) % 30);
  return [jy, jm, jd];
}

List<int> j2g(int jy, int jm, int jd) {
  jy += 1595;
  var days = -355668 + 365 * jy + (jy ~/ 33) * 8 + ((jy % 33) + 3) ~/ 4 + jd + (jm < 7 ? (jm - 1) * 31 : (jm - 7) * 30 + 186);
  var gy = 400 * (days ~/ 146097);
  days %= 146097;
  if (days > 36524) {
    days--;
    gy += 100 * (days ~/ 36524);
    days %= 36524;
    if (days >= 365) days++;
  }
  gy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    gy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  var gd = days + 1;
  final sal = [0, 31, (gy % 4 == 0 && gy % 100 != 0) || gy % 400 == 0 ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  var gm = 0;
  while (gm < 12 && gd > sal[gm]) {
    gd -= sal[gm];
    gm++;
  }
  return [gy, gm, gd];
}

int jmLen(int y, int m) {
  if (m <= 6) return 31;
  if (m <= 11) return 30;
  final g = j2g(y, 12, 30);
  final b = g2j(g[0], g[1], g[2]);
  return (b[0] == y && b[1] == 12 && b[2] == 30) ? 30 : 29;
}

DateTime jDate(int y, int m, int d) {
  final g = j2g(y, m, d);
  return DateTime(g[0], g[1], g[2]);
}

String fd(String iso) {
  if (!jal) return iso.substring(0, 10);
  final p = iso.substring(0, 10).split('-').map(int.parse).toList();
  final j = g2j(p[0], p[1], p[2]);
  return '${j[0]}/${j[1].toString().padLeft(2, '0')}/${j[2].toString().padLeft(2, '0')}';
}

// تاریخ بلند: «شنبه 7 مهر 1405»
String fdl(DateTime d) {
  if (!jal) return ds(d);
  final j = g2j(d.year, d.month, d.day);
  return '${wdn[d.weekday]} ${j[2]} ${jmn[j[1] - 1]} ${j[0]}';
}

String monthStart(DateTime now) {
  if (!jal) return ds(DateTime(now.year, now.month));
  final j = g2j(now.year, now.month, now.day);
  return ds(jDate(j[0], j[1], 1));
}

// شبکه‌ی ماه شمسی (هم در انتخاب تاریخ و هم در تقویم برنامه)
Widget monthGrid(BuildContext c, int jy, int jm,
    {DateTime? sel, int Function(DateTime)? mark, bool Function(DateTime)? ok, required void Function(DateTime) onTap}) {
  final cs = Theme.of(c).colorScheme;
  final first = jal ? jDate(jy, jm, 1) : DateTime(jy, jm, 1);
  final len = jal ? jmLen(jy, jm) : DateTime(jy, jm + 1, 0).day;
  final off = (first.weekday + 1) % 7;
  final today = DateTime.now();
  final cells = <Widget>[for (var i = 0; i < off; i++) const SizedBox()];
  for (var d = 1; d <= len; d++) {
    final dt = jal ? jDate(jy, jm, d) : DateTime(jy, jm, d);
    final enabled = ok?.call(dt) ?? true;
    final isSel = sel != null && sameDay(dt, sel);
    final isToday = sameDay(dt, today);
    final m = mark?.call(dt) ?? 0;
    final fg = isSel ? cs.onPrimary : (!enabled ? cs.outline.withOpacity(.5) : (dt.weekday == 5 ? Colors.red : null));
    cells.add(InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? () => onTap(dt) : null,
        child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSel ? cs.primary : null,
                border: isToday && !isSel ? Border.all(color: cs.primary) : null),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$d', style:k('عنوان (مثلاً کلاس ...)', o?['t'] ?? '');
    if (title == null || title.trim().isEmpty || !mounted) return;
    final wd = await showDialog<int>(
        context: context,
        builder: (_) => SimpleDialog(title: const Text('روز هفته'), children: [
              for (final d in wdo) SimpleDialogOption(onPressed: () => Navigator.pop(context, d), child: Text(wdn[d]!))
            ]));
    if (wd == null || !mounted) return;
    final a = await showTimePicker(
        context: context,
        initialTime: o != null ? TimeOfDay(hour: o['s'] ~/ 60, minute: o['s'] % 60) : const TimeOfDay(hour: 8, minute: 0),
        helpText: 'شروع');
    if (a == null || !mounted) return;
    final b = await showTimePicker(
        context: context,
        initialTime: o != null ? TimeOfDay(hour: o['e'] ~/ 60, minute: o['e'] % 60) : a.replacing(hour: (a.hour + 2) % 24),
        helpText: 'پایان');
    if (b == null || !mounted) return;
    final now = DateTime.now();
    final to = await pickDate(context,
        initial: o != null ? DateTime.parse(o['to']) : now.add(const Duration(days: 112)),
        first: DateTime(2020),
        last: now.add(const Duration(days: 1100)),
        help: 'پایان ترم');
    if (to == null) return;
    final e = {
      'id': o?['id'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      't': title.trim(),
      'wd': wd,
      's': a.hour * 60 + a.minute,
      'e': b.hour * 60 + b.minute,
      'from': o?['from'] ?? ds(now),
      'to': ds(to)
    };
    if (o != null) {
      notif.cancel(eventNid(o['id'] as int));
      D.events.remove(o);
    }
    D.events.add(e);
    sfx('add');
    upd(); // اول نمایش و ذخیره؛ بعد اعلان (خطای اعلان دیگر جلوی نمایش را نمی‌گیرد)
    await schedule(e);
  }

  void goM(int d) => setState(() {
        cm += d;
        if (cm > 12) {
          cm = 1;
          cy++;
        }
        if (cm < 1) {
          cm = 12;
          cy--;
        }
      });

  Widget cal() {
    bool onDay(Map e, DateTime d) {
      final s = ds(d);
      return e['wd'] == d.weekday && s.compareTo(e['from']) >= 0 && s.compareTo(e['to']) <= 0;
    }

    int mark(DateTime d) =>
        D.events.where((e) => onDay(e, d)).length + D.tasks.where((k) => k['done'] != true && k['r'] != null && (k['r'] as String).startsWith(ds(d))).length;
    final dayEv = D.events.where((e) => onDay(e, sel)).toList()..sort(byStart);
    final dayTk = D.tasks.where((k) => k['r'] != null && (k['r'] as String).startsWith(ds(sel))).toList();
    final today = DateTime.now();
    return ListView(padding: const EdgeInsets.only(bottom: 90), children: [
      Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(children: [
                Row(children: [
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => goM(-1)),
                  Expanded(child: Center(child: Text('${jmn[cm - 1]} $cy', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
                  TextButton(
                      onPressed: () {
                        final j = g2j(today.year, today.month, today.day);
                        setState(() {
                          cy = j[0];
                          cm = j[1];
                          sel = DateTime(today.year, today.month, today.day);
                        });
                      },
                      child: const Text('امروز')),
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => goM(1)),
                ]),
                monthGrid(context, cy, cm, sel: sel, mark: mark, onTap: (d) => setState(() => sel = d)),
              ]))),
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(fdl(sel), style: const TextStyle(fontWeight: FontWeight.bold))),
      if (dayEv.isEmpty && dayTk.isEmpty) const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('برنامه‌ای برای این روز نیست.')),
      for (final e in dayEv)
        ListTile(dense: true, leading: const Icon(Icons.schedule), title: Text(e['t']), subtitle: Text('${hm(e['s'])} – ${hm(e['e'])}'), onTap: () => addEvent(e)),
      for (final k in dayTk)
        ListTile(
            dense: true,
            leading: Icon(k['done'] == true ? Icons.check_circle : Icons.alarm),
            title: Text(k['t']),
            subtitle: Text((k['r'] as String).substring(11, 16))),
      const Divider(height: 32),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('برنامه‌ی هفتگی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      for (final d in wdo) ...[
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(wdn[d]!, style: TextStyle(fontWeight: FontWeight.bold, color: d == 5 ? Colors.red : null))),
        for (final e in D.events.where((e) => e['wd'] == d).toList()..sort(byStart))
          ListTile(
              onTap: () => addEvent(e),
              title: Text(e['t']),
              subtitle: Text('${hm(e['s'])} – ${hm(e['e'])}   تا ${fd(e['to'])}'),
              trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => delEvent(e))),
      ],
    ]);
  }

  // ── مالی ──
  void delTx(Map x) {
    sfx('delete');
    final i = D.txs.indexOf(x);
    D.txs.remove(x);
    upd();
    undo('حذف شد', () {
      D.txs.insert(i.clamp(0, D.txs.length), x);
      upd();
    });
  }

  Future<void> manageCats(BuildContext ctx) {
    final c = TextEditingController();
    return showDialog(
        context: ctx,
        builder: (_) => StatefulBuilder(builder: (dc, set) {
              void add() {
                final v = c.text.trim();
                if (v.isEmpty || D.cats.contains(v)) return;
                D.cats.add(v);
                D.save();
                c.clear();
                set(() {});
              }

              return AlertDialog(
                title: const Text('مدیریت دسته‌ها'),
                content: SizedBox(
                    width: 300,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Row(children: [
                        Expanded(child: TextField(controller: c, decoration: const InputDecoration(hintText: 'دسته‌ی جدید'), onSubmitted: (_) => add())),
                        IconButton(icon: const Icon(Icons.add_circle), onPressed: add),
                      ]),
                      Flexible(
                          child: ListView(shrinkWrap: true, children: [
                        for (final k in List.of(D.cats))
                          ListTile(
                              dense: true,
                              title: Text(k),
                              trailing: k == 'سایر'
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () {
                                        D.cats.remove(k);
                                        D.save();
                                        set(() {});
                                      }))
                      ])),
                    ])),
                actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('تمام'))],
              );
            }));
  }

  Future<void> txSheet([Map? o]) async {
    final amt = TextEditingController(text: o != null ? n(o['a']) : ''), ttl = TextEditingController(text: o?['t'] ?? ''), note = TextEditingController(text: o?['note'] ?? '');
    var inc = o?['inc'] == true;
    var cat = (o?['c'] ?? 'سایر') as String;
    var date = o != null ? DateTime.parse(o['d']) : DateTime.now();
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => StatefulBuilder(builder: (ctx, set) {
              final list = [...D.cats, if (!D.cats.contains(cat)) cat];
              return Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
                  child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(controller: ttl, decoration: const InputDecoration(labelText: 'عنوان')),
                    TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'توضیحات / یادداشت', hintText: 'مثلاً بابت چه چیزی پرداخت شد؟')),
                    TextField(
                        controller: amt,
                        autofocus: o == null,
                        keyboardType: TextInputType.number,
                        inputFormatters: [ThousandFmt()],
                        decoration: const InputDecoration(labelText: 'مبلغ (تومان)')),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                        segments: const [ButtonSegment(value: false, label: Text('هزینه')), ButtonSegment(value: true, label: Text('درآمد'))],
                        selected: {inc},
                        onSelectionChanged: (s) => set(() => inc = s.first)),
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event),
                        title: Text(fdl(date)),
                        onTap: () async {
                          final d = await pickDate(ctx, initial: date, help: 'تاریخ تراکنش');
                          if (d != null) set(() => date = d);
                        }),
                    Wrap(spacing: 6, children: [
                      for (final k in list) ChoiceChip(label: Text(k), selected: cat == k, onSelected: (_) => set(() => cat = k)),
                      ActionChip(
                          avatar: const Icon(Icons.edit, size: 16),
                          label: const Text('مدیریت دسته‌ها'),
                          onPressed: () async {
                            await manageCats(ctx);
                            set(() {
                              if (!D.cats.contains(cat)) cat = 'سایر';
                            });
                          }),
                    ]),
                    const SizedBox(height: 8),
                    FilledButton(
                        onPressed: () {
                          final v = int.tryParse(en(amt.text));
                          if (v == null || v == 0) return;
                          final m = {'a': v, 'inc': inc, 'c': cat, 't': ttl.text.trim(), 'note': note.text.trim(), 'd': ds(date)};
                          if (o != null) {
                            o.addAll(m);
                          } else {
                            sfx('add');
                            D.txs.add({'id': DateTime.now().microsecondsSinceEpoch, ...m});
                          }
                          Navigator.pop(ctx);
                          upd();
                        },
                        child: Text(o != null ? 'ذخیره‌ی تغییرات' : 'ثبت')),
                  ])));
            }));
  }

  // ── بازه‌های زمانی مالی بر اساس تقویم (شمسی یا میلادی) ──
  DateTime _monthFirst(DateTime now, int back) {
    if (jal) {
      final j = g2j(now.year, now.month, now.day);
      var y = j[0], m = j[1] - back;
      while (m < 1) {
        m += 12;
        y--;
      }
      while (m > 12) {
        m -= 12;
        y++;
      }
      return jDate(y, m, 1);
    }
    return DateTime(now.year, now.month - back, 1);
  }

  String monthName(DateTime first) => jal ? jmn[g2j(first.year, first.month, first.day)[1] - 1] : gmn[first.month - 1];

  String monthLabel(DateTime first) => jal ? '${monthName(first)} ${g2j(first.year, first.month, first.day)[0]}' : '${monthName(first)} ${first.year}';

  DateTime weekStart(DateTime now, int back) => DateTime(now.year, now.month, now.day - ((now.weekday + 1) % 7) - 7 * back);

  List<Map<String, dynamic>> periods() {
    final now = DateTime.now();
    final t = DateTime(now.year, now.month, now.day);
    final w0 = weekStart(now, 0), w1 = weekStart(now, 1);
    final cm0 = _monthFirst(now, 0), pm0 = _monthFirst(now, 1), nm0 = _monthFirst(now, -1);
    return [
      {'label': 'امروز', 'from': ds(t), 'to': ds(DateTime(t.year, t.month, t.day + 1))},
      {'label': 'دیروز', 'from': ds(DateTime(t.year, t.month, t.day - 1)), 'to': ds(t)},
      {'label': 'این هفته', 'from': ds(w0), 'to': ds(DateTime(w0.year, w0.month, w0.day + 7))},
      {'label': 'هفته‌ی قبل', 'from': ds(w1), 'to': ds(w0)},
      {'label': 'این ماه (${monthName(cm0)})', 'from': ds(cm0), 'to': ds(nm0), 'month': true},
      {'label': 'ماه قبل (${monthName(pm0)})', 'from': ds(pm0), 'to': ds(cm0), 'month': true},
    ];
  }

  Iterable<Map> inRange(String from, String to) => D.txs.where((x) {
        final d = x['d'] as String;
        return d.compareTo(from) >= 0 && d.compareTo(to) < 0;
      });

  int sumR(String from, String to, bool inc) => inRange(from, to).where((x) => (x['inc'] == true) == inc).fold<int>(0, (a, x) => a + (x['a'] as int));

  Map<String, int> spentByCat(String from, String to) {
    final r = <String, int>{};
    for (final x in inRange(from, to).where((x) => x['inc'] != true)) {
      r['${x['c']}'] = (r['${x['c']}'] ?? 0) + (x['a'] as int);
    }
    return r;
  }

  Widget budgetCard() {
    final cs = Theme.of(context).colorScheme;
    final p = periods()[4];
    final spent = spentByCat(p['from'] as String, p['to'] as String);
    final b = budgets;
    final entries = b.entries.where((e) => e.value is num && (e.value as num) > 0).toList();
    final totalB = entries.fold<num>(0, (a, e) => a + (e.value as num));
    final totalS = entries.fold<int>(0, (a, e) => a + (spent[e.key] ?? 0));
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.savings_outlined, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('بودجه‌ی ${p['label']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                TextButton(onPressed: budgetSheet, child: Text(entries.isEmpty ? 'تعیین بودجه' : 'ویرایش')),
              ]),
              if (entries.isEmpty)
                const Text('هنوز بودجه‌ای تعیین نکردی. برای هر دسته یه سقف ماهانه بذار تا میزان مصرفش رو همین‌جا ببینی.')
              else ...[
                Text('کل: ${n(totalS)} از ${n(totalB)}  •  ${totalB - totalS >= 0 ? 'باقی‌مانده ${n(totalB - totalS)}' : 'بیشتر از سقف ${n(totalS - totalB)}'}'),
                for (final e in entries)
                  Builder(builder: (_) {
                    final bd = e.value as num, sp = spent[e.key] ?? 0, over = sp > bd;
                    final ratio = bd > 0 ? (sp / bd).clamp(0.0, 1.0).toDouble() : 0.0;
                    return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [Expanded(child: Text(e.key)), Text('${n(sp)} از ${n(bd)}')]),
                          const SizedBox(height: 3),
                          LinearProgressIndicator(
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(8),
                              value: ratio,
                              color: over ? Colors.red : (ratio >= .8 ? Colors.orange : null)),
                          Text(over ? 'بیشتر از سقف: ${n(sp - bd)}' : 'باقی‌مانده: ${n(bd - sp)}',
                              style: TextStyle(fontSize: 11, color: over ? Colors.red : cs.outline)),
                        ]));
                  }),
              ],
            ])));
  }

  Future<void> historySheet() async {
    var mode = 2; // 0 روز، 1 هفته، 2 ماه
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => StatefulBuilder(builder: (ctx, set) {
              final now = DateTime.now();
              final rows = <List<String>>[]; // [عنوان، از، تا]
              if (mode == 0) {
                for (var i = 0; i < 31; i++) {
                  final d = DateTime(now.year, now.month, now.day - i);
                  rows.add([i == 0 ? 'امروز' : (i == 1 ? 'دیروز' : fdl(d)), ds(d), ds(DateTime(d.year, d.month, d.day + 1))]);
                }
              } else if (mode == 1) {
                for (var i = 0; i < 12; i++) {
                  final st = weekStart(now, i), en = DateTime(st.year, st.month, st.day + 7);
                  final last = DateTime(st.year, st.month, st.day + 6);
                  rows.add([(i == 0 ? 'این هفته: ' : (i == 1 ? 'هفته‌ی قبل: ' : '')) + '${fd(ds(st))} تا ${fd(ds(last))}', ds(st), ds(en)]);
                }
              } else {
                for (var i = 0; i < 12; i++) {
                  final f = _monthFirst(now, i), nx = _monthFirst(now, i - 1);
                  rows.add([monthLabel(f), ds(f), ds(nx)]);
                }
              }
              return SafeArea(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const Text('تاریخچه‌ی مالی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),
                        SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 0, label: Text('روزها')),
                              ButtonSegment(value: 1, label: Text('هفته‌ها')),
                              ButtonSegment(value: 2, label: Text('ماه‌ها')),
                            ],
                            selected: {mode},
                            onSelectionChanged: (v) => set(() => mode = v.first)),
                        const SizedBox(height: 8),
                        Flexible(
                            child: ListView(shrinkWrap: true, children: [
                          for (final r in rows)
                            Builder(builder: (_) {
                              final inc = sumR(r[1], r[2], true), exp = sumR(r[1], r[2], false), net = inc - exp;
                              final empty = inc == 0 && exp == 0;
                              return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(r[0], style: TextStyle(color: empty ? Theme.of(ctx).colorScheme.outline : null)),
                                  subtitle: Text('درآمد ${n(inc)}  |  هزینه ${n(exp)}'),
                                  trailing: Text(n(net), style: TextStyle(fontWeight: FontWeight.bold, color: empty ? null : (net >= 0 ? Colors.green : Colors.red))));
                            }),
                        ])),
                      ])));
            }));
  }

  Widget money() {
    int sum(Iterable<Map> l, bool inc) => l.where((x) => x['inc'] == inc).fold(0, (p, x) => p + (x['a'] as int));
    final found = D.txs.where((x) => '${x['t'] ?? ''} ${x['c']} ${x['note'] ?? ''}'.contains(q)).toList()
      ..sort((a, b) {
        final c = (b['d'] as String).compareTo(a['d']);
        return c != 0 ? c : (b['id'] as int).compareTo(a['id'] as int);
      });
    return ListView(padding: const EdgeInsets.all(12), children: [
      TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'جستجو در عنوان، توضیحات یا دسته'),
          onChanged: (v) => setState(() => q = v.trim())),
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(icon: const Icon(Icons.bar_chart), label: const Text('گزارش نموداری'), onPressed: reportSheet),
        OutlinedButton.icon(icon: const Icon(Icons.history), label: const Text('تاریخچه'), onPressed: historySheet),
      ]),
      if (q.isNotEmpty)
        Card(child: ListTile(title: Text('${found.length} بار'), subtitle: Text('درآمد ${n(sum(found, true))}  |  هزینه ${n(sum(found, false))}')))
      else ...[
        for (final p in periods())
          Builder(builder: (_) {
            final inc = sumR(p['from'] as String, p['to'] as String, true), exp = sumR(p['from'] as String, p['to'] as String, false);
            return Card(
                child: ListTile(
                    dense: true,
                    title: Text(p['label'] as String),
                    subtitle: Text('درآمد ${n(inc)}  |  هزینه ${n(exp)}'),
                    trailing: Text(n(inc - exp), style: const TextStyle(fontWeight: FontWeight.bold))));
          }),
        budgetCard(),
      ],
      for (final x in found.take(q.isEmpty ? 30 : 500))
        Dismissible(
            key: ObjectKey(x),
            background: Container(color: Colors.red),
            onDismissed: (_) => delTx(x),
            child: ListTile(
                dense: true,
                onTap: () => txSheet(x),
                leading: Icon(x['inc'] == true ? Icons.south_west : Icons.north_east, color: x['inc'] == true ? Colors.green : Colors.red),
                title: Text((x['t'] ?? '') != '' ? x['t'] : x['c']),
                subtitle: Text('${x['c']} • ${fd(x['d'])}${(x['note'] ?? '').toString().isNotEmpty ? ' • ${x['note']}' : ''}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(n(x['a'])),
                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => delTx(x)),
                ]))),
      const SizedBox(height: 80),
    ]);
  }

  Map<String, dynamic> get budgets {
    try {
      return Map<String, dynamic>.from(jsonDecode(prefs.getString('budgets') ?? '{}') as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> budgetSheet() async {
    final b = budgets;
    final ctl = {for (final k in D.cats) k: TextEditingController(text: b[k] != null ? n(b[k] as num) : '')};
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('بودجه‌ی ماهانه‌ی هر دسته (تومان؛ خالی = بدون سقف)', style: TextStyle(fontWeight: FontWeight.bold)),
              for (final k in D.cats)
                TextField(controller: ctl[k], keyboardType: TextInputType.number, inputFormatters: [ThousandFmt()], decoration: InputDecoration(labelText: k)),
              const SizedBox(height: 8),
              FilledButton(
                  onPressed: () {
                    final r = <String, dynamic>{};
                    ctl.forEach((k, c) {
                      final v = int.tryParse(en(c.text));
                      if (v != null && v > 0) r[k] = v;
                    });
                    prefs.setString('budgets', jsonEncode(r));
                    Navigator.pop(ctx);
                    setState(() {});
                  },
                  child: const Text('ذخیره')),
            ]))));
  }

  Future<void> reportSheet() async {
    var p = 4;
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => StatefulBuilder(builder: (ctx, set) {
              final now = DateTime.now();
              final pr = periods()[p];
              final l = inRange(pr['from'] as String, pr['to'] as String).toList();
              int sm(bool inc) => l.where((x) => (x['inc'] == true) == inc).fold<int>(0, (a, x) => a + (x['a'] as int));
              final byCat = <String, int>{};
              for (final x in l.where((x) => x['inc'] != true)) {
                byCat['${x['c']}'] = (byCat['${x['c']}'] ?? 0) + (x['a'] as int);
              }
              final rows = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              final top = rows.isEmpty ? 1 : rows.first.value;
              final bg = budgets;
              final days = [for (var i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i)];
              final dv = [for (final d in days) D.txs.where((x) => x['inc'] != true && x['d'] == ds(d)).fold<int>(0, (a, x) => a + (x['a'] as int))];
              final mx = dv.fold<int>(1, (a, v) => v > a ? v : a);
              return SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Wrap(spacing: 6, children: [
                          for (var i = 0; i < 6; i++)
                            ChoiceChip(label: Text(periods()[i]['label'] as String), selected: p == i, onSelected: (_) => set(() => p = i))
                        ]),
                        const SizedBox(height: 12),
                        Text('درآمد ${n(sm(true))}   |   هزینه ${n(sm(false))}   |   مانده ${n(sm(true) - sm(false))}'),
                        const SizedBox(height: 12),
                        const Text('هزینه بر اساس دسته', style: TextStyle(fontWeight: FontWeight.bold)),
                        if (rows.isEmpty) const Text('هزینه‌ای ثبت نشده'),
                        for (final r in rows)
                          Builder(builder: (_) {
                            final bd = pr['month'] == true ? bg[r.key] as num? : null;
                            return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [Expanded(child: Text(r.key)), Text(bd != null ? '${n(r.value)} از ${n(bd)}' : n(r.value))]),
                                  LinearProgressIndicator(
                                      minHeight: 8,
                                      value: bd != null ? (r.value / bd).clamp(0.0, 1.0).toDouble() : r.value / top,
                                      color: bd != null && r.value > bd ? Colors.red : null),
                                ]));
                          }),
                        const SizedBox(height: 16),
                        const Text('هزینه‌ی ۷ روز اخیر', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SizedBox(
                            height: 90,
                            child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                              for (var i = 0; i < 7; i++)
                                Container(
                                    width: 18,
                                    height: 6 + 70.0 * dv[i] / mx,
                                    decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.primary, borderRadius: BorderRadius.circular(4)))
                            ])),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                          for (final d in days) Text('${jal ? g2j(d.year, d.month, d.day)[2] : d.day}', style: const TextStyle(fontSize: 11))
                        ]),
                      ])));
            }));
  }

  void minimalDay() {
    final open = D.tasks.where((k) => k['done'] != true).toList()
      ..sort((a, b) {
        final s = (b['star'] == true ? 1 : 0) - (a['star'] == true ? 1 : 0);
        return s != 0 ? s : ((a['r'] ?? '9') as String).compareTo((b['r'] ?? '9') as String);
      });
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('حداقل روز'),
              content: Text(open.isEmpty
                  ? 'کار بازی نداری؛ امروز رو موفق حساب کن.'
                  : 'امروز فقط همین یک کار، ۱۰ دقیقه:\n\n${open.first['t']}\n\nفقط شروعش کن. همین کافیه که امروز حساب بشه.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بعداً')),
                if (open.isNotEmpty)
                  FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        toggle(open.first);
                      },
                      child: const Text('انجامش دادم')),
              ],
            ));
  }

  void weekReview() {
    final now = DateTime.now();
    final from = ds(DateTime(now.year, now.month, now.day - 6));
    final dn = D.tasks.where((k) => k['done'] == true && ((k['doneAt'] ?? '') as String).compareTo(from) >= 0).length;
    final od = D.tasks.where((k) {
      if (k['done'] == true || k['r'] == null) return false;
      try {
        return DateTime.parse(k['r']).isBefore(now);
      } catch (_) {
        return false;
      }
    }).toList();
    final hb = D.habits.isEmpty
        ? 0
        : D.habits.fold<int>(0, (a, h) => a + (h['log'] as List).where((d) => '$d'.compareTo(from) >= 0).length) * 100 ~/ (D.habits.length * 7);
    final spent = D.txs.where((x) => x['inc'] != true && (x['d'] as String).compareTo(from) >= 0).fold<int>(0, (a, x) => a + (x['a'] as int));
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SingleChildScrollView(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  const Text('بازبینی ۷ روز اخیر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('کار انجام‌شده: $dn   |   عقب‌افتاده: ${od.length}'),
                  Text('پایبندی به عادت‌ها: $hb٪'),
                  Text('هزینه‌ی هفته: ${n(spent)}'),
                  const SizedBox(height: 12),
                  if (od.isNotEmpty) const Text('عقب‌افتاده‌ها؛ کدوم رو دیگه لازم نداری؟'),
                  for (final k in od)
                    ListTile(
                        dense: true,
                        title: Text(k['t']),
                        trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              Navigator.pop(ctx);
                              delTask(k);
                            })),
                ]))));
  }

  bool hDone(Map h, String d) => (h['log'] as List).contains(d);

  int streak(Map h) {
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day), c = 0;
    if (!hDone(h, ds(d))) d = DateTime(d.year, d.month, d.day - 1); // امروز هنوز تموم نشده، زنجیره نمی‌شکنه
    while (hDone(h, ds(d))) {
      c++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return c;
  }

  Future<void> habitSheet([Map? o]) async {
    final t = TextEditingController(text: o?['t'] ?? ''), m = TextEditingController(text: o?['min'] ?? '');
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: t, autofocus: o == null, decoration: const InputDecoration(labelText: 'عادت (مثلاً ورزش، مطالعه)')),
              TextField(controller: m, decoration: const InputDecoration(labelText: 'نسخه‌ی حداقلی برای روزهای بد (مثلاً ۱ دقیقه)')),
              const SizedBox(height: 12),
              Row(children: [
                if (o != null)
                  TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        D.habits.remove(o);
                        upd();
                      },
                      child: const Text('حذف')),
                const Spacer(),
                FilledButton(
                    onPressed: () {
                      if (t.text.trim().isEmpty) return;
                      if (o != null) {
                        o['t'] = t.text.trim();
                        o['min'] = m.text.trim();
                      } else {
                        sfx('add');
                        D.habits.add(<String, dynamic>{'id': DateTime.now().microsecondsSinceEpoch, 't': t.text.trim(), 'min': m.text.trim(), 'log': []});
                      }
                      Navigator.pop(ctx);
                      upd();
                    },
                    child: const Text('ثبت')),
              ]),
            ])));
  }

  List<Widget> habitItems() {
    final now = DateTime.now(), today = ds(now);
    final days = [for (var i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i)];
    final doneToday = D.habits.where((h) => hDone(h, today)).length;
    return [
      if (D.habits.isEmpty)
        const Padding(padding: EdgeInsets.all(24), child: Text('هنوز عادتی نداری. با + یک عادت کوچیک شروع کن؛ هرچی کوچیک‌تر، ماندگارتر.'))
      else
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('امروز $doneToday از ${D.habits.length} عادت انجام شد')),
      for (final h in D.habits)
        Card(
            child: ListTile(
                onTap: () => habitSheet(h),
                title: Text(h['t']),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if ((h['min'] ?? '') != '') Text('حداقل: ${h['min']}', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(children: [
                    for (final d in days)
                      Padding(padding: const EdgeInsetsDirectional.only(end: 4), child: Icon(hDone(h, ds(d)) ? Icons.circle : Icons.circle_outlined, size: 12))
                  ]),
                  Text('زنجیره: ${streak(h)} روز'),
                ]),
                trailing: Checkbox(
                    value: hDone(h, today),
                    onChanged: (v) {
                      final l = h['log'] as List;
                      if (v == true) {
                        if (!l.contains(today)) l.add(today);
                        sfx('done');
                      } else {
                        l.remove(today);
                      }
                      upd();
                    }))),
    ];
  }

  Widget sectionHead(String title, IconData icon, VoidCallback onAdd) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Spacer(),
        TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 18), label: const Text('افزودن')),
      ]));

  // اهداف و عادت‌ها در یک صفحه
  Widget plan() => ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 90), children: [
        sectionHead('اهداف', Icons.flag_outlined, () => goalSheet()),
        ...goalItems(),
        const SizedBox(height: 8),
        const Divider(),
        sectionHead('عادت‌ها', Icons.local_fire_department_outlined, () => habitSheet()),
        ...habitItems(),
      ]);

  void addPlan() => showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('هدف جدید'),
                onTap: () {
                  Navigator.pop(ctx);
                  goalSheet();
                }),
            ListTile(
                leading: const Icon(Icons.local_fire_department_outlined),
                title: const Text('عادت جدید'),
                onTap: () {
                  Navigator.pop(ctx);
                  habitSheet();
                }),
          ])));

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(['کارها', 'تقویم', 'اهداف و عادت‌ها', 'مالی'][tab]), actions: [
          IconButton(icon: const Icon(Icons.help_outline), tooltip: 'راهنما', onPressed: openGuide),
          IconButton(icon: const Icon(Icons.settings), tooltip: 'تنظیمات', onPressed: settings),
        ]),
        body: [tasks, cal, plan, money][tab](),
        floatingActionButton: FloatingActionButton(
            onPressed: () => [() => taskSheet(), () => addEvent(), () => addPlan(), () => txSheet()][tab](), child: .)),
        bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.checklist), label: 'کارها'),
              NavigationDestination(icon: Icon(Icons.calendar_month), label: 'تقویم'),
              NavigationDestination(icon: Icon(Icons.track_changes), label: 'اهداف و عادت'),
              NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'مالی'),
              NavigationDestination(icon: Icon(Icons.timer), label: 'تمرکز'),
              NavigationDestination(icon: Icon(Icons.pets), label: 'قهرمان'),
            ]),
      );
}
