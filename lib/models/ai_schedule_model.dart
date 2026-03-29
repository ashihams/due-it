class AiMicrotask {
  final String title;
  final bool completed;

  AiMicrotask({required this.title, this.completed = false});

  factory AiMicrotask.fromMap(Map<String, dynamic> map) => AiMicrotask(
        title: (map['title'] ?? '').toString(),
        completed: map['completed'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {'title': title, 'completed': completed};
}

class AiDaySchedule {
  final String date; // YYYY-MM-DD
  final String subtask;
  final List<AiMicrotask> microtasks;

  AiDaySchedule({
    required this.date,
    required this.subtask,
    required this.microtasks,
  });

  factory AiDaySchedule.fromMap(Map<String, dynamic> map) => AiDaySchedule(
        date: (map['date'] ?? '').toString(),
        subtask: (map['subtask'] ?? '').toString(),
        microtasks: (map['microtasks'] as List<dynamic>? ?? [])
            .map((m) => AiMicrotask.fromMap(Map<String, dynamic>.from(m as Map)))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'date': date,
        'subtask': subtask,
        'microtasks': microtasks.map((m) => m.toMap()).toList(),
      };
}

class TaskAiData {
  final List<AiDaySchedule> schedule;
  final bool generated;

  TaskAiData({required this.schedule, required this.generated});

  factory TaskAiData.fromMap(Map<String, dynamic> map) => TaskAiData(
        generated: map['generated'] as bool? ?? false,
        schedule: (map['schedule'] as List<dynamic>? ?? [])
            .map((s) => AiDaySchedule.fromMap(Map<String, dynamic>.from(s as Map)))
            .toList(),
      );

  AiDaySchedule? scheduleForDateKey(String key) {
    try {
      return schedule.firstWhere((s) => s.date == key);
    } catch (_) {
      return null;
    }
  }

  AiDaySchedule? get todaySchedule {
    final now = DateTime.now();
    final key =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return scheduleForDateKey(key);
  }
}


