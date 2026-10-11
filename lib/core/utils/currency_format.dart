String formatIndianRupees(num amount) {
  final digits = amount.round().toString();
  if (digits.length <= 3) return '₹ $digits';
  final groups = <String>[];
  var leading = digits.substring(0, digits.length - 3);
  while (leading.length > 2) {
    groups.insert(0, leading.substring(leading.length - 2));
    leading = leading.substring(0, leading.length - 2);
  }
  groups.insert(0, leading);
  return '₹ ${groups.join(',')},${digits.substring(digits.length - 3)}';
}
