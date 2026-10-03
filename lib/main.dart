import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/scheduler.dart';
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
  GAnimal('wolf', 'گرگ', '🐺', 'steak'),
];

class GItem {
  final String id, name, emoji, slot, love, how;
  final int price, xp;
  const GItem(this.id, this.name, this.emoji, this.slot, {this.price = 0, this.xp = 0, this.love = '', this.how = ''});
}

const slotNames = {'food': 'غذا', 'hat': 'کلاه', 'face': 'عینک و صورت', 'neck': 'گردن', 'back': 'پشت', 'hand': 'دست', 'bg': 'پس‌زمینه'};

const gItems = [
  GItem('fd_apple', 'سیب', '🍎', 'food', price: 8, xp: 15),
  GItem('fd_fish', 'ماهی', '🐟', 'food', price: 18, xp: 30, love: 'fish'),
  GItem('fd_meat', 'گوشت', '🍖', 'food', price: 18, xp: 30, love: 'meat'),
  GItem('fd_pepper', 'فلفل آتشین', '🌶️', 'food', price: 18, xp: 30, love: 'spicy'),
  GItem('fd_cookie', 'کلوچه', '🍪', 'food', price: 18, xp: 30, love: 'cookie'),
  GItem('fd_egg', 'تخم‌مرغ', '🥚', 'food', price: 18, xp: 30, love: 'egg'),
  GItem('fd_steak', 'استیک', '🥩', 'food', price: 22, xp: 38, love: 'steak'),
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
  GItem('bg_cave', 'غار کریستالی', '🕳️', 'bg', price: 120),
  GItem('bg_beach', 'ساحل', '🏖️', 'bg', price: 150),
  GItem('bg_castle', 'قلعه', '🏰', 'bg', price: 220),
  GItem('bg_space', 'فضا', '🪐', 'bg', price: 300),
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
  static String bg = 'meadow';
  static List<Map> heroes = [];
  static Map<String, int> inv = {};
  static Set<String> rw = {};
  static void Function(String msg, bool big)? onEvent;

  static int need(int lv) => 100 + 60 * (lv - 1);

  // سیری: ۰ تا ۱۰۰ و کم‌شدن حدود ۲٫۵ واحد در ساعت
  static double sat(Map h) {
    final s = (h['sat'] as num?)?.toDouble() ?? 80;
    final t = (h['satT'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
    final v = s - (DateTime.now().millisecondsSinceEpoch - t) / 3600000 * 2.5;
    return v < 0 ? 0 : v;
  }

  static void setSat(Map h, double v) {
    h['sat'] = v < 0 ? 0 : (v > 100 ? 100 : v);
    h['satT'] = DateTime.now().millisecondsSinceEpoch;
  }
  static void say(String m, [bool big = false]) => onEvent?.call(m, big);

  static void load() {
    heroes = [];
    inv = {};
    rw = {};
    coins = 0;
    active = 0;
    focusTotal = 0;
    pool = 0;
    bg = 'meadow';
    try {
      final raw = prefs.getString('hero');
      if (raw != null && raw.isNotEmpty) {
        final m = jsonDecode(raw) as Map;
        coins = (m['coins'] as num?)?.toInt() ?? 0;
        active = (m['active'] as num?)?.toInt() ?? 0;
        focusTotal = (m['focus'] as num?)?.toInt() ?? 0;
        pool = (m['pool'] as num?)?.toInt() ?? 0;
        bg = '${m['bg'] ?? 'meadow'}';
        heroes = (m['heroes'] as List? ?? []).map<Map>((e) => Map<String, dynamic>.from(e as Map)).toList();
        inv = {for (final e in (m['inv'] as Map? ?? {}).entries) '${e.key}': (e.value as num).toInt()};
        rw = {for (final e in (m['rw'] as List? ?? [])) '$e'};
      }
    } catch (_) {}
    for (final h in heroes) {
      h['eq'] = Map<String, dynamic>.from((h['eq'] as Map?) ?? {});
      h['lv'] ??= 1;
      h['xp'] ??= 0;
      if (h['satT'] == null) setSat(h, 80);
    }
    active = heroes.isEmpty ? 0 : active.clamp(0, heroes.length - 1).toInt();
  }

  static Future<void> save() async {
    final cut = ds(DateTime.now().subtract(const Duration(days: 45)));
    rw.removeWhere((k) => k.startsWith('h:') && k.split(':').last.compareTo(cut) < 0);
    await prefs.setString('hero', jsonEncode({'coins': coins, 'active': active, 'focus': focusTotal, 'pool': pool, 'heroes': heroes, 'inv': inv, 'rw': rw.toList(), 'bg': bg}));
  }

  static void addXp(int x, {bool raw = false}) {
    if (heroes.isEmpty || heroes[active]['hatched'] == false) {
      pool += x;
      return;
    }
    final h = heroes[active];
    final stBefore = stageOf((h['lv'] as int?) ?? 1);
    if (!raw && sat(h) < 25) x = (x * .5).round();
    h['xp'] = (h['xp'] as int) + x;
    while ((h['xp'] as int) >= need(h['lv'] as int)) {
      h['xp'] = (h['xp'] as int) - need(h['lv'] as int);
      h['lv'] = (h['lv'] as int) + 1;
      final bonus = (h['lv'] as int) * 5;
      coins += bonus;
      say('🎉 ${h['n']} به سطح ${h['lv']} رسید!\nجایزه‌ی ارتقا: $bonus سکه', true);
    }
    final stAfter = stageOf(h['lv'] as int);
    if (stAfter > stBefore) say('🌱 ${h['n']} بزرگ‌تر شد!\nحالا «${stageNames[stAfter]}» است.', true);
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
    final dk = 'fd:${ds(DateTime.now())}';
    prefs.setInt(dk, (prefs.getInt(dk) ?? 0) + min);
    final comp = heroes.isNotEmpty && heroes[active]['hatched'] != false && sat(heroes[active]) >= 25;
    final c = focusCoins(min) + (comp ? (focusCoins(min) * .25).round() : 0);
    coins += c;
    addXp(min);
    say('🧠 $min دقیقه تمرکز کامل شد!\n+$c سکه${comp ? ' (با پاداش پت همراه)' : ''} و +$min تجربه', true);
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
    if (it.slot == 'bg') {
      bg = bg == it.id ? 'meadow' : it.id;
      save();
      return;
    }
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
    addXp(x, raw: true);
    setSat(h, math.min(100.0, sat(h) + it.xp * .8));
    save();
    return loved ? '${h['n']} عاشق ${it.name} بود! +$x تجربه 😍' : '+$x تجربه برای ${h['n']}';
  }

  static Map create(String animal, String name, [int rar = 0]) {
    final h = <String, dynamic>{'id': DateTime.now().microsecondsSinceEpoch, 'a': animal, 'n': name, 'lv': 1, 'xp': 0, 'eq': <String, dynamic>{}, 'hatched': false, 'rar': rar};
    heroes.add(h);
    active = heroes.length - 1;
    save();
    return h;
  }

  // بعد از باز شدن تخم: تجربه‌ی جمع‌شده به پت می‌رسد
  static void hatched(Map h) {
    h['hatched'] = true;
    setSat(h, 70);
    if (pool > 0) {
      final p = pool;
      pool = 0;
      addXp(p);
    }
    save();
  }
}

// ───────────────────────── پیکسل‌آرت: پت و آیتم‌ها ─────────────────────────
int stageOf(int lv) => lv < 5 ? 0 : (lv < 10 ? 1 : (lv < 18 ? 2 : (lv < 30 ? 3 : 4)));
const stageNames = ['نوزاد', 'کودک', 'نوجوان', 'بالغ', 'افسانه‌ای'];

int seasonNow() {
  final n = DateTime.now();
  final j = g2j(n.year, n.month, n.day)[1];
  return j <= 3 ? 0 : (j <= 6 ? 1 : (j <= 9 ? 2 : 3)); // بهار، تابستان، پاییز، زمستان
}

int rollRarity(bool premium) {
  final r = math.Random().nextDouble();
  if (premium) return r < .3 ? 2 : 1;
  return r < .08 ? 2 : (r < .3 ? 1 : 0);
}

int _cl(num v) => v < 0 ? 0 : (v > 255 ? 255 : v.round());
int _rgb2(int r, int g, int b) => 0xFF000000 | (r << 16) | (g << 8) | b;
int _shade(int c, double f) {
  final r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
  if (f >= 1) {
    final t = f - 1;
    return _rgb2(_cl(r + (255 - r) * t), _cl(g + (255 - g) * t), _cl(b + (255 - b) * t));
  }
  return _rgb2(_cl(r * f), _cl(g * f), _cl(b * f));
}

List<int> _tones(int c) => [_shade(c, 1.3), c, _shade(c, .68)];

class Px {
  final int w, h;
  final List<int> p;
  Px(this.w, this.h) : p = List<int>.filled(w * h, 0);
  void set(int x, int y, int c) {
    if (x >= 0 && y >= 0 && x < w && y < h) p[y * w + x] = c;
  }

  int get(int x, int y) => (x < 0 || y < 0 || x >= w || y >= h) ? 0 : p[y * w + x];

  void ell(double cx, double cy, double rx, double ry, List<int> t, {bool onlyOn = false}) {
    if (rx < .5 || ry < .5) return;
    for (var y = (cy - ry).floor(); y <= (cy + ry).ceil(); y++) {
      for (var x = (cx - rx).floor(); x <= (cx + rx).ceil(); x++) {
        final dx = (x + .5 - cx) / rx, dy = (y + .5 - cy) / ry;
        if (dx * dx + dy * dy > 1) continue;
        if (onlyOn && get(x, y) == 0) continue;
        final l = -dx * .55 - dy * .8;
        set(x, y, l > .38 ? t[0] : (l > -.3 ? t[1] : t[2]));
      }
    }
  }

  void rect(int x0, int y0, int x1, int y1, int c) {
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        set(x, y, c);
      }
    }
  }

  void tri(double x0, double y0, double x1, double y1, double x2, double y2, List<int> t) {
    final minX = math.min(x0, math.min(x1, x2)).floor(), maxX = math.max(x0, math.max(x1, x2)).ceil();
    final minY = math.min(y0, math.min(y1, y2)).floor(), maxY = math.max(y0, math.max(y1, y2)).ceil();
    double sg(double ax, double ay, double bx, double by, double cx, double cy) => (ax - cx) * (by - cy) - (bx - cx) * (ay - cy);
    final cyc = (y0 + y1 + y2) / 3;
    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final px = x + .5, py = y + .5;
        final d1 = sg(px, py, x0, y0, x1, y1), d2 = sg(px, py, x1, y1, x2, y2), d3 = sg(px, py, x2, y2, x0, y0);
        final neg = d1 < 0 || d2 < 0 || d3 < 0, pos = d1 > 0 || d2 > 0 || d3 > 0;
        if (neg && pos) continue;
        set(x, y, py < cyc - .6 ? t[0] : (py > cyc + 1.6 ? t[2] : t[1]));
      }
    }
  }

  void line(double x0, double y0, double x1, double y1, int c) {
    final n = math.max((x1 - x0).abs(), (y1 - y0).abs()).ceil();
    for (var i = 0; i <= n; i++) {
      final t = n == 0 ? 0.0 : i / n;
      set((x0 + (x1 - x0) * t).floor(), (y0 + (y1 - y0) * t).floor(), c);
    }
  }

  void outline(int c) {
    final src = List<int>.from(p);
    int g(int x, int y) => (x < 0 || y < 0 || x >= w || y >= h) ? 0 : src[y * w + x];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (src[y * w + x] != 0) continue;
        if (g(x - 1, y) != 0 || g(x + 1, y) != 0 || g(x, y - 1) != 0 || g(x, y + 1) != 0) p[y * w + x] = c;
      }
    }
  }
}

