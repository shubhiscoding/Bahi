import 'package:flutter/material.dart';
import '../services/voice_service.dart';
import '../theme/colors.dart';

enum _VoiceStage { listening, confirming, error }

/// The voice input + confirm flow required by design.md rule 1:
/// listen → show heard text LARGE + speak it back audibly → user taps
/// "सही है" (confirm) or "फिर से बोलें" (retry). Never a silent checkmark.
///
/// Returns the confirmed text, or null if the user cancelled.
Future<String?> showVoiceInputSheet(
  BuildContext context, {
  required String fieldLabel,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _VoiceConfirmSheet(fieldLabel: fieldLabel),
  );
}

class _VoiceConfirmSheet extends StatefulWidget {
  final String fieldLabel;

  const _VoiceConfirmSheet({required this.fieldLabel});

  @override
  State<_VoiceConfirmSheet> createState() => _VoiceConfirmSheetState();
}

class _VoiceConfirmSheetState extends State<_VoiceConfirmSheet> {
  _VoiceStage _stage = _VoiceStage.listening;
  String _heardText = '';

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    VoiceService.stopListening();
    VoiceService.stopSpeaking();
    super.dispose();
  }

  Future<void> _startListening() async {
    setState(() {
      _stage = _VoiceStage.listening;
      _heardText = '';
    });

    final available = await VoiceService.initialize();
    if (!available) {
      if (mounted) setState(() => _stage = _VoiceStage.error);
      return;
    }

    await VoiceService.listen(
      onResult: (text) async {
        if (!mounted) return;
        if (text.trim().isEmpty) {
          setState(() => _stage = _VoiceStage.error);
          return;
        }
        setState(() {
          _heardText = text;
          _stage = _VoiceStage.confirming;
        });
        // Speak it back — the audible half of the confirmation (rule 1)
        await VoiceService.speak(text);
      },
    );
  }

  void _handleConfirm() {
    Navigator.of(context).pop(_heardText);
  }

  void _handleRetry() {
    _startListening();
  }

  void _handleCancel() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.fieldLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            _buildStageContent(context),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _handleCancel,
              child: const Text('रद्द करें'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageContent(BuildContext context) {
    switch (_stage) {
      case _VoiceStage.listening:
        return Column(
          children: [
            // Mic is the largest, most dominant control (rule 1)
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'सुन रहे हैं... बोलिए',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        );

      case _VoiceStage.confirming:
        return Column(
          children: [
            // Large heard-text display (the visual half of confirmation)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _heardText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            // Replay button — user can hear it again if they missed it
            TextButton.icon(
              onPressed: () => VoiceService.speak(_heardText),
              icon: const Icon(Icons.volume_up, size: 20),
              label: const Text('फिर से सुनें'),
            ),
            const SizedBox(height: 16),
            // Confirm / retry — never a silent checkmark (rule 1)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _handleRetry,
                    child: const Text('फिर से बोलें'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleConfirm,
                    child: const Text('सही है'),
                  ),
                ),
              ],
            ),
          ],
        );

      case _VoiceStage.error:
        return Column(
          children: [
            Icon(Icons.mic_off, color: AppColors.danger, size: 48),
            const SizedBox(height: 12),
            Text(
              'सुनाई नहीं दिया। फिर से कोशिश करें।',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.danger,
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _handleRetry,
              child: const Text('फिर से बोलें'),
            ),
          ],
        );
    }
  }
}
