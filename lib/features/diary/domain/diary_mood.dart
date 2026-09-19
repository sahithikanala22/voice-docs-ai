/// How the day felt — shown as an emoji on the entry.
enum DiaryMood {
  amazing('🤩', 'Amazing'),
  happy('😊', 'Happy'),
  loved('🥰', 'Loved'),
  calm('😌', 'Calm'),
  okay('🙂', 'Okay'),
  tired('😴', 'Tired'),
  sad('😢', 'Sad'),
  anxious('😰', 'Anxious'),
  angry('😠', 'Angry');

  const DiaryMood(this.emoji, this.label);

  final String emoji;
  final String label;
}
