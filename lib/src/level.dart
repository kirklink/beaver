/// Severity levels for log entries, ordered from lowest to highest.
enum Level implements Comparable<Level> {
  debug,
  info,
  warn,
  error,
  fatal;

  /// Returns true if this level is at or above [threshold].
  bool passes(Level threshold) => index >= threshold.index;

  @override
  int compareTo(Level other) => index.compareTo(other.index);
}
