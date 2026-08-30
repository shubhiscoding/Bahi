import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/theme/colors.dart';
import '../providers/business_providers.dart';

/// Business Join Screen (design.md §4)
/// User enters an invite code shared via WhatsApp → joins as a member.
class BusinessJoinScreen extends ConsumerStatefulWidget {
  const BusinessJoinScreen({super.key});

  @override
  ConsumerState<BusinessJoinScreen> createState() => _BusinessJoinScreenState();
}

class _BusinessJoinScreenState extends ConsumerState<BusinessJoinScreen> {
  late TextEditingController _codeController;
  bool _isJoining = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleJoinBusiness() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'कोड डालें');
      return;
    }

    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      await ref.read(joinBusinessProvider(code).future);
      // Refresh business state and pop to root so AppRouter re-renders
      ref.invalidate(currentBusinessProvider);
      ref.invalidate(userBusinessesProvider);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() {
        _isJoining = false;
        _errorMessage = Strings.codeNotFound;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('दुकान जोड़ें'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                Strings.enterCode,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // Code input (design.md rule 7: min 48px touch target)
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'ABCD1234',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),

              // Error message (design.md rule 11: plain language, no jargon)
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.danger,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Primary action button (design.md rule 6)
              ElevatedButton(
                onPressed: _isJoining ? null : _handleJoinBusiness,
                child: _isJoining
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        Strings.joinButtonLabel,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
              ),

              const SizedBox(height: 24),

              Text(
                'दुकान के मालिक से कोड लें।',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
