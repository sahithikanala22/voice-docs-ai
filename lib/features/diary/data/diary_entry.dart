enum DiaryMood {
  happy('Happy', '☺'),
  calm('Calm', '☘'),
  neutral('Neutral', '◉'),
  sad('Sad', '☁'),
  tired('Tired', '☾');

  const DiaryMood(this.label, this.symbol);
  final String label;
  final String symbol;
}

enum DiaryPageStyle { system, warm, midnight }

/// A composed diary page, kept separate from voice transcript history.
class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.title = '',
    this.body = '',
    this.photos = const [],
    this.mood,
    this.pageStyle = DiaryPageStyle.system,
  });
  final String id;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String title;
  final String body;
  final List<String> photos;
  final DiaryMood? mood;
  final DiaryPageStyle pageStyle;
  bool get isBlank =>
      title.trim().isEmpty && body.trim().isEmpty && photos.isEmpty;
  String get displayTitle =>
      title.trim().isEmpty ? 'A moment to remember' : title.trim();

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'title': title,
    'body': body,
    'mood': mood?.name,
    'pageStyle': pageStyle.name,
    // imagePath integrates with the existing portable backup attachments.
    'photos': photos.map((p) => {'imagePath': p}).toList(),
  };

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    if (id.isEmpty) throw const FormatException('Diary entry has no id.');
    final rawPhotos = json['photos'] as List? ?? const [];
    return DiaryEntry(
      id: id,
      date: DateTime.parse(json['date'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      photos: List.unmodifiable(
        rawPhotos.map(
          (p) => (p as Map<String, dynamic>)['imagePath'] as String,
        ),
      ),
      mood: DiaryMood.values.where((m) => m.name == json['mood']).firstOrNull,
      pageStyle:
          DiaryPageStyle.values
              .where((s) => s.name == json['pageStyle'])
              .firstOrNull ??
          DiaryPageStyle.system,
    );
  }
}
