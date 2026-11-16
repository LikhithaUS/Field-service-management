import 'package:flutter/material.dart';

import '../models/paginated.dart';

/// "Showing 11–20 of 45   ‹ 2 / 5 ›" footer shared by every paginated list.
class PaginationBar extends StatelessWidget {
  const PaginationBar({super.key, required this.page, required this.onPageChanged});

  final Paginated<Object?> page;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing ${page.from}–${page.to} of ${page.total}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          IconButton(
            tooltip: 'Previous page',
            onPressed: page.hasPrevious ? () => onPageChanged(page.page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('${page.page} / ${page.totalPages}'),
          IconButton(
            tooltip: 'Next page',
            onPressed: page.hasNext ? () => onPageChanged(page.page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
