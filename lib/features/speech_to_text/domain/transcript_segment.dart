/// A recognizer-provided time range relative to the original recording.
class TranscriptSegment {
  const TranscriptSegment({
    required this.text,
    required this.start,
    required this.end,
  });
  final String text;
  final Duration start, end;

  Map<String, dynamic> toJson() => {
    'text': text,
    'startMs': start.inMilliseconds,
    'endMs': end.inMilliseconds,
  };

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    final start = json['startMs'] as int;
    final end = json['endMs'] as int;
    if (start < 0 || end < start) {
      throw const FormatException('Invalid transcript timing');
    }
    return TranscriptSegment(
      text: json['text'] as String,
      start: Duration(milliseconds: start),
      end: Duration(milliseconds: end),
    );
  }
}

/// Group timed words into readable passages, keeping real recognizer times.
List<TranscriptSegment> transcriptPassages(List<TranscriptSegment> segments) {
  final passages = <TranscriptSegment>[];
  for (final segment in segments) {
    if (passages.isEmpty ||
        passages.last.text.length >= 100 ||
        segment.start - passages.last.start >= const Duration(seconds: 15)) {
      passages.add(segment);
    } else {
      final previous = passages.removeLast();
      passages.add(
        TranscriptSegment(
          text: '${previous.text} ${segment.text}',
          start: previous.start,
          end: segment.end,
        ),
      );
    }
  }
  return passages;
}
