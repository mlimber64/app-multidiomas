import '../../../core/result/result.dart';
import 'review_item.dart';

/// Persistence boundary for `review_memory`: scheduling state only, never a
/// copy of what is in learning memory. Local JSON today; replaceable later.
abstract interface class ReviewRepository {
  /// Every stored item, in a deterministic order (by id); empty when nothing
  /// is stored or the store is unreadable garbage.
  Future<Result<List<ReviewItem>>> getItems();

  Future<Result<ReviewItem?>> getItem(String id);

  /// Inserts or replaces the item with the same [ReviewItem.id].
  Future<Result<void>> saveItem(ReviewItem item);

  /// Inserts or replaces several items with one write.
  Future<Result<void>> saveItems(Iterable<ReviewItem> items);

  Future<Result<void>> deleteItem(String id);
}
