String formatTime(int seconds) {
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;

  if (minutes == 0) {
    return '${remainingSeconds}s';
  }

  return '${minutes}m ${remainingSeconds}s';
}
