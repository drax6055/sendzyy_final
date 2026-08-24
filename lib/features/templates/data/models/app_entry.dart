class AppEntry {
  final String packageName; // max 224 chars
  final String signatureHash; // exactly 11 chars

  const AppEntry({
    required this.packageName,
    required this.signatureHash,
  });

  AppEntry copyWith({
    String? packageName,
    String? signatureHash,
  }) {
    return AppEntry(
      packageName: packageName ?? this.packageName,
      signatureHash: signatureHash ?? this.signatureHash,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppEntry &&
          runtimeType == other.runtimeType &&
          packageName == other.packageName &&
          signatureHash == other.signatureHash;

  @override
  int get hashCode => packageName.hashCode ^ signatureHash.hashCode;

  @override
  String toString() =>
      'AppEntry(packageName: $packageName, signatureHash: $signatureHash)';
}
