import 'package:share_plus/share_plus.dart';

/// Shares an invite code via the platform share sheet (design.md: lean on
/// WhatsApp's own share sheet rather than building custom sharing flows).
class InviteShare {
  static Future<void> shareInviteCode({
    required String businessName,
    required String inviteCode,
  }) {
    final message =
        '$businessName पर बही में जुड़ें।\nकोड: $inviteCode\n\nBahi app खोलें और "दुकान जोड़ें" में यह कोड डालें।';
    return Share.share(message);
  }
}
