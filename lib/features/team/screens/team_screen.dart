import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/models/business.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/invite_share.dart';
import '../../../core/utils/name_formatter.dart';
import '../../../core/utils/offline_guard.dart';
import '../../business/providers/business_providers.dart';
import '../providers/team_providers.dart';

/// Team Screen (design.md §6)
/// Member list, invite (generate-and-share a fresh OTP-style code),
/// owner-only remove.
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
          showModalBottomSheet(
            context: context,
            backgroundColor: AppColors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) => _InviteCodeSheet(businessId: business.id, businessName: business.name),
          );
        },
        icon: const Icon(Icons.person_add, size: 28),
        label: Text(
          Strings.addCoworker,
          style: Theme.of(context).textTheme.labelLarge,
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

/// Bottom sheet: generate a fresh 5-minute, single-use invite code and
/// share it — OTP-style (design.md rule 12), no permanent code shown.
class _InviteCodeSheet extends ConsumerStatefulWidget {
  final String businessId;
  final String businessName;

  const _InviteCodeSheet({required this.businessId, required this.businessName});

  @override
  ConsumerState<_InviteCodeSheet> createState() => _InviteCodeSheetState();
}

class _InviteCodeSheetState extends ConsumerState<_InviteCodeSheet> {
  InviteCode? _activeCode;
  Timer? _countdownTimer;
  int _secondsLeft = 0;
  bool _isSharing = false;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleGenerateAndShare() async {
    if (!await ensureOnline(context)) return;

    setState(() => _isSharing = true);
    try {
      final invite = await ref.read(
        generateInviteCodeProvider(widget.businessId).future,
      );
      setState(() => _activeCode = invite);
      _startCountdown(invite.expiresAt);

      await InviteShare.shareInviteCode(
        businessName: widget.businessName,
        inviteCode: invite.code,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('त्रुटि: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _startCountdown(DateTime expiresAt) {
    _countdownTimer?.cancel();
    void tick() {
      final remaining = expiresAt.difference(DateTime.now()).inSeconds;
      setState(() => _secondsLeft = remaining > 0 ? remaining : 0);
      if (remaining <= 0) _countdownTimer?.cancel();
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider).value ?? true;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'साथियों को जोड़ने के लिए कोड',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            if (_activeCode != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Text(
                        _activeCode!.code,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _secondsLeft > 0 ? '$_secondsLeft सेकंड में खत्म होगा' : 'कोड खत्म हो गया',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _secondsLeft > 0 ? AppColors.inkSoft : AppColors.danger,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            ElevatedButton.icon(
              onPressed: (_isSharing || !isOnline) ? null : _handleGenerateAndShare,
              icon: const Icon(Icons.share),
              label: Text(_activeCode == null ? 'कोड बनाएं और साझा करें' : 'नया कोड बनाएं'),
            ),

            const SizedBox(height: 12),
            if (!isOnline)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, size: 18, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Text(
                    Strings.connectToInternet,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.danger,
                        ),
                  ),
                ],
              )
            else
              Text(
                'कोड 5 मिनट या एक बार उपयोग होने पर खत्म हो जाता है।',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends ConsumerWidget {
  final BusinessMember member;
  final bool isCurrentUserOwner;
  final String? businessId;

  const _MemberCard({
    required this.member,
    required this.isCurrentUserOwner,
    required this.businessId,
  });

  Future<void> _handleRemove(BuildContext context, WidgetRef ref) async {
    if (!await ensureOnline(context)) return;

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
    final isOnline = ref.watch(isOnlineProvider).value ?? true;

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
                onPressed: isOnline ? () => _handleRemove(context, ref) : null,
                icon: Icon(
                  Icons.person_remove_outlined,
                  color: isOnline ? AppColors.danger : AppColors.inkSoft,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
