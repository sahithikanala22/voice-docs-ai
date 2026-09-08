/// Parses the "Speaker N: ..." lines the Google Cloud speech provider
/// produces when diarization found more than one voice in a recording —
/// lets the user keep just their own lines instead of everyone who was
/// picked up.
final _speakerLine = RegExp(r'^Speaker (\d+): (.*)$');

/// Distinct speaker numbers found, in order of first appearance. Empty for
/// a plain (single-speaker) transcript, since that never carries the
/// "Speaker N:" prefix in the first place.
List<int> speakersIn(String transcript) {
  final speakers = <int>[];
  for (final line in transcript.split('\n')) {
    final match = _speakerLine.firstMatch(line);
    if (match == null) continue;
    final speaker = int.parse(match.group(1)!);
    if (!speakers.contains(speaker)) speakers.add(speaker);
  }
  return speakers;
}

bool hasMultipleSpeakers(String transcript) =>
    speakersIn(transcript).length > 1;

/// Rejoins only [speaker]'s lines into a clean transcript, dropping the
/// "Speaker N:" labels — the point is a normal-looking entry in just your
/// own words, not a transcript that still reads like a meeting log.
String keepOnlySpeaker(String transcript, int speaker) {
  final kept = <String>[];
  for (final line in transcript.split('\n')) {
    final match = _speakerLine.firstMatch(line);
    if (match == null) continue;
    if (int.parse(match.group(1)!) == speaker) {
      kept.add(match.group(2)!);
    }
  }
  return kept.join(' ').trim();
}
