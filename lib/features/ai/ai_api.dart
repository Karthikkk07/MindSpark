import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

class GoalSuggestion {
  const GoalSuggestion({required this.dailyAction, required this.milestones});

  factory GoalSuggestion.fromJson(Map<String, dynamic> json) => GoalSuggestion(
        dailyAction: json['dailyAction'] as String? ?? '',
        milestones: ((json['milestones'] as List<dynamic>?) ?? const [])
            .whereType<String>()
            .toList(),
      );

  final String dailyAction;
  final List<String> milestones;
}

/// What the coach is told about a goal's progress.
class GoalProgress {
  const GoalProgress({
    required this.title,
    required this.categoryId,
    required this.currentStreak,
    required this.longestStreak,
    required this.checkInsLast14Days,
    required this.milestonesDone,
    required this.milestonesTotal,
    required this.checkedInToday,
  });

  final String title;
  final String categoryId;
  final int currentStreak;
  final int longestStreak;
  final int checkInsLast14Days;
  final int milestonesDone;
  final int milestonesTotal;
  final bool checkedInToday;

  Map<String, dynamic> toJson() => {
        'title': title,
        'category': categoryId,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'checkInsLast14Days': checkInsLast14Days,
        'milestonesDone': milestonesDone,
        'milestonesTotal': milestonesTotal,
        'checkedInToday': checkedInToday,
      };
}

/// The AI goal coach. The server holds the Gemini key; the app only sends the
/// goal text and progress numbers.
abstract class AiApi {
  Future<GoalSuggestion> suggestGoal(
    String token, {
    required String title,
    required String description,
    required String categoryId,
  });

  Future<String> encourage(String token, GoalProgress progress);
}

class ApiAiApi implements AiApi {
  ApiAiApi(this._api);

  final ApiClient _api;

  @override
  Future<GoalSuggestion> suggestGoal(
    String token, {
    required String title,
    required String description,
    required String categoryId,
  }) async {
    final json = await _api.post(
      '/ai/goal-suggestions',
      body: {
        'title': title,
        'description': description,
        'category': categoryId,
      },
      token: token,
    );
    return GoalSuggestion.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<String> encourage(String token, GoalProgress progress) async {
    final json = await _api.post(
      '/ai/encouragement',
      body: progress.toJson(),
      token: token,
    );
    final data = json['data'] as Map<String, dynamic>;
    return data['message'] as String? ?? '';
  }
}

final aiApiProvider = Provider<AiApi>(
  (ref) => ApiAiApi(ref.watch(apiClientProvider)),
);

/// Text shown next to the AI buttons.
const String aiPrivacyNote =
    'The goal text is sent to Google Gemini to write this.';

/// A message that is safe to show for a failed AI request.
String aiErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  return 'Something went wrong. Try again later.';
}
