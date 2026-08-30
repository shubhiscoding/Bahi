import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/sign_in_screen.dart';
import '../../features/business/screens/business_create_or_join_screen.dart';
import '../../features/inventory/screens/inventory_home_screen.dart';

/// App router — routes based on auth state
/// No session → Sign-In
/// Session + no business → Create/Join
/// Session + business → Inventory/Team tabs
class AppRouter extends ConsumerWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authSessionProvider);

    return authState.when(
      // Loading: show splash/loading screen
      loading: () => Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),

      // Error: show error screen
      error: (err, stack) => Scaffold(
        body: Center(
          child: Text('Auth error: $err'),
        ),
      ),

      // Data: route based on auth state
      data: (state) {
        // No session → Sign-In
        if (!state.isAuthenticated) {
          return SignInScreen();
        }

        // Session exists → check if user has a business
        // For now, route to inventory (which will check business membership internally)
        return InventoryHomeScreen();
      },
    );
  }
}
