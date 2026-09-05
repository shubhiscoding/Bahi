import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/voice_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/offline_guard.dart';
import '../../../core/utils/search_match.dart';
import '../../../core/widgets/mic_search_field.dart';
import '../providers/unit_providers.dart';

/// Unit picker (design.md §5 replacement for the old hardcoded 8-item
/// list): a search field over the business's own linked units (rule 9:
/// tap over typing), tappable chips for matches, and an "add new unit"
/// affordance that turns into an inline input + mic + tick/cross.
class UnitPicker extends ConsumerStatefulWidget {
  final String selectedUnit;
  final ValueChanged<String> onSelected;

  const UnitPicker({
    super.key,
    required this.selectedUnit,
    required this.onSelected,
  });

  @override
  ConsumerState<UnitPicker> createState() => _UnitPickerState();
}

class _UnitPickerState extends ConsumerState<UnitPicker> {
  final _searchController = TextEditingController();
  final _addController = TextEditingController();
  String _searchQuery = '';
  bool _isAdding = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _searchController.dispose();
    _addController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveNewUnit() async {
    final name = _addController.text.trim();
    if (name.isEmpty) return;
    if (!await ensureOnline(context)) return;

    setState(() => _isSaving = true);
    try {
      final unit = await ref.read(addUnitProvider(name).future);
      ref.invalidate(unitsProvider);
      widget.onSelected(unit.name); // auto-select the new unit (confirmed decision)
      setState(() {
        _isAdding = false;
        _isSaving = false;
        _addController.clear();
      });
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('त्रुटि: ${e.toString()}')),
        );
      }
    }
  }

  void _handleCancelAdd() {
    setState(() {
      _isAdding = false;
      _addController.clear();
    });
  }

  Future<void> _handleMicForNewUnit() async {
    final available = await VoiceService.initialize();
    if (!available) return;
    await VoiceService.listen(
      onResult: (text) {
        if (!mounted) return;
        setState(() => _addController.text = text);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final unitsAsync = ref.watch(unitsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('यूनिट', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),

        // Search field (lightweight mic, no confirm sheet — same pattern
        // as the inventory search bar)
        MicSearchField(
          controller: _searchController,
          hintText: 'यूनिट खोजें',
          onChanged: (value) => setState(() => _searchQuery = value.trim()),
        ),
        const SizedBox(height: 12),

        unitsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ),
          error: (err, stack) => Text(
            'यूनिट लोड नहीं हो सके',
            style: TextStyle(color: AppColors.danger),
          ),
          data: (units) {
            // units is already sorted by recency (last used on an item)
            // server-side. Empty search shows only the top 8 — full list
            // is one search away (confirmed decision, Phase 7 §C).
            const maxWithoutSearch = 8;
            final filtered = _searchQuery.isEmpty
                ? units.take(maxWithoutSearch).toList()
                : units
                    .where((u) => matchesSearch(u.name, _searchQuery))
                    .toList();

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...filtered.map((unit) {
                  final isSelected = widget.selectedUnit == unit.name;
                  return ChoiceChip(
                    label: Text(unit.name),
                    selected: isSelected,
                    onSelected: (_) => widget.onSelected(unit.name),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.inkPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  );
                }),
                if (filtered.isEmpty)
                  Text(
                    'कोई यूनिट नहीं मिला',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                  ),
              ],
            );
          },
        ),

        const SizedBox(height: 16),

        // Add-new-unit affordance
        if (!_isAdding)
          OutlinedButton.icon(
            onPressed: () => setState(() => _isAdding = true),
            icon: const Icon(Icons.add, size: 24),
            label: const Text('नया यूनिट जोड़ें'),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Mic — dictate the new unit's name directly into the input
              InkWell(
                onTap: _handleMicForNewUnit,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _addController,
                  autofocus: true,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'यूनिट का नाम',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Tick — save (bold, filled, colored per rule 2)
              InkWell(
                onTap: _isSaving ? null : _handleSaveNewUnit,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isSaving
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 8),
              // Cross — cancel
              InkWell(
                onTap: _handleCancelAdd,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
