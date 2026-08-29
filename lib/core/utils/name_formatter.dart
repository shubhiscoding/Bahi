/// Format names according to design.md rule 10:
/// "पहला-नाम दूसरे-नाम-का-पहला-अक्षर" (e.g. "रमेश क.")
class NameFormatter {
  /// Short name format: "first_name last_initial."
  /// Example: "Ramesh Kumar" -> "रमेश क."
  /// Example: "Anita" -> "अनिता"
  static String shortName(String fullName) {
    if (fullName.isEmpty) return '';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0];
    }
    final firstName = parts[0];
    final lastInitial = parts.last.isNotEmpty ? '${parts.last[0]}.' : '';
    return '$firstName $lastInitial'.trim();
  }

  /// First letter (for avatar initial)
  static String getInitial(String fullName) {
    if (fullName.isEmpty) return '?';
    return fullName.trim()[0];
  }

  /// "पहला-नाम द." format for "edited by" attribution
  /// Example: "Ramesh Kumar" -> "रमेश क."
  static String editedByFormat(String fullName) => shortName(fullName);
}
