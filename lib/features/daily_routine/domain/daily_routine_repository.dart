import '../../../core/result/result.dart';
import '../../profile/domain/language_pair.dart';
import 'daily_routine.dart';

/// Persistence boundary for the routine of each day and language. It only
/// stores and returns what it is given: it plans nothing, schedules nothing
/// and never touches the learning or review memory.
abstract interface class DailyRoutineRepository {
  /// The routine of [date] (`yyyy-MM-dd`) in [language], or `null` when none
  /// was stored (or the stored one is unreadable).
  Future<Result<DailyRoutine?>> load(String date, AppLanguage language);

  /// Inserts or replaces the routine with the same date and language.
  Future<Result<void>> save(DailyRoutine routine);
}
