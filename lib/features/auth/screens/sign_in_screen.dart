import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/theme/colors.dart';
import '../providers/auth_provider.dart';

/// Sign-In Screen
/// Design.md rule 3: Minimal choices, single button, one-time assisted setup.
/// One action: Google Sign-In. No secondary options, no complexity.
///
/// Uses local state (not ref.watch on the sign-in provider) so the OAuth
/// flow only ever starts from the button tap — watching a side-effecting
/// provider in build() previously auto-triggered Google sign-in the
/// instant this screen rendered, before the user tapped anything.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _isLoading = false;
  bool _hasError = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      await ref.read(googleSignInProvider.future);
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title: बही
              Text(
                'बही',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 12),

              // Subtitle: स्टॉक मैनेजमेंट
              Text(
                'स्टॉक मैनेजमेंट',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.inkSoft,
                      fontSize: 18,
                    ),
              ),
              const SizedBox(height: 64),

              // Primary action: Google Sign-In button (design.md rule 3: single button, no choices)
              // Rule 7: min 56px touch target, use labelLarge for text
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                icon: const Icon(Icons.login, size: 24),
                label: Text(
                  Strings.signInGoogle,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),

              // Loading state
              if (_isLoading) ...[
                const SizedBox(height: 24),
                Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  Strings.signingIn,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],

              // Error state
              if (_hasError) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'साइन इन में त्रुटि। फिर से कोशिश करें।',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.danger,
                        ),
                  ),
                ),
              ],

              const SizedBox(height: 48),

              // Helper text: explain the flow (simple, no jargon, per design.md copy rules)
              Text(
                'Google खाते से साइन इन करें',
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