class PxPainter extends CustomPainter {
  final Px px;
  PxPainter(this.px);
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / px.w;
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < px.h; y++) {
      for (var x = 0; x < px.w; x++) {
        final c = px.p[y * px.w + x];
        if (c == 0) continue;
        paint.color = Color(c);
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell + .6, cell + .6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(PxPainter old) => old.px != px;
}

// ایموجی → پیکسل‌آرت سه‌بعدی (ضخامت + سایه + خط دور)
final _pxFut = <String, Future<ui.Image>>{};
Future<ui.Image> pixelEmoji(String e, [int g = 18]) => _pxFut.putIfAbsent('$e|$g', () => _mkPixelEmoji(e, g));

Future<ui.Image> _pxToImage(Px px) {
  final bytes = Uint8List(px.w * px.h * 4);
  for (var i = 0; i < px.p.length; i++) {
    final c = px.p[i];
    if (c == 0) continue;
    bytes[i * 4] = (c >> 16) & 255;
    bytes[i * 4 + 1] = (c >> 8) & 255;
    bytes[i * 4 + 2] = c & 255;
    bytes[i * 4 + 3] = 255;
  }
  final comp = Completer<ui.Image>();
  ui.decodeImageFromPixels(bytes, px.w, px.h, ui.PixelFormat.rgba8888, comp.complete);
  return comp.future;
}

Future<ui.Image> _mkPixelEmoji(String e, int g) async {
  final rec = ui.PictureRecorder();
  final cv = Canvas(rec);
  final tp = TextPainter(text: TextSpan(text: e, style: TextStyle(fontSize: g * .78)), textDirection: TextDirection.ltr)..layout();
  tp.paint(cv, Offset((g - tp.width) / 2, (g - tp.height) / 2));
  final img = await rec.endRecording().toImage(g, g);
  final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final o = g + 5;
  final out = Px(o, o);
  if (bd != null) {
    final src = bd.buffer.asUint8List();
    final mask = List<bool>.filled(g * g, false);
    final col = List<int>.filled(g * g, 0);
    int q(int v) => _cl(((v / 64).round() * 64));
    for (var i = 0; i < g * g; i++) {
      if (src[i * 4 + 3] > 140) {
        mask[i] = true;
        col[i] = _rgb2(q(src[i * 4]), q(src[i * 4 + 1]), q(src[i * 4 + 2]));
      }
    }
    for (var d = 3; d >= 1; d--) {
      for (var y = 0; y < g; y++) {
        for (var x = 0; x < g; x++) {
          if (mask[y * g + x]) out.set(x + 1 + d, y + 1 + d, _shade(col[y * g + x], d == 3 ? .42 : (d == 2 ? .5 : .58)));
        }
      }
    }
    for (var y = 0; y < g; y++) {
      for (var x = 0; x < g; x++) {
        if (!mask[y * g + x]) continue;
        var c = col[y * g + x];
        final up = y > 0 && mask[(y - 1) * g + x], left = x > 0 && mask[y * g + x - 1];
        if (!up || !left) c = _shade(c, 1.22);
        out.set(x + 1, y + 1, c);
      }
    }
  }
  out.outline(0xFF1D1D29);
  return _pxToImage(out);
}

class PxEmoji extends StatelessWidget {
  final String e;
  final double size;
  const PxEmoji(this.e, this.size, {super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<ui.Image>(
      future: pixelEmoji(e),
      builder: (c, snap) => snap.hasData
          ? RawImage(image: snap.data, width: size, height: size, fit: BoxFit.contain, filterQuality: FilterQuality.none)
          : SizedBox(width: size, height: size));
}

// ── پت‌های پیکسلی ──
const _pal = {
  'cat': [0xFFF0A24A, 0xFFFFE6C0, 0xFFB5651D],
  'dog': [0xFFC9904E, 0xFFF3DDB5, 0xFF7A4A21],
  'dragon': [0xFF4FBF6B, 0xFFF4DC8A, 0xFF2C7A47],
  'crow': [0xFF3B3B52, 0xFF5E5E7C, 0xFF1B1B26],
  'snake': [0xFF7FCB5E, 0xFFEFF2B0, 0xFF3F8F3A],
  'wolf': [0xFF8A97AB, 0xFFEFF3F8, 0xFF4F5A6C],
};

int _hueRot(int c, double deg) {
  final hsv = HSVColor.fromColor(Color(c));
  return hsv.withHue((hsv.hue + deg) % 360).withSaturation(math.max(hsv.saturation, .38)).toColor().toARGB32();
}

List<int> _palFor(String sp, int rar) {
  final b = _pal[sp] ?? _pal['cat']!;
  if (rar == 2) return const [0xFFF6C945, 0xFFFFF3C4, 0xFFC98B1F];
  if (rar == 1) return [for (final c in b) _hueRot(c, 150)];
  return b;
}

class PetSprite {
  final Px px;
  final double hx, hy, hrx, hry, bx, by, brx, bry, mx, my, ey;
  PetSprite(this.px, this.hx, this.hy, this.hrx, this.hry, this.bx, this.by, this.brx, this.bry, this.mx, this.my, this.ey);
}

final _spriteCache = <String, PetSprite>{};
PetSprite petSprite(String sp, int stage, String face, [int rar = 0]) => _spriteCache.putIfAbsent('$sp|$stage|$face|$rar', () => _buildPet(sp, stage, face, rar));

PetSprite _buildPet(String sp, int stage, String face, int rar) {
  final px = Px(48, 48);
  final pc = _palFor(sp, rar);
  final base = _tones(pc[0]), belly = _tones(pc[1]), acc = _tones(pc[2]);
  final sc = const [.58, .74, .9, 1.0, 1.06][stage];
  final hk = const [1.5, 1.3, 1.12, 1.0, 1.0][stage];
  var brx = 11.0 * sc, bry = 8.5 * sc;
  if (sp == 'snake') {
    brx = 9.5 * sc;
    bry = 3.4 * sc + .8;
  }
  final bcx = 24.0;
  var bcy = 43.0 - bry;
  final hrx = 8.8 * sc * hk, hry = 8.0 * sc * hk;
  var hcy = bcy - bry * .55 - hry * .55;
  final hcx = 24.0;
  if (sp == 'snake') {
    bcy = 41.0;
    hcy = 41.0 - 10 * sc - 3 * sc - hry * .7;
  }
  final k = sc;

  // ───── بدن و اندام‌ها (پشت سر) ─────
  if (sp == 'cat' || sp == 'dog' || sp == 'wolf' || sp == 'dragon') {
    final tl = sp == 'dragon' ? 15.0 : (sp == 'wolf' ? 11.0 : (sp == 'dog' ? 7.0 : 12.0));
    final tr = sp == 'wolf' ? 2.4 : (sp == 'dragon' ? 2.0 : 1.7);
    for (var i = 0; i < 9; i++) {
      final t = i / 8;
      final tx = bcx + brx * .75 + math.sin(t * 2.2) * 4.5 * k + t * 3 * k;
      final ty = bcy + bry * .25 - t * tl * k * (sp == 'dog' ? 1.0 : .9);
      px.ell(tx, ty, tr * k + .6 - (sp == 'dragon' ? t * 1.2 * k : 0), tr * k + .6 - (sp == 'dragon' ? t * 1.2 * k : 0), sp == 'wolf' && i > 6 ? belly : base);
    }
    if (sp == 'dragon') {
      px.tri(bcx + brx * .75 + 6 * k + 2.8 * k, bcy - tl * k * .9 + bry * .25 - 2.4 * k, bcx + brx * .75 + 6 * k + 2.8 * k, bcy - tl * k * .9 + bry * .25 + 2.4 * k, bcx + brx * .75 + 6 * k + 6.5 * k, bcy - tl * k * .9 + bry * .25, _tones(0xFFF4DC8A));
    }
  }
  if (sp == 'dragon') {
    final wk = const [.38, .58, .82, 1.05, 1.3][stage];
    for (final sd in [-1, 1]) {
      final x0 = bcx + sd * brx * .55;
      px.tri(x0, bcy - bry * .1, x0 + sd * 12 * wk, bcy - bry - 11 * wk, x0 + sd * 13 * wk, bcy + 1 * wk, acc);
      px.tri(x0 + sd * 1.5 * wk, bcy - bry * .1, x0 + sd * 9.5 * wk, bcy - bry - 7 * wk, x0 + sd * 10 * wk, bcy - 1 * wk, _tones(0xFF7BD88F));
    }
  }
  if (stage == 4 && sp != 'dragon') {
    for (final sd in [-1, 1]) {
      final x0 = bcx + sd * brx * .55;
      px.tri(x0, bcy - bry * .1, x0 + sd * 11, bcy - bry - 9, x0 + sd * 12, bcy + 1, _tones(0xFFEAF2FF));
      px.tri(x0 + sd * 1.5, bcy - bry * .1, x0 + sd * 8.5, bcy - bry - 5.5, x0 + sd * 9.5, bcy - 1, _tones(0xFFFFFFFF));
    }
  }
  if (sp == 'crow') {
    for (var i = 0; i < 3; i++) {
      px.tri(bcx + brx * .5 + i * 1.2 * k, bcy + bry * .1, bcx + brx * 1.5 + i * 1.4 * k, bcy + bry * (.5 + i * .25), bcx + brx * .75 + i * 1.2 * k, bcy + bry * 1.05, acc);
    }
    px.line(bcx - brx * .35, 43, bcx - brx * .35, 46, 0xFFF2A53A);
    px.line(bcx + brx * .35, 43, bcx + brx * .35, 46, 0xFFF2A53A);
  }

  if (sp == 'snake') {
    // دم
    px.ell(bcx + brx * 1.15, 42.2, 3.2 * k + .6, 1.4 * k + .5, base);
    px.ell(bcx + brx * 1.15 + 3.4 * k, 42.2, 1.8 * k + .5, 1.0 * k + .4, base);
    final coils = [
      [41.0, brx, 3.4 * k + .8],
      [41.0 - 5 * k, brx * .85, 3.0 * k + .7],
      [41.0 - 10 * k, brx * .66, 2.8 * k + .6],
    ];
    for (final c in coils) {
      px.ell(bcx, c[0], c[1], c[2], base);
      px.ell(bcx, c[0] + c[2] * .35, c[1] * .62, c[2] * .55, belly, onlyOn: true);
      for (var i = -2; i <= 2; i++) {
        final dx = (bcx + i * c[1] * .36).round();
        px.set(dx, (c[0] - c[2] * .45).round(), acc[1]);
        px.set(dx + 1, (c[0] - c[2] * .45).round(), acc[1]);
      }
    }
  } else {
    // بدن
    px.ell(bcx, bcy, brx, bry, base);
    px.ell(bcx, bcy + bry * .28, brx * .6, bry * .62, belly, onlyOn: true);
    for (final sd in [-1, 1]) {
      px.ell(bcx + sd * brx * .55, 43.2, 3.0 * k + .6, 1.9 * k + .5, sp == 'wolf' || sp == 'cat' ? base : base);
    }
    if (sp == 'dragon') {
      for (var i = -1; i <= 1; i++) {
        px.tri(bcx + i * brx * .35 - 1.4 * k, bcy - bry + .5, bcx + i * brx * .35 + 1.4 * k, bcy - bry + .5, bcx + i * brx * .35, bcy - bry - 2.4 * k - .5, _tones(0xFFF4DC8A));
      }
    }
    if (sp == 'crow') {
      for (final sd in [-1, 1]) {
        px.ell(bcx + sd * brx * .72, bcy, brx * .42, bry * .8, _tones(0xFF4A4A68));
      }
    }
    if (sp == 'wolf') {
      px.ell(bcx, bcy - bry * .1, brx * .5, bry * .85, belly, onlyOn: true);
    }
  }

  // ───── گوش و شاخ (پشت سر، قبل از کله) ─────
  if (sp == 'cat' || sp == 'wolf') {
    final eh = sp == 'wolf' ? 1.7 : 1.5;
    for (final sd in [-1, 1]) {
      px.tri(hcx + sd * hrx * .92, hcy - hry * .15, hcx + sd * hrx * .2, hcy - hry * .85, hcx + sd * hrx * (sp == 'wolf' ? .8 : .85), hcy - hry * eh, base);
      px.tri(hcx + sd * hrx * .75, hcy - hry * .35, hcx + sd * hrx * .38, hcy - hry * .8, hcx + sd * hrx * .72, hcy - hry * (eh - .3), sp == 'wolf' ? acc : _tones(0xFFFF9BB0));
    }
  }
  if (sp == 'dragon') {
    final hl = const [.6, .9, 1.2, 1.5, 1.8][stage];
    for (final sd in [-1, 1]) {
      px.tri(hcx + sd * hrx * .62, hcy - hry * .6, hcx + sd * hrx * .2, hcy - hry * .85, hcx + sd * hrx * .75, hcy - hry * .85 - 4.2 * hl, _tones(0xFFF4DC8A));
    }
  }

  // ───── کله ─────
  px.ell(hcx, hcy, hrx, hry, base);
  if (sp == 'snake') {
    px.ell(hcx, hcy + hry * .35, hrx * .7, hry * .5, belly, onlyOn: true);
  }
  if (sp == 'cat') {
    px.ell(hcx, hcy + hry * .42, hrx * .45, hry * .36, belly, onlyOn: true);
    for (final i in [-1, 0, 1]) {
      px.rect((hcx + i * hrx * .22).round(), (hcy - hry * .85).round(), (hcx + i * hrx * .22).round(), (hcy - hry * .5).round(), acc[1]);
    }
  }
  if (sp == 'dog') {
    px.ell(hcx, hcy + hry * .42, hrx * .52, hry * .42, belly, onlyOn: true);
    for (final sd in [-1, 1]) {
      px.ell(hcx + sd * hrx * 1.0, hcy + hry * .15, hrx * .3, hry * .62, acc);
    }
  }
  if (sp == 'wolf') {
    px.ell(hcx, hcy + hry * .45, hrx * .55, hry * .42, belly, onlyOn: true);
    for (final sd in [-1, 1]) {
      px.tri(hcx + sd * hrx * .95, hcy + hry * .1, hcx + sd * hrx * 1.35, hcy + hry * .55, hcx + sd * hrx * .75, hcy + hry * .75, belly);
    }
  }
  if (sp == 'dragon') {
    px.ell(hcx, hcy + hry * .42, hrx * .52, hry * .38, _tones(0xFF8FE0A0), onlyOn: true);
    for (final sd in [-1, 1]) {
      px.set((hcx + sd * hrx * .2).round(), (hcy + hry * .35).round(), acc[2]);
    }
  }
  if (sp == 'crow') {
    // منقار
    final open = face == 'eat' || face == 'happy';
    px.tri(hcx - hrx * .28, hcy + hry * .02, hcx + hrx * .28, hcy + hry * .02, hcx, hcy + hry * .62, _tones(0xFFF2A53A));
    if (open) px.set(hcx.round(), (hcy + hry * .5).round(), 0xFF7A2A2A);
  }

  // ───── صورت ─────
  final ey = hcy - hry * .1;
  final exo = hrx * .42;
  final big = stage == 0;
  final lx = (hcx - exo).round(), rx2 = (hcx + exo).round();
  const dark = 0xFF1A1A24;
  void eyeAt(int x) {
    if (face == 'blink') {
      px.rect(x - 1, ey.round() + 1, x, ey.round() + 1, dark);
    } else if (face == 'sleep') {
      px.set(x - 1, ey.round(), dark);
      px.set(x, ey.round() + 1, dark);
      px.set(x + 1, ey.round(), dark);
    } else if (face == 'happy') {
      px.set(x - 1, ey.round() + 1, dark);
      px.set(x, ey.round(), dark);
      px.set(x + 1, ey.round() + 1, dark);
    } else {
      final h = big ? 3 : 2;
      if (sp == 'crow') px.rect(x - 1, ey.round() - 1, x + 1, ey.round() + h - 1, 0xFFFFFFFF);
      px.rect(x, ey.round(), x, ey.round() + h - 1, dark);
      px.rect(x + (sp == 'crow' ? 0 : 1), ey.round(), x + (sp == 'crow' ? 0 : 1), ey.round() + h - 1, dark);
      if (sp != 'crow') px.set(x, ey.round(), 0xFFFFFFFF);
    }
  }

  eyeAt(lx);
  eyeAt(rx2);
  if (face == 'sad') px.set(rx2 + 1, ey.round() + 3, 0xFF7CC8FF);
  final mx = hcx, my = hcy + hry * .68;
  if (sp != 'crow') {
    if (sp == 'cat' || sp == 'dog' || sp == 'wolf') {
      px.set(hcx.round() - 1, (hcy + hry * .28).round(), face == 'sleep' ? dark : 0xFF2A1A1A);
      px.set(hcx.round(), (hcy + hry * .28).round(), face == 'sleep' ? dark : 0xFF2A1A1A);
    }
    final mxi = mx.round(), myi = my.round();
    if (face == 'eat') {
      px.ell(mx, my + .4, 2.2, 1.7, const [0xFF8A2D3A, 0xFF8A2D3A, 0xFF5E1D28]);
    } else if (face == 'happy') {
      px.rect(mxi - 1, myi, mxi + 1, myi, 0xFF8A2D3A);
      px.rect(mxi, myi + 1, mxi, myi + 1, 0xFFFF7A8A);
    } else if (face == 'sad') {
      px.set(mxi - 1, myi + 1, 0xFF5E2A2A);
      px.set(mxi, myi, 0xFF5E2A2A);
      px.set(mxi + 1, myi + 1, 0xFF5E2A2A);
    } else if (face == 'sleep') {
      px.set(mxi, myi, dark);
    } else {
      px.set(mxi - 1, myi, 0xFF5E2A2A);
      px.set(mxi, myi + 1, 0xFF5E2A2A);
      px.set(mxi + 1, myi, 0xFF5E2A2A);
    }
    if (sp == 'snake' && face != 'happy') {
      px.line(mx, my + 2, mx, my + 4, 0xFFE0334A);
      px.set(mxi - 1, myi + 5, 0xFFE0334A);
      px.set(mxi + 1, myi + 5, 0xFFE0334A);
    }
    if (sp == 'dog' && (face == 'happy' || face == 'eat2')) px.rect(mxi, myi + 1, mxi + 1, myi + 3, 0xFFFF7A9A);
  }
  if (face == 'happy' || face == 'eat' || face == 'eat2') {
    px.rect((hcx - hrx * .72).round(), (hcy + hry * .32).round(), (hcx - hrx * .72).round() + 1, (hcy + hry * .32).round(), 0xFFFF9BB0);
    px.rect((hcx + hrx * .72).round() - 1, (hcy + hry * .32).round(), (hcx + hrx * .72).round(), (hcy + hry * .32).round(), 0xFFFF9BB0);
  }
  if (sp == 'cat') {
    for (final sd in [-1, 1]) {
      px.line(hcx + sd * hrx * .55, hcy + hry * .4, hcx + sd * hrx * 1.1, hcy + hry * .3, 0xFFF0F0F0);
      px.line(hcx + sd * hrx * .55, hcy + hry * .5, hcx + sd * hrx * 1.1, hcy + hry * .58, 0xFFF0F0F0);
    }
  }

  if (stage == 4) {
    px.rect(hcx.round() - 1, (hcy - hry * .62).round(), hcx.round(), (hcy - hry * .62).round() + 1, 0xFF4FE3FF);
    px.set(hcx.round() - 1, (hcy - hry * .62).round(), 0xFFFFFFFF);
  }
  px.outline(0xFF20202C);
  return PetSprite(px, hcx, hcy, hrx, hry, bcx, bcy, brx, bry, mx, my, ey);
}

final _eggCache = <String, Px>{};
Px eggSprite(String sp, int cracks, [int rar = 0]) => _eggCache.putIfAbsent('$sp|$cracks|$rar', () {
      final px = Px(48, 48);
      final pc = _palFor(sp, rar);
      final shell = _tones(0xFFF7F0DE), spot = _tones(pc[0]);
      const cy = 27.0, ry = 19.0;
      for (var y = 0; y < 48; y++) {
        final t = (y + .5 - cy) / ry;
        if (t.abs() > 1) continue;
        final rx = 14.0 * math.sqrt(1 - t * t) * (1 + .18 * t);
        for (var x = (24 - rx).floor(); x <= (24 + rx).ceil(); x++) {
          final dx = (x + .5 - 24) / (rx < .5 ? .5 : rx);
          if (dx.abs() > 1) continue;
          final l = -dx * .55 - t * .8;
          px.set(x, y, l > .38 ? shell[0] : (l > -.3 ? shell[1] : shell[2]));
        }
      }
      px.ell(18, 31, 4.2, 3.4, spot, onlyOn: true);
      px.ell(30, 22, 3.6, 3.0, spot, onlyOn: true);
      px.ell(29, 36, 3.4, 2.4, _tones(pc[2]), onlyOn: true);
      px.ell(20, 17, 2.2, 1.8, _tones(pc[2]), onlyOn: true);
      const cr = 0xFF5B4A3A, glow = 0xFFFFE680;
      void zig(List<List<double>> pts) {
        for (var i = 0; i < pts.length - 1; i++) {
          px.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], cr);
          px.line(pts[i][0] + 1, pts[i][1], pts[i + 1][0] + 1, pts[i + 1][1], glow);
        }
      }

      if (cracks >= 1) zig([[24, 9], [22, 14], [26, 18]]);
      if (cracks >= 2) zig([[26, 18], [21, 23], [27, 28]]);
      if (cracks >= 3) {
        zig([[27, 28], [22, 33], [28, 38]]);
        zig([[22, 14], [17, 17], [15, 22]]);
        zig([[27, 28], [33, 26], [36, 30]]);
      }
      px.outline(0xFF20202C);
      return px;
    });

bool isNight() {
  final h = DateTime.now().hour;
  return h >= 23 || h < 6;
}

Widget petCanvas(Map h, {double size = 200, String face = 'idle', double bob = 0}) {
  final cell = size / 48;
  final rar = (h['rar'] as int?) ?? 0;
  if (h['hatched'] == false) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: PxPainter(eggSprite('${h['a']}', 0, rar))));
  }
  final sp = '${h['a']}';
  final stage = stageOf((h['lv'] as int?) ?? 1);
  final spr = petSprite(sp, stage, face, rar);
  final eq = Map<String, dynamic>.from((h['eq'] as Map?) ?? {});
  Widget item(String slot, double cx, double cy, double w) {
    final it = eq[slot] == null ? null : itemById('${eq[slot]}');
    if (it == null) return const SizedBox.shrink();
    final sz = w * cell;
    return Positioned(left: cx * cell - sz / 2, top: cy * cell - sz / 2, width: sz, height: sz, child: PxEmoji(it.emoji, sz));
  }

  final hatW = spr.hrx * 1.5, faceW = spr.hrx * 1.45;
  return SizedBox(
      width: size,
      height: size,
      child: Transform.translate(
          offset: Offset(0, bob),
          child: Stack(clipBehavior: Clip.none, children: [
            item('back', spr.bx - spr.brx * .95, spr.by - spr.bry * .2, spr.brx * 1.7),
            Positioned.fill(child: CustomPaint(painter: PxPainter(spr.px))),
            item('neck', spr.hx, spr.hy + spr.hry * .95, spr.brx * 1.05),
            item('face', spr.hx, spr.ey + .6, faceW),
            item('hat', spr.hx, spr.hy - spr.hry * .95 - hatW * .12, hatW),
            item('hand', spr.bx + spr.brx * 1.1, spr.by + spr.bry * .15, spr.brx * 1.3),
          ])));
}

Widget heroView(Map h, {double size = 110}) => petCanvas(h, size: size * 1.8);

