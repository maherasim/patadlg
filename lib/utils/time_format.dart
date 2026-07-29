/// Plain "HH:MM[:SS]" time-of-day string (e.g. AttendanceRecord.checkInTime)
/// -> "9:29 AM". Pakistan-facing app — always 12-hour with AM/PM, never 24-hour.
String formatTime12h(String? time) {
  if (time == null || time.isEmpty) return '—';
  final parts = time.split(':');
  if (parts.length < 2) return time;
  final hour24 = int.tryParse(parts[0]);
  final minute = parts[1];
  if (hour24 == null || minute.length != 2) return time;

  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour12:$minute $period';
}

/// Same as [formatTime12h] but from a DateTime (e.g. DateTime.now()).
String formatDateTime12h(DateTime dt) {
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour12:$minute $period';
}

/// "just now" / "5m ago" / "3h ago" / "2d ago" — mirrors the web app's own
/// NotificationBell.jsx timeAgo() exactly.
String timeAgo(DateTime dt) {
  final seconds = DateTime.now().difference(dt).inSeconds;
  if (seconds < 60) return 'just now';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m ago';
  final hours = minutes ~/ 60;
  if (hours < 24) return '${hours}h ago';
  final days = hours ~/ 24;
  return '${days}d ago';
}
