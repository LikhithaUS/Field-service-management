import 'dart:math' as math;

/// One page of results plus the backend's pagination metadata.
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<T> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasPrevious => page > 1;
  bool get hasNext => page < totalPages;

  /// 1-based index of the first/last item on this page ("Showing 11-20 of 45").
  int get from => total == 0 ? 0 : (page - 1) * limit + 1;
  int get to => math.min(page * limit, total);

  factory Paginated.fromJson(Map<String, dynamic> data, T Function(Map<String, dynamic>) fromItem) {
    final meta = data['pagination'] as Map<String, dynamic>;
    return Paginated(
      items: (data['items'] as List).map((e) => fromItem(e as Map<String, dynamic>)).toList(),
      page: (meta['page'] as num).toInt(),
      limit: (meta['limit'] as num).toInt(),
      total: (meta['total'] as num).toInt(),
      totalPages: (meta['totalPages'] as num).toInt(),
    );
  }
}
