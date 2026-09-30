import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzd;
import 'package:timezone/timezone.dart' as tz;
import 'package:home_widget/home_widget.dart';

// ───────────────────────── تنظیمات و ثابت‌ها ─────────────────────────
const kVer = 4; // نسخه‌ی ساختار داده؛ با تغییر ساختار بالا ببر و در D.load مهاجرت بنویس
final notif = FlutterLocalNotificationsPlugin();
late SharedPreferences prefs;
final look = ValueNotifier<int>(0); // با هر تغییر ظاهر (رنگ/حالت تیره) زیاد می‌شود
bool jal = true;

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
  'هر روز یه شروع تازه‌ست. همین الان یه کار کوچیک رو شروع کن.'
];

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
  final first = jDate(jy, jm, 1);
  final off = (first.weekday + 1) % 7;
  final today = DateTime.now();
  final cells = <Widget>[for (var i = 0; i < off; i++) const SizedBox()];
  for (var d = 1; d <= jmLen(jy, jm); d++) {
    final dt = jDate(jy, jm, d);
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

// ───────────────────────── ویجت صفحه‌ی اصلی اندروید ─────────────────────────
Future<void> syncHomeWidget() async {
  try {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayTasks = D.tasks.where((k) {
      if (k['done'] == true) return false;
      final r = k['r'];
      if (r == null) return true;
      try {
        final d = DateTime.parse(r);
        return d.year == today.year && d.month == today.month && d.day == today.day;
      } catch (_) {
        return true;
      }
    }).toList();

    final doneToday = D.tasks.where((k) {
      if (k['done'] != true) return false;
      final r = k['r'];
      if (r == null) return false;
      try {
        final d = DateTime.parse(r);
        return d.year == today.year && d.month == today.month && d.day == today.day;
      } catch (_) {
        return false;
      }
    }).length;

    String nextTask = 'برای امروز کاری نداری 🎉';
    if (todayTasks.isNotEmpty) {
      todayTasks.sort((a, b) => ((a['r'] ?? '') as String).compareTo((b['r'] ?? '') as String));
      nextTask = (todayTasks.first['t'] ?? '').toString();
      if (nextTask.length > 34) nextTask = '${nextTask.substring(0, 34)}…';
    }

    final goalCount = D.goals.length;
    final goalAvg = goalCount == 0
        ? 0
        : (D.goals.map((g) => (g['progress'] as int? ?? 0)).reduce((a, b) => a + b) / goalCount).round();

    await Future.wait([
      HomeWidget.saveWidgetData<int>('today_tasks', todayTasks.length),
      HomeWidget.saveWidgetData<int>('done_today', doneToday),
      HomeWidget.saveWidgetData<int>('goal_count', goalCount),
      HomeWidget.saveWidgetData<int>('goal_avg', goalAvg),
      HomeWidget.saveWidgetData<String>('next_task', nextTask),
    ]);

    await HomeWidget.updateWidget(androidName: 'KonjWidgetProvider');
  } catch (_) {}
}

// ───────────────────────── داده‌ها ─────────────────────────
class D {
  static List<Map> tasks = [], events = [], txs = [], goals = [];
  static List<String> cats = [];
  static const defCats = ['غذا', 'حمل‌ونقل', 'خرید', 'قبوض', 'کار', 'سایر'];

  static List<Map> _readList(String key) {
    try {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static void load() {
    tasks = _readList('tasks');
    events = _readList('events');
    txs = _readList('txs');
    goals = _readList('goals');

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
    await prefs.setString('cats', jsonEncode(cats));
  }

  static String backup() => jsonEncode({
        'app': 'Konj Planner',
        'ver': kVer,
        'tasks': tasks,
        'events': events,
        'txs': txs,
        'goals': goals,
        'cats': cats,
        'clr': prefs.getInt('clr') ?? 0,
        'tm': prefs.getInt('tm') ?? 0,
        'jal': jal,
        'hope': prefs.getInt('hope') ?? -1
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
      if (m['cats'] is List) await prefs.setString('cats', jsonEncode(m['cats']));
      if (m['clr'] is int) await prefs.setInt('clr', m['clr']);
      if (m['tm'] is int) await prefs.setInt('tm', m['tm']);
      if (m['jal'] is bool) {
        jal = m['jal'];
        await prefs.setBool('jal', jal);
      }
      if (m['hope'] is int) await prefs.setInt('hope', m['hope']);
      load();
      look.value++;
      await scheduleAll();
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ───────────────────────── اعلان‌ها ─────────────────────────
const nd = NotificationDetails(
  android: AndroidNotificationDetails(
    'konj_reminders_v2',
    'یادآوری‌های Konj Planner',
    channelDescription: 'یادآوری کارها، برنامه‌ها و پیام‌های روزانه',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    channelShowBadge: true,
  ),
);

int taskNid(int id) => 200000000 + id;
int eventNid(int id) => 100000000 + id;

Future<bool> zs(int id, String t, String b, tz.TZDateTime w, {bool weekly = false}) async {
  try {
    await notif.zonedSchedule(
      id, t, b, w, nd,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: weekly ? DateTimeComponents.dayOfWeekAndTime : null,
    );
    return true;
  } catch (_) {
    try {
      await notif.zonedSchedule(
        id, t, b, w, nd,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: weekly ? DateTimeComponents.dayOfWeekAndTime : null,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

tz.TZDateTime nextAt(int wd, int m) {
  final now = tz.TZDateTime.now(tz.local);
  var day = tz.TZDateTime(tz.local, now.year, now.month, now.day);
  var t = day.add(Duration(minutes: m));
  while (t.weekday != wd || !t.isAfter(now)) {
    day = day.add(const Duration(days: 1));
    t = tz.TZDateTime(tz.local, day.year, day.month, day.day, m ~/ 60, m % 60);
  }
  return t;
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
    if (m >= 0) {
      ok = await zs(
        900000 + i,
        'یه پیام برای تو',
        hope[i - 1],
        nextAt(i, m),
        weekly: true,
      ) && ok;
    }
  }
  return ok;
}

Future<void> scheduleAll() async {
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
  tzd.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Tehran'));

  prefs = await SharedPreferences.getInstance();
  jal = prefs.getBool('jal') ?? true;
  D.load();

  // اول خود رابط برنامه را نمایش می‌دهیم؛ سرویس‌های جانبی نباید مانع بالا آمدن برنامه شوند.
  runApp(const App());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initBackgroundServices();
  });
}

Future<void> _initBackgroundServices() async {
  // اعلان‌ها، مجوزها و Widget در پس‌زمینه راه‌اندازی می‌شوند تا در صورت خطا
  // یا تأخیر سرویس‌های اندروید، صفحه اصلی برنامه سیاه یا متوقف نشود.
  try {
    await notif.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  } catch (_) {}

  try {
    final a = notif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await a?.requestNotificationsPermission();
  } catch (_) {}

  try {
    final a = notif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await a?.requestExactAlarmsPermission();
  } catch (_) {}

  try {
    await scheduleAll();
  } catch (_) {}

  try {
    await syncHomeWidget();
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
      'این برنامه چهار بخش داره: کارها، تقویم، اهداف و مالی.\nاین راهنما هر بخش رو کوتاه توضیح می‌ده. هر وقت خواستی با دکمه‌ی ؟ بالای صفحه دوباره بازش کن.'),
  _GP(Icons.checklist, 'کارها',
      '• با دکمه‌ی + یک کار جدید بنویس. اگه خواستی چند «زیرمجموعه» هم براش اضافه کن.\n• ستاره‌ی کنار هر کار رو بزن تا مهم علامت بخوره و بالای لیست بمونه.\n• می‌تونی یه تاریخ و ساعت برای یادآوری بذاری.\n• کار رو با تیک انجام‌شده کن. با منوی ⋮ ویرایش یا زیرمجموعه اضافه کن.\n• کار رو به کنار بکش تا حذف بشه (چند ثانیه فرصت «بازگردانی» داری).\n• پایین صفحه گزارش امروز، هفته و ماه رو می‌بینی.'),
  _GP(Icons.calendar_month, 'برنامه‌ی هفتگی و تقویم',
      '• بالای صفحه تقویم شمسیه؛ روی هر روز بزنی برنامه‌ها و کارهای اون روز پایین نشون داده می‌شه. نقطه‌ی زیر عدد یعنی اون روز برنامه داری.\n• با + برنامه‌ی تکرارشونده (مثل کلاس) با روز هفته، ساعت شروع و پایان و تاریخ پایان ترم بساز.\n• ۱۰ دقیقه قبل از شروع بهت اعلان می‌آد.\n• روی هر برنامه بزنی ویرایشش می‌کنی و با آیکون سطل حذفش می‌کنی.'),
  _GP(Icons.account_balance_wallet, 'مالی',
      '• با + هزینه یا درآمد ثبت کن. مبلغ خودش هر سه رقم با نقطه جدا می‌شه تا خوندنش راحت باشه.\n• دسته رو انتخاب کن؛ با «مدیریت دسته‌ها» خودت دسته اضافه یا حذف کن.\n• روی هر تراکنش بزنی می‌تونی مبلغ، دسته و تاریخش رو اصلاح کنی. با آیکون سطل یا کشیدن حذف می‌شه.\n• بالای صفحه جمع امروز، هفته و ماه و بخش جستجو هست.'),
  _GP(Icons.settings, 'تنظیمات',
      'با آیکون چرخ‌دنده:\n• رنگ برنامه و حالت روشن/تیره (نارنجی با پس‌زمینه‌ی خاکستری تیره هم داریم)\n• نمایش تاریخ شمسی\n• پیام امیدبخش روزانه: ساعتش رو انتخاب کن. دکمه‌ی «ارسال آزمایشی» هم برای تست هست.\n• پشتیبان‌گیری: از اطلاعاتت کپی نگه دار و هر وقت خواستی بازیابی کن.'),
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

class _H extends State<Home> {
  int tab = 0, cy = 1400, cm = 1;
  String q = '';
  DateTime sel = DateTime.now();

  @override
  void initState() {
    super.initState();
    sel = DateTime(sel.year, sel.month, sel.day);
    final j = g2j(sel.year, sel.month, sel.day);
    cy = j[0];
    cm = j[1];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!(prefs.getBool('guide') ?? false)) openGuide();
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
                            set(() {});
                            setState(() {});
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
                      Wrap(spacing: 8, children: [
                        OutlinedButton.icon(
                            icon: const Icon(Icons.notifications),
                            label: const Text('ارسال آزمایشی'),
                            onPressed: () => notif.show(1, 'یه پیام برای تو', hope[DateTime.now().weekday - 1], nd)),
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
    g['progress'] = progress;

    if (o == null) {
      D.goals.add(g);
    }
    await D.save();
    if (mounted) setState(() {});
  }

  Widget goals() {
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      children: [
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
      ],
    );
  }

  // ── کارها ──
  void delTask(Map k) {
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
    k['done'] = !d;
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
    upd(); // اول ذخیره و نمایش؛ بعد زمان‌بندی اعلان
    await scheduleTask(k);
  }

  Widget tasks() {
    final now = DateTime.now();
    final today = ds(now);
    final nowIso = now.toIso8601String();
    final wk = ds(now.subtract(Duration(days: (now.weekday + 1) % 7)));
    final mo = monthStart(now);
    final ev = D.events.where((e) => e['wd'] == now.weekday && today.compareTo(e['from']) >= 0 && today.compareTo(e['to']) <= 0).toList()
      ..sort(byStart);

    bool overdue(Map k) {
      if (k['done'] == true) return false;
      final r = k['r'] as String?;
      return r != null && r.compareTo(nowIso) < 0;
    }

    final need = D.tasks.where((k) => k['done'] != true && !overdue(k)).toList()
      ..sort((a, b) {
        final s = (b['star'] == true ? 1 : 0) - (a['star'] == true ? 1 : 0);
        if (s != 0) return s;
        final ar = (a['r'] as String?) ?? '9999-99-99T99:99:99';
        final br = (b['r'] as String?) ?? '9999-99-99T99:99:99';
        final r = ar.compareTo(br);
        return r != 0 ? r : (a['id'] as int).compareTo(b['id'] as int);
      });

    final late = D.tasks.where(overdue).toList()
      ..sort((a, b) => ((a['r'] as String?) ?? '').compareTo((b['r'] as String?) ?? ''));

    final done = D.tasks.where((k) => k['done'] == true).toList()
      ..sort((a, b) => ((b['doneAt'] as String?) ?? '').compareTo((a['doneAt'] as String?) ?? ''));

    Widget tile(Map k) {
      final d = k['done'] == true;
      final subs = (k['subs'] as List? ?? const []).cast<Map>();
      final sd = subs.where((s) => s['done'] == true).length;
      final lateNow = overdue(k);
      final info = [
        if (k['r'] != null) '${lateNow ? '⚠️' : '⏰'} ${fd(k['r'])}  ${(k['r'] as String).substring(11, 16)}',
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
                subtitle: info.isEmpty ? null : Text(info, style: lateNow ? TextStyle(color: Theme.of(context).colorScheme.error) : null),
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
            for (final sub in subs)
              CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.only(right: 40, left: 16),
                  value: sub['done'] == true,
                  title: Text(sub['t'], style: sub['done'] == true ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey) : null),
                  onChanged: (v) {
                    sub['done'] = v == true;
                    upd();
                  }),
          ])));
    }

    Widget rep(String label, String from) {
      final dn = D.tasks.where((k) => k['done'] == true && ((k['doneAt'] ?? '') as String).compareTo(from) >= 0).length;
      final od = D.tasks.where((k) {
        final r = k['r'] as String?;
        return k['done'] != true && r != null && r.compareTo(nowIso) < 0 && r.substring(0, 10).compareTo(from) >= 0;
      }).length;
      final todo = D.tasks.where((k) => k['done'] != true && !overdue(k)).length;
      return ListTile(dense: true, title: Text(label), subtitle: Text('نیاز به انجام $todo'), trailing: Text('انجام‌شده $dn   |   عقب‌افتاده $od'));
    }

    Widget section(String title, IconData icon, List<Map> list, {Color? color, String? empty}) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 6),
              child: Row(children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 7),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                const SizedBox(width: 6),
                Text('(${list.length})', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
              ]),
            ),
            if (list.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(empty ?? 'موردی نیست.')),
            for (final k in list) tile(k),
          ],
        );

    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final e in ev)
        Card(child: ListTile(leading: const Icon(Icons.schedule), title: Text(e['t']), subtitle: Text('${hm(e['s'])} – ${hm(e['e'])}'))),
      section('نیاز به انجام', Icons.radio_button_unchecked, need, color: Theme.of(context).colorScheme.primary, empty: 'فعلاً کاری برای انجام نداری. با دکمه + یک کار ثبت کن.'),
      section('عقب‌افتاده', Icons.warning_amber_rounded, late, color: Theme.of(context).colorScheme.error, empty: 'کار عقب‌افتاده‌ای نداری. عالیه!'),
      section('انجام‌شده', Icons.check_circle_outline, done, color: Colors.green, empty: 'هنوز کاری را انجام‌شده ثبت نکردی.'),
      const Divider(height: 32),
      const Text('گزارش کارها', style: TextStyle(fontWeight: FontWeight.bold)),
      Card(child: Column(children: [rep('امروز', today), rep('این هفته', wk), rep('این ماه', mo)])),
      const SizedBox(height: 80),
    ]);
  }

  // ── برنامه‌ی هفتگی و تقویم ──
  void delEvent(Map e) {
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
    final amt = TextEditingController(text: o != null ? n(o['a']) : ''),
        ttl = TextEditingController(text: o?['t'] ?? ''),
        note = TextEditingController(text: o?['note'] ?? '');
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
                    TextField(
                        controller: note,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'یادداشت / توضیحات',
                          hintText: 'مثلاً بابت چه چیزی، برای چه کسی یا چه توضیحی لازم است؟',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_outlined),
                        )),
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
                          final m = {
                            'a': v,
                            'inc': inc,
                            'c': cat,
                            't': ttl.text.trim(),
                            'note': note.text.trim(),
                            'd': ds(date),
                          };
                          if (o != null) {
                            o.addAll(m);
                          } else {
                            D.txs.add({'id': DateTime.now().microsecondsSinceEpoch, ...m});
                          }
                          Navigator.pop(ctx);
                          upd();
                        },
                        child: Text(o != null ? 'ذخیره‌ی تغییرات' : 'ثبت')),
                  ])));
            }));
  }

  Widget money() {
    final now = DateTime.now();
    final wk = now.subtract(Duration(days: (now.weekday + 1) % 7));
    int sum(Iterable<Map> l, bool inc) => l.where((x) => x['inc'] == inc).fold(0, (p, x) => p + (x['a'] as int));
    Iterable<Map> since(String from) => D.txs.where((x) => (x['d'] as String).compareTo(from) >= 0);
    final froms = {'امروز': ds(now), 'این هفته': ds(wk), 'این ماه': monthStart(now)};
    final found = D.txs.where((x) => '${x['t'] ?? ''} ${x['c']} ${x['note'] ?? ''}'.contains(q)).toList()
      ..sort((a, b) {
        final c = (b['d'] as String).compareTo(a['d']);
        return c != 0 ? c : (b['id'] as int).compareTo(a['id'] as int);
      });
    return ListView(padding: const EdgeInsets.all(12), children: [
      TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'جستجو در عنوان یا دسته'),
          onChanged: (v) => setState(() => q = v.trim())),
      if (q.isNotEmpty)
        Card(child: ListTile(title: Text('${found.length} بار'), subtitle: Text('درآمد ${n(sum(found, true))}  |  هزینه ${n(sum(found, false))}')))
      else
        for (final f in froms.entries)
          Card(
              child: ListTile(
                  title: Text(f.key),
                  subtitle: Text('درآمد ${n(sum(since(f.value), true))}  |  هزینه ${n(sum(since(f.value), false))}'),
                  trailing: Text(n(sum(since(f.value), true) - sum(since(f.value), false)), style: const TextStyle(fontWeight: FontWeight.bold)))),
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
                subtitle: Text(
                    '${x['c']} • ${fd(x['d'])}${(x['note'] ?? '').toString().trim().isNotEmpty ? ' • ${x['note']}' : ''}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(n(x['a'])),
                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => delTx(x)),
                ]))),
      const SizedBox(height: 80),
    ]);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(['کارها', 'تقویم', 'اهداف', 'مالی'][tab]), actions: [
          IconButton(icon: const Icon(Icons.help_outline), tooltip: 'راهنما', onPressed: openGuide),
          IconButton(icon: const Icon(Icons.settings), tooltip: 'تنظیمات', onPressed: settings),
        ]),
        body: [tasks, cal, goals, money][tab](),
        floatingActionButton: FloatingActionButton(
            onPressed: () => [() => taskSheet(), () => addEvent(), () => goalSheet(), () => txSheet()][tab](), child: const Icon(Icons.add)),
        bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.checklist), label: 'کارها'),
              NavigationDestination(icon: Icon(Icons.calendar_month), label: 'تقویم'),
              NavigationDestination(icon: Icon(Icons.flag_outlined), label: 'اهداف'),
              NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'مالی'),
            ]),
      );
}
