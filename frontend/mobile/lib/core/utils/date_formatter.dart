import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static String time(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat('HH:mm').format(dateTime.toLocal());
  }

  static String relative(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final local = dateTime.toLocal();
    final diff = now.difference(local);

    if (diff.inSeconds < 60) return 'Vua xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes}p';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}ng';

    return DateFormat('dd/MM').format(local);
  }

  static String formatTimelineDate(DateTime? dateTime) {
    if (dateTime == null) return '';
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);

    final timeStr = DateFormat('HH:mm').format(local);

    if (date == today) {
      return '$timeStr Hôm nay';
    }
    
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == yesterday) {
      return '$timeStr Hôm qua';
    }

    return '$timeStr ${DateFormat('dd/MM/yyyy').format(local)}';
  }
}
