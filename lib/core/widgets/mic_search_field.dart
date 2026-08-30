import 'package:flutter/material.dart';
import '../services/voice_service.dart';
import '../theme/colors.dart';

/// A search field with an embedded mic button — lightweight, instant
/// dictation (tap → speak → text fills the box → caller's onChanged
/// fires), no confirm sheet. Search is low-stakes/non-destructive (a
/// wrong search just shows the wrong filtered results, easily redone),
/// so this deliberately skips the full listen→confirm→speak-back flow
/// used for data entry (design.md rule 1's confirmation requirement is
/// about permanent records, not transient filtering) — confirmed
/// decision, not every mic interaction needs to look the same.
class MicSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  const MicSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  @override
  State<MicSearchField> createState() => _MicSearchFieldState();
}

class _MicSearchFieldState extends State<MicSearchField> {
  bool _isListening = false;

  Future<void> _handleMicTap() async {
    if (_isListening) return;

    final available = await VoiceService.initialize();
    if (!available) return;

    setState(() => _isListening = true);
    await VoiceService.listen(
      onResult: (text) {
        if (!mounted) return;
        widget.controller.text = text;
        widget.onChanged(text);
        setState(() => _isListening = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: Icon(Icons.search, color: AppColors.inkSoft),
        suffixIcon: IconButton(
          onPressed: _handleMicTap,
          icon: Icon(
            _isListening ? Icons.mic : Icons.mic_none,
            color: _isListening ? AppColors.primary : AppColors.inkSoft,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
