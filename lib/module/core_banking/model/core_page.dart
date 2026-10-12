/// Core's `pagination` block: which page of how many this reply is.
class CorePage {
  const CorePage({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;

  static CorePage? tryParse(Object? json) {
    if (json is! Map) return null;
    final page = json['page'];
    final pageSize = json['pageSize'];
    final total = json['total'];
    final totalPages = json['totalPages'];
    if (page is! int ||
        pageSize is! int ||
        total is! int ||
        totalPages is! int) {
      return null;
    }
    return CorePage(
      page: page,
      pageSize: pageSize,
      total: total,
      totalPages: totalPages,
    );
  }
}
