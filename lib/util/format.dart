/// Formats a duration in milliseconds as a speed-run clock.
///
/// Under an hour: `M:SS.d` (e.g. `1:07.4`). Over an hour: `H:MM:SS`.
String formatClock(int? ms) {
  if (ms == null) return '—';
  final totalTenths = (ms / 100).round();
  final tenths = totalTenths % 10;
  final totalSeconds = totalTenths ~/ 10;
  final seconds = totalSeconds % 60;
  final totalMinutes = totalSeconds ~/ 60;
  final minutes = totalMinutes % 60;
  final hours = totalMinutes ~/ 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}.$tenths';
}

/// A compact average form without the tenths, e.g. `1:07`.
String formatClockShort(int? ms) {
  if (ms == null) return '—';
  final totalSeconds = (ms / 1000).round();
  final seconds = totalSeconds % 60;
  final totalMinutes = totalSeconds ~/ 60;
  final minutes = totalMinutes % 60;
  final hours = totalMinutes ~/ 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
