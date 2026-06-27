/// A recipient parsed from CSV or manual input.
/// [variables] maps variable index (1-based) to its value, e.g. {1: 'John', 2: '+91...'}
class RecipientData {
  final String mobileNumber;
  final Map<int, String> variables; // {1: name, 2: mobile, 3: company ...}
  final bool fromCsv; // true = CSV row (pre-filled, not shown in manual table)

  const RecipientData({
    required this.mobileNumber,
    required this.variables,
    this.fromCsv = false,
  });

  /// Normalize a mobile number:
  /// - Strip spaces, dashes, +, leading zeros
  /// - 10 digits → prepend "91"
  /// - 12 digits starting with 91 → valid as-is
  /// - anything else → returns null (invalid)
  static String? normalizeNumber(String raw) {
    // Remove all non-digit characters
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return digits;
    return null; // invalid
  }

  /// Build from a CSV row. Expected columns: mobile, var1, var2, var3 ...
  factory RecipientData.fromCsvRow(List<dynamic> row) {
    final raw = row[0].toString().trim();
    final mobile = normalizeNumber(raw) ?? raw; // keep raw if invalid so caller can filter
    final vars = <int, String>{};
    for (int i = 1; i < row.length; i++) {
      vars[i] = row[i].toString().trim();
    }
    return RecipientData(mobileNumber: mobile, variables: vars, fromCsv: true);
  }

  /// Build from manual number entry (no variables pre-filled)
  factory RecipientData.fromNumber(String number) {
    final normalized = normalizeNumber(number) ?? number;
    return RecipientData(mobileNumber: normalized, variables: {});
  }
}
