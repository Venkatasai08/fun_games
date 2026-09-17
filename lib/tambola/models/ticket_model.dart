// lib/models/ticket_model.dart
import 'dart:math';

class TicketGenerator {
  /// Generates a Tambola ticket.
  /// - Always 3 rows, 10 columns
  /// - Each row has exactly 5 filled cells
  /// - Each column i covers range: floor(i*max/10)+1 .. floor((i+1)*max/10)
  static List<List<int?>> generate(int maxNumber) {
    final random = Random();
    const rows = 3;
    const cols = 10;

    // ticket[row][col]
    var ticket = List.generate(rows, (_) => List<int?>.filled(cols, null));

    // For each column, figure out which rows will have a number
    // We need exactly 5 filled per row → total 15 numbers across 10 cols
    // Column fill counts can be 0, 1, 2, or 3 but sum over cols must = 15
    // Use a balanced approach: assign "filled slots" per column

    // Step 1: Each row selects 5 random columns to fill
    for (int row = 0; row < rows; row++) {
      List<int> colIndices = List.generate(cols, (i) => i)..shuffle(random);
      List<int> selectedCols = colIndices.sublist(0, 5);

      for (int col in selectedCols) {
        int rangeStart = col * maxNumber ~/ cols + 1;
        int rangeEnd = (col + 1) * maxNumber ~/ cols;
        if (rangeStart > rangeEnd) rangeEnd = rangeStart;

        // Find numbers not already used in this column across other rows
        List<int> usedInCol = [];
        for (int r = 0; r < rows; r++) {
          if (ticket[r][col] != null) usedInCol.add(ticket[r][col]!);
        }

        List<int> available = [];
        for (int n = rangeStart; n <= rangeEnd; n++) {
          if (!usedInCol.contains(n)) available.add(n);
        }

        if (available.isNotEmpty) {
          available.shuffle(random);
          ticket[row][col] = available.first;
        } else {
          // Fallback: just pick a number (shouldn't happen with enough range)
          ticket[row][col] = rangeStart + random.nextInt(rangeEnd - rangeStart + 1);
        }
      }
    }

    // Step 2: Sort numbers within each column (ascending, nulls stay null)
    for (int col = 0; col < cols; col++) {
      List<int> colNums = [];
      for (int row = 0; row < rows; row++) {
        if (ticket[row][col] != null) colNums.add(ticket[row][col]!);
      }
      colNums.sort();
      int idx = 0;
      for (int row = 0; row < rows; row++) {
        if (ticket[row][col] != null) {
          ticket[row][col] = colNums[idx++];
        }
      }
    }

    return ticket;
  }

  /// Converts ticket to a flat list of 30 ints for Firestore storage.
  /// Firestore does NOT allow nested arrays, so we flatten 3×10 → 30 values.
  /// Blank cells (null) are stored as 0.
  static List<int> toJson(List<List<int?>> ticket) {
    return ticket
        .expand((row) => row.map((cell) => cell ?? 0))
        .toList();
  }

  /// Reconstructs a 3×10 ticket from the flat list stored in Firestore.
  /// 0 values are converted back to null (blank cells).
  static List<List<int?>> fromJson(List<dynamic> flat) {
    final values = flat.map((e) => (e as num).toInt()).toList();
    return List.generate(
      3,
      (row) => List.generate(
        10,
        (col) {
          final v = values[row * 10 + col];
          return v == 0 ? null : v;
        },
      ),
    );
  }

  /// Check if a row is complete (all 5 numbers marked)
  static bool isRowComplete(List<int?> row, List<int> markedNumbers) {
    return row.where((n) => n != null).every((n) => markedNumbers.contains(n));
  }

  /// Check if full house (all numbers marked)
  static bool isFullHouse(List<List<int?>> ticket, List<int> markedNumbers) {
    return ticket.every((row) => isRowComplete(row, markedNumbers));
  }

  /// Count matched numbers
  static int countMatched(List<List<int?>> ticket, List<int> markedNumbers) {
    int count = 0;
    for (var row in ticket) {
      for (var cell in row) {
        if (cell != null && markedNumbers.contains(cell)) count++;
      }
    }
    return count;
  }
}