// ── صحنه‌ی پت: تنفس، پلک، غذا خوردن، خوشحالی، تخم و بیرون آمدن ──
class ScenePainter extends CustomPainter {
  final String scene;
  final bool night;
  final int season;
  final Animation<double> anim;
  ScenePainter(this.scene, this.night, this.season, this.anim) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size s) {
    final t = anim.value;
    final u = s.width / 40;
    final gy = s.height * .8;
    final p = Paint()..isAntiAlias = false;
    void sky(Color a, Color b) => canvas.drawRect(Offset.zero & s, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, s.height), [a, b]));
    void box(double x, double y, double w, double h, Color c) {
      p.color = c;
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), p);
    }

    void ground(Color a, Color b) {
      box(0, gy, s.width, s.height - gy, a);
      box(0, gy, s.width, u * .9, b);
    }

    switch (scene) {
      case 'cave':
        sky(const Color(0xFF1B1626), const Color(0xFF3A2D4A));
        for (var i = 0; i < 9; i++) {
          final x = i * 4.6 * u, w = (2.4 + (i % 3)) * u, h = (4 + (i * 7 % 5)) * u;
          canvas.drawPath(Path()..moveTo(x, 0)..lineTo(x + w, 0)..lineTo(x + w / 2, h)..close(), p..color = const Color(0xFF2A2236));
        }
        for (var i = 0; i < 7; i++) {
          final pulse = .55 + .45 * math.sin(t * math.pi * 2 + i);
          box((3 + i * 5.3) * u, gy - (2 + (i % 3) * 1.5) * u, u * 1.2, u * (2 + (i % 3) * 1.5), (i.isEven ? const Color(0xFF58E0FF) : const Color(0xFFD27BFF)).withOpacity(pulse));
        }
        ground(const Color(0xFF4A4458), const Color(0xFF6A6480));
        break;
      case 'beach':
        sky(night ? const Color(0xFF1A2650) : const Color(0xFF8FD3FF), night ? const Color(0xFF3A4A8A) : const Color(0xFFFFF1D0));
        box(30 * u, 2.5 * u, 4 * u, 4 * u, night ? const Color(0xFFFFF0B0) : const Color(0xFFFFE066));
        box(0, s.height * .52, s.width, gy - s.height * .52, const Color(0xFF3FA9E0));
        for (var i = 0; i < 8; i++) {
          box(((i * 5.5 + t * 8) % 44 - 2) * u, s.height * .52 + (i % 3) * 2.2 * u, u * 3, u * .7, Colors.white.withOpacity(.8));
        }
        ground(const Color(0xFFF0D9A0), const Color(0xFFD9BE80));
        for (var i = 0; i < 6; i++) {
          box((3 + i * 6.2) * u, gy + (2 + (i % 2) * 2) * u, u * .9, u * .9, const Color(0xFFFF9BB0));
        }
        break;
      case 'castle':
        sky(night ? const Color(0xFF14183A) : const Color(0xFF5B6BD6), night ? const Color(0xFF3A2F6B) : const Color(0xFFF6B58A));
        const wall = Color(0xFF6B6F8F), dk = Color(0xFF4C5070);
        box(9 * u, gy - 9 * u, 22 * u, 9 * u, wall);
        for (final tx in [6.0, 30.0]) {
          box(tx * u, gy - 14 * u, 5 * u, 14 * u, dk);
          for (var i = 0; i < 3; i++) {
            box((tx + i * 2) * u, gy - 15.5 * u, u * 1.1, u * 1.5, dk);
          }
        }
        for (var i = 0; i < 8; i++) {
          box((9.5 + i * 2.8) * u, gy - 10.5 * u, u * 1.4, u * 1.5, wall);
        }
        box(18 * u, gy - 5 * u, 4 * u, 5 * u, const Color(0xFF2A2236));
        for (final wx in [11.5, 26.0]) {
          box(wx * u, gy - 7 * u, u * 1.4, u * 2, const Color(0xFFFFE066).withOpacity(.6 + .4 * math.sin(t * math.pi * 2 + wx)));
        }
        ground(const Color(0xFF8A8DA8), const Color(0xFFA7AAC4));
        for (var i = 0; i < 10; i++) {
          box(i * 4.2 * u, gy + 3 * u, u * 2, u * .5, const Color(0xFF70738C));
        }
        break;
      case 'space':
        sky(const Color(0xFF05061A), const Color(0xFF241B54));
        for (var i = 0; i < 26; i++) {
          final tw = .4 + .6 * math.sin(t * math.pi * 2 + i * 1.7).abs();
          box(((i * 13) % 40) * u, ((i * 7) % 28) * u, u * .6, u * .6, Colors.white.withOpacity(tw));
        }
        p.color = const Color(0xFFE59A5B);
        canvas.drawCircle(Offset(31 * u, 6 * u), 4.2 * u, p);
        box(25.5 * u, 5.6 * u, 11 * u, u * .8, const Color(0xFFF3D2A8));
        ground(const Color(0xFF9A9AAE), const Color(0xFFB8B8CC));
        for (final c in [[6.0, 3.0], [20.0, 5.0], [32.0, 3.5]]) {
          canvas.drawOval(Rect.fromLTWH(c[0] * u, gy + c[1] * u, u * 4, u * 1.4), p..color = const Color(0xFF7C7C92));
        }
        break;
      default:
        sky(night ? const Color(0xFF141B3A) : const Color(0xFF8FD3FF), night ? const Color(0xFF3A2F6B) : const Color(0xFFFFF1D0));
        if (night) {
          for (final st in [[4, 3], [11, 6], [19, 2], [27, 5], [33, 3], [37, 8], [8, 9], [24, 9]]) {
            box(st[0] * u, st[1] * u, u * .7, u * .7, const Color(0xFFFFF6C8));
          }
          box(31 * u, 2 * u, 3 * u, 3 * u, const Color(0xFFFFF0B0));
          box(32.2 * u, 1.6 * u, 2.6 * u, 2.6 * u, const Color(0xFF3A2F6B));
        } else {
          box(31 * u, 2.5 * u, 4 * u, 4 * u, const Color(0xFFFFE066));
          for (final c in [[5, 4, 7], [16, 8, 5], [24, 3, 6]]) {
            box(c[0] * u, c[1] * u, c[2] * u, 1.6 * u, Colors.white.withOpacity(.9));
            box((c[0] + 1) * u, (c[1] - 1) * u, (c[2] - 2) * u, 1.6 * u, Colors.white.withOpacity(.9));
          }
        }
        final g1 = [const Color(0xFF7CCB5B), const Color(0xFF6DBB4A), const Color(0xFFC8903A), const Color(0xFFEAF2F8)][season];
        final g2 = [const Color(0xFF5FAE45), const Color(0xFF4F9B3A), const Color(0xFFA9742A), const Color(0xFFCFE0EE)][season];
        ground(night ? Color.lerp(g1, Colors.black, .5)! : g1, night ? Color.lerp(g2, Colors.black, .5)! : g2);
        for (var i = 0; i < 14; i++) {
          box((i * 3.1 + 1) * u, gy + u * (1.5 + (i % 3) * 1.4), u * .8, u * .8, Color.lerp(g1, Colors.white, .22)!);
        }
        // ذرات فصلی: گلبرگ، برگ پاییزی، برف / کرم شب‌تاب
        if (season != 1 || night) {
          for (var i = 0; i < 16; i++) {
            final x = ((i * 29) % 40 + math.sin(t * math.pi * 2 + i) * 1.2) * u;
            final y = ((t * (.5 + (i % 4) * .18) + i * .173) % 1.0) * gy;
            final c = season == 1 ? const Color(0xFFFFF27A).withOpacity(.5 + .5 * math.sin(t * math.pi * 4 + i).abs()) : [const Color(0xFFFFB3C7), Colors.white, const Color(0xFFE0762A), Colors.white][season];
            box(x, season == 1 ? gy * (.5 + (i % 5) * .09) : y, u * .7, u * .7, c);
          }
        }
    }
  }

  @override
  bool shouldRepaint(ScenePainter o) => o.scene != scene || o.night != night || o.season != season;
}

class PetStage extends StatefulWidget {
  final Map hero;
  final VoidCallback onChanged;
  const PetStage({super.key, required this.hero, required this.onChanged});
  @override
  State<PetStage> createState() => PetStageState();
}

class PetStageState extends State<PetStage> with TickerProviderStateMixin {
  static final Map<String, int> _taps = {};
  late final AnimationController _idle, _act, _wob, _hatch;
  GItem? _food;
  VoidCallback? _afterEat;
  bool busy = false, _eaten = false;
  int _bite = 0;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
    _act = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
    _wob = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _hatch = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
    _act.addListener(() {
      if (_food == null) return;
      final t = _act.value;
      if (t >= .3 && t < .75) {
        final b = ((t - .3) / .45 * 4).floor();
        if (b > _bite) {
          _bite = b;
          sfx('munch');
        }
      }
      if (!_eaten && t >= .75) {
        _eaten = true;
        final cb = _afterEat;
        _afterEat = null;
        cb?.call();
      }
    });
    _act.addStatusListener((st) {
      if (st == AnimationStatus.completed) {
        busy = false;
        _food = null;
        if (mounted) setState(() {});
      }
    });
    _hatch.addStatusListener((st) {
      if (st == AnimationStatus.completed) {
        final h = widget.hero;
        _taps.remove('${h['id']}');
        Gm.hatched(h);
        final rr = (h['rar'] as int?) ?? 0;
        Gm.say('🐣 ${h['n']} به دنیا اومد!${rr == 2 ? '\n👑 پت افسانه‌ای!' : (rr == 1 ? '\n💎 پت نادر!' : '')}\nاز حالا ازش مراقبت کن و باهاش بزرگ شو.', true);
        _hatch.reset();
        widget.onChanged();
      }
    });
  }

  @override
  void didUpdateWidget(PetStage old) {
    super.didUpdateWidget(old);
    if (old.hero['id'] != widget.hero['id']) {
      _act.reset();
      _hatch.reset();
      busy = false;
      _food = null;
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _act.dispose();
    _wob.dispose();
    _hatch.dispose();
    super.dispose();
  }

  void feed(GItem it, VoidCallback onEaten) {
    if (busy) return;
    busy = true;
    _food = it;
    _afterEat = onEaten;
    _eaten = false;
    _bite = 0;
    _act.duration = const Duration(milliseconds: 2800);
    _act.forward(from: 0);
    setState(() {});
  }

  void react() {
    if (busy) return;
    busy = true;
    _food = null;
    _act.duration = const Duration(milliseconds: 1400);
    _act.forward(from: 0);
    setState(() {});
  }

  void _tapEgg() {
    if (_hatch.isAnimating) return;
    final id = '${widget.hero['id']}';
    final t = (_taps[id] ?? 0) + 1;
    _taps[id] = t;
    sfx('crack');
    _wob.forward(from: 0);
    setState(() {});
    if (t >= 3) {
      Future.delayed(const Duration(milliseconds: 520), () {
        if (!mounted) return;
        sfx('hatch');
        _hatch.forward(from: 0);
      });
    }
  }

  static const double S = 230;
  static const double H = 280;

  Widget _wrap(Widget child, {String? hint}) => SizedBox(
      height: H,
      width: double.infinity,
      child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: ScenePainter(Gm.bg, isNight(), seasonNow(), _idle))),
            Align(alignment: const Alignment(0, .78), child: SizedBox(width: S, height: S, child: child)),
            if (hint != null) Positioned(bottom: 8, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)), child: Text(hint, style: const TextStyle(color: Colors.white, fontSize: 12))))),
          ])));

  @override
  Widget build(BuildContext context) {
    final h = widget.hero;
    if (h['hatched'] == false) return _eggView(h);
    return _wrap(AnimatedBuilder(
        animation: Listenable.merge([_idle, _act]),
        builder: (c, _) {
          final cell = S / 48;
          final stage = stageOf((h['lv'] as int?) ?? 1);
          final rar = (h['rar'] as int?) ?? 0;
          final hungry = Gm.sat(h) < 25;
          final aura = rar == 2 ? const Color(0xFFFFD35A) : (stage == 4 ? const Color(0xFF7CE8FF) : null);
          final spr = petSprite('${h['a']}', stage, 'idle', rar);
          var face = 'idle';
          double jump = 0;
          final t = _act.value;
          final acting = _act.isAnimating;
          final iv = _idle.value;
          final widgets = <Widget>[];
          final mouth = Offset(spr.mx * cell, spr.my * cell);
          final hearts = <Widget>[];
          if (acting && _food != null) {
            if (t < .3) {
              final e = Curves.easeIn.transform(t / .3);
              final st = Offset(S * .98, -S * .02);
              final pos = Offset(st.dx + (mouth.dx - st.dx) * e, st.dy + (mouth.dy - st.dy) * e - math.sin(e * math.pi) * S * .12);
              widgets.add(Positioned(left: pos.dx - S * .1, top: pos.dy - S * .1, width: S * .2, height: S * .2, child: Transform.rotate(angle: e * 5, child: PxEmoji(_food!.emoji, S * .2))));
            } else if (t < .75) {
              final ph = (t - .3) / .45;
              face = ((ph * 8).floor() % 2 == 0) ? 'eat' : 'eat2';
              final left = 1 - ((ph * 4).floor()) * .24;
              final sz = S * .2 * left.clamp(.1, 1.0);
              widgets.add(Positioned(left: mouth.dx - sz / 2, top: mouth.dy - sz * .1, width: sz, height: sz, child: PxEmoji(_food!.emoji, sz)));
              jump = -math.sin(ph * math.pi * 8).abs() * 3;
            } else {
              face = 'happy';
            }
          } else if (acting) {
            face = 'happy';
          } else if (isNight()) {
            face = 'sleep';
          } else if (hungry) {
            face = 'sad';
          } else if (iv > .91 && iv < .96) {
            face = 'blink';
          }
          if (face == 'happy' && acting) {
            final hp = _food != null ? ((t - .75) / .25).clamp(0.0, 1.0).toDouble() : t;
            jump = -math.sin(hp * math.pi * 3).abs() * 16 * (1 - hp * .5);
            for (var i = 0; i < 5; i++) {
              final q = ((hp + i * .17) % 1.0);
              hearts.add(Positioned(
                  left: S * .5 + (i - 2) * 24 + math.sin(q * 6 + i) * 8 - 9,
                  top: S * .3 - q * 70 - i * 6,
                  child: Opacity(opacity: (1 - q).clamp(0.0, 1.0).toDouble(), child: const PxEmoji('❤️', 18))));
            }
          }
          final bob = math.sin(iv * math.pi * 2) * 1.6 + jump;
          final sq = 1 + math.sin(iv * math.pi * 2) * .015;
          return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: react,
              child: Stack(clipBehavior: Clip.none, children: [
                if (aura != null) Positioned.fill(child: Container(decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [aura.withOpacity(.35 + .1 * math.sin(iv * math.pi * 2)), Colors.transparent])))),
                if (rar == 2)
                  for (var i = 0; i < 6; i++)
                    Positioned(left: S * .5 + math.cos(iv * math.pi * 2 + i * math.pi / 3) * S * .4 - 9, top: S * .5 + math.sin(iv * math.pi * 2 + i * math.pi / 3) * S * .32 - 9, child: const Text('✨', style: TextStyle(fontSize: 18))),
                Positioned(left: S * .27, right: S * .27, bottom: S * .03, height: S * .05, child: DecoratedBox(decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(S)))),
                Transform(alignment: Alignment.bottomCenter, transform: Matrix4.diagonal3Values(1, sq, 1), child: petCanvas(h, size: S, face: face, bob: bob)),
                ...widgets,
                ...hearts,
                if (hungry && !acting && face != 'sleep') Positioned(left: spr.hx * cell + 16, top: spr.hy * cell - 44 + math.sin(iv * math.pi * 4) * 3, child: const PxEmoji('🍖', 24)),
                if (face == 'sleep') Positioned(left: spr.hx * cell + 18, top: spr.hy * cell - 40, child: const Text('💤', style: TextStyle(fontSize: 26))),
              ]));
        }));
  }

  Widget _eggView(Map h) {
    final id = '${h['id']}';
    final tp = _taps[id] ?? 0;
    final sp = '${h['a']}';
    final rar = (h['rar'] as int?) ?? 0;
    return GestureDetector(
        onTap: _tapEgg,
        child: _wrap(
            AnimatedBuilder(
                animation: Listenable.merge([_wob, _hatch]),
                builder: (c, _) {
                  final hv = _hatch.value;
                  if (_hatch.isAnimating && hv > 0) {
                    final lim = <Widget>[];
                    if (hv < .3) {
                      final rot = math.sin(hv * 90) * .22;
                      lim.add(Center(child: Container(width: S * (.3 + hv * 1.6), height: S * (.3 + hv * 1.6), decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [const Color(0xFFFFF2A0).withOpacity(.85 * hv / .3), Colors.transparent])))));
                      lim.add(Transform.rotate(alignment: Alignment.bottomCenter, angle: rot, child: SizedBox(width: S, height: S, child: CustomPaint(painter: PxPainter(eggSprite(sp, 3, rar))))));
                    } else {
                      final e = Curves.easeOut.transform(((hv - .3) / .7).clamp(0.0, 1.0).toDouble());
                      final shell = SizedBox(width: S, height: S, child: CustomPaint(painter: PxPainter(eggSprite(sp, 3, rar))));
                      lim.add(Center(child: Container(width: S * (.9 + e * 1.4), height: S * (.9 + e * 1.4), decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Colors.white.withOpacity((1 - e).clamp(0.0, 1.0) * .9), Colors.transparent])))));
                      final pe = Curves.elasticOut.transform(((hv - .34) / .66).clamp(0.0, 1.0).toDouble());
                      final babyH = Map<String, dynamic>.from(h)..['hatched'] = true;
                      lim.add(Transform.scale(alignment: Alignment.bottomCenter, scale: pe, child: petCanvas(babyH, size: S, face: 'happy', bob: -math.sin(e * math.pi) * 26)));
                      lim.add(Opacity(
                          opacity: (1 - e).clamp(0.0, 1.0).toDouble(),
                          child: Transform.translate(offset: Offset(-S * .3 * e, -S * .4 * e), child: Transform.rotate(angle: -1.0 * e, child: ClipRect(child: Align(alignment: Alignment.topCenter, heightFactor: .5, child: shell))))));
                      lim.add(Opacity(
                          opacity: (1 - e).clamp(0.0, 1.0).toDouble(),
                          child: Transform.translate(offset: Offset(S * .28 * e, S * .22 * e), child: Transform.rotate(angle: .8 * e, child: ClipRect(child: Align(alignment: Alignment.bottomCenter, heightFactor: .5, child: shell))))));
                      for (var i = 0; i < 10; i++) {
                        final a = i / 10 * math.pi * 2, r = S * (.15 + e * .55);
                        lim.add(Positioned(left: S / 2 + math.cos(a) * r - 9, top: S * .45 + math.sin(a) * r - 9, child: Opacity(opacity: (1 - e).clamp(0.0, 1.0).toDouble(), child: const Text('✨', style: TextStyle(fontSize: 18)))));
                      }
                    }
                    return Stack(clipBehavior: Clip.none, children: lim);
                  }
                  final w = math.sin(_wob.value * math.pi * 6) * .2 * (1 - _wob.value);
                  final eggW = Transform.rotate(alignment: Alignment.bottomCenter, angle: w, child: SizedBox(width: S, height: S, child: CustomPaint(painter: PxPainter(eggSprite(sp, tp.clamp(0, 3).toInt(), rar)))));
                  if (rar == 0) return eggW;
                  final gc = rar == 2 ? const Color(0xFFFFD35A) : const Color(0xFF7CC8FF);
                  return Stack(clipBehavior: Clip.none, children: [
                    Positioned.fill(child: Container(decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [gc.withOpacity(.4), Colors.transparent])))),
                    eggW,
                    for (var i = 0; i < 4; i++) Positioned(left: S * (.2 + i * .2), top: S * (.15 + (i % 2) * .5), child: const Text('✨', style: TextStyle(fontSize: 16))),
                  ]);
                }),
            hint: _hatch.isAnimating ? null : '🥚 روی تخم بزن! (${(3 - tp).clamp(0, 3)} ضربه‌ی دیگه)'));
  }
}

class FocusPet extends StatefulWidget {
  final Map hero;
  final bool running;
  const FocusPet({super.key, required this.hero, required this.running});
  @override
  State<FocusPet> createState() => _FocusPetState();
}

class _FocusPetState extends State<FocusPet> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _tm;
  int _msg = 0;
  static const msgs = ['تمرکز کن، من کنارتم 📖', 'تو می‌تونی 💪', 'داری عالی پیش می‌ری!', 'یه کم دیگه مونده ✨', 'آفرین، حواست جمعه 👏'];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _tm = Timer.periodic(const Duration(seconds: 7), (_) {
      if (mounted && widget.running) setState(() => _msg = (_msg + 1) % msgs.length);
    });
  }

  @override
  void dispose() {
    _tm?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hero;
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
        animation: _c,
        builder: (c, _) {
          final iv = _c.value;
          final hatched = h['hatched'] != false;
          final face = !hatched ? 'idle' : (Gm.sat(h) < 25 && !widget.running ? 'sad' : (iv > .9 && iv < .95 ? 'blink' : 'idle'));
          return Column(children: [
            if (widget.running)
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(14)),
                  child: Text(msgs[_msg], style: TextStyle(color: cs.onSecondaryContainer))),
            SizedBox(
                width: 170,
                height: 160,
                child: Stack(alignment: Alignment.bottomCenter, children: [
                  Positioned(top: 0, child: petCanvas(h, size: 150, face: face, bob: math.sin(iv * math.pi * 2) * 1.5)),
                  if (widget.running && hatched) Positioned(bottom: 2, child: const PxEmoji('📖', 46)),
                ])),
          ]);
        });
  }
}

class _Fall {
  double x, y, v;
  String e;
  int pts;
  bool bad;
  _Fall(this.x, this.y, this.v, this.e, this.pts, this.bad);
}

class CatchGame extends StatefulWidget {
  final Map hero;
  const CatchGame({super.key, required this.hero});
  @override
  State<CatchGame> createState() => _CatchGameState();
}

class _CatchGameState extends State<CatchGame> with SingleTickerProviderStateMixin {
  late final Ticker _tk;
  Duration _last = Duration.zero;
  final _rnd = math.Random();
  final items = <_Fall>[];
  double px = .5, left = 25, spawn = .4, faceT = 0;
  int score = 0, lives = 3;
  bool over = false, started = false;
  String result = '', face = 'idle';
  static const total = 25.0;

  @override
  void initState() {
    super.initState();
    _tk = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _tk.dispose();
    super.dispose();
  }

