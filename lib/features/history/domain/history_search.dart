/// Whether every word in [query] shows up in [text] — matched by root
/// rather than exact spelling (so "stressed"/"stressful"/"stress" all count
/// as the same word) and independent of word order or position, unlike a
/// plain substring `.contains()` check. Deliberately simple: a crude suffix
/// strip, not a real stemming library — enough to feel smarter without
/// pulling in NLP machinery for something this small.
bool matchesSearch(String text, String query) {
  final queryWords = _normalizedWords(query);
  if (queryWords.isEmpty) return true;

  final textWords = _normalizedWords(text);
  return queryWords.every(
    (q) => textWords.any((t) => t == q || t.startsWith(q) || q.startsWith(t)),
  );
}

// Unicode-aware: splits on anything that isn't a letter or number in ANY
// script, not just a-z0-9 — the app supports 60+ languages, and an
// ASCII-only split would treat a whole non-Latin entry (Hindi, Telugu,
// etc.) as one giant separator, leaving zero words to match against.
final _wordBoundary = RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);

List<String> _normalizedWords(String input) {
  return input
      .toLowerCase()
      .split(_wordBoundary)
      .where((w) => w.isNotEmpty)
      .map(_stem)
      .toList();
}

const _suffixes = ['fulness', 'edly', 'ing', 'ful', 'ed', 'es', 'ly', 's'];

String _stem(String word) {
  if (word.length <= 4) return word;
  for (final suffix in _suffixes) {
    if (word.endsWith(suffix) && word.length - suffix.length >= 3) {
      return word.substring(0, word.length - suffix.length);
    }
  }
  return word;
}
