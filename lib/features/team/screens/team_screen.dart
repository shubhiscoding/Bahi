import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/name_formatter.dart';
import '../../business/providers/business_providers.dart';
import '../providers/team_providers.dart';
import '../repositories/team_repository.dart';

/// Team Screen (design.md §6)
/// Member list, invite (re-shows invite code), owner-only remove.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(teamMembersProvider);
    final roleAsync = ref.watch(currentUserRoleProvider);
    final isOwner = roleAsync.value == 'owner';
    final businessAsync = ref.watch(currentBusinessProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => _errorState(),
        data: (members) {
          if (members.isEmpty) {
            return _emptyState();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return _MemberCard(
                member: member,
                isCurrentUserOwner: isOwner,
                businessId: businessAsync.value?.id,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final business = businessAsync.value;
          if (business == null) return;
          _showInviteSheet(context, business.inviteCode);
        },
        icon: const Icon(Icons.person_add, size: 28),
        label: Text(
          Strings.addCoworker,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
    );
  }

  void _showInviteSheet(BuildContext context, String inviteCode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'साथियों को जोड़ने के लिए कोड:',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    inviteCode,
                    style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Wire share_plus (plan §O)
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(content: Text('WhatsApp साझा करना जल्द आएगा')),
                  );
                },
                icon: const Icon(Icons.share),
                label: Text(Strings.shareViaWhatsApp),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64, color: AppColors.inkSoft),
            const SizedBox(height: 16),
            Text(
              Strings.noCoworkers,
              style: const TextStyle(fontSize: 18, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              Strings.errorOccurred,
              style: const TextStyle(fontSize: 18, color: AppColors.danger),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends ConsumerWidget {
  final TeamMember member;
  final bool isCurrentUserOwner;
  final String? businessId;

  const _MemberCard({
    required this.member,
    required this.isCurrentUserOwner,
    required this.businessId,
  });

  Future<void> _handleRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${Strings.removeMember}?'),
        content: Text('${member.fullName} को हटाएँ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(Strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              Strings.removeMember,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(removeMemberProvider(member.userId).future);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('त्रुटि: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarColor = AppColors.avatarColorForName(member.fullName);
    final shortName = NameFormatter.shortName(member.fullName);
    final initial = NameFormatter.getInitial(member.fullName);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: avatarColor,
              child: Text(
                initial,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shortName, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    member.isOwner ? Strings.owner : Strings.member,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: member.isOwner ? AppColors.accent : AppColors.inkSoft,
                        ),
                  ),
                ],
              ),
            ),
            // Owner-only remove action (design.md rule 6: secondary/rare, smaller)
            if (isCurrentUserOwner && !member.isOwner)
              IconButton(
                onPressed: () => _handleRemove(context, ref),
                icon: const Icon(Icons.person_remove_outlined, color: AppColors.danger),
              ),
          ],
        ),
      ),
    );
  }
}
