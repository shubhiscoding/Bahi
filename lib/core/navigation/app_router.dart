import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/colors.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/sign_in_screen.dart';
import '../../features/business/providers/business_providers.dart';
import '../../features/business/screens/business_create_or_join_screen.dart';
import '../../features/inventory/screens/app_shell_screen.dart';

/// App router — routes based on auth + business membership state
/// No session → Sign-In
/// Session + no business → Create/Join
/// Session + business → Main app shell (Inventory/Team tabs)
class AppRouter extends ConsumerWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authSessionProvider);

    return authState.when(
      loading: () => _loadingScreen(),
      error: (err, stack) => _errorScreen(err),
      data: (state) {
        // No session → Sign-In
        if (!state.isAuthenticated) {
          return const SignInScreen();
        }

        // Session exists → check business membership
        final businessState = ref.watch(currentBusinessProvider);

        return businessState.when(
          loading: () => _loadingScreen(),
          error: (err, stack) => _errorScreen(err),
          data: (business) {
            // No business membership → Create/Join screen
            if (business == null) {
              return const BusinessCreateOrJoinScreen();
            }

            // Has business → main app shell (Inventory/Team tabs)
            return const AppShellScreen();
          },
        );
      },
    );
  }

  Widget _loadingScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }

  Widget _errorScreen(Object err) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'कुछ गलत हुआ। ऐप फिर से खोलें।',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: AppColors.danger),
          ),
        ),
      ),
    );
  }
}
