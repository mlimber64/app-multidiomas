import '../../profile/domain/language_pair.dart';
import 'scenario_mission.dart';

/// Where a step of the routine stands. Completing a step means the learner did
/// the activity, not that they got it right: correctness belongs to the review
/// and learning systems.
enum RoutineStepState {
  pending,
  completed,

  /// There was nothing to practice here today (no exercise, no word): the step
  /// is simply left out. Nothing is made up to fill it.
  unavailable,
}

/// How far the routine has come. Derived from the steps, never stored.
enum RoutineStatus { notStarted, step1Completed, step2Completed, completed }

/// Step 1, "Ripassa": up to [maxItems] review exercises. Holds the ids of the
/// review items chosen by the ReviewEngine; the exercises themselves are built
/// from them when the learner practices.
class ReviewStep {
  const ReviewStep({required this.state, this.itemIds = const []});

  static const maxItems = 3;

  final RoutineStepState state;
  final List<String> itemIds;

  ReviewStep completed() =>
      ReviewStep(state: RoutineStepState.completed, itemIds: itemIds);

  @override
  bool operator ==(Object other) =>
      other is ReviewStep &&
      other.state == state &&
      _same(other.itemIds, itemIds);

  @override
  int get hashCode => Object.hash(state, Object.hashAll(itemIds));
}

/// Step 2, "Parla": a conversation mission.
class ScenarioStep {
  const ScenarioStep({required this.state, this.mission});

  final RoutineStepState state;
  final ScenarioMission? mission;

  ScenarioStep completed() =>
      ScenarioStep(state: RoutineStepState.completed, mission: mission);

  @override
  bool operator ==(Object other) =>
      other is ScenarioStep && other.state == state && other.mission == mission;

  @override
  int get hashCode => Object.hash(state, mission);
}

/// Step 3, "Consolida": up to [maxWords] words to reinforce, by their
/// vocabulary id.
class VocabularyStep {
  const VocabularyStep({required this.state, this.vocabularyIds = const []});

  static const maxWords = 2;

  final RoutineStepState state;
  final List<String> vocabularyIds;

  VocabularyStep completed() => VocabularyStep(
    state: RoutineStepState.completed,
    vocabularyIds: vocabularyIds,
  );

  @override
  bool operator ==(Object other) =>
      other is VocabularyStep &&
      other.state == state &&
      _same(other.vocabularyIds, vocabularyIds);

  @override
  int get hashCode => Object.hash(state, Object.hashAll(vocabularyIds));
}

bool _same(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The learner's practice for one day in one language: three steps in order,
/// each optional in content (a step with nothing to practice is
/// [RoutineStepState.unavailable]) and none a test. Immutable: completing a step
/// returns the next routine, or `null` when that is not allowed now.
///
/// It only coordinates: what to review, what to say and which words come from
/// the review and learning systems; it holds no learning or scheduling logic.
class DailyRoutine {
  const DailyRoutine({
    required this.date,
    required this.learningLanguage,
    required this.step1,
    required this.step2,
    required this.step3,
  });

  /// Local calendar day, `yyyy-MM-dd`.
  final String date;
  final AppLanguage learningLanguage;
  final ReviewStep step1;
  final ScenarioStep step2;
  final VocabularyStep step3;

  /// A routine is one per day and language: the same day in another language is
  /// another routine.
  String get key => keyFor(date, learningLanguage);

  static String keyFor(String date, AppLanguage language) =>
      '$date|${language.code}';

  /// `yyyy-MM-dd` of the local calendar day of [moment].
  static String dateOf(DateTime moment) {
    final d = moment.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
  }

  List<RoutineStepState> get _states => [step1.state, step2.state, step3.state];

  /// Steps that have content today.
  int get availableCount =>
      _states.where((s) => s != RoutineStepState.unavailable).length;

  /// Steps the learner has done.
  int get completedCount =>
      _states.where((s) => s == RoutineStepState.completed).length;

  bool get isComplete => _states.every((s) => s != RoutineStepState.pending);

  /// Nothing to practice at all today.
  bool get isEmpty => availableCount == 0;

  /// 1, 2 or 3: the next step to do (the first still pending), or `null` when
  /// the routine is complete.
  int? get currentStep {
    for (var i = 0; i < 3; i++) {
      if (_states[i] == RoutineStepState.pending) return i + 1;
    }
    return null;
  }

  /// A step can be done once every step before it is done or left out.
  bool canComplete(int step) =>
      step >= 1 &&
      step <= 3 &&
      _states[step - 1] == RoutineStepState.pending &&
      _states.take(step - 1).every((s) => s != RoutineStepState.pending);

  RoutineStatus get status {
    if (isComplete && !isEmpty) return RoutineStatus.completed;
    if (completedCount == 0) return RoutineStatus.notStarted;
    final settledPrefix = _states
        .takeWhile((s) => s != RoutineStepState.pending)
        .length;
    return settledPrefix >= 2
        ? RoutineStatus.step2Completed
        : RoutineStatus.step1Completed;
  }

  DailyRoutine? completeStep1() =>
      canComplete(1) ? _with(step1: step1.completed()) : null;

  DailyRoutine? completeStep2() =>
      canComplete(2) ? _with(step2: step2.completed()) : null;

  DailyRoutine? completeStep3() =>
      canComplete(3) ? _with(step3: step3.completed()) : null;

  DailyRoutine _with({
    ReviewStep? step1,
    ScenarioStep? step2,
    VocabularyStep? step3,
  }) => DailyRoutine(
    date: date,
    learningLanguage: learningLanguage,
    step1: step1 ?? this.step1,
    step2: step2 ?? this.step2,
    step3: step3 ?? this.step3,
  );

  @override
  bool operator ==(Object other) =>
      other is DailyRoutine &&
      other.date == date &&
      other.learningLanguage == learningLanguage &&
      other.step1 == step1 &&
      other.step2 == step2 &&
      other.step3 == step3;

  @override
  int get hashCode => Object.hash(date, learningLanguage, step1, step2, step3);
}
