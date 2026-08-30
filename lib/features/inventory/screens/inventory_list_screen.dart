import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/models/inventory_item.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/name_formatter.dart';
import '../../../core/utils/relative_time.dart';
import '../../team/providers/team_providers.dart';
import '../providers/inventory_providers.dart';
import 'add_edit_item_screen.dart';

/// Inventory List Screen (design.md §5)
/// Real item list, "edited by" attribution (rule 10), one primary FAB (rule 6).
class InventoryListScreen extends ConsumerWidget {
  const InventoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(inventoryItemsProvider);
    final roleAsync = ref.watch(currentUserRoleProvider);
    final isOwner = roleAsync.value == 'owner';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => _errorState(),
        data: (items) {
          if (items.isEmpty) {
            return _emptyState();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _ItemCard(item: items[index], isOwner: isOwner);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEditItemScreen()),
          );
        },
        icon: const Icon(Icons.add, size: 28),
        label: Text(
          Strings.addItem,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.inkSoft),
            const SizedBox(height: 16),
            Text(
              Strings.noItems,
              style: const TextStyle(fontSize: 18, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              Strings.errorOccurred,
              style: const TextStyle(fontSize: 18, color: AppColors.danger),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single inventory item card, showing name, unit, quantity, price, and
/// the "edited by" attribution (design.md rule 10).
class _ItemCard extends ConsumerWidget {
  final InventoryItem item;
  final bool isOwner;

  const _ItemCard({required this.item, required this.isOwner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Look up the editor's name from the team members list (already fetched with profile names)
    final teamMembers = ref.watch(teamMembersProvider).value ?? [];
    final editor = teamMembers.where((m) => m.userId == item.updatedBy).firstOrNull;
    final editorName = editor?.fullName ?? '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AddEditItemScreen(item: item)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.quantity} ${item.unit}  •  ₹${item.price.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkSoft,
                          ),
                    ),
                    const SizedBox(height: 8),
                    // "Edited by" attribution (design.md rule 10)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.avatarColorForName(editorName),
                          child: Text(
                            NameFormatter.getInitial(editorName),
                            style: const TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${Strings.editedBy} ${NameFormatter.editedByFormat(editorName)} • ${formatRelativeHindi(item.updatedAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
