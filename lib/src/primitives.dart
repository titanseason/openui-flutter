import 'package:flutter/material.dart';

/// Hand primitives (the "hand" layer of the OpenUI React SDK): skeleton
/// placeholders, citations and sources. These are plain widgets a host
/// can also use directly, outside the renderer.
///
/// Colour note: skeleton bars default to [Colors.grey.shade300], the
/// same colour the renderer's internal `_Skeleton` uses. Hosts that
/// want a theme-matched bar can pass [color] explicitly. The renderer
/// deliberately does not substitute the OpenUI theme's surface colour
/// here: in the light theme that surface is white, which as a bar on a
/// white page would be invisible.

/// One skeleton bar per count, stacked vertically.
class Skeleton extends StatelessWidget {
  const Skeleton({this.count = 3, this.color});
  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? Colors.grey.shade300;
    return Column(
      children: [
        for (var i = 0; i < count; i++)
          Container(
            height: 16,
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(8)),
          ),
      ],
    );
  }
}

/// A skeleton placeholder shaped like a table: [rows] rows of [columns]
/// cells each.
class TableSkeleton extends StatelessWidget {
  const TableSkeleton({this.columns = 3, this.rows = 4, this.color});
  final int columns;
  final int rows;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cellColor = color ?? Colors.grey.shade300;
    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < columns; c++)
                Expanded(
                  child: Container(
                    height: 16,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: cellColor, borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// A citation chip: `[n]`. Tapping calls [onTap] when supplied and
/// otherwise does nothing. [title] is shown as a tooltip; [url] is
/// carried for hosts that resolve the citation on tap.
class Citation extends StatelessWidget {
  const Citation({required this.index, required this.title, this.url, this.onTap});
  final int index;
  final String title;
  final String? url;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: title,
      child: GestureDetector(
        onTap: onTap,
        child: Chip(label: Text('[$index]')),
      ),
    );
  }
}

/// One row of a [Sources] list.
typedef SourceItem = ({String title, String? url, String? faviconUrl});

/// A list of sources: one row per item, with a favicon image when
/// [SourceItem.faviconUrl] is present and the title text. Tapping a
/// row currently does nothing: the brief's theme link handler does
/// not exist in [OpenUIThemeData] (Task 2), and no host use in this
/// task requires one, so adding it here would be scope expansion.
/// A link handler (theme-level or per-widget) is deferred to a later
/// task that actually needs it.
class Sources extends StatelessWidget {
  const Sources({required this.items});
  final List<SourceItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                if (item.faviconUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Image.network(
                      item.faviconUrl!,
                      width: 16,
                      height: 16,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(width: 16, height: 16),
                    ),
                  ),
                Expanded(child: Text(item.title)),
              ],
            ),
          ),
      ],
    );
  }
}
