/// Formats a DateTime as an absolute Hindi-numeral-free timestamp
/// ("29 अगस्त 2026, 4:30 pm") — used on the item detail screen, where the
/// exact time matters (as opposed to relative_time.dart's "2 घंटे पहले",
/// used on the list card).
String formatAbsoluteHindi(DateTime dateTime) {
  const months = [
    'जनवरी', 'फ़रवरी', 'मार्च', 'अप्रैल', 'मई', 'जून',
    'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर',
  ];

  final hour24 = dateTime.hour;
  final period = hour24 < 12 ? 'am' : 'pm';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');

  return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}, $hour12:$minute $period';
}
