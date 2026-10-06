import 'dart:convert';

import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../../services/storage/local_storage.dart';
import '../domain/review_item.dart';
import '../domain/review_repository.dart';

/// Stores review memory as one versioned JSON document (`review_memory`) in
/// [LocalStorage], separate from `learning_memory`. Writes are serialized
/// (read-modify-write of one document must not interleave).
///
/// Reading is defensive: unreadable JSON is an empty memory, and a malformed
/// item (unknown type or status, invalid dates, non-numeric counters, id that
/// does not match its type and source) is skipped without affecting the rest.
/// Negative counters or intervals are normalized to zero. Items with the same
/// id keep the one reviewed most recently (ties: the first stored). A document
/// written by a newer app version is reported as a failure and never
/// overwritten.
class LocalReviewRepository implements ReviewRepository {
  LocalReviewRepository(this._storage);

  static const storageKey = 'review_memory';
  static const currentVersion = 1;

  final LocalStorage _storage;
  Future<void> _tail = Future<void>.value();

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<Result<List<ReviewItem>>> getItems() => _enqueue(() async {
    return switch (await _load()) {
      Failure(:final failure) => Failure(failure),
      Success(value: final items) => Success(_sorted(items.values)),
    };
  });

  @override
  Future<Result<ReviewItem?>> getItem(String id) => _enqueue(() async {
    return switch (await _load()) {
      Failure(:final failure) => Failure(failure),
      Success(value: final items) => Success(items[id]),
    };
  });

  @override
  Future<Result<void>> saveItem(ReviewItem item) => saveItems([item]);

  @override
  Future<Result<void>> saveItems(Iterable<ReviewItem> items) => _update((m) {
    for (final item in items) {
      m[item.id] = item;
    }
  });

  @override
  Future<Result<void>> deleteItem(String id) => _update((m) => m.remove(id));

  Future<Result<void>> _update(void Function(Map<String, ReviewItem>) change) =>
      _enqueue(() async {
        switch (await _load()) {
          case Failure(:final failure):
            return Failure<void>(failure);
          case Success(value: final items):
            change(items);
            return _storage.writeString(
              storageKey,
              jsonEncode({
                'version': currentVersion,
                'items': [for (final i in _sorted(items.values)) _encode(i)],
              }),
            );
        }
      });

  static List<ReviewItem> _sorted(Iterable<ReviewItem> items) =>
      items.toList()..sort((a, b) => a.id.compareTo(b.id));

  Future<Result<Map<String, ReviewItem>>> _load() async {
    final read = await _storage.readString(storageKey);
    switch (read) {
      case Failure(:final failure):
        return Failure(failure);
      case Success(value: final raw):
        return _decode(raw);
    }
  }

  static Result<Map<String, ReviewItem>> _decode(String? raw) {
    final items = <String, ReviewItem>{};
    if (raw == null) return Success(items);
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return Success(items);
    }
    if (json is! Map) return Success(items);
    final version = json['version'];
    if (version is! int || version < 1) return Success(items);
    if (version > currentVersion) {
      return const Failure(
        StorageFailure('review_memory was written by a newer app version'),
      );
    }
    final list = json['items'];
    if (list is! List) return Success(items);
    for (final entry in list) {
      final item = _decodeItem(entry);
      if (item == null) continue;
      final existing = items[item.id];
      if (existing == null || _recency(item).isAfter(_recency(existing))) {
        items[item.id] = item;
      }
    }
    return Success(items);
  }

  static DateTime _recency(ReviewItem i) => i.lastReviewedAt ?? i.firstSeenAt;

  static Map<String, Object?> _encode(ReviewItem i) => {
    'id': i.id,
    'type': i.type.name,
    'sourceId': i.sourceId,
    'status': i.status.name,
    'firstSeenAt': i.firstSeenAt.toUtc().toIso8601String(),
    'lastReviewedAt': i.lastReviewedAt?.toUtc().toIso8601String(),
    'nextReviewAt': i.nextReviewAt.toUtc().toIso8601String(),
    'intervalSeconds': i.interval.inSeconds,
    'successfulReviews': i.successfulReviews,
    'failedReviews': i.failedReviews,
    'consecutiveSuccesses': i.consecutiveSuccesses,
  };

  static ReviewItem? _decodeItem(Object? json) {
    if (json is! Map) return null;
    final type = _byName(ReviewItemType.values, json['type']);
    final status = _byName(ReviewStatus.values, json['status']);
    final sourceId = json['sourceId'];
    if (type == null || status == null) return null;
    if (sourceId is! String || sourceId.isEmpty) return null;
    if (json['id'] != ReviewItem.idFor(type, sourceId)) return null;

    final first = _date(json['firstSeenAt']);
    final next = _date(json['nextReviewAt']);
    if (first == null || next == null) return null;
    DateTime? last;
    if (json['lastReviewedAt'] != null) {
      last = _date(json['lastReviewedAt']);
      if (last == null) return null;
    }
    final seconds = json['intervalSeconds'];
    final successes = json['successfulReviews'];
    final failures = json['failedReviews'];
    final streak = json['consecutiveSuccesses'];
    if (seconds is! int ||
        successes is! int ||
        failures is! int ||
        streak is! int) {
      return null;
    }
    return ReviewItem(
      type: type,
      sourceId: sourceId,
      status: status,
      firstSeenAt: first,
      lastReviewedAt: last,
      nextReviewAt: next,
      interval: Duration(seconds: seconds < 0 ? 0 : seconds),
      successfulReviews: successes < 0 ? 0 : successes,
      failedReviews: failures < 0 ? 0 : failures,
      consecutiveSuccesses: streak < 0 ? 0 : streak,
    );
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;

  static T? _byName<T extends Enum>(List<T> values, Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
