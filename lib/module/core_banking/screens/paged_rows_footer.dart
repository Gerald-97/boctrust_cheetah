import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../provider/core_paged_rows.dart';

/// What follows a paged list's rows: why the last refresh or "Show more"
/// failed, then progress while the next page loads or "Show more".
class PagedRowsFooter extends StatelessWidget {
  const PagedRowsFooter({
    required this.rows,
    required this.onShowMore,
    super.key,
  });

  final PagedRows<Object?> rows;
  final VoidCallback onShowMore;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (rows.failure case final failure?)
        Padding(
          padding: const EdgeInsets.only(top: BocSpace.xs),
          child: Semantics(
            liveRegion: true,
            child: Text(
              failure,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.bocColors.errorText,
              ),
            ),
          ),
        ),
      if (rows.loadingMore)
        const ApiLoadingSection(label: 'Loading more')
      else if (rows.hasMore)
        Center(
          child: TextButton(
            onPressed: onShowMore,
            child: const Text('Show more'),
          ),
        ),
    ],
  );
}
