import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 4 discrete, pre-tested levels — deliberately not a continuous slider
/// (design.md rule 9: tap over drag; also the only way to guarantee every
/// value is safe against this app's existing layouts). Phase 11.
enum TextSizeLevel {
  small(0.9, 'छोटा'),
  normal(1.0, 'सामान्य'),
  large(1.15, 'बड़ा'),
  extraLarge(1.3, 'बहुत बड़ा');

  final double scale;
  final String label;
  const TextSizeLevel(this.scale, this.label);

  TextSizeLevel? get next {
    final i = TextSizeLevel.values.indexOf(this);
    return i + 1 < TextSizeLevel.values.length ? TextSizeLevel.values[i + 1] : null;
  }

  TextSizeLevel? get previous {
    final i = TextSizeLevel.values.indexOf(this);
    return i - 1 >= 0 ? TextSizeLevel.values[i - 1] : null;
  }
}

const _prefsKey = 'text_size_level';

/// Reads the persisted level — call once in main() before runApp() so the
/// very first frame already renders at the right size (no flash-then-
/// resize). Defaults to TextSizeLevel.normal if never set/invalid.
Future<TextSizeLevel> loadPersistedTextSizeLevel() async {
  final prefs = await SharedPreferences.getInstance();
  final index = prefs.getInt(_prefsKey);
  if (index == null || index < 0 || index >= TextSizeLevel.values.length) {
    return TextSizeLevel.normal;
  }
  return TextSizeLevel.values[index];
}

class TextScaleNotifier extends StateNotifier<TextSizeLevel> {
  TextScaleNotifier(super.initial);

  Future<void> _persist(TextSizeLevel level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, TextSizeLevel.values.indexOf(level));
  }

  void increase() {
    final next = state.next;
    if (next == null) return; // already at max — bound enforced here too
    state = next;
    _persist(next);
  }

  void decrease() {
    final previous = state.previous;
    if (previous == null) return; // already at min
    state = previous;
    _persist(previous);
  }
}

/// Overridden in main() with the persisted value before runApp() —
/// intentionally has no default constructor argument here, so forgetting
/// the override is a loud error, not a silent flash-then-resize.
final textScaleProvider = StateNotifierProvider<TextScaleNotifier, TextSizeLevel>(
  (ref) => throw UnimplementedError('textScaleProvider must be overridden in main()'),
);
