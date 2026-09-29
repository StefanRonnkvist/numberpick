import 'dart:math';

import 'package:flutter/material.dart';
import 'package:numberpick/features/game/domain/models.dart';

/// Measurements used to size and scroll the number-tile grid.
class BoardLayoutMetrics {
  const BoardLayoutMetrics({
    required this.rowsNeeded,
    required this.contentWidth,
    required this.contentHeight,
    required this.rowGap,
    required this.needsVerticalScroll,
    required this.needsHorizontalScroll,
  });

  final int rowsNeeded;
  final double contentWidth;
  final double contentHeight;
  final double rowGap;
  final bool needsVerticalScroll;
  final bool needsHorizontalScroll;
}

/// Returns how many fixed-width tiles fit in the usable board width.
///
/// The result is always between one and [maxColumns], even when the available
/// width is narrower than a single tile.
int resolveColumnCount({
  required double availableWidth,
  required double tileSize,
  required int maxColumns,
  required double horizontalPadding,
}) {
  final double usableWidth = max(1, availableWidth - (horizontalPadding * 2));
  return (usableWidth / tileSize).floor().clamp(1, maxColumns);
}

/// Calculates grid dimensions, row spacing, and required scroll directions.
///
/// Rows share any spare vertical space when they fit. Once they no longer fit,
/// [minRowGap] is used and the resulting content height enables scrolling.
BoardLayoutMetrics buildBoardLayoutMetrics({
  required double availableWidth,
  required double availableHeight,
  required double tileSize,
  required int columnCount,
  required int numberTiles,
  required double topPadding,
  required double bottomPadding,
  required double minRowGap,
  required double horizontalPadding,
}) {
  final int rowsNeeded = (numberTiles + columnCount - 1) ~/ columnCount;
  final int maxRowsByHeight = max(
    1,
    ((availableHeight - topPadding - bottomPadding) / tileSize).floor(),
  );

  final double maxTileWidth = max(1, availableWidth - (horizontalPadding * 2));
  final double contentWidth = max(maxTileWidth, columnCount * tileSize);

  final bool needsVerticalScroll = rowsNeeded > maxRowsByHeight;
  final double rowGap = needsVerticalScroll
      ? minRowGap
      : rowsNeeded <= 1
      ? 0
      : ((availableHeight -
                    topPadding -
                    bottomPadding -
                    (rowsNeeded * tileSize)) /
                max(1, rowsNeeded - 1))
            .clamp(0, double.infinity);

  final double contentHeight =
      topPadding +
      bottomPadding +
      (rowsNeeded * tileSize) +
      (max(0, rowsNeeded - 1) * rowGap);

  return BoardLayoutMetrics(
    rowsNeeded: rowsNeeded,
    contentWidth: contentWidth,
    contentHeight: contentHeight,
    rowGap: rowGap,
    needsVerticalScroll: needsVerticalScroll,
    needsHorizontalScroll: contentWidth > availableWidth,
  );
}

/// Displays number tiles in fixed column lanes with two-axis overflow support.
class NumberTilesBoard extends StatelessWidget {
  const NumberTilesBoard({
    super.key,
    required this.numberTiles,
    required this.columnCount,
    required this.lockedTileIds,
    required this.tileSize,
    required this.onAvailableWidth,
  });

  final List<NumberTile> numberTiles;
  final int columnCount;
  final Set<int> lockedTileIds;
  final double tileSize;
  final ValueChanged<double> onAvailableWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        const double topPadding = 12;
        const double bottomPadding = 12;
        const double minRowGap = 6;
        const double horizontalPadding = 16;

        onAvailableWidth(width);

        final BoardLayoutMetrics metrics = buildBoardLayoutMetrics(
          availableWidth: width,
          availableHeight: height,
          tileSize: tileSize,
          columnCount: columnCount,
          numberTiles: numberTiles.length,
          topPadding: topPadding,
          bottomPadding: bottomPadding,
          minRowGap: minRowGap,
          horizontalPadding: horizontalPadding,
        );

        final double contentWidth = max(width, metrics.contentWidth);
        final double contentHeight = max(height, metrics.contentHeight);
        final double boardWidth = max(
          contentWidth,
          (columnCount * tileSize) + (horizontalPadding * 2),
        );
        final double boardHeight = max(
          contentHeight,
          (metrics.rowsNeeded * tileSize) +
              ((max(0, metrics.rowsNeeded - 1)) * metrics.rowGap) +
              topPadding +
              bottomPadding,
        );
        final double offsetX = max(0, (boardWidth - contentWidth) / 2);
        final double offsetY = max(0, (boardHeight - contentHeight) / 2);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: boardWidth,
              height: boardHeight,
              child: Stack(
                children: [
                  for (final NumberTile tile in numberTiles)
                    _buildNumberTileWidget(
                      tile,
                      boardWidth,
                      topPadding + offsetY,
                      metrics.rowGap,
                      horizontalPadding + offsetX,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNumberTileWidget(
    NumberTile tile,
    double width,
    double topPadding,
    double rowGap,
    double horizontalPadding,
  ) {
    final double y = topPadding + tile.row * (tileSize + rowGap);

    final double laneWidth = (width - (horizontalPadding * 2)) / columnCount;
    final double laneCenterX =
        horizontalPadding + laneWidth * tile.column + (laneWidth / 2);
    final double x = laneCenterX - (tileSize / 2);

    final Color tileColor = tile.color;
    final Color textColor = tileColor.computeLuminance() > 0.55
        ? Colors.black
        : Colors.white;
    final bool isLocked = lockedTileIds.contains(tile.id);

    if (isLocked) {
      return Positioned(
        left: x,
        top: y,
        child: Opacity(
          opacity: 0.35,
          child: _buildNumberTileBody(tile, tileColor, textColor),
        ),
      );
    }

    return Positioned(
      left: x,
      top: y,
      child: Draggable<DraggedNumber>(
        data: DraggedNumber(tileId: tile.id, value: tile.value),
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: tileSize,
            height: tileSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  '${tile.value}',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.2,
          child: _buildNumberTileBody(tile, tileColor, textColor),
        ),
        child: _buildNumberTileBody(tile, tileColor, textColor),
      ),
    );
  }

  Widget _buildNumberTileBody(
    NumberTile tile,
    Color tileColor,
    Color textColor,
  ) {
    return SizedBox(
      width: tileSize,
      height: tileSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${tile.value}',
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
