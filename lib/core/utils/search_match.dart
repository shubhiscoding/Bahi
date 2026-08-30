import 'package:inditrans/inditrans.dart' as inditrans;

/// Cross-script ("Hinglish") search matching: a query typed in English
/// should match Hindi-named items and vice versa (e.g. "fortune" should
/// find "फॉर्चून", and "फॉर्चून" should find "Fortune").
///
/// Best-effort, not perfect: romanization schemes don't always land on
/// the exact casual spelling someone types (e.g. "फॉर्चून" might
/// romanize to something not spelled exactly like "fortune"). This
/// handles common/phonetic cases well, not every word — confirmed as an
/// acceptable tradeoff rather than pulling in a full phonetic-matching
/// service for an MVP.
final _devanagariRegex = RegExp(r'[ऀ-ॿ]');

bool _isDevanagari(String text) => _devanagariRegex.hasMatch(text);

/// Romanizes Devanagari text to a casual-reading Latin approximation.
/// Non-Devanagari text is returned unchanged. Fails open (returns the
/// original text) if inditrans isn't initialized or errors — a missed
/// cross-script match is a much smaller problem than a crashed search.
String romanize(String text) {
  if (!_isDevanagari(text)) return text;
  try {
    return inditrans.transliterate(text, inditrans.Script.devanagari, inditrans.Script.readableLatin);
  } catch (e) {
    return text;
  }
}

/// Whether [itemName] matches a search [query], checking both scripts as-is
/// and romanized.
bool matchesSearch(String itemName, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;

  final n = itemName.trim().toLowerCase();
  if (n.contains(q)) return true;

  final nRoman = romanize(itemName).toLowerCase();
  if (nRoman.contains(q)) return true;

  final qRoman = romanize(query).toLowerCase();
  if (qRoman.isNotEmpty && n.contains(qRoman)) return true;
  if (qRoman.isNotEmpty && nRoman.contains(qRoman)) return true;

  return false;
}
