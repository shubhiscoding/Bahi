import 'package:flutter/material.dart';
import '../../../core/constants/strings.dart';
import '../../../core/theme/colors.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _isLoading = false;

  void _handleGoogleSignIn() {
    setState(() => _isLoading = true);
    // TODO: Implement Supabase + Google Sign-In
    // For now, just a placeholder
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isLoading = false);
        // TODO: Navigate to business creation/join flow
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App title
              Text(
                'बही',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
              ),
              SizedBox(height: 12),
              Text(
                'स्टॉक मैनेजमेंट',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.inkSoft,
                    ),
              ),
              SizedBox(height: 64),

              // Google Sign-In button (design.md rule 3: single button, no choices)
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                icon: Icon(Icons.login, size: 24),
                label: Text(
                  Strings.signInGoogle,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),

              if (_isLoading) ...[
                SizedBox(height: 24),
                Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  Strings.signingIn,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],

              SizedBox(height: 48),

              // Simple help text
              Text(
                'Google खाते से साइन इन करें',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
