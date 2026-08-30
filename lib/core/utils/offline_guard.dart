import 'package:flutter/material.dart';
import '../constants/strings.dart';
import '../providers/connectivity_provider.dart';
import '../theme/colors.dart';

/// Call at the top of any write-handler (add/edit/delete item, invite/
/// remove member, create/join business) as a second check in addition to
/// the button already being visually disabled when offline (design.md §9:
/// writes are blocked with a plain "connect to internet" prompt, never a
/// silent failure). Returns true if the action should proceed.
Future<bool> ensureOnline(BuildContext context) async {
  final online = await isCurrentlyOnline();
  if (!online && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(Strings.connectToInternet),
          ],
        ),
        backgroundColor: AppColors.danger,
      ),
    );
  }
  return online;
}
