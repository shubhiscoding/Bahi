import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/constants/strings.dart';

/// Placeholder: Business Create or Join screen
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
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {},
                child: Text(Strings.createBusiness),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {},
                child: Text(Strings.joinBusiness),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
