import '../domain/models/category.dart';
import '../domain/models/item.dart';

/// Represents availability metrics and fill rate for a specific menu category.
class CategoryAvailabilityMetrics {
  final Category category;
  final int totalItems;
  final int availableItems;
  final int unavailableItems;
  final double availabilityRate; // 0.0 to 1.0
  final double availabilityPercentage; // 0.0 to 100.0

  const CategoryAvailabilityMetrics({
    required this.category,
    required this.totalItems,
    required this.availableItems,
    required this.unavailableItems,
    required this.availabilityRate,
    required this.availabilityPercentage,
  });

  /// Formatted percentage string (e.g., "100%", "85%", "0%")
  String get percentageLabel => '${availabilityPercentage.toStringAsFixed(0)}%';

  /// Operational status badge text
  String get statusLabel {
    if (totalItems == 0) return '0 ITEMS (EMPTY)';
    if (unavailableItems == 0) return '100% READY';
    if (availableItems == 0) return '0% (ALL OUT)';
    return '${availabilityPercentage.toStringAsFixed(0)}% READY ($unavailableItems OUT)';
  }

  /// True if all items in this category are active
  bool get isFullyAvailable => totalItems > 0 && unavailableItems == 0;

  /// True if any items in this category are currently marked out of stock
  bool get hasOutItems => unavailableItems > 0;

  /// True if category has no items
  bool get isEmpty => totalItems == 0;
}

/// Sorting modes supported in Menu Management
enum CategorySortMode {
  /// Default: Sorted by availability fill rate (%) descending (mostly filled first)
  availabilityFillRate,

  /// Alphabetical A-Z by category name
  alphabetical,

  /// Native custom ordering as configured by admin
  customOrder,
}

/// Robust, high-performance algorithm to calculate category availability fill rates
/// and rank categories by default so that the most available / mostly filled
/// categories appear first (in percentage, not in raw numbers).
class CategoryAvailabilityAlgorithm {
  /// Sorts and ranks categories based on the requested [CategorySortMode].
  ///
  /// Mathematical Formulation for `availabilityFillRate`:
  /// - Fill Rate = availableItems / totalItems (if totalItems > 0, else 0.0)
  /// - Availability Percentage = Fill Rate * 100
  ///
  /// Priority Ranking Criteria:
  /// 1. Availability Percentage DESC (e.g. 100% > 90% > 50% > 0%)
  ///    * Note: A category with 2/2 (100%) ranks HIGHER than 9/10 (90%),
  ///      honoring the strict requirement of percentage over raw counts.
  /// 2. Tie-breaker 1: Total available items DESC (volume of ready inventory)
  /// 3. Tie-breaker 2: Total items count DESC
  /// 4. Tie-breaker 3: Alphabetical by category name ASC (stable deterministic order)
  ///
  /// Complexity: O(N + C log C)
  /// Uses an O(N) hash-map indexing step to eliminate O(N * C) nested list scans.
  static List<CategoryAvailabilityMetrics> rankCategories({
    required List<Category> categories,
    required List<Item> items,
    CategorySortMode sortMode = CategorySortMode.availabilityFillRate,
  }) {
    if (categories.isEmpty) return const [];

    // 1. Index items by categoryId in a single pass O(N)
    final Map<String, List<Item>> itemsByCategory = {};
    for (final item in items) {
      itemsByCategory.putIfAbsent(item.categoryId, () => []).add(item);
    }

    // 2. Compute metrics for each category in O(C)
    final List<CategoryAvailabilityMetrics> metricsList = categories.map((cat) {
      final categoryItems = itemsByCategory[cat.categoryId] ?? const <Item>[];
      final total = categoryItems.length;
      final available = categoryItems.where((i) => i.isAvailable).length.clamp(0, total);
      final unavailable = total - available;

      final double rate = total > 0 ? (available / total) : 0.0;
      final double percentage = rate * 100.0;

      return CategoryAvailabilityMetrics(
        category: cat,
        totalItems: total,
        availableItems: available,
        unavailableItems: unavailable,
        availabilityRate: rate,
        availabilityPercentage: percentage,
      );
    }).toList();

    // 3. Apply sorting based on selected mode
    switch (sortMode) {
      case CategorySortMode.availabilityFillRate:
        metricsList.sort((a, b) {
          // Primary: Exact rational cross-multiplication for zero-epsilon floating point precision
          final int cmpRatio;
          if (a.totalItems > 0 && b.totalItems > 0) {
            cmpRatio = (b.availableItems * a.totalItems).compareTo(a.availableItems * b.totalItems);
          } else {
            cmpRatio = b.availabilityPercentage.compareTo(a.availabilityPercentage);
          }
          if (cmpRatio != 0) return cmpRatio;

          // Tie-breaker 1: Higher available items count (greater active inventory volume)
          final cmpAvailable = b.availableItems.compareTo(a.availableItems);
          if (cmpAvailable != 0) return cmpAvailable;

          // Tie-breaker 2: Higher total catalog size
          final cmpTotal = b.totalItems.compareTo(a.totalItems);
          if (cmpTotal != 0) return cmpTotal;

          // Tie-breaker 3: Alphabetical by trimmed lowercase name
          final cmpName = a.category.name.trim().toLowerCase().compareTo(b.category.name.trim().toLowerCase());
          if (cmpName != 0) return cmpName;

          // Tie-breaker 4: Strict unique Category ID (guarantees mathematical determinism across all platforms)
          return a.category.categoryId.compareTo(b.category.categoryId);
        });
        break;

      case CategorySortMode.alphabetical:
        metricsList.sort((a, b) {
          final cmpName = a.category.name.trim().toLowerCase().compareTo(b.category.name.trim().toLowerCase());
          if (cmpName != 0) return cmpName;
          return a.category.categoryId.compareTo(b.category.categoryId);
        });
        break;

      case CategorySortMode.customOrder:
        metricsList.sort((a, b) {
          final cmpOrder = a.category.order.compareTo(b.category.order);
          if (cmpOrder != 0) return cmpOrder;
          final cmpName = a.category.name.trim().toLowerCase().compareTo(b.category.name.trim().toLowerCase());
          if (cmpName != 0) return cmpName;
          return a.category.categoryId.compareTo(b.category.categoryId);
        });
        break;
    }

    return metricsList;
  }
}
