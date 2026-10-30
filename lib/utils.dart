// Chhote helper functions (formatting, dates, raqam parse karna).

String two(int n) => n.toString().padLeft(2, '0');

String nowStr() {
  final d = DateTime.now();
  return '${d.year}-${two(d.month)}-${two(d.day)} '
      '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

String dateStr(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

/// "2026-10-22 13:05:00" -> "22-10-2026 01:05 PM"
String fmtDt(String? s) {
  if (s == null || s.length < 19) return s ?? '';
  final y = s.substring(0, 4);
  final mo = s.substring(5, 7);
  final d = s.substring(8, 10);
  final h = int.tryParse(s.substring(11, 13)) ?? 0;
  final mi = s.substring(14, 16);
  final ap = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$d-$mo-$y ${two(h12)}:$mi $ap';
}

/// Sirf waqt: "01:05 PM"
String fmtTime(String? s) {
  final full = fmtDt(s);
  return full.length >= 19 ? full.substring(11) : full;
}

/// 1200.0 -> "1200" (ya "1,200" agar grouping), 33.333 -> "33.33"
String fmtNum(double x, {bool grouping = false}) {
  final neg = x < 0;
  final ax = x.abs();
  var s = (ax - ax.roundToDouble()).abs() < 0.005
      ? ax.round().toString()
      : ax.toStringAsFixed(2);
  if (grouping) {
    final parts = s.split('.');
    final intPart = parts[0]
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    s = parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  }
  return neg ? '-$s' : s;
}

String money(double x) => 'Rs ${fmtNum(x, grouping: true)}';

String cleanName(String s) =>
    s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).join(' ');

/// Galat ho to null deta hai.
double? parseAmount(String text, {bool allowZero = false}) {
  final t = text.replaceAll(',', '').trim();
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null || v.isNaN || v.isInfinite || v < 0) return null;
  if (v == 0 && !allowZero) return null;
  return v;
}

class DateRange {
  DateRange(this.start, this.end);
  final String start;
  final String end;
}

const List<String> kPeriods = ['Aaj', 'Kal', 'Is hafta', 'Is mahine', 'Sab'];

DateRange periodRange(String label) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  switch (label) {
    case 'Aaj':
      return DateRange(dateStr(today), dateStr(today));
    case 'Kal':
      final y = today.subtract(const Duration(days: 1));
      return DateRange(dateStr(y), dateStr(y));
    case 'Is hafta':
      final start = today.subtract(Duration(days: today.weekday - 1));
      return DateRange(dateStr(start), dateStr(today));
    case 'Is mahine':
      return DateRange(dateStr(DateTime(today.year, today.month, 1)), dateStr(today));
    default:
      return DateRange('0001-01-01', '9999-12-31');
  }
}

/// Waqt ke hisaab se charge: rate per ghanta x guzra hua waqt, nearest rupee tak.
double timeCharge(DateTime start, DateTime end, double hourlyRate) {
  final secs = end.difference(start).inSeconds;
  if (secs <= 0 || hourlyRate <= 0) return 0;
  return (hourlyRate * secs / 3600).roundToDouble();
}

/// 90 min -> "1 ghanta 30 min", 20 min -> "20 min"
String fmtDuration(Duration d) {
  final mins = d.inMinutes < 0 ? 0 : d.inMinutes;
  final h = mins ~/ 60;
  final m = mins % 60;
  return h == 0 ? '$m min' : '$h ghanta $m min';
}
