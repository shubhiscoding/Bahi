/// Formats a DateTime as a short relative-time Hindi string
/// ("अभी अभी", "5 मिनट पहले", "2 घंटे पहले", "3 दिन पहले"), falling back
/// to an absolute short date beyond ~7 days.
String formatRelativeHindi(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);

  if (diff.inSeconds < 60) return 'अभी अभी';
  if (diff.inMinutes < 60) return '${diff.inMinutes} मिनट पहले';
  if (diff.inHours < 24) return '${diff.inHours} घंटे पहले';
  if (diff.inDays < 7) return '${diff.inDays} दिन पहले';

  const months = [
    'जन', 'फ़र', 'मार्च', 'अप्रैल', 'मई', 'जून',
    'जुल', 'अग', 'सित', 'अक्टू', 'नव', 'दिस',
  ];
  return '${dateTime.day} ${months[dateTime.month - 1]}';
}
