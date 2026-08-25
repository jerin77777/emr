class DateFormatter {
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static DateTime? parse(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr.toLowerCase() == 'n/a') {
      return null;
    }
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      // Try to parse YYYY-MM-DD HH:MM:SS format manually if standard parse fails
      try {
        final parts = dateStr.split(' ');
        if (parts.isNotEmpty) {
          final dateParts = parts[0].split('-');
          if (dateParts.length == 3) {
            final year = int.parse(dateParts[0]);
            final month = int.parse(dateParts[1]);
            final day = int.parse(dateParts[2]);
            int hour = 0;
            int minute = 0;
            int second = 0;
            if (parts.length > 1) {
              final timeParts = parts[1].split(':');
              if (timeParts.length >= 2) {
                hour = int.parse(timeParts[0]);
                minute = int.parse(timeParts[1]);
              }
              if (timeParts.length >= 3) {
                second = int.parse(timeParts[2].split('.')[0]);
              }
            }
            return DateTime(year, month, day, hour, minute, second);
          }
        }
      } catch (_) {}
      return null;
    }
  }

  // Input: e.g. "2026-08-12" or "2026-08-12 13:13:22"
  // Output: e.g. "12 Aug 2026"
  static String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr.toLowerCase() == 'n/a') {
      return 'N/A';
    }
    // If it's already in the correct display format (e.g. contains month name like "Aug"), return as is
    for (final month in _months) {
      if (dateStr.contains(month)) {
        return dateStr;
      }
    }
    final dt = parse(dateStr);
    if (dt == null) return dateStr;
    return "${dt.day.toString().padLeft(2, '0')} ${_months[dt.month - 1]} ${dt.year}";
  }

  // Input: e.g. "2026-08-12 13:13:22"
  // Output: e.g. "12 Aug 2026, 01:13 PM"
  static String formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty || dateTimeStr.toLowerCase() == 'n/a') {
      return 'N/A';
    }
    final dt = parse(dateTimeStr);
    if (dt == null) return dateTimeStr;
    
    final dayStr = dt.day.toString().padLeft(2, '0');
    final monthStr = _months[dt.month - 1];
    final hour = dt.hour;
    final isPm = hour >= 12;
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayHourStr = displayHour.toString().padLeft(2, '0');
    final minStr = dt.minute.toString().padLeft(2, '0');
    final amPm = isPm ? 'PM' : 'AM';
    
    return "$dayStr $monthStr ${dt.year}, $displayHourStr:$minStr $amPm";
  }

  // Input: e.g. "2026-08-12 13:13:22"
  // Output: e.g. "01:13 PM"
  static String formatTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty || dateTimeStr.toLowerCase() == 'n/a') {
      return 'N/A';
    }
    final dt = parse(dateTimeStr);
    if (dt == null) return dateTimeStr;
    
    final hour = dt.hour;
    final isPm = hour >= 12;
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayHourStr = displayHour.toString().padLeft(2, '0');
    final minStr = dt.minute.toString().padLeft(2, '0');
    final amPm = isPm ? 'PM' : 'AM';
    
    return "$displayHourStr:$minStr $amPm";
  }

  /// Returns the cutoff DateTime until which a consultation visit can be edited.
  /// Allowed within midnight of same date + 30 mins buffer (00:30 next calendar day, or at least 30m after entry).
  static DateTime? getVisitEditCutoff(String? visitDateStr, [String? createdAtStr]) {
    if (visitDateStr == null && createdAtStr == null) return null;
    final dt = parse(visitDateStr) ?? parse(createdAtStr);
    if (dt == null) return null;

    final midnightCutoff = DateTime(dt.year, dt.month, dt.day + 1, 0, 30);
    final entryBuffer = dt.add(const Duration(minutes: 30));
    return midnightCutoff.isAfter(entryBuffer) ? midnightCutoff : entryBuffer;
  }

  /// Checks if a consultation visit is still within the allowable edit window.
  static bool isVisitEditable(String? visitDateStr, [String? createdAtStr]) {
    final cutoff = getVisitEditCutoff(visitDateStr, createdAtStr);
    if (cutoff == null) return false;
    return DateTime.now().isBefore(cutoff);
  }

  /// Returns a human-friendly string for the edit window status.
  static String getEditStatusText(String? visitDateStr, [String? createdAtStr]) {
    final cutoff = getVisitEditCutoff(visitDateStr, createdAtStr);
    if (cutoff == null) return 'Not editable';
    final now = DateTime.now();
    if (now.isBefore(cutoff)) {
      final diff = cutoff.difference(now);
      if (diff.inHours > 0) {
        return 'Editable until ${formatTime(cutoff.toIso8601String())} (${diff.inHours}h ${diff.inMinutes % 60}m remaining)';
      } else {
        return 'Editable until ${formatTime(cutoff.toIso8601String())} (${diff.inMinutes}m remaining)';
      }
    } else {
      return 'Edit window closed at ${formatTime(cutoff.toIso8601String())}';
    }
  }

  /// Checks if a bill is still within the allowable edit window (midnight of same date + 30m buffer).
  static bool isBillEditable(String? billDateStr) {
    return isVisitEditable(billDateStr);
  }

  /// Returns a human-friendly string for the bill edit window status.
  static String getBillEditStatusText(String? billDateStr) {
    return getEditStatusText(billDateStr);
  }
}
