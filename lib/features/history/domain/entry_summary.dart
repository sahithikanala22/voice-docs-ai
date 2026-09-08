/// A short, scannable gist of an entry's transcript — the first sentence
/// when there's a clear one, otherwise a clean word-boundary cut — so
/// History/Calendar tiles read as headlines instead of a truncated wall of
/// text. Purely local string logic; the full transcript is unaffected and
/// still shown in the entry's detail view.
String entrySummary(String text, {int maxLength = 80}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '';

  final sentenceEnd = RegExp(r'[.!?]').firstMatch(trimmed);
  if (sentenceEnd != null && sentenceEnd.end <= maxLength + 20) {
    return trimmed.substring(0, sentenceEnd.end).trim();
  }

  if (trimmed.length <= maxLength) return trimmed;

  // Cut at the last space before maxLength so a word isn't sliced in half.
  final cut = trimmed.substring(0, maxLength);
  final lastSpace = cut.lastIndexOf(' ');
  final clean = lastSpace > 20 ? cut.substring(0, lastSpace) : cut;
  return '${clean.trim()}…';
}
