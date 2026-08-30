import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/theme/colors.dart';
import '../providers/auth_provider.dart';

/// Sign-In Screen
/// Design.md rule 3: Minimal choices, single button, one-time assisted setup.
/// One action: Google Sign-In. No secondary options, no complexity.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final googleSignInAsync = ref.watch(googleSignInProvider);

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
                onPressed: googleSignInAsync.isLoading ? null : () => _handleGoogleSignIn(ref),
                icon: const Icon(Icons.login, size: 24),
                label: Text(
                  Strings.signInGoogle,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),

              // Loading state
              if (googleSignInAsync.isLoading) ...[
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
              if (googleSignInAsync.hasError) ...[
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

  void _handleGoogleSignIn(WidgetRef ref) {
    ref.read(googleSignInProvider);
  }
}
