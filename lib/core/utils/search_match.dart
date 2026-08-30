import 'package:dart_phonetics/dart_phonetics.dart';
import 'package:inditrans/inditrans.dart' as inditrans;

/// Cross-script ("Hinglish") search matching: a query typed OR SPOKEN in
/// English should match Hindi-named items and vice versa (e.g. "fortune"
/// should find "फॉर्चून", and "फॉर्चून" should find "Fortune").
///
/// Voice search always transcribes in the hi_IN locale (see
/// voice_service.dart/mic_search_field.dart), so a spoken English item
/// name routinely comes back as Devanagari — this is the common case for
/// voice search on English/brand-name items, not a rare edge case.
///
/// Best-effort, not perfect: romanization renders Devanagari
/// *phonetically* ("फॉर्चून" -> "forchoon"), which is spelled quite
/// differently from "fortune" even though the two are phonetically
/// close (English "fortune" is itself pronounced "for-chun" — the
/// mismatch is in English orthography, not in the sounds). Plain
/// character edit-distance penalizes that spelling gap harshly; Double
/// Metaphone (designed exactly for "sounds alike, spelled differently"
/// English matching — handles digraphs like "tu"/"ti" affricating to a
/// "ch"/"sh" sound) closes it much better than edit distance alone.
final _devanagariRegex = RegExp(r'[ऀ-ॿ]');
final _metaphone = DoubleMetaphone.defaultEncoder;

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

/// Double Metaphone codes for every word in [text] (primary + alternates,
/// deduplicated) — computed per-word since item names are often multiple
/// words ("Fortune Sunflower Oil") but a search query is usually one.
Set<String> _phoneticCodes(String text) {
  final codes = <String>{};
  for (final word in text.split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    final encoding = _metaphone.encode(word);
    if (encoding == null) continue;
    codes.add(encoding.primary);
    if (encoding.alternates != null) codes.addAll(encoding.alternates!);
  }
  return codes;
}

/// Standard iterative Levenshtein (edit) distance — fallback for
/// near-typo cases Double Metaphone doesn't cover (e.g. minor spelling
/// slips within the same script).
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
        previousRow[j] + 1,
        currentRow[j - 1] + 1,
        previousRow[j - 1] + cost,
      ].reduce((a, b) => a < b ? a : b);
    }
    final tmp = previousRow;
    previousRow = currentRow;
    currentRow = tmp;
  }
  return previousRow[b.length];
}

bool _fuzzyContains(String haystack, String needle) {
  if (needle.isEmpty) return true;
  if (haystack.contains(needle)) return true;
  if (needle.length < 3) return false;

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

/// Whether any phonetic code of [text] matches any phonetic code of
/// [query] (Double Metaphone on whichever side is/was romanized to Latin).
bool _phoneticMatch(String text, String query) {
  final textCodes = _phoneticCodes(text);
  if (textCodes.isEmpty) return false;
  final queryCodes = _phoneticCodes(query);
  if (queryCodes.isEmpty) return false;
  return textCodes.intersection(queryCodes).isNotEmpty;
}

/// Whether [itemName] matches a search [query], checking both scripts —
/// as typed/spoken and romanized — with phonetic matching (primary) and
/// edit-distance fuzzy matching (fallback) for tolerance.
bool matchesSearch(String itemName, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;

  final n = itemName.trim().toLowerCase();
  final nRoman = romanize(itemName).toLowerCase();
  final qRoman = romanize(query).toLowerCase();

  // Exact/fuzzy substring, same script or already-romanized
  if (_fuzzyContains(n, q)) return true;
  if (_fuzzyContains(nRoman, q)) return true;
  if (qRoman.isNotEmpty) {
    if (_fuzzyContains(n, qRoman)) return true;
    if (_fuzzyContains(nRoman, qRoman)) return true;
  }

  // Phonetic match — catches phonetically-close-but-differently-spelled
  // cases (e.g. "forchoon" vs "fortune") that edit distance misses
  if (_phoneticMatch(n, q)) return true;
  if (qRoman.isNotEmpty && _phoneticMatch(n, qRoman)) return true;
  if (_phoneticMatch(nRoman, q)) return true;

  return false;
}
