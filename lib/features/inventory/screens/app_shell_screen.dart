import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/services/update_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/name_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import 'inventory_list_screen.dart';
import '../../team/screens/team_screen.dart';

/// App Shell — wraps Inventory + Team tabs with a persistent user avatar
/// header (design.md rule 4: always visible, never tucked into a menu) and
/// a bottom nav with max 2 icons (rule 5).
class AppShellScreen extends ConsumerStatefulWidget {
  const AppShellScreen({super.key});

  @override
  ConsumerState<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends ConsumerState<AppShellScreen> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    // Check for updates automatically on launch (silent — no dialog if
    // there's nothing new), per the confirmed update UX decision.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate(silent: true));
  }

  Future<void> _checkForUpdate({required bool silent}) async {
    final update = await UpdateService.checkForUpdate();
    if (!mounted) return;

    if (update == null) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('अभी कोई अपडेट नहीं है')),
        );
      }
      return;
    }

    // Optional update: user can dismiss or update (confirmed decision)
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('नया वर्शन उपलब्ध है'),
        content: Text('वर्शन ${update.version} डाउनलोड करें?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('बाद में'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await UpdateService.downloadUpdate(update.downloadUrl);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(Strings.downloadingUpdate)),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('त्रुटि: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('अपडेट करें'),
          ),
        ],
      ),
    );
  }

  void _openSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _SettingsSheet(onCheckForUpdates: () => _checkForUpdate(silent: false)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: userAsync.when(
          data: (user) => _UserHeader(
            fullName: user?.fullName ?? '?',
            onTap: () => _openSettingsSheet(context),
          ),
          loading: () => const SizedBox(height: 40),
          error: (err, stack) => const SizedBox(height: 40),
        ),
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: const [
          InventoryListScreen(),
          TeamScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (idx) => setState(() => _selectedTab = idx),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.inventory_2, size: 28),
            label: Strings.inventory,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people, size: 28),
            label: Strings.team,
          ),
        ],
      ),
    );
  }
}

/// Persistent user indicator (design.md rule 4)
class _UserHeader extends StatelessWidget {
  final String fullName;
  final VoidCallback onTap;

  const _UserHeader({required this.fullName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initial = NameFormatter.getInitial(fullName);
    final shortName = NameFormatter.shortName(fullName);
    final avatarColor = AppColors.avatarColorForName(fullName);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: avatarColor,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                shortName,
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.settings, color: AppColors.inkSoft, size: 24),
          ],
        ),
      ),
    );
  }
}

/// Settings sheet (design.md §7.5): Check for Updates + Logout
class _SettingsSheet extends ConsumerWidget {
  final VoidCallback onCheckForUpdates;

  const _SettingsSheet({required this.onCheckForUpdates});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              Strings.settings,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onCheckForUpdates();
              },
              icon: const Icon(Icons.system_update, size: 24),
              label: Text(Strings.checkForUpdates),
            ),

            const SizedBox(height: 16),

            // Logout
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await ref.read(signOutProvider.future);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              icon: const Icon(Icons.logout, size: 24),
              label: Text(Strings.logout),
            ),
          ],
        ),
      ),
    );
  }
}
