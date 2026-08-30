import 'package:inditrans/inditrans.dart' as inditrans;

/// Cross-script ("Hinglish") search matching: a query typed in English
/// should match Hindi-named items and vice versa (e.g. "fortune" should
/// find "फॉर्चून", and "फॉर्चून" should find "Fortune").
///
/// Best-effort, not perfect: romanization schemes render Devanagari
/// *phonetically*, which doesn't always land on the exact casual English
/// spelling someone types — e.g. "फॉर्चून" romanizes to something like
/// "forchoon", not "fortune", even though they're phonetically close.
/// Plain substring matching misses that; fuzzy (edit-distance-tolerant)
/// matching below is what actually catches it.
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

/// Standard iterative Levenshtein (edit) distance.
int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previousRow = List<int>.generate(b.length + 1, (i) => i);
  var currentRow = List<int>.filled(b.length + 1, 0);

  for (int i = 1; i <= a.length; i++) {
    currentRow[0] = i;
    for (int j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      currentRow[j] = [
        previousRow[j] + 1, // deletion
        currentRow[j - 1] + 1, // insertion
        previousRow[j - 1] + cost, // substitution
      ].reduce((a, b) => a < b ? a : b);
    }
    final tmp = previousRow;
    previousRow = currentRow;
    currentRow = tmp;
  }
  return previousRow[b.length];
}

/// Fuzzy substring check: true if [needle] appears in [haystack] exactly,
/// OR if some window of [haystack] is within edit-distance tolerance of
/// [needle] (tolerance scales with needle length — short words need an
/// almost-exact match, longer ones tolerate a couple character
/// differences, matching typical romanization drift).
bool _fuzzyContains(String haystack, String needle) {
  if (needle.isEmpty) return true;
  if (haystack.contains(needle)) return true;
  if (needle.length < 3) return false; // too short to fuzzy-match meaningfully

  final maxDistance = (needle.length / 3).ceil().clamp(1, 4);

  for (int start = 0; start < haystack.length; start++) {
    for (int lenDelta = -2; lenDelta <= 2; lenDelta++) {
      final len = needle.length + lenDelta;
      if (len < 1 || start + len > haystack.length) continue;
      final window = haystack.substring(start, start + len);
      if (_levenshtein(window, needle) <= maxDistance) return true;
    }
  }
  return false;
}

/// Whether [itemName] matches a search [query], checking both scripts —
/// as typed and romanized — with fuzzy tolerance for phonetic drift
/// introduced by romanization.
bool matchesSearch(String itemName, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;

  final n = itemName.trim().toLowerCase();
  if (_fuzzyContains(n, q)) return true;

  final nRoman = romanize(itemName).toLowerCase();
  if (_fuzzyContains(nRoman, q)) return true;

  final qRoman = romanize(query).toLowerCase();
  if (qRoman.isNotEmpty) {
    if (_fuzzyContains(n, qRoman)) return true;
    if (_fuzzyContains(nRoman, qRoman)) return true;
  }

  return false;
}
