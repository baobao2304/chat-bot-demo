import 'package:flutter/material.dart';

class ChatMessageContent extends StatelessWidget {
  const ChatMessageContent({
    super.key,
    required this.text,
    required this.textColor,
  });

  final String text;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseMarkdownBlocks(text);
    final textStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: textColor, height: 1.35);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < blocks.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          switch (blocks[index]) {
            _TextBlock(:final content) => Text(content, style: textStyle),
            _TableBlock(:final headers, :final rows) => MarkdownTableView(
              headers: headers,
              rows: rows,
              textColor: textColor,
            ),
          },
        ],
      ],
    );
  }
}

class MarkdownTableView extends StatelessWidget {
  const MarkdownTableView({
    super.key,
    required this.headers,
    required this.rows,
    required this.textColor,
  });

  final List<String> headers;
  final List<List<String>> rows;
  final Color textColor;

  static const _compactCellWidth = 124.0;
  static const _wideCellWidth = 148.0;
  static const _firstCellExtraWidth = 18.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final columnCount = headers.length.clamp(1, 99);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width * 0.82;
        final baseCellWidth = columnCount <= 3
            ? (availableWidth - _firstCellExtraWidth) / columnCount
            : _compactCellWidth;
        final cellWidth = baseCellWidth.clamp(
          _compactCellWidth,
          _wideCellWidth,
        );
        final firstCellWidth = cellWidth + _firstCellExtraWidth;
        final tableWidth = firstCellWidth + cellWidth * (columnCount - 1);
        final canScroll = tableWidth > availableWidth + 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.65),
                  width: 1.2,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MarkdownTableRow(
                          cells: headers,
                          cellWidth: cellWidth,
                          firstCellWidth: firstCellWidth,
                          backgroundColor: colorScheme.primaryContainer,
                          borderColor: colorScheme.outlineVariant.withValues(
                            alpha: 0.8,
                          ),
                          textColor: colorScheme.onPrimaryContainer,
                          isHeader: true,
                          isLastRow: rows.isEmpty,
                        ),
                        for (var index = 0; index < rows.length; index++)
                          _MarkdownTableRow(
                            cells: _normalizeCellCount(
                              rows[index],
                              headers.length,
                            ),
                            cellWidth: cellWidth,
                            firstCellWidth: firstCellWidth,
                            backgroundColor: index.isEven
                                ? colorScheme.surface
                                : colorScheme.surfaceContainerLowest,
                            borderColor: colorScheme.outlineVariant.withValues(
                              alpha: 0.58,
                            ),
                            textColor: colorScheme.onSurface,
                            isLastRow: index == rows.length - 1,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (canScroll) ...[
              const SizedBox(height: 6),
              Text(
                'Vuốt ngang để xem thêm cột',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline.withValues(alpha: 0.65),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static List<String> _normalizeCellCount(List<String> cells, int count) {
    if (cells.length == count) {
      return cells;
    }
    if (cells.length > count) {
      return cells.take(count).toList();
    }
    return <String>[...cells, ...List.filled(count - cells.length, '')];
  }
}

class _MarkdownTableRow extends StatelessWidget {
  const _MarkdownTableRow({
    required this.cells,
    required this.cellWidth,
    required this.firstCellWidth,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.isLastRow,
    this.isHeader = false,
  });

  final List<String> cells;
  final double cellWidth;
  final double firstCellWidth;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final bool isLastRow;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: textColor.withValues(alpha: isHeader ? 0.95 : 0.85),
      height: 1.4,
      fontSize: 13.5,
      fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var index = 0; index < cells.length; index++)
          Container(
            width: index == 0 ? firstCellWidth : cellWidth,
            constraints: BoxConstraints(minHeight: isHeader ? 48 : 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(
                right: index == cells.length - 1
                    ? BorderSide.none
                    : BorderSide(color: borderColor),
                bottom: isLastRow
                    ? BorderSide.none
                    : BorderSide(color: borderColor),
              ),
            ),
            child: Text(
              cells[index].isEmpty ? '—' : cells[index],
              style: style,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
      ],
    );
  }
}

sealed class _MarkdownBlock {
  const _MarkdownBlock();
}

class _TextBlock extends _MarkdownBlock {
  const _TextBlock(this.content);

  final String content;
}

class _TableBlock extends _MarkdownBlock {
  const _TableBlock({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;
}

List<_MarkdownBlock> _parseMarkdownBlocks(String source) {
  final lines = source.split('\n');
  final blocks = <_MarkdownBlock>[];
  final textBuffer = <String>[];

  void flushText() {
    final content = textBuffer.join('\n').trim();
    if (content.isNotEmpty) {
      blocks.add(_TextBlock(content));
    }
    textBuffer.clear();
  }

  var index = 0;
  while (index < lines.length) {
    final line = lines[index];
    final nextLine = index + 1 < lines.length ? lines[index + 1] : null;

    if (_isTableRow(line) && nextLine != null && _isSeparatorRow(nextLine)) {
      final headers = _parseTableCells(line);
      final rows = <List<String>>[];
      index += 2;

      while (index < lines.length && _isTableRow(lines[index])) {
        final cells = _parseTableCells(lines[index]);
        if (cells.isNotEmpty) {
          rows.add(cells);
        }
        index++;
      }

      if (headers.isNotEmpty && rows.isNotEmpty) {
        flushText();
        blocks.add(_TableBlock(headers: headers, rows: rows));
      } else {
        textBuffer.add(line);
        textBuffer.add(nextLine);
      }
      continue;
    }

    textBuffer.add(line);
    index++;
  }

  flushText();
  return blocks;
}

bool _isTableRow(String line) {
  final trimmed = line.trim();
  return trimmed.startsWith('|') &&
      trimmed.endsWith('|') &&
      trimmed.contains('|');
}

bool _isSeparatorRow(String line) {
  if (!_isTableRow(line)) {
    return false;
  }
  final cells = _parseTableCells(line);
  return cells.isNotEmpty &&
      cells.every((cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell));
}

List<String> _parseTableCells(String line) {
  var normalized = line.trim();
  if (normalized.startsWith('|')) {
    normalized = normalized.substring(1);
  }
  if (normalized.endsWith('|')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized.split('|').map((cell) => cell.trim()).toList();
}
