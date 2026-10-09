/// Formats a DateTime as a local timestamp ("29/08/26, 4:30 शाम") for detail
/// screens where the exact time matters. List cards use relative time instead.
String formatAbsoluteHindi(DateTime dateTime) {
  // API timestamps arrive in UTC. Format them in the device's local timezone
  // so the displayed time matches when the shopkeeper performed the action.
  final localDateTime = dateTime.toLocal();
  final hour24 = localDateTime.hour;
  final period = switch (hour24) {
    < 4 => 'रात',
    < 12 => 'सुबह',
    12 => 'दोपहर',
    < 17 => 'दोपहर',
    < 20 => 'शाम',
    _ => 'रात',
  };
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = localDateTime.minute.toString().padLeft(2, '0');

  return '${formatDateDDMMYY(localDateTime)}, $hour12:$minute $period';
}

/// Formats a local date as zero-padded day/month/two-digit-year.
String formatDateDDMMYY(DateTime dateTime) {
  final localDateTime = dateTime.toLocal();
  final day = localDateTime.day.toString().padLeft(2, '0');
  final month = localDateTime.month.toString().padLeft(2, '0');
  final year = (localDateTime.year % 100).toString().padLeft(2, '0');
  return '$day/$month/$year';
}
