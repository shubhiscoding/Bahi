import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/constants/strings.dart';
import 'business_create_screen.dart';
import 'business_join_screen.dart';

/// Business Create or Join Screen (design.md rule 3: minimal choices)
/// First screen after sign-in with no business membership.
class BusinessCreateOrJoinScreen extends StatelessWidget {
  const BusinessCreateOrJoinScreen({super.key});

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
              Text(
                'दुकान चुनें',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'नई दुकान बनाएँ या पुरानी दुकान से जुड़ें',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkSoft,
                    ),
              ),
              const SizedBox(height: 48),

              // Primary action: Create business
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BusinessCreateScreen(),
                    ),
                  );
                },
                child: Text(
                  Strings.createBusiness,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),

              const SizedBox(height: 16),

              // Secondary action: Join business
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BusinessJoinScreen(),
                    ),
                  );
                },
                child: Text(Strings.joinBusiness),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
