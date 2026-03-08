class DueTask {
  final String id;
  final String title;
  final String description;
  final String group;

  final DateTime endDate;
  final int? durationMinutes; // Nullable - AI will estimate if not provided

  bool isDone;
  DateTime? completedAt;

  DueTask({
    required this.id,
    required this.title,
    required this.description,
    required this.group,
    required this.endDate,
    this.durationMinutes, // Optional - AI will estimate
    this.isDone = false,
    this.completedAt,
  });
}
