import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/strings.dart';
import '../providers/connectivity_provider.dart';
import '../theme/colors.dart';

/// Phase 12 §E: persistent, unmissable "you're offline, what you see may
/// be old" indicator — mounted once in AppShellScreen so every tab gets
/// it for free, matching the same "persistent, not tucked away" treatment
/// already given to the user-identity header (design.md rule 4). Without
/// this, a cached list shown offline (Phase 12 §A-§C) looked identical to
/// a live one, with zero visual distinction (design.md rule 8: meaning
/// through color/icon, not just text).
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: isOnline
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              color: AppColors.dangerSoft,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: AppColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      Strings.offlineShowingOldData,
                      style: const TextStyle(color: AppColors.danger, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
