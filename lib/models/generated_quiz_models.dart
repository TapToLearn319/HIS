import 'dart:convert';

class QuizOptionItem {
  String text;

  QuizOptionItem({
    required this.text,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
    };
  }

  factory QuizOptionItem.fromMap(Map<String, dynamic> map) {
    return QuizOptionItem(
      text: (map['text'] ?? '').toString(),
    );
  }
}

class GeneratedQuizQuestion {
  String question;
  List<QuizOptionItem> options;
  int correctIndex;
  bool isEnabled;
  bool isExpanded;

  GeneratedQuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.isEnabled = true,
    this.isExpanded = false,
  });

  GeneratedQuizQuestion copyWith({
    String? question,
    List<QuizOptionItem>? options,
    int? correctIndex,
    bool? isEnabled,
    bool? isExpanded,
  }) {
    return GeneratedQuizQuestion(
      question: question ?? this.question,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
      isEnabled: isEnabled ?? this.isEnabled,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options.map((e) => e.toMap()).toList(),
      'correctIndex': correctIndex,
      'isEnabled': isEnabled,
      'isExpanded': isExpanded,
    };
  }

  factory GeneratedQuizQuestion.fromMap(Map<String, dynamic> map) {
    final rawOptions = (map['options'] as List? ?? []);
    return GeneratedQuizQuestion(
      question: (map['question'] ?? '').toString(),
      options: rawOptions
          .map((e) => QuizOptionItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      correctIndex: (map['correctIndex'] ?? 0) as int,
      isEnabled: (map['isEnabled'] ?? true) as bool,
      isExpanded: (map['isExpanded'] ?? false) as bool,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory GeneratedQuizQuestion.fromJson(String source) =>
      GeneratedQuizQuestion.fromMap(jsonDecode(source));
}

class QuizSettingsModel {
  bool showResultsInRealTime;
  bool anonymous;
  bool multipleSelections;
  int timeLimitHours;
  int timeLimitMinutes;
  int timeLimitSeconds;
  bool isPublic;

  QuizSettingsModel({
    this.showResultsInRealTime = true,
    this.anonymous = true,
    this.multipleSelections = true,
    this.timeLimitHours = 0,
    this.timeLimitMinutes = 5,
    this.timeLimitSeconds = 0,
    this.isPublic = false,
  });

  int get totalSeconds =>
      (timeLimitHours * 3600) + (timeLimitMinutes * 60) + timeLimitSeconds;

  Map<String, dynamic> toMap() {
    return {
      'showResultsInRealTime': showResultsInRealTime,
      'anonymous': anonymous,
      'multipleSelections': multipleSelections,
      'timeLimitHours': timeLimitHours,
      'timeLimitMinutes': timeLimitMinutes,
      'timeLimitSeconds': timeLimitSeconds,
      'timeLimitTotalSeconds': totalSeconds,
      'isPublic': isPublic,
    };
  }

  factory QuizSettingsModel.fromMap(Map<String, dynamic> map) {
    return QuizSettingsModel(
      showResultsInRealTime: (map['showResultsInRealTime'] ?? true) as bool,
      anonymous: (map['anonymous'] ?? true) as bool,
      multipleSelections: (map['multipleSelections'] ?? true) as bool,
      timeLimitHours: (map['timeLimitHours'] ?? 0) as int,
      timeLimitMinutes: (map['timeLimitMinutes'] ?? 5) as int,
      timeLimitSeconds: (map['timeLimitSeconds'] ?? 0) as int,
      isPublic: (map['isPublic'] ?? false) as bool,
    );
  }
}

class GeneratedQuizBundle {
  final String title;
  final List<GeneratedQuizQuestion> questions;

  GeneratedQuizBundle({
    required this.title,
    required this.questions,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'questions': questions.map((e) => e.toMap()).toList(),
    };
  }

  factory GeneratedQuizBundle.fromMap(Map<String, dynamic> map) {
    return GeneratedQuizBundle(
      title: (map['title'] ?? '').toString(),
      questions: ((map['questions'] as List?) ?? [])
          .map((e) => GeneratedQuizQuestion.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}