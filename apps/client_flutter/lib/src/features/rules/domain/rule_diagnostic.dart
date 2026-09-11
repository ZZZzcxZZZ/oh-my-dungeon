enum RuleSeverity { error, warning }

class RuleDiagnostic {
  const RuleDiagnostic({
    required this.path,
    required this.severity,
    required this.code,
    required this.message,
  });

  final String path;
  final RuleSeverity severity;
  final String code;
  final String message;

  @override
  String toString() => '[$severity/$code] $path: $message';
}
