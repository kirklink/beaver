/// Severity levels for log entries, ordered from lowest to highest.
enum Level implements Comparable<Level> {
  /// Verbose diagnostic information, typically disabled in production.
  debug,

  /// Routine operational messages.
  info,

  /// Potential issues that are not yet errors.
  warn,

  /// Recoverable failures that need attention.
  error,

  /// Unrecoverable failures that require immediate action.
  fatal;

  /// Returns true if this level is at or above [threshold].
  bool passes(Level threshold) => index >= threshold.index;

  @override
  int compareTo(Level other) => index.compareTo(other.index);
}
