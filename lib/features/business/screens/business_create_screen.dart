import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/theme/colors.dart';
import '../providers/business_providers.dart';

/// Business Create Screen (design.md rule 3: one-time setup, minimal decisions)
/// User enters business name → sees invite code → shares via WhatsApp
class BusinessCreateScreen extends ConsumerStatefulWidget {
  const BusinessCreateScreen({super.key});

  @override
  ConsumerState<BusinessCreateScreen> createState() => _BusinessCreateScreenState();
}

class _BusinessCreateScreenState extends ConsumerState<BusinessCreateScreen> {
  late TextEditingController _nameController;
  String? _createdInviteCode;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleCreateBusiness() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('दुकान का नाम डालें')),
      );
      return;
    }

    try {
      final business = await ref.read(createBusinessProvider(name).future);
      // Refresh business state so the router picks up the new membership
      ref.invalidate(currentBusinessProvider);
      ref.invalidate(userBusinessesProvider);
      setState(() => _createdInviteCode = business.inviteCode);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('त्रुटि: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // If invite code created, show confirmation screen
    if (_createdInviteCode != null) {
      return _buildInviteCodeConfirmation(context);
    }

    // Show create form
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('नई दुकान'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Text(
                'दुकान का नाम',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // Input field (design.md rule 7: min 48px touch target, 16px text)
              TextField(
                controller: _nameController,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: Strings.enterBusinessName,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),

              const SizedBox(height: 32),

              // Primary action button (design.md rule 6: one obvious action)
              ElevatedButton(
                onPressed: _handleCreateBusiness,
                child: Text(
                  Strings.createButtonLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),

              const SizedBox(height: 48),

              // Helper text (design.md copy rules: plain Hindi, ~8-10 words)
              Text(
                'दुकान का नाम दिए बिना आगे नहीं बढ़ सकते।',
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

  /// Confirmation screen showing the invite code + WhatsApp share
  Widget _buildInviteCodeConfirmation(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('दुकान बनाई गई'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success icon + message
              Center(
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'दुकान बनाई गई!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 32),

              // Invite code (large, readable per design.md rule 7)
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'साथियों को जोड़ने के लिए कोड:',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _createdInviteCode!,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Primary action: Share via WhatsApp (design.md rule 6)
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Wire share_plus to open WhatsApp with pre-filled message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('WhatsApp साझा करना जल्द आएगा')),
                  );
                },
                icon: Icon(Icons.share),
                label: Text(
                  Strings.shareViaWhatsApp,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),

              const SizedBox(height: 16),

              // Secondary action: Continue (smaller button)
              // Pop to root so AppRouter re-renders with the new business membership
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: Text('आगे बढ़ें'),
              ),

              const SizedBox(height: 24),

              // Info text (design.md copy rules)
              Text(
                'इस कोड को WhatsApp पर साझा करें।',
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
