import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/models/buyer.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/mic_search_field.dart';
import '../providers/buyer_providers.dart';

/// "Sold to" buyer picker (Phase 8 §E) — dropdown + search over the
/// business's buyers (already recency-sorted server-side: most recently
/// billed first), a bounded-height scrollable list so the first ~4 show
/// without scrolling and the rest are one scroll away, and a visually
/// distinct trailing "add new buyer" row that opens a modal (per spec —
/// not the unit picker's inline mic/tick/cross row).
///
/// Collapses to a single row showing just the selected name once a buyer
/// is picked — tapping that row re-expands back to search+list+add.
/// The add-new row is ALWAYS present while expanded, even with zero
/// search matches (previously it vanished behind a plain "not found"
/// message — a shopkeeper searching for someone not yet added must still
/// be able to add them without clearing the search first).
class BuyerPicker extends ConsumerStatefulWidget {
  final Buyer? selectedBuyer;
  final ValueChanged<Buyer> onSelected;

  const BuyerPicker({super.key, required this.selectedBuyer, required this.onSelected});

  @override
  ConsumerState<BuyerPicker> createState() => _BuyerPickerState();
}

class _BuyerPickerState extends ConsumerState<BuyerPicker> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isExpanded = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleAddNew() async {
    final created = await showDialog<Buyer>(
      context: context,
      builder: (_) => const _AddBuyerDialog(),
    );
    if (created != null) {
      widget.onSelected(created);
      setState(() => _isExpanded = false);
    }
  }

  void _handleSelect(Buyer buyer) {
    widget.onSelected(buyer);
    setState(() => _isExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isExpanded && widget.selectedBuyer != null) {
      return _CollapsedRow(
        label: Strings.soldTo,
        name: widget.selectedBuyer!.name,
        onTap: () => setState(() => _isExpanded = true),
      );
    }

    final buyersAsync = ref.watch(buyersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(Strings.soldTo, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        MicSearchField(
          controller: _searchController,
          hintText: 'खरीदार खोजें',
          onChanged: (value) => setState(() => _searchQuery = value.trim()),
        ),
        const SizedBox(height: 12),
        buyersAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ),
          error: (err, stack) => Text(
            'खरीदार लोड नहीं हो सके',
            style: TextStyle(color: AppColors.danger),
          ),
          data: (buyers) {
            final filtered = _searchQuery.isEmpty
                ? buyers
                : buyers
                    .where((b) => b.name.toLowerCase().contains(_searchQuery.toLowerCase()))
                    .toList();
            final showNoResults = filtered.isEmpty && _searchQuery.isNotEmpty;

            // Bounded height so ~4 rows show by default; the rest of the
            // list (and the add-new row) is one scroll away — matches
            // "top 4, then scrollable" from the spec without needing to
            // slice the list itself. The add-new row is always the last
            // child, never conditionally omitted.
            return Container(
              constraints: const BoxConstraints(maxHeight: 4.5 * 64),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final buyer in filtered) ...[
                    _BuyerRow(
                      buyer: buyer,
                      isSelected: widget.selectedBuyer?.id == buyer.id,
                      onTap: () => _handleSelect(buyer),
                    ),
                    Divider(height: 1, color: AppColors.border),
                  ],
                  if (showNoResults) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        Strings.noBuyersFound,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                      ),
                    ),
                    Divider(height: 1, color: AppColors.border),
                  ],
                  _AddNewBuyerRow(onTap: _handleAddNew),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Collapsed state (Phase 8 follow-up) — shown once a buyer is selected;
/// tapping re-expands to search+list+add. Styled like the date field in
/// add_bill_screen.dart for visual consistency.
class _CollapsedRow extends StatelessWidget {
  final String label;
  final String name;
  final VoidCallback onTap;

  const _CollapsedRow({required this.label, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
              color: AppColors.primarySoft,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(Icons.expand_more, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BuyerRow extends StatelessWidget {
  final Buyer buyer;
  final bool isSelected;
  final VoidCallback onTap;

  const _BuyerRow({required this.buyer, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: isSelected ? AppColors.primarySoft : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Primary line — truncated on overflow (spec requirement).
                  Text(
                    buyer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                  ),
                  // Full, untruncated name repeated as subtext — spec
                  // requirement, so nothing is lost even when the
                  // primary line is cut off.
                  Text(
                    buyer.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Visually distinct from buyer rows (spec: "a separate looking button in
/// scroll too") — accent-tinted background + a bold add icon.
class _AddNewBuyerRow extends StatelessWidget {
  final VoidCallback onTap;

  const _AddNewBuyerRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: AppColors.accentSoft,
        child: Row(
          children: [
            Icon(Icons.person_add, color: AppColors.accent, size: 24),
            const SizedBox(width: 12),
            Text(
              Strings.addNewBuyer,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.inkPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal: required name field + Create — per spec, not the unit picker's
/// inline mic/tick/cross row.
class _AddBuyerDialog extends ConsumerStatefulWidget {
  const _AddBuyerDialog();

  @override
  ConsumerState<_AddBuyerDialog> createState() => _AddBuyerDialogState();
}

class _AddBuyerDialogState extends ConsumerState<_AddBuyerDialog> {
  final _nameController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final buyer = await ref.read(createBuyerProvider(name).future);
      if (mounted) Navigator.of(context).pop(buyer);
    } catch (e) {
      setState(() {
        _isSaving = false;
        _error = e.toString().contains('409') ? Strings.duplicateBuyerName : Strings.errorOccurred;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(Strings.addNewBuyer),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(hintText: Strings.buyerName),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(Strings.cancel),
        ),
        TextButton(
          onPressed: _isSaving ? null : _handleCreate,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(Strings.createBuyer),
        ),
      ],
    );
  }
}
