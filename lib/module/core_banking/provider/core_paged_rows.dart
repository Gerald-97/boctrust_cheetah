import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../model/core_page.dart';

/// The rows of a paged Core list read so far.
class PagedRows<T> {
  const PagedRows({
    required this.rows,
    this.hasMore = false,
    this.loadingMore = false,
    this.failure,
  });

  final List<T> rows;
  final bool hasMore;
  final bool loadingMore;

  /// Why the last refresh or "Show more" failed. The rows already shown are
  /// kept.
  final String? failure;
}

/// One page as a [PagedRowsNotifier] needs it.
typedef PagedRead<T> = ({List<T> rows, CorePage? page});

/// Reads a Core list a page at a time, newest first, keeping the rows already
/// shown when a refresh or a later page fails. Re-read when the session
/// changes, so one customer's rows never show for another.
abstract class PagedRowsNotifier<T>
    extends Notifier<NotifierState<PagedRows<T>>> {
  int _generation = 0;
  int _page = 1;
  bool _reloading = false;

  /// Rows asked for per page.
  int get pageSize;

  /// Shown when the first page cannot be read and Core gave no reason.
  String get loadFailure;

  /// Reads [page] of [pageSize] rows.
  Future<NotifierState<PagedRead<T>>> readPage(int page);

  /// Identifies a row so a later page never repeats it; null never matches.
  Object? rowKey(T row);

  /// Watches whatever the rows belong to, such as the session.
  void watchScope();

  @override
  NotifierState<PagedRows<T>> build() {
    watchScope();
    _generation++;
    _page = 1;
    _reloading = false;
    Future.microtask(reload);
    return const NotifierState.loading();
  }

  bool _hasMore(PagedRead<T> read) =>
      read.page?.hasMore ?? read.rows.length >= pageSize;

  /// Reads the first page again, dropping any later pages. A failure keeps
  /// the rows already shown.
  Future<void> reload() async {
    if (!ref.mounted) return;
    final generation = ++_generation;
    _reloading = true;
    final result = await readPage(1);
    if (!ref.mounted || generation != _generation) return;
    _reloading = false;
    final read = result.data;
    final shown = state.data;
    if (read == null) {
      final message = result.message ?? loadFailure;
      state = shown == null
          ? NotifierState.error(message, statusCode: result.statusCode)
          : NotifierState.done(
              PagedRows(
                rows: shown.rows,
                hasMore: shown.hasMore,
                failure: message,
              ),
            );
      return;
    }
    _page = 1;
    state = NotifierState.done(
      PagedRows(rows: read.rows, hasMore: _hasMore(read)),
    );
  }

  /// Adds the next page, keeping the rows already shown. Ignored while a
  /// refresh is reading, so the two never mix pages.
  Future<void> loadMore() async {
    final current = state.data;
    if (current == null ||
        !current.hasMore ||
        current.loadingMore ||
        _reloading) {
      return;
    }
    final generation = _generation;
    state = NotifierState.done(
      PagedRows(rows: current.rows, hasMore: true, loadingMore: true),
    );
    final result = await readPage(_page + 1);
    if (!ref.mounted || generation != _generation) return;
    final read = result.data;
    if (read == null) {
      state = NotifierState.done(
        PagedRows(
          rows: current.rows,
          hasMore: true,
          failure: result.message ?? "We couldn't load more.",
        ),
      );
      return;
    }
    _page++;
    final known = {for (final row in current.rows) ?rowKey(row)};
    bool isNew(T row) {
      final key = rowKey(row);
      return key == null || known.add(key);
    }

    state = NotifierState.done(
      PagedRows(
        rows: [...current.rows, ...read.rows.where(isNew)],
        hasMore: _hasMore(read),
      ),
    );
  }
}
