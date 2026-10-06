import 'dart:math' as math;

/// How many days until a sighting counts half as much. Relevance fades with
/// time so what the learner struggled with *recently* ranks above old history.
const recencyHalfLifeDays = 14.0;

/// 1.0 for something seen right now, 0.5 after [recencyHalfLifeDays], 0.25
/// after twice that, and so on. Never negative; a future date counts as now.
double recencyWeight(DateTime lastSeen, DateTime now) {
  final days = now.difference(lastSeen).inSeconds / Duration.secondsPerDay;
  return math.pow(0.5, (days < 0 ? 0 : days) / recencyHalfLifeDays).toDouble();
}