  void _tick(Duration d) {
    final dt = ((d - _last).inMicroseconds / 1e6).clamp(0.0, .05).toDouble();
    _last = d;
    if (over || !started) return;
    left -= dt;
    spawn -= dt;
    faceT -= dt;
    if (faceT <= 0) face = 'idle';
    if (spawn <= 0) {
      spawn = math.max(.28, .6 - (total - left) / total * .3);
      final bad = _rnd.nextDouble() < .2;
      const foods = ['🍎', '🐟', '🍖', '🍪', '🥚', '🍰'];
      final fi = _rnd.nextInt(foods.length);
      items.add(_Fall(.08 + _rnd.nextDouble() * .84, -.06, .38 + _rnd.nextDouble() * .2 + (total - left) / total * .25, bad ? '💣' : foods[fi], bad ? 0 : (fi == 5 ? 3 : 1), bad));
    }
    for (final it in items) {
      it.y += it.v * dt;
    }
    items.removeWhere((it) {
      if (it.y > .62 && it.y < .8 && (it.x - px).abs() < .14) {
        if (it.bad) {
          lives--;
          face = 'sad';
          sfx('delete');
        } else {
          score += it.pts;
          face = 'happy';
          sfx('munch');
        }
        faceT = .5;
        return true;
      }
      return it.y > 1.05;
    });
    if (left <= 0 || lives <= 0) {
      over = true;
      _finish();
    }
    setState(() {});
  }

  void _finish() {
    final key = 'mg:${ds(DateTime.now())}';
    final plays = prefs.getInt(key) ?? 0;
    if (plays >= 3) {
      result = 'امتیاز $score\nسقف جایزه‌ی امروز (۳ بار) پر شده؛ فردا دوباره بیا!';
    } else if (score > 0) {
      prefs.setInt(key, plays + 1);
      final c = math.min(25, score);
      result = 'امتیاز $score\nجایزه: $c سکه 🪙';
      Gm.earn(c, (score / 2).round());
    } else {
      result = 'امتیاز $score';
    }
    sfx(score > 10 ? 'hatch' : 'done');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: LayoutBuilder(builder: (c, cons) {
        final W = cons.maxWidth, H = cons.maxHeight;
        return GestureDetector(
            onHorizontalDragUpdate: (d) => setState(() => px = (px + d.delta.dx / W).clamp(.1, .9).toDouble()),
            child: Stack(children: [
              Positioned.fill(child: CustomPaint(painter: ScenePainter(Gm.bg, isNight(), seasonNow(), const AlwaysStoppedAnimation<double>(0)))),
              for (final it in items) Positioned(left: it.x * W - 20, top: it.y * H - 20, width: 40, height: 40, child: PxEmoji(it.e, 40)),
              Positioned(left: px * W - 60, top: H * .8 - 112, width: 120, height: 120, child: petCanvas(widget.hero, size: 120, face: face)),
              SafeArea(
                  child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        IconButton(icon: const Icon(Icons.close), color: Colors.white, onPressed: () => Navigator.pop(context)),
                        Expanded(child: Text('امتیاز: $score', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 4)]))),
                        Text('❤️' * lives, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 12),
                        Text('${left.ceil().clamp(0, 99)}s', style: const TextStyle(color: Colors.white, fontSize: 18, shadows: [Shadow(blurRadius: 4)])),
                        const SizedBox(width: 8),
                      ]))),
              if (!started || over)
                Center(
                    child: Card(
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(over ? 'بازی تموم شد' : 'گرفتن غذا 🍖', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(over ? result : 'پتت رو با انگشت چپ و راست ببر و غذاها رو بگیر.\nاز 💣 دوری کن! ۳ جون داری.\nروزی ۳ بار جایزه‌ی سکه داره.', textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton(
                                  onPressed: () {
                                    if (over) {
                                      Navigator.pop(context);
                                    } else {
                                      setState(() => started = true);
                                    }
                                  },
                                  child: Text(over ? 'بستن' : 'شروع')),
                            ])))),
            ]));
      }));
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
              Text('$d', style: TextStyle(color: fg, fontWeight: isToday ? FontWeight.bold : null)),
              if (m > 0)
                Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: isSel ? cs.onPrimary : cs.tertiary)),
            ]))));
  }
  return Column(children: [
    Row(children: [
      for (final s in ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'])
        Expanded(child: Center(child: Text(s, style: TextStyle(color: s == 'ج' ? Colors.red : cs.outline, fontSize: 12))))
    ]),
    const SizedBox(height: 4),
    GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        childAspectRatio: 1.1,
        physics: const NeverScrollableScrollPhysics(),
        children: cells),
  ]);
}

Future<DateTime?> pickDate(BuildContext c, {DateTime? initial, DateTime? first, DateTime? last, String? help}) {
  final f = first ?? DateTime(2020), l = last ?? DateTime(2045);
  var i = initial ?? DateTime.now();
  if (i.isBefore(f)) i = f;
  if (i.isAfter(l)) i = l;
  if (!jal) return showDatePicker(context: c, initialDate: i, firstDate: f, lastDate: l, helpText: help);
  return showDialog<DateTime>(context: c, builder: (_) => _JPick(i, f, l, help));
}

class _JPick extends StatefulWidget {
  final DateTime i, f, l;
  final String? help;
  const _JPick(this.i, this.f, this.l, this.help);
  @override
  State<_JPick> createState() => _JPickS();
}

class _JPickS extends State<_JPick> {
  late int y, m;
  late DateTime sel;
  @override
  void initState() {
    super.initState();
    sel = DateTime(widget.i.year, widget.i.month, widget.i.day);
    final j = g2j(sel.year, sel.month, sel.day);
    y = j[0];
    m = j[1];
  }

  void go(int d) => setState(() {
        m += d;
        if (m > 12) {
          m = 1;
          y++;
        }
        if (m < 1) {
          m = 12;
          y--;
        }
      });

  @override
  Widget build(BuildContext c) {
    final f = DateTime(widget.f.year, widget.f.month, widget.f.day), l = DateTime(widget.l.year, widget.l.month, widget.l.day);
    final now = DateTime.now(), today = DateTime(now.year, now.month, now.day);
    return AlertDialog(
      title: Text(widget.help ?? 'انتخاب تاریخ', style: const TextStyle(fontSize: 15)),
      content: SizedBox(
          width: 330,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.keyboard_double_arrow_right), onPressed: () => setState(() => y--)),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => go(-1)),
              Expanded(child: Center(child: Text('${jmn[m - 1]} $y', style: const TextStyle(fontWeight: FontWeight.bold)))),
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => go(1)),
              IconButton(icon: const Icon(Icons.keyboard_double_arrow_left), onPressed: () => setState(() => y++)),
            ]),
            monthGrid(c, y, m,
                sel: sel,
                ok: (d) => !d.isBefore(f) && !d.isAfter(l),
                onTap: (d) => Navigator.pop(c, d)),
          ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('انصراف')),
        if (!today.isBefore(f) && !today.isAfter(l)) TextButton(onPressed: () => Navigator.pop(c, today), child: const Text('امروز')),
      ],
    );
  }
}

// ───────────────────────── داده‌ها ─────────────────────────
class D {
  static List<Map> tasks = [], events = [], txs = [], goals = [], habits = [];
  static List<String> cats = [];
  static const defCats = ['غذا', 'حمل‌ونقل', 'خرید', 'قبوض', 'کار', 'سایر'];

  static List<Map> _readList(String key) {
    try {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.map<Map>((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static void load() {
    tasks = _readList('tasks');
    events = _readList('events');
    txs = _readList('txs');
    goals = _readList('goals');
    habits = _readList('habits');
    for (final h in habits) {
      h['log'] ??= [];
      h['id'] ??= DateTime.now().microsecondsSinceEpoch;
    }

    try {
      final c = jsonDecode(prefs.getString('cats') ?? 'null');
      cats = c is List ? c.map((e) => e.toString()).toList() : List.of(defCats);
    } catch (_) {
      cats = List.of(defCats);
    }
    if (!cats.contains('سایر')) cats.add('سایر');

    // مهاجرت امن: فیلدهای جدید فقط به داده‌های قبلی اضافه می‌شوند.
    var i = 0;
    for (final k in tasks) {
      k['subs'] ??= [];
      k['star'] ??= false;
      k['id'] ??= DateTime.now().microsecondsSinceEpoch + i++;
    }
    for (final x in txs) {
      x['id'] ??= DateTime.now().microsecondsSinceEpoch + i++;
      x['note'] ??= '';
    }
    for (final g in goals) {
      g['id'] ??= DateTime.now().microsecondsSinceEpoch + i++;
      g['progress'] ??= 0;
      g['deadline'] ??= ds(DateTime.now());
    }
    prefs.setInt('ver', kVer);
  }

  static Future<void> save() async {
    await prefs.setString('tasks', jsonEncode(tasks));
    await prefs.setString('events', jsonEncode(events));
    await prefs.setString('txs', jsonEncode(txs));
    await prefs.setString('goals', jsonEncode(goals));
    await prefs.setString('habits', jsonEncode(habits));
    await prefs.setString('cats', jsonEncode(cats));
  }

  static String backup() => jsonEncode({
        'app': 'Konj Planner',
        'ver': kVer,
        'tasks': tasks,
        'events': events,
        'txs': txs,
        'goals': goals,
        'habits': habits,
        'budgets': prefs.getString('budgets') ?? '{}',
        'cats': cats,
        'clr': prefs.getInt('clr') ?? 0,
        'tm': prefs.getInt('tm') ?? 0,
        'jal': jal,
        'hope': prefs.getInt('hope') ?? -1,
        'hero': prefs.getString('hero') ?? '{}',
        'moods': prefs.getString('moods') ?? '{}'
      });

  static Future<bool> restore(String s) async {
    try {
      final m = jsonDecode(s) as Map;
      final t = m['tasks'] is List ? m['tasks'] : [];
      final e = m['events'] is List ? m['events'] : [];
      final x = m['txs'] is List ? m['txs'] : [];
      final g = m['goals'] is List ? m['goals'] : [];
      await prefs.setString('tasks', jsonEncode(t));
      await prefs.setString('events', jsonEncode(e));
      await prefs.setString('txs', jsonEncode(x));
      await prefs.setString('goals', jsonEncode(g));
      if (m['habits'] is List) await prefs.setString('habits', jsonEncode(m['habits']));
      if (m['budgets'] is String) await prefs.setString('budgets', m['budgets']);
      if (m['cats'] is List) await prefs.setString('cats', jsonEncode(m['cats']));
      if (m['clr'] is int) await prefs.setInt('clr', m['clr']);
      if (m['tm'] is int) await prefs.setInt('tm', m['tm']);
      if (m['jal'] is bool) {
        jal = m['jal'];
        await prefs.setBool('jal', jal);
      }
      if (m['hope'] is int) await prefs.setInt('hope', m['hope']);
      if (m['hero'] is String) await prefs.setString('hero', m['hero']);
      if (m['moods'] is String) await prefs.setString('moods', m['moods']);
      load();
      Gm.load();
      look.value++;
      await scheduleAll();
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ───────────────────────── ویجت صفحه اصلی ─────────────────────────
String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

Future<void> syncHomeWidget() async {
  try {
    final now = DateTime.now(), today = ds(now);
    final open = D.tasks.where((k) => k['done'] != true).length;
    final overdue = D.tasks.where((k) {
      if (k['done'] == true || k['r'] == null) return false;
      try { return DateTime.parse(k['r']).isBefore(now); } catch (_) { return false; }
    }).length;
    final top = D.tasks.where((k) => k['done'] != true).toList()
      ..sort((a, b) {
        final s = (b['star'] == true ? 1 : 0) - (a['star'] == true ? 1 : 0);
        return s != 0 ? s : ((a['r'] ?? '9') as String).compareTo((b['r'] ?? '9') as String);
      });
    final hd = D.habits.where((h) => hDoneG(h, today)).length;
    final items = <Map>[
      for (final k in top.take(20)) {'k': 't', 'i': '☐', 'id': '${k['id']}', 't': '${k['star'] == true ? '★ ' : ''}${k['t']}', 'd': false},
      for (final h in D.habits) {'k': 'h', 'i': hDoneG(h, today) ? '✅' : '🔥', 'id': '${h['id']}', 't': '${h['t']}', 'd': hDoneG(h, today)},
    ];
    // رنگ ویجت از رنگ برنامه
    final p = pals[(prefs.getInt('clr') ?? 0).clamp(0, pals.length - 1)];
    final hsl = HSLColor.fromColor(p.c);
    final bg = p.darkBg ?? hsl.withSaturation(.38).withLightness(.16).toColor();
    final acc = hsl.withSaturation(.62).withLightness(.5).toColor();
    await HomeWidget.saveWidgetData<String>('wbg', _hex(bg));
    await HomeWidget.saveWidgetData<String>('wacc', _hex(acc));
    await HomeWidget.saveWidgetData<String>('today', fd(ds(now)));
    await HomeWidget.saveWidgetData<String>('summary', 'کار: $open  •  عقب‌افتاده: $overdue  •  عادت: $hd/${D.habits.length}');
    await HomeWidget.saveWidgetData<String>('items', jsonEncode(items));
    await HomeWidget.updateWidget(androidName: 'KonjPlannerWidgetProvider');
  } catch (_) {}
}

// ───────────────────────── اعلان‌ها ─────────────────────────
// تیک زدن کار از روی ویجت؛ در ایزوله‌ی پس‌زمینه اجرا می‌شود
@pragma('vm:entry-point')
Future<void> widgetBackground(Uri? uri) async {
  if (uri == null || uri.pathSegments.isEmpty) return;
  if (uri.host != 'done' && uri.host != 'habit') return;
  final id = int.tryParse(uri.pathSegments.first);
  if (id == null) return;
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  jal = prefs.getBool('jal') ?? true;
  D.load();
  Gm.load();
  final today = ds(DateTime.now());
  if (uri.host == 'done') {
    final hit = D.tasks.where((x) => x['id'] == id).toList();
    if (hit.isEmpty) return;
    hit.first['done'] = true;
    hit.first['doneAt'] = today;
    Gm.taskDone(hit.first);
  } else {
    final hit = D.habits.where((x) => x['id'] == id).toList();
    if (hit.isEmpty) return;
    final l = hit.first['log'] as List;
    if (l.contains(today)) {
      l.remove(today);
    } else {
      l.add(today);
      Gm.habitDone(hit.first, today);
    }
  }
  await D.save();
  await Gm.save();
  await syncHomeWidget();
}

const nd = NotificationDetails(
  android: AndroidNotificationDetails(
    'konj_reminders_v3',
    'یادآوری‌های Konj Planner',
    channelDescription: 'یادآوری کارها، برنامه‌ها و پیام‌های روزانه',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('konj_notify'),
    enableVibration: true,
    channelShowBadge: true,
    icon: 'ic_notif',
  ),
);

int taskNid(int id) => 1000000000 + (id.abs() % 500000000);
int eventNid(int id) => 1500000000 + (id.abs() % 500000000);

String lastErr = '';

Future<bool> zs(int id, String t, String b, tz.TZDateTime w, {bool weekly = false, bool daily = false, String? payload}) async {
  for (final mode in [AndroidScheduleMode.exactAllowWhileIdle, AndroidScheduleMode.alarmClock, AndroidScheduleMode.inexactAllowWhileIdle]) {
    try {
      await notif.zonedSchedule(id, t, b, w, nd,
          payload: payload,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: weekly ? DateTimeComponents.dayOfWeekAndTime : (daily ? DateTimeComponents.time : null));
      return true;
    } catch (e) {
      lastErr = '$e';
    }
  }
  return false;
}

tz.TZDateTime nextDaily(int m) {
  final now = DateTime.now();
  var t = DateTime(now.year, now.month, now.day, m ~/ 60, m % 60);
  if (!t.isAfter(now)) t = DateTime(now.year, now.month, now.day + 1, m ~/ 60, m % 60);
  return tz.TZDateTime.from(t, tz.local);
}

int habitNid(int id) => 1200000000 + (id.abs() % 300000000);

Future<void> scheduleHabit(Map h) async {
  final r = h['rem'];
  if (r is! int) return;
  await zs(habitNid(h['id'] as int), 'عادت: ${h['t']}', (h['min'] ?? '').toString().isEmpty ? 'وقتشه! امروز انجامش بده 🔥' : 'حداقلش: ${h['min']}', nextDaily(r), daily: true);
}

Future<void> scheduleCheckin(int m) async {
  try {
    await notif.cancel(800001);
  } catch (_) {}
  if (m >= 0) await zs(800001, 'امروز چطور بود؟', 'یه نگاه به خلاصه‌ی امروزت بنداز و حالت رو ثبت کن', nextDaily(m), daily: true, payload: 'checkin');
}

tz.TZDateTime nextAt(int wd, int m) {
  final now = DateTime.now();
  var t = DateTime(now.year, now.month, now.day).add(Duration(minutes: m));
  var day = DateTime(now.year, now.month, now.day);
  while (t.weekday != wd || !t.isAfter(now)) {
    day = DateTime(day.year, day.month, day.day + 1);
    t = DateTime(day.year, day.month, day.day, m ~/ 60, m % 60);
  }
  return tz.TZDateTime.from(t, tz.local);
}

Future<bool> schedule(Map e) {
  var s = (e['s'] as int) - 10;
  var wd = e['wd'] as int;
  if (s < 0) {
    s += 1440;
    wd = wd == 1 ? 7 : wd - 1;
  }
  return zs(eventNid(e['id'] as int), e['t'], 'شروع تا ۱۰ دقیقه‌ی دیگر', nextAt(wd, s), weekly: true);
}

Future<void> scheduleTask(Map k) async {
  if (k['r'] == null || k['done'] == true) return;
  try {
    final t = tz.TZDateTime.from(DateTime.parse(k['r']), tz.local);
    if (t.isAfter(tz.TZDateTime.now(tz.local))) {
      await zs(taskNid(k['id'] as int), 'یادآوری: ${k['t']}', 'زمانش رسیده', t);
    }
  } catch (_) {}
}

Future<bool> scheduleHope(int m) async {
  var ok = true;
  for (var i = 1; i <= 7; i++) {
    try {
      await notif.cancel(900000 + i);
    } catch (_) {}
  }
  for (var i = 0; i < 14; i++) {
    try {
      await notif.cancel(900100 + i);
    } catch (_) {}
  }
  if (m < 0) return true;
  final now = DateTime.now();
  for (var i = 0; i < 14; i++) {
    final day = DateTime(now.year, now.month, now.day + i);
    final t = DateTime(day.year, day.month, day.day, m ~/ 60, m % 60);
    if (!t.isAfter(now)) continue;
    ok = await zs(900100 + i, 'یه پیام برای تو', hopeFor(day), tz.TZDateTime.from(t, tz.local)) && ok;
  }
  return ok;
}

Future<void> scheduleAll() async {
  try {
    await notif.cancelAll(); // پاک‌کردن زمان‌بندی‌های قدیمی/یتیم تا دوبار نوتیف نیاد
  } catch (_) {}
  final today = ds(DateTime.now());

  for (final e in D.events) {
    try {
      final nid = eventNid(e['id'] as int);
      if ((e['to'] as String).compareTo(today) < 0) {
        await notif.cancel(nid);
      } else {
        await schedule(e);
      }
    } catch (_) {}
  }

  for (final k in D.tasks) {
    try {
      await scheduleTask(k);
    } catch (_) {}
  }

  for (final hb in D.habits) {
    try {
      await scheduleHabit(hb);
    } catch (_) {}
  }
  final ck = prefs.getInt('chk') ?? 1290;
  try {
    await scheduleCheckin(ck);
  } catch (_) {}
  final fe = prefs.getInt('fEnd') ?? 0;
  if (fe > DateTime.now().millisecondsSinceEpoch) {
    await zs(7777, 'تمرکزت تموم شد 🎉', 'برگرد و سکه‌هات رو بگیر', tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, fe));
  }
  final h = prefs.getInt('hope') ?? -1;
  if (h >= 0) await scheduleHope(h);
}

Future<void> askPerms() async {
  final a = notif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  try {
    await a?.requestNotificationsPermission();
    await a?.requestExactAlarmsPermission();
  } catch (_) {}
  await scheduleAll();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // UI is mounted immediately. All local services are initialized by Bootstrap
  // after the first frame, so notification/widget failures can never block the UI.
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  bool ready = false;
  Object? error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      tzd.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Tehran'));
      prefs = await SharedPreferences.getInstance();
      jal = prefs.getBool('jal') ?? true;
      D.load();
      Gm.load();

      if (!mounted) return;
      setState(() => ready = true);

      // Never block the first frame with notifications or widgets.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initBackgroundServices();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ready) return const App();

    if (error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Konj Planner',
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 52),
                  const SizedBox(height: 16),
                  const Text('راه‌اندازی برنامه با مشکل مواجه شد', textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('$error', textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: () => setState(() { error = null; ready = false; _boot(); }), child: const Text('تلاش دوباره')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Konj Planner',
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.task_alt, size: 64),
              SizedBox(height: 16),
              Text('Konj Planner', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _initBackgroundServices() async {
  try {
    await HomeWidget.registerInteractivityCallback(widgetBackground);
  } catch (_) {}
  try {
    await notif.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notif'),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload == 'checkin') checkinReq.value++;
      },
    );
    try {
      final d = await notif.getNotificationAppLaunchDetails();
      if (d?.didNotificationLaunchApp == true && d?.notificationResponse?.payload == 'checkin') checkinReq.value++;
    } catch (_) {}

    final a = notif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await a?.requestNotificationsPermission();
    await a?.requestExactAlarmsPermission();
  } catch (_) {
    // Notification errors must never affect the app UI.
  }

  try {
    await scheduleAll();
  } catch (_) {}

  try {
    await syncHomeWidget();
  } catch (_) {}

  try {
    if (prefs.getBool('shake') ?? false) await shakeCh.invokeMethod('start');
  } catch (_) {}
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => ValueListenableBuilder<int>(
      valueListenable: look,
      builder: (c, _, __) {
        final p = pals[(prefs.getInt('clr') ?? 0).clamp(0, pals.length - 1)];
        final tm = [ThemeMode.system, ThemeMode.light, ThemeMode.dark][(prefs.getInt('tm') ?? 0).clamp(0, 2)];
        return MaterialApp(
          title: 'Konj Planner',
          debugShowCheckedModeBanner: false,
          theme: mk(p, Brightness.light),
          darkTheme: mk(p, Brightness.dark),
          themeMode: tm,
          builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
          home: const Home(),
        );
      });
}

// ───────────────────────── راهنما ─────────────────────────
class _GP {
  final IconData i;
  final String t, b;
  const _GP(this.i, this.t, this.b);
}

const _pages = [
  _GP(Icons.waving_hand, 'خوش اومدی!',
      'این برنامه چهار بخش داره: کارها، تقویم، اهداف و عادت‌ها، و مالی.\nاین راهنما هر بخش رو کوتاه توضیح می‌ده. هر وقت خواستی با دکمه‌ی ؟ بالای صفحه دوباره بازش کن.'),
  _GP(Icons.checklist, 'کارها',
      '• با دکمه‌ی + یک کار جدید بنویس. اگه خواستی چند «زیرمجموعه» هم براش اضافه کن.\n• ستاره‌ی کنار هر کار رو بزن تا مهم علامت بخوره و بالای لیست بمونه.\n• می‌تونی یه تاریخ و ساعت برای یادآوری بذاری.\n• کار رو با تیک انجام‌شده کن. با منوی ⋮ ویرایش یا زیرمجموعه اضافه کن.\n• کار رو به کنار بکش تا حذف بشه (چند ثانیه فرصت «بازگردانی» داری).\n• پایین صفحه گزارش امروز، هفته و ماه رو می‌بینی.'),
  _GP(Icons.calendar_month, 'برنامه‌ی هفتگی و تقویم',
      '• بالای صفحه تقویم شمسیه؛ روی هر روز بزنی برنامه‌ها و کارهای اون روز پایین نشون داده می‌شه. نقطه‌ی زیر عدد یعنی اون روز برنامه داری.\n• با + برنامه‌ی تکرارشونده (مثل کلاس) با روز هفته، ساعت شروع و پایان و تاریخ پایان ترم بساز.\n• ۱۰ دقیقه قبل از شروع بهت اعلان می‌آد.\n• روی هر برنامه بزنی ویرایشش می‌کنی و با آیکون سطل حذفش می‌کنی.'),
  _GP(Icons.track_changes, 'اهداف و عادت‌ها',
      '• هر دو در یک صفحه‌ان: بالا اهداف، پایین عادت‌ها.\n• برای هدف ددلاین بذار و درصد پیشرفت رو هر وقت خواستی عوض کن.\n• عادت‌ها رو هر روز تیک بزن تا زنجیره‌ات ادامه پیدا کنه.\n• با دکمه‌ی + می‌تونی هدف یا عادت جدید بسازی.'),
  _GP(Icons.account_balance_wallet, 'مالی',
      '• با + هزینه یا درآمد ثبت کن. مبلغ خودش هر سه رقم با نقطه جدا می‌شه تا خوندنش راحت باشه.\n• دسته رو انتخاب کن؛ با «مدیریت دسته‌ها» خودت دسته اضافه یا حذف کن.\n• روی هر تراکنش بزنی می‌تونی مبلغ، دسته و تاریخش رو اصلاح کنی. با آیکون سطل یا کشیدن حذف می‌شه.\n• بالای صفحه جمع امروز، دیروز، این هفته، هفته‌ی قبل، این ماه و ماه قبل (با نام ماه شمسی) هست. با «تاریخچه» روزها، هفته‌ها و ماه‌های گذشته رو می‌بینی.\n• بودجه‌ی ماه جاری با میزان مصرف و باقی‌مانده هر دسته توی همین صفحه نشون داده می‌شه.'),
  _GP(Icons.timer, 'تمرکز و قهرمان',
      '• در بخش تمرکز، مدت رو انتخاب کن و تایمر رو شروع کن؛ بعد از تموم شدنش سکه می‌گیری.\n• با انجام کارها، عادت‌ها و رسیدن به هدف هم سکه و تجربه می‌گیری.\n• در بخش قهرمان یه حیوون بساز و اسمش رو بذار. با سکه براش غذا و آیتم بخر. غذا تجربه می‌ده و سطحش رو بالا می‌بره.\n• پت از تخم شروع می‌شه: سه بار روش بزن تا باز بشه. با بالا رفتن سطح بزرگ‌تر می‌شه و غذا و آیتم‌ها رو توی صحنه می‌بینی.\n• وقتی تمرکز روشنه نمی‌تونی از برنامه بیرون بری؛ اگه بری جلسه متوقف می‌شه.\n• پت سیری داره و کم‌کم گرسنه می‌شه؛ گرسنه که باشه تجربه‌ها نصف حساب می‌شن. پت سیر هنگام تمرکز ۲۵٪ سکه‌ی اضافه می‌ده.\n• تخم‌ها گاهی نادر 💎 یا افسانه‌ای 👑 درمیان؛ «تخم ویژه» حتماً یکی از این دوتاست. در سطح ۳۰ پت به شکل افسانه‌ای تکامل پیدا می‌کنه.\n• از فروشگاه می‌تونی پس‌زمینه‌ی غار، ساحل، قلعه یا فضا بخری. دشت پیش‌فرض با فصل‌ها عوض می‌شه.\n• مینی‌بازی «گرفتن غذا» روزی ۳ بار جایزه‌ی سکه داره.\n• زنجیره‌ی عادت‌ها و رسیدن به اهداف جایزه‌ی ویژه داره.\n• با آیکون 🙂 بالای صفحه، حال و خلاصه‌ی امروزت رو ثبت می‌کنی.'),
  _GP(Icons.settings, 'تنظیمات',
      'با آیکون چرخ‌دنده:\n• رنگ برنامه و حالت روشن/تیره (نارنجی با پس‌زمینه‌ی خاکستری تیره هم داریم)\n• نمایش تاریخ شمسی\n• روشن/خاموش کردن صدای محیط برنامه\n• پیام امیدبخش روزانه: ساعتش رو انتخاب کن. دکمه‌ی «ارسال آزمایشی» هم برای تست هست.\n• پشتیبان‌گیری: از اطلاعاتت کپی نگه دار و هر وقت خواستی بازیابی کن.'),
  _GP(Icons.notifications_active, 'اجازه‌ها',
      'برای اینکه یادآورها دقیق بیان، اجازه‌ی اعلان و «زنگ و یادآور دقیق» رو بده و برنامه رو از محدودیت باتری آزاد کن (بعضی گوشی‌ها برنامه‌ها رو می‌بندن).\n\nدکمه‌ی پایین اجازه‌ها رو درخواست می‌کنه.'),
];

class Guide extends StatefulWidget {
  const Guide({super.key});
  @override
  State<Guide> createState() => _GuideS();
}

class _GuideS extends State<Guide> {
  final pc = PageController();
  int i = 0;
  void done() {
    prefs.setBool('guide', true);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext c) {
    final last = i == _pages.length - 1;
    return Scaffold(
      appBar: AppBar(title: const Text('راهنما'), actions: [TextButton(onPressed: done, child: const Text('رد کردن'))]),
      body: Column(children: [
        Expanded(
            child: PageView(controller: pc, onPageChanged: (v) => setState(() => i = v), children: [
          for (final p in _pages)
            SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  const SizedBox(height: 16),
                  Icon(p.i, size: 72, color: Theme.of(c).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(p.t, style: Theme.of(c).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  Text(p.b, style: const TextStyle(fontSize: 16, height: 1.9)),
                  if (p == _pages.last) ...[
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                        onPressed: askPerms, icon: const Icon(Icons.verified_user), label: const Text('درخواست اجازه‌ها')),
                  ]
                ])),
        ])),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var k = 0; k < _pages.length; k++)
            Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: k == i ? Theme.of(c).colorScheme.primary : Theme.of(c).colorScheme.outlineVariant)),
        ]),
        Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              if (i > 0)
                OutlinedButton(
                    onPressed: () => pc.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                    child: const Text('قبلی')),
              const Spacer(),
              FilledButton(
                  onPressed: last ? done : () => pc.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                  child: Text(last ? 'شروع' : 'بعدی')),
            ])),
      ]),
    );
  }
}

// ───────────────────────── صفحه‌ی اصلی ─────────────────────────
class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _H();
}

class _Sub {
  final TextEditingController c;
  bool done;
  _Sub(String t, this.done) : c = TextEditingController(text: t);
}

class _H extends State<Home> with WidgetsBindingObserver {
  int tab = 0, cy = 1400, cm = 1, hv = 0, fMin = 25, fType = 0, fMon = 0;
  final stageKey = GlobalKey<PetStageState>();
  Uri? _pendingUri;
  bool _booted = false, _viaWidget = false;
  Timer? _ft;
  DateTime? rf, rt;
  String q = '';
  DateTime sel = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HomeWidget.widgetClicked.listen(_widgetUri);
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_widgetUri);
    sel = DateTime(sel.year, sel.month, sel.day);
    _setCalFrom(sel);
    Gm.onEvent = _gmEvent;
    checkinReq.addListener(_onCheckinReq);
    if ((prefs.getInt('fEnd') ?? 0) > 0) {
      prefs.setInt('fEnd', 0);
      prefs.setInt('fFail', 1);
      notif.cancel(7777);
    }
    _focusResume();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _booted = true;
      if (_pendingUri != null) {
        final u = _pendingUri;
        _pendingUri = null;
        _viaWidget = true;
        Future.delayed(const Duration(milliseconds: 250), () => _widgetUri(u));
      }
      _startup();
      _checkFocusFail();
      if (checkinReq.value > 0) _onCheckinReq();
    });
  }

  void _setCalFrom(DateTime d) {
    if (jal) {
      final j = g2j(d.year, d.month, d.day);
      cy = j[0];
      cm = j[1];
    } else {
      cy = d.year;
      cm = d.month;
    }
  }

  void _gmEvent(String m, bool big) {
    if (!mounted) return;
    if (big) {
      sfx('done');
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('🎉', textAlign: TextAlign.center, style: TextStyle(fontSize: 40)),
                content: Text(m, textAlign: TextAlign.center),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('عالی!'))],
              ));
    } else {
      toast(m);
    }
    setState(() {});
  }

  void _onCheckinReq() {
    if (!mounted || checkinReq.value == 0) return;
    checkinReq.value = 0;
    checkinDialog();
  }

  Future<void> _startup() async {
    if (!(prefs.getBool('guide') ?? false)) {
      openGuide();
      return;
    }
    final now = DateTime.now(), today = ds(now);
    if (prefs.getString('hopeDay') != today && !_viaWidget) {
      await prefs.setString('hopeDay', today);
      if (!mounted) return;
      await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('پیام امروز برای تو 💚'),
                content: Text(hopeFor(now), style: const TextStyle(fontSize: 16, height: 1.7)),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ممنون'))],
              ));
    }
    final chk = prefs.getInt('chk') ?? 1290;
    if (chk >= 0 && prefs.getString('chkDay') != today && readMoods()[today] == null && now.hour * 60 + now.minute >= chk) {
      await prefs.setString('chkDay', today);
      if (mounted) checkinDialog();
    }
  }

  // ── تمرکز ──
  void _focusTick() {
    final end = prefs.getInt('fEnd') ?? 0;
    if (end == 0) {
      _ft?.cancel();
      return;
    }
    if (DateTime.now().millisecondsSinceEpoch >= end) {
      _focusFinish();
    } else if (mounted && tab == 4) {
      setState(() {});
    }
  }

  void _focusResume() {
    _ft?.cancel();
    if ((prefs.getInt('fEnd') ?? 0) > 0) {
      _ft = Timer.periodic(const Duration(seconds: 1), (_) => _focusTick());
      _focusTick();
    }
  }

  void _keepOn(bool on) {
    try {
      shakeCh.invokeMethod('keepOn', on);
    } catch (_) {}
  }

  void _focusFail() {
    prefs.setInt('fEnd', 0);
    prefs.setInt('fFail', 1);
    _ft?.cancel();
    notif.cancel(7777);
    _keepOn(false);
    notif.show(7778, 'تمرکزت متوقف شد 😕', 'از برنامه بیرون رفتی؛ این جلسه سکه‌ای نداشت. دوباره امتحان کن!', nd);
  }

  void _checkFocusFail() {
    if ((prefs.getInt('fFail') ?? 0) != 1) return;
    prefs.setInt('fFail', 0);
    if (!mounted) return;
    sfx('fail');
    setState(() => tab = 4);
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              icon: const Text('😕', style: TextStyle(fontSize: 40)),
              title: const Text('تمرکزت متوقف شد'),
              content: const Text('وسط تمرکز از برنامه بیرون رفتی، برای همین این جلسه سکه‌ای نداشت. دفعه‌ی بعد گوشی رو کنار بذار و تا آخر بمون!'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('باشه'))],
            ));
  }

  Future<void> _focusStart() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('شروع تمرکز؟'),
              content: Text('تا $fMin دقیقه‌ی آینده نمی‌تونی از این بخش بیرون بیای. اگه از برنامه خارج بشی، جلسه متوقف می‌شه و سکه‌ای نمی‌گیری.\n\nصفحه روشن می‌مونه.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('نه')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('شروع')),
              ],
            ));
    if (ok != true) return;
    _keepOn(true);
    tab = 4;
    final end = DateTime.now().add(Duration(minutes: fMin)).millisecondsSinceEpoch;
    await prefs.setInt('fEnd', end);
    await prefs.setInt('fLen', fMin);
    await zs(7777, 'تمرکزت تموم شد 🎉', 'برگرد و سکه‌هات رو بگیر', tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, end));
    _focusResume();
    if (mounted) setState(() {});
  }

  void _focusFinish() {
    final len = prefs.getInt('fLen') ?? 25;
    prefs.setInt('fEnd', 0);
    _ft?.cancel();
    notif.cancel(7777);
    _keepOn(false);
    Gm.focusDone(len);
    if (mounted) setState(() {});
  }

  Future<void> _focusCancel() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('انصراف از تمرکز؟'),
              content: const Text('اگه الان انصراف بدی سکه‌ای نمی‌گیری.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ادامه می‌دم')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('انصراف')),
              ],
            ));
    if (ok != true) return;
    await prefs.setInt('fEnd', 0);
    _ft?.cancel();
    notif.cancel(7777);
    _keepOn(false);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    Gm.onEvent = null;
    checkinReq.removeListener(_onCheckinReq);
    _ft?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // برگشت به برنامه: تغییرهای ویجت (کار تیک‌خورده) دوباره خوانده می‌شود تا ذخیره‌ی بعدی روی‌شان نوشته نشود
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) async {
    if ((s == AppLifecycleState.paused || s == AppLifecycleState.hidden) && (prefs.getInt('fEnd') ?? 0) > 0) {
      _focusFail();
      return;
    }
    if (s != AppLifecycleState.resumed) return;
    _checkFocusFail();
    await prefs.reload();
    D.load();
    Gm.load();
    _focusResume();
    if (mounted) setState(() {});
    scheduleAll();
    syncHomeWidget();
  }

  void _widgetUri(Uri? u) {
    if (u == null || !mounted) return;
    if (u.host != 'addtask' && u.host != 'addtx') return;
    if (!_booted) {
      _pendingUri = u;
      return;
    }
    if ((prefs.getInt('fEnd') ?? 0) > 0) {
      toast('در حال تمرکز هستی!');
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      if (u.host == 'addtask') {
        setState(() => tab = 0);
        taskSheet();
      } else {
        setState(() => tab = 3);
        txSheet();
      }
    });
  }

  void openGuide() => Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const Guide()));

  Future<void> upd() async {
    await D.save();
    await syncHomeWidget();
    if (mounted) setState(() {});
  }

  void undo(String msg, VoidCallback back) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(content: Text(msg), action: SnackBarAction(label: 'بازگردانی', onPressed: back)));
  }

  void toast(String msg) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<String?> ask(String hint, [String init = '']) {
    final c = TextEditingController(text: init);
    return showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
              content: TextField(
                  controller: c,
                  autofocus: true,
                  decoration: InputDecoration(hintText: hint),
                  onSubmitted: (v) => Navigator.pop(context, v)),
              actions: [TextButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('ثبت'))],
            ));
  }

  // ── تنظیمات ──
  void settings() => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, set) {
            final hp = prefs.getInt('hope') ?? -1, cur = prefs.getInt('clr') ?? 0;
            return SafeArea(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('حالت نمایش', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 0, label: Text('خودکار')),
                            ButtonSegment(value: 1, label: Text('روشن')),
                            ButtonSegment(value: 2, label: Text('تیره')),
                          ],
                          selected: {prefs.getInt('tm') ?? 0},
                          onSelectionChanged: (s) {
                            prefs.setInt('tm', s.first);
                            look.value++;
                            set(() {});
                          }),
                      const SizedBox(height: 16),
                      const Text('رنگ برنامه', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 10, runSpacing: 10, children: [
                        for (var i = 0; i < pals.length; i++)
                          GestureDetector(
                              onTap: () {
                                prefs.setInt('clr', i);
                                look.value++;
                                syncHomeWidget();
                                set(() {});
                              },
                              child: Tooltip(
                                  message: pals[i].name,
                                  child: CircleAvatar(
                                      backgroundColor: pals[i].c,
                                      radius: 18,
                                      child: cur == i ? const Icon(Icons.check, color: Colors.white, size: 18) : null)))
                      ]),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('نمایش تاریخ شمسی'),
                          value: jal,
                          onChanged: (v) {
                            jal = v;
                            prefs.setBool('jal', v);
                            _setCalFrom(sel);
                            syncHomeWidget();
                            set(() {});
                            setState(() {});
                          }),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('صدای محیط برنامه'),
                          subtitle: const Text('صدای تیک‌زدن کار، افزودن و حذف'),
                          value: prefs.getBool('sfx') ?? true,
                          onChanged: (v) {
                            prefs.setBool('sfx', v);
                            set(() {});
                            if (v) sfx('done');
                          }),
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('پیام امیدبخش روزانه'),
                          subtitle: Text(hp < 0 ? 'خاموش (برای روشن کردن بزن)' : hm(hp)),
                          onTap: () async {
                            final t = await showTimePicker(
                                context: ctx,
                                initialTime: hp < 0 ? const TimeOfDay(hour: 9, minute: 0) : TimeOfDay(hour: hp ~/ 60, minute: hp % 60),
                                helpText: 'ساعت پیام');
                            if (t == null) return;
                            final m = t.hour * 60 + t.minute;
                            prefs.setInt('hope', m);
                            final ok = await scheduleHope(m);
                            if (!ok) toast('ثبت پیام ناموفق بود؛ اجازه‌ی اعلان را بررسی کن.');
                            set(() {});
                          },
                          trailing: TextButton(
                              onPressed: () async {
                                prefs.setInt('hope', -1);
                                await scheduleHope(-1);
                                set(() {});
                              },
                              child: const Text('خاموش'))),
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('پرسش حال روز و خلاصه‌ی روز'),
                          subtitle: Text((prefs.getInt('chk') ?? 1290) < 0 ? 'خاموش (برای روشن کردن بزن)' : 'هر روز ساعت ${hm(prefs.getInt('chk') ?? 1290)}'),
                          onTap: () async {
                            final cur = prefs.getInt('chk') ?? 1290;
                            final t = await showTimePicker(
                                context: ctx,
                                initialTime: cur < 0 ? const TimeOfDay(hour: 21, minute: 30) : TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
                                helpText: 'ساعت پرسش حال روز');
                            if (t == null) return;
                            final m = t.hour * 60 + t.minute;
                            prefs.setInt('chk', m);
                            await scheduleCheckin(m);
                            set(() {});
                          },
                          trailing: TextButton(
                              onPressed: () async {
                                prefs.setInt('chk', -1);
                                await scheduleCheckin(-1);
                                set(() {});
                              },
                              child: const Text('خاموش'))),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('باز شدن برنامه با تکان دادن گوشی'),
                          subtitle: const Text('یه اعلان دائمی کوچیک می‌خواد و برای باز شدن از پس‌زمینه، اجازه‌ی «نمایش روی سایر برنامه‌ها» لازمه'),
                          value: prefs.getBool('shake') ?? false,
                          onChanged: (v) async {
                            prefs.setBool('shake', v);
                            set(() {});
                            try {
                              if (v) {
                                await shakeCh.invokeMethod('start');
                                final ok = await shakeCh.invokeMethod('hasOverlay');
                                if (ok != true && ctx.mounted) {
                                  final go = await showDialog<bool>(
                                      context: ctx,
                                      builder: (dc) => AlertDialog(
                                            title: const Text('اجازه‌ی نمایش روی سایر برنامه‌ها'),
                                            content: const Text('بدون این اجازه اندروید نمی‌ذاره برنامه از پس‌زمینه خودش باز بشه؛ فقط یه اعلان می‌آد که با زدنش برنامه باز می‌شه. اجازه رو بدی؟'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('بعداً')),
                                              TextButton(onPressed: () => Navigator.pop(dc, true), child: const Text('باز کردن تنظیمات')),
                                            ],
                                          ));
                                  if (go == true) await shakeCh.invokeMethod('openOverlay');
                                }
                              } else {
                                await shakeCh.invokeMethod('stop');
                              }
                            } catch (_) {
                              toast('فعال‌سازی تکان ناموفق بود');
                            }
                          }),
                      Wrap(spacing: 8, children: [
                        OutlinedButton.icon(
                            icon: const Icon(Icons.notifications),
                            label: const Text('ارسال آزمایشی'),
                            onPressed: () => notif.show(1, 'یه پیام برای تو', hopeFor(DateTime.now()), nd)),
                        OutlinedButton.icon(
                            icon: const Icon(Icons.alarm),
                            label: const Text('یادآوری آزمایشی (۱ دقیقه بعد)'),
                            onPressed: () async {
                              final ok = await zs(999, 'یادآوری آزمایشی', 'اگه این رو می‌بینی، زمان‌بندی درست کار می‌کنه',
                                  tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1)));
                              toast(ok ? 'زمان‌بندی شد؛ تا یک دقیقه‌ی دیگه نوتیف میاد' : 'زمان‌بندی ناموفق بود: $lastErr');
                            }),
                        OutlinedButton.icon(
                            icon: const Icon(Icons.verified_user),
                            label: const Text('اجازه‌ی زنگ دقیق'),
                            onPressed: askPerms),
                      ]),
                      const Divider(height: 28),
                      const Text('پشتیبان‌گیری', style: TextStyle(fontWeight: FontWeight.bold)),
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.copy),
                          title: const Text('کپی پشتیبان همه‌ی اطلاعات'),
                          subtitle: const Text('متن کپی‌شده را جایی امن (مثلاً پیام‌های ذخیره‌شده) نگه دار'),
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: D.backup()));
                            toast('پشتیبان کپی شد');
                          }),
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.restore),
                          title: const Text('بازیابی از پشتیبان'),
                          onTap: () async {
                            Navigator.pop(ctx);
                            restoreDlg();
                          }),
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.help_outline),
                          title: const Text('راهنمای برنامه'),
                          onTap: () {
                            Navigator.pop(ctx);
                            openGuide();
                          }),
                    ])));
          }));

  Future<void> restoreDlg() async {
    final c = TextEditingController();
    final txt = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('بازیابی'),
              content: TextField(
                  controller: c,
                  maxLines: 6,
                  decoration: const InputDecoration(hintText: 'متن پشتیبان را اینجا بچسبان (اطلاعات فعلی جایگزین می‌شود)')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
                TextButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('بازیابی')),
              ],
            ));
    if (txt == null || txt.trim().isEmpty) return;
    final ok = await D.restore(txt.trim());
    toast(ok ? 'بازیابی انجام شد' : 'متن پشتیبان معتبر نیست');
    if (mounted) setState(() {});
  }

  // ── اهداف ──
  void delGoal(Map g) {
    sfx('delete');
    final i = D.goals.indexOf(g);
    D.goals.remove(g);
    upd();
    undo('هدف حذف شد', () {
      D.goals.insert(i.clamp(0, D.goals.length), g);
      upd();
    });
  }

  Future<void> goalSheet([Map? o]) async {
    final title = TextEditingController(text: o?['t'] ?? '');
    var progress = (o?['progress'] as int? ?? 0).clamp(0, 100);
    var deadline = o != null && o['deadline'] != null
        ? DateTime.parse(o['deadline'])
        : DateTime.now().add(const Duration(days: 30));
    var saved = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(o == null ? 'هدف جدید' : 'ویرایش هدف',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: title,
                  autofocus: o == null,
                  decoration: const InputDecoration(
                    labelText: 'هدف',
                    hintText: 'مثلاً راه‌اندازی کامل کُنج',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: const Text('ددلاین'),
                  subtitle: Text(fdl(deadline)),
                  onTap: () async {
                    final d = await pickDate(
                      ctx,
                      initial: deadline,
                      first: DateTime(2020),
                      last: DateTime.now().add(const Duration(days: 3650)),
                      help: 'ددلاین هدف',
                    );
                    if (d != null) set(() => deadline = d);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.trending_up),
                    const SizedBox(width: 12),
                    const Text('درصد پیشرفت'),
                    const Spacer(),
                    Text('$progress٪', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: progress.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  label: '$progress٪',
                  onChanged: (v) => set(() => progress = v.round()),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () {
                    if (title.text.trim().isEmpty) return;
                    saved = true;
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.check),
                  label: Text(o == null ? 'ثبت هدف' : 'ذخیره تغییرات'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!saved) return;
    final g = o ?? <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch,
    };
    g['t'] = title.text.trim();
    g['deadline'] = ds(deadline);
    final prevProg = (g['progress'] as int?) ?? 0;
    g['progress'] = progress;
    if (progress >= 100 && prevProg < 100) Gm.goalDone(g);

    if (o == null) {
      sfx('add');
      D.goals.add(g);
    }
    await D.save();
    if (mounted) setState(() {});
  }

  List<Widget> goalItems() {
    final now = DateTime.now();
    final list = List<Map>.from(D.goals)
      ..sort((a, b) {
        final ad = DateTime.tryParse(a['deadline'] ?? '') ?? DateTime(9999);
        final bd = DateTime.tryParse(b['deadline'] ?? '') ?? DateTime(9999);
        return ad.compareTo(bd);
      });

    String remaining(Map g) {
      final d = DateTime.tryParse(g['deadline'] ?? '');
      if (d == null) return '';
      final days = DateTime(d.year, d.month, d.day)
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;
      if (days < 0) return 'از ددلاین گذشته';
      if (days == 0) return 'ددلاین امروز';
      if (days == 1) return 'فردا';
      return '$days روز مانده';
    }

    return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.flag_circle, size: 42, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'هدف‌هایت را مشخص کن، درصد پیشرفت را هر وقت خواستی تغییر بده و ددلاین را جلوی چشمت نگه دار.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (list.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: const [
                  Icon(Icons.flag_outlined, size: 52),
                  SizedBox(height: 10),
                  Text('هنوز هدفی ثبت نکردی.'),
                  SizedBox(height: 4),
                  Text('با + اولین هدفت را بساز.'),
                ],
              ),
            ),
          ),
        for (final g in list)
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => goalSheet(g),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          (g['progress'] as int? ?? 0) >= 100
                              ? Icons.flag
                              : Icons.outlined_flag,
                          color: (g['progress'] as int? ?? 0) >= 100
                              ? Colors.green
                              : Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            g['t'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') goalSheet(g);
                            if (v == 'delete') delGoal(g);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                            PopupMenuItem(value: 'delete', child: Text('حذف')),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: ((g['progress'] as int? ?? 0).clamp(0, 100)) / 100,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('${g['progress'] ?? 0}٪'),
                        const Spacer(),
                        Text(remaining(g)),
                        const SizedBox(width: 8),
                        Text(fd(g['deadline'] ?? '')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    ];
  }

  // ── کارها ──
  void delTask(Map k) {
    sfx('delete');
    final i = D.tasks.indexOf(k);
    notif.cancel(taskNid(k['id'] as int));
    D.tasks.remove(k);
    upd();
    undo('کار حذف شد', () {
      D.tasks.insert(i.clamp(0, D.tasks.length), k);
      scheduleTask(k);
      upd();
    });
  }

  void toggle(Map k) {
    final d = k['done'] == true;
    if (!d) sfx('done');
    k['done'] = !d;
    if (!d) Gm.taskDone(k);
    k['doneAt'] = d ? null : ds(DateTime.now());
    if (d) {
      scheduleTask(k);
    } else {
      notif.cancel(taskNid(k['id'] as int));
    }
    upd();
  }

  Future<void> addSub(Map k) async {
    final s = await ask('زیرمجموعه‌ی جدید');
    if (s == null || s.trim().isEmpty) return;
    (k['subs'] as List).add({'t': s.trim(), 'done': false});
    upd();
  }

  Future<void> taskSheet([Map? o]) async {
    final title = TextEditingController(text: o?['t'] ?? '');
    final subs = <_Sub>[for (final s in (o?['subs'] as List? ?? [])) _Sub(s['t'], s['done'] == true)];
    DateTime? rem = o?['r'] != null ? DateTime.parse(o!['r']) : null;
    var saved = false;
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => StatefulBuilder(
            builder: (ctx, set) => Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
                child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextField(
                      controller: title,
                      autofocus: o == null,
                      decoration: const InputDecoration(labelText: 'کار (یک قدم مشخص)')),
                  const SizedBox(height: 8),
                  for (var i = 0; i < subs.length; i++)
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: subs[i].c,
                              decoration: InputDecoration(labelText: 'زیرمجموعه ${i + 1}', isDense: true))),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => set(() => subs.removeAt(i))),
                    ]),
                  Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('افزودن زیرمجموعه'),
                          onPressed: () => set(() => subs.add(_Sub('', false))))),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.alarm),
                      title: Text(rem == null ? 'بدون یادآوری (برای افزودن بزن)' : '${fd(rem!.toIso8601String())}   ${hm(rem!.hour * 60 + rem!.minute)}'),
                      trailing: rem == null ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => set(() => rem = null)),
                      onTap: () async {
                        final now = DateTime.now();
                        final d = await pickDate(ctx,
                            initial: rem ?? now,
                            first: now.subtract(const Duration(days: 1)),
                            last: now.add(const Duration(days: 730)),
                            help: 'روز یادآوری');
                        if (d == null) return;
                        final t = await showTimePicker(
                            context: ctx,
                            initialTime: rem != null ? TimeOfDay.fromDateTime(rem!) : TimeOfDay.now(),
                            helpText: 'ساعت یادآوری');
                        if (t == null) return;
                        set(() => rem = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                      }),
                  FilledButton(
                      onPressed: () {
                        if (title.text.trim().isEmpty) return;
                        saved = true;
                        Navigator.pop(ctx);
                      },
                      child: const Text('ثبت')),
                ])))));
    if (!saved) return;
    final so = [
      for (final s in subs)
        if (s.c.text.trim().isNotEmpty) {'t': s.c.text.trim(), 'done': s.done}
    ];
    final Map k;
    if (o == null) {
      k = <String, dynamic>{'id': DateTime.now().millisecondsSinceEpoch ~/ 1000, 'done': false, 'star': false};
      D.tasks.add(k);
    } else {
      k = o;
      notif.cancel(taskNid(k['id'] as int));
    }
    k['t'] = title.text.trim();
    k['subs'] = so;
    if (rem != null) {
      k['r'] = rem!.toIso8601String();
    } else {
      k.remove('r');
    }
    sfx('add');
    upd(); // اول ذخیره و نمایش؛ بعد زمان‌بندی اعلان
    await scheduleTask(k);
  }

  Widget tasks() {
    final now = DateTime.now(), t = ds(now), nowIso = now.toIso8601String();
    final wk = ds(now.subtract(Duration(days: (now.weekday + 1) % 7)));
    final mo = monthStart(now);
    final ev = D.events.where((e) => e['wd'] == now.weekday && t.compareTo(e['from']) >= 0 && t.compareTo(e['to']) <= 0).toList()
      ..sort(byStart);
    final overdue = D.tasks.where((k) {
      if (k['done'] == true || k['r'] == null) return false;
      try { return DateTime.parse(k['r']).isBefore(now); } catch (_) { return false; }
    }).toList();
    final needs = D.tasks.where((k) => k['done'] != true && !overdue.contains(k)).toList();
    final done = D.tasks.where((k) => k['done'] == true).toList();
    int taskSort(Map a, Map b) {
      final s = (b['star'] == true ? 1 : 0) - (a['star'] == true ? 1 : 0);
      return s != 0 ? s : (a['id'] as int).compareTo(b['id'] as int);
    }
    needs.sort(taskSort);
    overdue.sort((a, b) => ((a['r'] ?? '') as String).compareTo((b['r'] ?? '') as String));
    done.sort((a, b) => ((b['doneAt'] ?? '') as String).compareTo((a['doneAt'] ?? '') as String));

    Widget tile(Map k) {
      final d = k['done'] == true;
      final subs = (k['subs'] as List).cast<Map>();
      final sd = subs.where((s) => s['done'] == true).length;
      final info = [
        if (k['r'] != null) '⏰ ${fd(k['r'])}  ${(k['r'] as String).length >= 16 ? (k['r'] as String).substring(11, 16) : ''}',
        if (subs.isNotEmpty) 'زیرمجموعه: $sd از ${subs.length}',
      ].join('   •   ');
      return Dismissible(
          key: ObjectKey(k),
          background: Container(color: Colors.red),
          onDismissed: (_) => delTask(k),
          child: Card(
              child: Column(children: [
            ListTile(
                leading: Checkbox(value: d, onChanged: (_) => toggle(k)),
                title: Text(k['t'], style: d ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey) : null),
                subtitle: info.isEmpty ? null : Text(info),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      tooltip: 'مهم',
                      icon: Icon(k['star'] == true ? Icons.star : Icons.star_border, color: k['star'] == true ? Colors.amber : null),
                      onPressed: () {
                        k['star'] = k['star'] != true;
                        upd();
                      }),
                  PopupMenuButton<String>(
                      onSelected: (v) => v == 'e' ? taskSheet(k) : (v == 's' ? addSub(k) : delTask(k)),
                      itemBuilder: (_) => const [
                            PopupMenuItem(value: 'e', child: Text('ویرایش')),
                            PopupMenuItem(value: 's', child: Text('افزودن زیرمجموعه')),
                            PopupMenuItem(value: 'd', child: Text('حذف')),
                          ]),
                ])),
            for (final s in subs)
              CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.only(right: 40, left: 16),
                  value: s['done'] == true,
                  title: Text(s['t'],
                      style: s['done'] == true ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey) : null),
                  onChanged: (v) {
                    s['done'] = v == true;
                    upd();
                  }),
          ])));
    }

    Widget rep(String label, String from) {
      final dn = D.tasks.where((k) => k['done'] == true && ((k['doneAt'] ?? '') as String).compareTo(from) >= 0).length;
      final od = overdue.where((k) {
        final r = k['r'] as String?;
        return r != null && r.substring(0, 10).compareTo(from) >= 0;
      }).length;
      return ListTile(dense: true, title: Text(label), trailing: Text('انجام‌شده $dn   |   عقب‌افتاده $od'));
    }

    return ListView(padding: const EdgeInsets.all(12), children: [
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(icon: const Icon(Icons.bolt), label: const Text('حداقل روز'), onPressed: minimalDay),
        OutlinedButton.icon(icon: const Icon(Icons.insights), label: const Text('بازبینی هفته'), onPressed: weekReview),
      ]),
      for (final e in ev)
        Card(child: ListTile(leading: const Icon(Icons.schedule), title: Text(e['t']), subtitle: Text('${hm(e['s'])} – ${hm(e['e'])}'))),
      const Padding(padding: EdgeInsets.only(top: 12, bottom: 4), child: Text('نیاز به انجام', style: TextStyle(fontWeight: FontWeight.bold))),
      for (final k in needs) tile(k),
      if (needs.isEmpty) const Text('کار جدیدی برای انجام نداری.'),
      const Padding(padding: EdgeInsets.only(top: 16, bottom: 4), child: Text('عقب‌افتاده', style: TextStyle(fontWeight: FontWeight.bold))),
      for (final k in overdue) tile(k),
      if (overdue.isEmpty) const Text('کار عقب‌افتاده‌ای نداری.'),
      const Padding(padding: EdgeInsets.only(top: 16, bottom: 4), child: Text('انجام‌شده', style: TextStyle(fontWeight: FontWeight.bold))),
      for (final k in done) tile(k),
      if (done.isEmpty) const Text('هنوز کاری انجام‌شده ثبت نشده.'),
      const Divider(height: 32),
      const Text('گزارش کارها', style: TextStyle(fontWeight: FontWeight.bold)),
      Card(child: Column(children: [rep('امروز', t), rep('این هفته', wk), rep('این ماه', mo)])),
      const SizedBox(height: 80),
    ]);
  }

  // ── برنامه‌ی هفتگی و تقویم ──
  void delEvent(Map e) {
    sfx('delete');
    notif.cancel(eventNid(e['id'] as int));
    D.events.remove(e);
    upd();
    undo('برنامه حذف شد', () {
      D.events.add(e);
      schedule(e);
      upd();
    });
  }

  Future<void> addEvent([Map? o]) async {
    final title = await ask('عنوان (مثلاً کلاس ...)', o?['t'] ?? '');
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
                  Expanded(child: Center(child: Text('${jal ? jmn[cm - 1] : gmn[cm - 1]} $cy', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
                  TextButton(
                      onPressed: () {
                        setState(() {
                          _setCalFrom(today);
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
                          checkBudget(cat, ds(date), inc);
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

  void budgetAlert(String msg) {
    if (!mounted) return;
    sfx('delete');
    notif.show(5001 + (msg.hashCode.abs() % 900), 'هشدار بودجه', msg, nd);
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
              title: const Text('هشدار بودجه'),
              content: Text(msg),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('متوجه شدم'))],
            ));
  }

  String? _budgetMsg(String cat, Map<String, int> spent, Map<String, dynamic> b) {
    final bd = b[cat];
    if (bd is! num || bd <= 0) return null;
    final sp = spent[cat] ?? 0;
    if (sp > bd) return 'از بودجه‌ی «$cat» به اندازه‌ی ${n(sp - bd)} تومان بیشتر خرج کردی.\n(خرج: ${n(sp)} از ${n(bd)})';
    if (sp == bd) return 'بودجه‌ی «$cat» به سقفش رسید: ${n(sp)} از ${n(bd)} تومان.';
    return null;
  }

  void checkBudget(String cat, String dateIso, bool inc) {
    if (inc) return;
    final p = periods()[4];
    if (dateIso.compareTo(p['from'] as String) < 0 || dateIso.compareTo(p['to'] as String) >= 0) return;
    final m = _budgetMsg(cat, spentByCat(p['from'] as String, p['to'] as String), budgets);
    if (m != null) budgetAlert(m);
  }

  void checkAllBudgets() {
    final p = periods()[4];
    final sp = spentByCat(p['from'] as String, p['to'] as String), b = budgets;
    final msgs = [for (final k in b.keys) _budgetMsg(k, sp, b)].whereType<String>().toList();
    if (msgs.isNotEmpty) budgetAlert(msgs.join('\n\n'));
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

  Widget reportCard() {
    final now = DateTime.now();
    final days = [for (var i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i)];
    final dv = [for (final d in days) D.txs.where((x) => x['inc'] != true && x['d'] == ds(d)).fold<int>(0, (a, x) => a + (x['a'] as int))];
    final mx = dv.fold<int>(1, (a, v) => v > a ? v : a);
    final cs = Theme.of(context).colorScheme;
    return Card(
        color: cs.primaryContainer,
        child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: reportSheet,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Icon(Icons.bar_chart, size: 44, color: cs.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('گزارش نموداری', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.onPrimaryContainer)),
                    const SizedBox(height: 2),
                    Text('درآمد، هزینه و نمودار دسته‌ها', style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer)),
                  ])),
                  SizedBox(
                      height: 44,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        for (var i = 0; i < 7; i++)
                          Container(
                              width: 6,
                              height: 5 + 36.0 * dv[i] / mx,
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(3)))
                      ])),
                  Icon(Icons.chevron_left, color: cs.onPrimaryContainer),
                ]))));
  }

  Future<void> pickRange() async {
    final a = await pickDate(context, initial: rf ?? DateTime.now(), help: 'از تاریخ');
    if (a == null || !mounted) return;
    final b = await pickDate(context, initial: a, first: a, help: 'تا تاریخ');
    if (b == null) return;
    setState(() {
      rf = a;
      rt = b;
    });
  }

  IconData catIcon(String c) {
    if (c.contains('غذا') || c.contains('رستوران')) return Icons.restaurant;
    if (c.contains('حمل') || c.contains('رفت')) return Icons.directions_car;
    if (c.contains('خرید')) return Icons.shopping_bag_outlined;
    if (c.contains('قبض')) return Icons.receipt_long;
    if (c.contains('کار') || c.contains('حقوق')) return Icons.work_outline;
    if (c.contains('وام')) return Icons.event_available;
    if (c.contains('انتقال')) return Icons.swap_horiz;
    if (c.contains('سلامت') || c.contains('درمان')) return Icons.favorite_border;
    if (c.contains('سایر')) return Icons.category_outlined;
    return Icons.label_outline;
  }

  void catSheet(String cat, List<Map> list) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(cat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Flexible(
                      child: ListView(shrinkWrap: true, children: [
                    for (final x in list)
                      ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text((x['t'] ?? '') != '' ? '${x['t']}' : cat),
                          subtitle: Text(fd(x['d']) + ((x['note'] ?? '').toString().isNotEmpty ? ' • ${x['note']}' : '')),
                          trailing: Text(n(x['a'])),
                          onTap: () {
                            Navigator.pop(ctx);
                            txSheet(x);
                          }),
                  ])),
                ]))));
  }

  Widget money() {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final months = [for (var i = 0; i < 12; i++) _monthFirst(now, i)];
    final first = months[fMon], next = _monthFirst(now, fMon - 1);
    final from = ds(first), to = ds(next);
    final inc = fType == 1;
    final txs = inRange(from, to).where((x) => (x['inc'] == true) == inc).toList();
    final total = txs.fold<int>(0, (a, x) => a + (x['a'] as int));
    int len;
    if (jal) {
      final j = g2j(first.year, first.month, first.day);
      len = jmLen(j[0], j[1]);
    } else {
      len = DateTime(first.year, first.month + 1, 0).day;
    }
    final nb = (len / 7).ceil();
    final buckets = List<int>.filled(nb, 0);
    final byCat = <String, int>{};
    for (final x in txs) {
      final d = DateTime.parse(x['d']);
      final day = jal ? g2j(d.year, d.month, d.day)[2] : d.day;
      final i = ((day - 1) ~/ 7).clamp(0, nb - 1).toInt();
      buckets[i] += x['a'] as int;
      byCat['${x['c']}'] = (byCat['${x['c']}'] ?? 0) + (x['a'] as int);
    }
    final cats = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final mx = buckets.fold<int>(0, (a, v) => v > a ? v : a);
    final searching = q.isNotEmpty || rf != null;
    final fromS = rf == null ? null : ds(rf!), toS = rt == null ? null : ds(rt!);
    final found = D.txs.where((x) {
      if (!'${x['t'] ?? ''} ${x['c']} ${x['note'] ?? ''}'.contains(q)) return false;
      final d = x['d'] as String;
      if (searching) {
        if (fromS != null && d.compareTo(fromS) < 0) return false;
        if (toS != null && d.compareTo(toS) > 0) return false;
        return true;
      }
      return d.compareTo(from) >= 0 && d.compareTo(to) < 0 && (x['inc'] == true) == inc;
    }).toList()
      ..sort((a, b) {
        final c = (b['d'] as String).compareTo(a['d']);
        return c != 0 ? c : (b['id'] as int).compareTo(a['id'] as int);
      });
    Widget tabBtn(String t, int v) => Expanded(
        child: InkWell(
            onTap: () => setState(() => fType = v),
            child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(border: Border(bottom: BorderSide(width: 3, color: fType == v ? cs.primary : Colors.transparent))),
                child: Text(t, style: TextStyle(fontSize: 16, fontWeight: fType == v ? FontWeight.bold : FontWeight.normal, color: fType == v ? cs.primary : cs.outline)))));
    final barColor = inc ? Colors.green : cs.primary;
    return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 90), children: [
      Row(children: [tabBtn('هزینه‌ها', 0), tabBtn('درآمدها', 1)]),
      const Divider(height: 1),
      SizedBox(
          height: 56,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (var i = 0; i < months.length; i++)
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: ChoiceChip(label: Text(monthLabel(months[i])), selected: fMon == i, showCheckmark: false, onSelected: (_) => setState(() => fMon = i))),
          ])),
      Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: cs.outlineVariant)),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${n(total)} تومان', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    Text(inc ? 'مجموع درآمد ماه' : 'مجموع هزینه ماه', style: TextStyle(color: cs.outline)),
                  ])),
                  IconButton.filledTonal(icon: const Icon(Icons.bar_chart), tooltip: 'گزارش کامل‌تر', onPressed: reportSheet),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                    height: 170,
                    child: Stack(children: [
                      for (final f in [0.0, .5, 1.0]) Positioned(left: 0, right: 0, top: f * 150, child: Divider(height: 1, color: cs.outlineVariant)),
                      Positioned.fill(
                          bottom: 20,
                          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            for (final v in buckets)
                              Expanded(
                                  child: LayoutBuilder(
                                      builder: (c, cons) => Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                                            if (v == mx && v > 0) Text(n(v), style: const TextStyle(fontSize: 10)),
                                            Container(
                                                height: mx == 0 ? 0 : (cons.maxHeight - 16) * v / mx,
                                                margin: const EdgeInsets.symmetric(horizontal: 9),
                                                decoration: BoxDecoration(color: barColor.withOpacity(.75), borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))),
                                          ])))
                          ])),
                      Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Row(children: [
                            for (var i = 0; i < nb; i++)
                              Expanded(child: Text('${i * 7 + 1} تا ${math.min((i + 1) * 7, len)}', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: cs.outline)))
                          ])),
                    ])),
              ]))),
      Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: cs.outlineVariant)),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('دسته‌بندی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                if (cats.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('در این ماه تراکنشی نیست.', textAlign: TextAlign.center)),
                for (final e in cats)
                  InkWell(
                      onTap: () => catSheet(e.key, txs.where((x) => '${x['c']}' == e.key).toList()),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(children: [
                            Row(children: [
                              Icon(catIcon(e.key), color: barColor),
                              const SizedBox(width: 10),
                              Expanded(child: Text(e.key, style: const TextStyle(fontSize: 15))),
                              Text('${n(e.value)} تومان'),
                              const Icon(Icons.chevron_left),
                            ]),
                            const SizedBox(height: 6),
                            Row(children: [
                              SizedBox(width: 38, child: Text('${total == 0 ? 0 : (e.value * 100 / total).round()}٪', style: TextStyle(fontSize: 12, color: cs.outline))),
                              Expanded(child: LinearProgressIndicator(value: total == 0 ? 0 : e.value / total, minHeight: 6, borderRadius: BorderRadius.circular(6), color: barColor)),
                            ]),
                          ]))),
              ]))),
      if (!inc && fMon == 0) budgetCard(),
      const SizedBox(height: 4),
      TextField(
          decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'جستجو در همه‌ی تراکنش‌ها',
              suffixIcon: IconButton(icon: Icon(Icons.date_range, color: rf != null ? cs.primary : null), tooltip: 'جستجو در بازه‌ی تاریخ', onPressed: pickRange)),
          onChanged: (v) => setState(() => q = v.trim())),
      if (rf != null && rt != null)
        Wrap(children: [
          InputChip(
              avatar: const Icon(Icons.date_range, size: 18),
              label: Text('${fd(ds(rf!))} تا ${fd(ds(rt!))}'),
              onPressed: pickRange,
              onDeleted: () => setState(() {
                    rf = null;
                    rt = null;
                  })),
        ]),
      if (searching)
        Card(
            child: ListTile(
                title: Text('${found.length} مورد'),
                subtitle: Text('درآمد ${n(found.where((x) => x['inc'] == true).fold<int>(0, (a, x) => a + (x['a'] as int)))}  |  هزینه ${n(found.where((x) => x['inc'] != true).fold<int>(0, (a, x) => a + (x['a'] as int)))}'))),
      Padding(padding: const EdgeInsets.fromLTRB(4, 10, 4, 2), child: Text(searching ? 'نتیجه‌ی جستجو' : 'تراکنش‌های این ماه', style: const TextStyle(fontWeight: FontWeight.bold))),
      for (final x in found.take(300))
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
                    checkAllBudgets();
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
    int? rem = o?['rem'] is int ? o!['rem'] as int : null;
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
                child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: t, autofocus: o == null, decoration: const InputDecoration(labelText: 'عادت (مثلاً ورزش، مطالعه)')),
                  TextField(controller: m, decoration: const InputDecoration(labelText: 'نسخه‌ی حداقلی برای روزهای بد (مثلاً ۱ دقیقه)')),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.alarm),
                      title: const Text('یادآوری روزانه'),
                      subtitle: Text(rem == null ? 'خاموش (برای تنظیم بزن)' : 'هر روز ساعت ${hm(rem!)}'),
                      trailing: rem == null ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => set(() => rem = null)),
                      onTap: () async {
                        final p = await showTimePicker(
                            context: ctx,
                            initialTime: rem == null ? const TimeOfDay(hour: 20, minute: 0) : TimeOfDay(hour: rem! ~/ 60, minute: rem! % 60),
                            helpText: 'ساعت یادآوری عادت');
                        if (p != null) set(() => rem = p.hour * 60 + p.minute);
                      }),
                  const SizedBox(height: 8),
                  Row(children: [
                    if (o != null)
                      TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            sfx('delete');
                            D.habits.remove(o);
                            upd();
                            scheduleAll();
                          },
                          child: const Text('حذف')),
                    const Spacer(),
                    FilledButton(
                        onPressed: () {
                          if (t.text.trim().isEmpty) return;
                          if (o != null) {
                            o['t'] = t.text.trim();
                            o['min'] = m.text.trim();
                            if (rem == null) {
                              o.remove('rem');
                            } else {
                              o['rem'] = rem;
                            }
                          } else {
                            sfx('add');
                            D.habits.add(<String, dynamic>{
                              'id': DateTime.now().microsecondsSinceEpoch,
                              't': t.text.trim(),
                              'min': m.text.trim(),
                              'log': [],
                              if (rem != null) 'rem': rem
                            });
                          }
                          Navigator.pop(ctx);
                          upd();
                          scheduleAll();
                        },
                        child: const Text('ثبت')),
                  ]),
                ])))));
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
                  Text('زنجیره: ${streak(h)} روز${h['rem'] is int ? '   ⏰ ${hm(h['rem'] as int)}' : ''}'),
                ]),
                trailing: Checkbox(
                    value: hDone(h, today),
                    onChanged: (v) {
                      final l = h['log'] as List;
                      if (v == true) {
                        if (!l.contains(today)) l.add(today);
                        sfx('done');
                        Gm.habitDone(h, today);
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

  // ── بازبینی روز ──
  Map<String, dynamic> readReviews() {
    try {
      return Map<String, dynamic>.from(jsonDecode(prefs.getString('reviews') ?? '{}') as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> reviewSheet() async {
    final now = DateTime.now(), day = ds(now);
    final rv = readReviews();
    final cur = rv[day] as Map?;
    final good = TextEditingController(text: '${cur?['g'] ?? ''}');
    final imp = TextEditingController(text: '${cur?['i'] ?? ''}');
    final tom = TextEditingController(text: '${cur?['t'] ?? ''}');
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
              final doneT = D.tasks.where((k) => k['done'] == true && k['doneAt'] == day).length;
              final hDn = D.habits.where((h) => hDoneG(h, day)).length;
              final spent = D.txs.where((x) => x['inc'] != true && x['d'] == day).fold<int>(0, (a, x) => a + (x['a'] as int));
              final earned = D.txs.where((x) => x['inc'] == true && x['d'] == day).fold<int>(0, (a, x) => a + (x['a'] as int));
              final foc = prefs.getInt('fd:$day') ?? 0;
              final open = D.tasks.where((k) => k['done'] != true).take(8).toList();
              Widget stat(String e, String t) => Chip(label: Text('$e $t'), visualDensity: VisualDensity.compact);
              final past = rv.keys.where((k) => k != day).toList()..sort((a, b) => b.compareTo(a));
              return SafeArea(
                  child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
                      child: SingleChildScrollView(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                        Text('بازبینی روز • ${fdl(now)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, children: [
                          stat('✅', '$doneT کار انجام شد'),
                          stat('🔥', 'عادت $hDn از ${D.habits.length}'),
                          stat('🧠', '$foc دقیقه تمرکز'),
                          stat('💸', 'هزینه ${n(spent)}'),
                          if (earned > 0) stat('💰', 'درآمد ${n(earned)}'),
                        ]),
                        if (open.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Text('کارهای باقی‌مونده', style: TextStyle(fontWeight: FontWeight.bold)),
                          for (final k in open)
                            ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text('${k['t']}'),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconButton(tooltip: 'انجام شد', icon: const Icon(Icons.check_circle_outline), onPressed: () {
                                    toggle(k);
                                    set(() {});
                                  }),
                                  if (k['r'] != null)
                                    IconButton(tooltip: 'انتقال به فردا', icon: const Icon(Icons.redo), onPressed: () {
                                      try {
                                        final d = DateTime.parse(k['r']);
                                        k['r'] = DateTime(now.year, now.month, now.day + 1, d.hour, d.minute).toIso8601String();
                                        upd();
                                        scheduleAll();
                                        set(() {});
                                        toast('به فردا منتقل شد');
                                      } catch (_) {}
                                    }),
                                  IconButton(tooltip: 'حذف', icon: const Icon(Icons.delete_outline), onPressed: () {
                                    delTask(k);
                                    set(() {});
                                  }),
                                ])),
                        ],
                        const SizedBox(height: 8),
                        TextField(controller: good, maxLines: 2, decoration: const InputDecoration(labelText: 'امروز چی خوب پیش رفت؟')),
                        TextField(controller: imp, maxLines: 2, decoration: const InputDecoration(labelText: 'چی رو می‌شه بهتر کرد؟')),
                        TextField(controller: tom, maxLines: 2, decoration: const InputDecoration(labelText: 'سه اولویت فردا')),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: () {
                              rv[day] = {'g': good.text.trim(), 'i': imp.text.trim(), 't': tom.text.trim()};
                              prefs.setString('reviews', jsonEncode(rv));
                              if (Gm.rw.add('rv:$day')) Gm.earn(10, 20, '+۱۰ سکه برای بازبینی روز 🪙');
                              Navigator.pop(ctx);
                              toast('بازبینی ثبت شد');
                            },
                            child: const Text('ثبت بازبینی (+۱۰ سکه)')),
                        if (past.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('بازبینی‌های قبلی', style: TextStyle(fontWeight: FontWeight.bold)),
                          for (final k in past.take(5))
                            ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(fd(k)),
                                subtitle: Text('${(rv[k] as Map)['g'] ?? ''}\n${(rv[k] as Map)['t'] ?? ''}'.trim(), maxLines: 3, overflow: TextOverflow.ellipsis)),
                        ],
                      ]))));
            }));
  }

  // ── حال روز و خلاصه‌ی روز ──
  Future<void> checkinDialog() async {
    final now = DateTime.now(), day = ds(now);
    final moods = readMoods();
    var mood = (moods[day]?['m'] as int?) ?? -1;
    final note = TextEditingController(text: '${moods[day]?['n'] ?? ''}');
    final doneT = D.tasks.where((k) => k['done'] == true && k['doneAt'] == day).length;
    final openT = D.tasks.where((k) => k['done'] != true).length;
    final hDn = D.habits.where((h) => hDoneG(h, day)).length;
    final spent = D.txs.where((x) => x['inc'] != true && x['d'] == day).fold<int>(0, (a, x) => a + (x['a'] as int));
    const faces = ['😞', '😕', '😐', '🙂', '😄'];
    final week = [for (var i = 6; i >= 1; i--) ds(DateTime(now.year, now.month, now.day - i))];
    await showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
            builder: (ctx, set) => AlertDialog(
                  title: const Text('امروز چطور بود؟'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      for (var i = 0; i < 5; i++)
                        GestureDetector(
                            onTap: () => set(() => mood = i),
                            child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(shape: BoxShape.circle, color: mood == i ? Theme.of(ctx).colorScheme.primaryContainer : null),
                                child: Text(faces[i], style: const TextStyle(fontSize: 28))))
                    ]),
                    const SizedBox(height: 14),
                    const Text('خلاصه‌ی امروز', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('✅ کار انجام‌شده: $doneT   |   ☐ باقی‌مانده: $openT'),
                    Text('🔥 عادت‌ها: $hDn از ${D.habits.length}'),
                    Text('💸 هزینه‌ی امروز: ${n(spent)} تومان'),
                    const SizedBox(height: 12),
                    const Text('حال روزهای اخیر', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(children: [
                      for (final d in week)
                        Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: Text(moods[d] == null ? '·' : faces[((moods[d]['m'] as int?) ?? 2).clamp(0, 4).toInt()], style: const TextStyle(fontSize: 20)))
                    ]),
                    const SizedBox(height: 8),
                    TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'یادداشت امروز (اختیاری)')),
                  ])),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بعداً')),
                    TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          reviewSheet();
                        },
                        child: const Text('بازبینی روز')),
                    FilledButton(
                        onPressed: () {
                          if (mood < 0) return;
                          moods[day] = {'m': mood, 'n': note.text.trim()};
                          prefs.setString('moods', jsonEncode(moods));
                          Gm.checkin(day);
                          Navigator.pop(ctx);
                        },
                        child: const Text('ثبت')),
                  ],
                )));
    if (mounted) setState(() {});
  }

  // ── تمرکز ──
  Widget focusTab() {
    final end = prefs.getInt('fEnd') ?? 0;
    final running = end > 0;
    final len = prefs.getInt('fLen') ?? fMin;
    final left = running ? ((end - DateTime.now().millisecondsSinceEpoch) ~/ 1000).clamp(0, 86400).toInt() : 0;
    String mmss(int x) => '${(x ~/ 60).toString().padLeft(2, '0')}:${(x % 60).toString().padLeft(2, '0')}';
    final h = Gm.heroes.isEmpty ? null : Gm.heroes[Gm.active];
    return ListView(padding: const EdgeInsets.all(12), children: [
      Card(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                if (h != null) FocusPet(hero: h, running: running) else const Text('🎯', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                if (running) ...[
                  SizedBox(
                      width: 190,
                      height: 190,
                      child: Stack(alignment: Alignment.center, children: [
                        SizedBox(width: 190, height: 190, child: CircularProgressIndicator(value: (1 - left / (len * 60)).clamp(0.0, 1.0).toDouble(), strokeWidth: 10)),
                        Text(mmss(left), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold)),
                      ])),
                  const SizedBox(height: 12),
                  Text('جایزه‌ی این جلسه: ${focusCoins(len)} سکه و $len تجربه'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(icon: const Icon(Icons.stop), label: const Text('انصراف (بدون سکه)'), onPressed: _focusCancel),
                ] else ...[
                  const Text('مدت تمرکز', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    for (final m in [15, 25, 45, 60]) ChoiceChip(label: Text('$m دقیقه'), selected: fMin == m, onSelected: (_) => setState(() => fMin = m)),
                  ]),
                  const SizedBox(height: 12),
                  Text('جایزه: ${focusCoins(fMin)} سکه و $fMin تجربه برای قهرمانت 🪙'),
                  const SizedBox(height: 12),
                  FilledButton.icon(icon: const Icon(Icons.play_arrow), label: const Text('شروع تمرکز'), onPressed: _focusStart),
                ],
              ]))),
      Card(child: ListTile(leading: const Icon(Icons.timer_outlined), title: const Text('مجموع تمرکز'), subtitle: Text('${Gm.focusTotal ~/ 60} ساعت و ${Gm.focusTotal % 60} دقیقه'))),
      const Padding(
          padding: EdgeInsets.all(8),
          child: Text('گوشی رو کنار بذار و فقط روی یک کار تمرکز کن. وقتی تایمر تموم شد اعلان می‌آد و سکه‌ها حساب می‌شن. اگه از برنامه بیرون بری، تایمر ادامه داره.',
              style: TextStyle(fontSize: 12))),
    ]);
  }

  // ── قهرمان ──
  Future<void> playGame() async {
    if (Gm.heroes.isEmpty) return;
    final h = Gm.heroes[Gm.active];
    if (h['hatched'] == false) {
      toast('اول تخم رو باز کن 🥚');
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => CatchGame(hero: h)));
    if (mounted) setState(() {});
  }

  Future<void> createHeroSheet() async {
    final first = Gm.heroes.isEmpty;
    var animal = gAnimals.first.id;
    var premium = false;
    final name = TextEditingController();
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
              final cost = premium ? 400 : (first ? 0 : 150);
              return Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
                  child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('تخمت رو انتخاب کن 🥚', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
                      for (final a in gAnimals)
                        ChoiceChip(
                            label: Column(children: [Text(a.emoji, style: const TextStyle(fontSize: 34)), Text(a.name)]),
                            selected: animal == a.id,
                            onSelected: (_) => set(() => animal = a.id)),
                    ]),
                    const SizedBox(height: 8),
                    Text('غذای محبوب ${animalById(animal).name}: ${gItems.where((i) => i.love == animalById(animal).love).map((i) => '${i.emoji} ${i.name}').join('، ')} (۱٫۵ برابر تجربه)', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                        segments: [
                          ButtonSegment(value: false, label: Text(first ? 'تخم معمولی (رایگان)' : 'تخم معمولی (۱۵۰)')),
                          const ButtonSegment(value: true, label: Text('تخم ویژه (۴۰۰)')),
                        ],
                        selected: {premium},
                        onSelectionChanged: (v) => set(() => premium = v.first)),
                    Text(premium ? '💎 حتماً نادر یا 👑 افسانه‌ای (۳۰٪ افسانه‌ای)' : 'شانس نادر ۲۲٪ و افسانه‌ای ۸٪ (رنگ‌ها و درخشش خاص)', style: const TextStyle(fontSize: 12)),
                    TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم پت')),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: () {
                          final nm = name.text.trim();
                          if (nm.isEmpty) return;
                          if (Gm.coins < cost) {
                            Navigator.pop(ctx);
                            _noCoins(cost);
                            return;
                          }
                          Gm.coins -= cost;
                          Gm.create(animal, nm, rollRarity(premium));
                          sfx('add');
                          Navigator.pop(ctx);
                          setState(() {});
                          toast('تخمت آماده‌ست! سه بار روش بزن 🥚');
                        },
                        child: Text(cost == 0 ? 'گرفتن تخم' : 'گرفتن تخم ($cost سکه)')),
                  ])));
            }));
  }

  void _noCoins(int price) {
    sfx('delete');
    toast('سکه‌ی کافی نداری 🪙 ${price - Gm.coins} سکه‌ی دیگه لازمه؛ با کار، عادت و تمرکز سکه جمع کن');
  }

  Widget heroTab() {
    final h = Gm.heroes.isEmpty ? null : Gm.heroes[Gm.active];
    final cs = Theme.of(context).colorScheme;
    final kids = <Widget>[
      Card(child: ListTile(leading: const PxEmoji('🪙', 34), title: Text('${n(Gm.coins)} سکه'), subtitle: const Text('با انجام کارها، عادت‌ها و تمرکز سکه جمع کن'))),
    ];
    if (h == null) {
      kids.add(Card(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const PxEmoji('🥚', 72),
                const SizedBox(height: 8),
                const Text('هنوز پتی نداری', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('یه تخم انتخاب کن، سه بار روش بزن تا باز بشه و با کارهات پتت رو بزرگ کن. سکه‌ها و تجربه‌هایی که تا حالا گرفتی هم حفظ می‌شن.', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(icon: const Icon(Icons.add), label: const Text('گرفتن تخم'), onPressed: createHeroSheet),
              ]))));
    } else {
      final hatched = h['hatched'] != false;
      final lv = h['lv'] as int, xp = h['xp'] as int, nd2 = Gm.need(lv);
      kids.add(SizedBox(
          height: 52,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (var i = 0; i < Gm.heroes.length; i++)
              Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                      avatar: SizedBox(width: 30, height: 30, child: petCanvas(Gm.heroes[i], size: 30)),
                      label: Text('${Gm.heroes[i]['n']}'),
                      selected: Gm.active == i,
                      onSelected: (_) {
                        Gm.active = i;
                        Gm.save();
                        setState(() {});
                      })),
            ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('تخم جدید'), onPressed: createHeroSheet),
          ])));
      kids.add(PetStage(key: stageKey, hero: h, onChanged: () {
        if (mounted) setState(() {});
      }));
      if (hatched) {
        final plays = prefs.getInt('mg:${ds(DateTime.now())}') ?? 0;
        kids.add(Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(icon: const Icon(Icons.sports_esports), label: Text('مینی‌بازی گرفتن غذا (${math.max(0, 3 - plays)} بار جایزه‌دار امروز)'), onPressed: playGame)));
      }
      kids.add(Card(
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${h['n']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () async {
                        final v = await ask('اسم جدید', '${h['n']}');
                        if (v != null && v.trim().isNotEmpty) {
                          h['n'] = v.trim();
                          await Gm.save();
                          if (mounted) setState(() {});
                        }
                      }),
                ]),
                if (!hatched)
                  Text('🥚 هنوز تخمه! سه بار روش بزن تا باز بشه', style: TextStyle(color: cs.outline))
                else ...[
                  Text('${animalById('${h['a']}').name} • ${stageNames[stageOf(lv)]} • سطح $lv${((h['rar'] as int?) ?? 0) == 2 ? ' • 👑 افسانه‌ای' : (((h['rar'] as int?) ?? 0) == 1 ? ' • 💎 نادر' : '')}', style: TextStyle(color: cs.outline)),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Text('🍖 سیری '),
                    Expanded(child: LinearProgressIndicator(value: Gm.sat(h) / 100, minHeight: 8, color: Gm.sat(h) < 25 ? Colors.red : Colors.orange, borderRadius: BorderRadius.circular(8))),
                    Text(' ${Gm.sat(h).round()}٪'),
                  ]),
                  if (Gm.sat(h) < 25) const Text('پتت گرسنه‌ست! تا غذا نخوره تجربه‌ها نصف حساب می‌شن 😿', style: TextStyle(fontSize: 12, color: Colors.red)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: (xp / nd2).clamp(0.0, 1.0).toDouble(), minHeight: 10, borderRadius: BorderRadius.circular(8)),
                  const SizedBox(height: 4),
                  Text('تجربه: $xp از $nd2   (تا سطح بعد ${nd2 - xp})', style: const TextStyle(fontSize: 12)),
                  if (stageOf(lv) < 4) Text('تا مرحله‌ی «${stageNames[stageOf(lv) + 1]}»: سطح ${const [5, 10, 18, 30][stageOf(lv)]}', style: TextStyle(fontSize: 12, color: cs.outline)),
                ],
                if (Gm.pool > 0) Text('${Gm.pool} تجربه برای بعد از باز شدن تخم ذخیره شده', style: const TextStyle(fontSize: 12)),
              ]))));
      kids.add(SegmentedButton<int>(
          segments: const [ButtonSegment(value: 0, label: Text('فروشگاه')), ButtonSegment(value: 1, label: Text('کوله‌پشتی')), ButtonSegment(value: 2, label: Text('جوایز'))],
          selected: {hv},
          onSelectionChanged: (v) => setState(() => hv = v.first)));
      kids.add(const SizedBox(height: 8));
      Widget head(String t) => Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 2), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)));
      if (hv == 0) {
        for (final slot in slotNames.keys) {
          kids.add(head(slotNames[slot]!));
          for (final it in gItems.where((i) => i.slot == slot && i.price > 0)) {
            final owned = Gm.inv[it.id] ?? 0;
            final lovedBy = it.love.isEmpty ? null : gAnimals.where((a) => a.love == it.love).firstOrNull?.name;
            kids.add(ListTile(
                dense: true,
                leading: PxEmoji(it.emoji, 38),
                title: Text(it.name),
                subtitle: slot == 'food' ? Text('+${it.xp} تجربه${lovedBy != null ? ' • محبوب $lovedBy' : ''} • دارید: $owned') : null,
                trailing: slot != 'food' && owned > 0
                    ? const Text('✓ داری')
                    : FilledButton.tonal(
                        onPressed: () {
                          if (Gm.coins < it.price) {
                            _noCoins(it.price);
                            return;
                          }
                          if (Gm.buy(it)) {
                            sfx('add');
                            toast('${it.name} خریده شد');
                            setState(() {});
                            if (h['hatched'] != false && slot != 'food') stageKey.currentState?.react();
                          }
                        },
                        child: Text('${it.price} 🪙'))));
          }
        }
      } else if (hv == 1) {
        final eq = h['eq'] as Map;
        final gear = gItems.where((i) => i.slot != 'food' && (Gm.inv[i.id] ?? 0) > 0).toList();
        final food = gItems.where((i) => i.slot == 'food' && (Gm.inv[i.id] ?? 0) > 0).toList();
        if (gear.isEmpty && food.isEmpty) kids.add(const Padding(padding: EdgeInsets.all(16), child: Text('کوله‌پشتی خالیه؛ از فروشگاه خرید کن.')));
        if (gear.isNotEmpty) kids.add(head('آیتم‌ها'));
        if (gear.any((i) => i.slot == 'bg'))
          kids.add(ListTile(
              dense: true,
              leading: const PxEmoji('🌳', 38),
              title: const Text('دشت (پیش‌فرض)'),
              subtitle: const Text('پس‌زمینه • فصل‌ها خودکار عوض می‌شن'),
              trailing: Gm.bg == 'meadow'
                  ? const Text('✓ فعال')
                  : FilledButton.tonal(
                      onPressed: () => setState(() {
                            Gm.bg = 'meadow';
                            Gm.save();
                          }),
                      child: const Text('انتخاب'))));
        for (final it in gear) {
          final on = it.slot == 'bg' ? Gm.bg == it.id : eq[it.slot] == it.id;
          void tgl() {
            if (!hatched) {
              toast('اول تخم رو باز کن 🥚');
              return;
            }
            setState(() => Gm.equip(h, it));
            if (!on) {
              sfx('add');
              stageKey.currentState?.react();
            }
          }

          kids.add(ListTile(
              dense: true,
              leading: PxEmoji(it.emoji, 38),
              title: Text(it.name),
              subtitle: Text(slotNames[it.slot]!),
              trailing: on ? OutlinedButton(onPressed: tgl, child: Text(it.slot == 'bg' ? 'غیرفعال' : 'درآوردن')) : FilledButton.tonal(onPressed: tgl, child: Text(it.slot == 'bg' ? 'انتخاب' : 'پوشاندن'))));
        }
        if (food.isNotEmpty) kids.add(head('غذاها'));
        for (final it in food) {
          final loved = it.love.isNotEmpty && animalById('${h['a']}').love == it.love;
          kids.add(ListTile(
              dense: true,
              leading: PxEmoji(it.emoji, 38),
              title: Text('${it.name} × ${Gm.inv[it.id]}'),
              subtitle: Text(loved ? '+${(it.xp * 1.5).round()} تجربه (محبوبشه 😍)' : '+${it.xp} تجربه'),
              trailing: FilledButton.tonal(
                  onPressed: () {
                    if (!hatched) {
                      toast('اول تخم رو باز کن 🥚');
                      return;
                    }
                    final st = stageKey.currentState;
                    if (st == null || st.busy) return;
                    st.feed(it, () {
                      final m = Gm.feed(h, it);
                      if (m.isNotEmpty) toast(m);
                      if (mounted) setState(() {});
                    });
                  },
                  child: const Text('بخوراند'))));
        }
      } else {
        kids.add(const Padding(padding: EdgeInsets.all(4), child: Text('این آیتم‌ها فروخته نمی‌شن؛ فقط با دستاورد باز می‌شن.', style: TextStyle(fontSize: 12))));
        for (final it in gItems.where((i) => i.price == 0)) {
          final has = (Gm.inv[it.id] ?? 0) > 0;
          kids.add(ListTile(
              dense: true,
              leading: has ? PxEmoji(it.emoji, 38) : const Text('🔒', style: TextStyle(fontSize: 30)),
              title: Text(it.name),
              subtitle: Text(it.how),
              trailing: has ? const Icon(Icons.check_circle, color: Colors.green) : null));
        }
      }
    }
    kids.add(const SizedBox(height: 80));
    return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), children: kids);
  }

  @override
  Widget build(BuildContext c) {
    final locked = (prefs.getInt('fEnd') ?? 0) > 0;
    void lockMsg() => toast('در حال تمرکز هستی! اول تمرکز رو تموم کن یا انصراف بده');
    return PopScope(
        canPop: !locked,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && locked) lockMsg();
        },
        child: Scaffold(
          appBar: AppBar(title: Text(['کارها', 'تقویم', 'اهداف و عادت‌ها', 'مالی', 'تمرکز', 'پت من'][tab]), actions: [
            TextButton(onPressed: locked ? lockMsg : () => setState(() => tab = 5), child: Text('🪙 ${n(Gm.coins)}')),
            PopupMenuButton<String>(
                icon: const Icon(Icons.event_note),
                tooltip: 'حال و بازبینی روز',
                enabled: !locked,
                onSelected: (v) {
                  if (v == 'mood') checkinDialog();
                  if (v == 'review') reviewSheet();
                  if (v == 'help') openGuide();
                },
                itemBuilder: (_) => const [
                      PopupMenuItem(value: 'mood', child: Text('حال و خلاصه‌ی امروز')),
                      PopupMenuItem(value: 'review', child: Text('بازبینی روز')),
                      PopupMenuItem(value: 'help', child: Text('راهنما')),
                    ]),
            IconButton(icon: const Icon(Icons.settings), tooltip: 'تنظیمات', onPressed: locked ? lockMsg : settings),
          ]),
          body: [tasks, cal, plan, money, focusTab, heroTab][tab](),
          floatingActionButton: tab >= 4
              ? null
              : FloatingActionButton(onPressed: () => [() => taskSheet(), () => addEvent(), () => addPlan(), () => txSheet()][tab](), child: const Icon(Icons.add)),
          bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (i) {
                if (locked && i != 4) {
                  lockMsg();
                  return;
                }
                setState(() => tab = i);
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.checklist), label: 'کارها'),
                NavigationDestination(icon: Icon(Icons.calendar_month), label: 'تقویم'),
                NavigationDestination(icon: Icon(Icons.track_changes), label: 'اهداف'),
                NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'مالی'),
                NavigationDestination(icon: Icon(Icons.timer), label: 'تمرکز'),
                NavigationDestination(icon: Icon(Icons.pets), label: 'پت'),
              ]),
        ));
  }
}
