import 'machine_state.dart';
import 'heap_fcp.dart';
import 'suspension.dart';

/// Suspension operations using FCP-exact shared suspension records
/// Records stored in wrapper nodes in reader cells (no separate ROQ)
class SuspendOps {
  /// FCP-exact suspension: create ONE shared record, wrap in nodes for each reader
  /// Implements FCP emulate.h suspend_on lines 169-188
  static void suspendGoalFCP({
    required HeapFCP heap,
    required int goalId,
    required int kappa,
    required Set<int> readerVarIds,  // Variable IDs (not reader IDs)
  }) {
    // print('[TRACE SuspendOps FCP] Suspending goal $goalId on ${readerVarIds.length} reader(s):');
    // print('  Readers: ${readerVarIds.toList()}');
    // print('  Resume PC: $kappa');

    // Create ONE shared suspension record
    final sharedRecord = SuspensionRecord(goalId, kappa);

    // Create wrapper node for each reader cell (independent next pointers)
    for (final varId in readerVarIds) {
      final (_, rAddr) = heap.varTable[varId]!;
      final cell = heap.cells[rAddr];

      // Create wrapper node pointing to shared record
      final node = SuspensionListNode(sharedRecord);

      // Prepend to existing list (or null if none)
      node.next = cell.content is SuspensionListNode
          ? cell.content as SuspensionListNode
          : null;

      // REPLACE reader cell content with suspension list
      cell.content = node;

      // print('  → Added to R$varId suspension list (addr=$rAddr)');
    }

    // print('  ✓ Goal $goalId suspended (shared record)');
  }

  /// Legacy version using ROQ (for backward compatibility during migration)
  /// TODO: Remove after runner.dart updated to use FCP suspension
  static void suspendGoal({
    required int goalId,
    required int kappa,
    required Set<int> readerVarIds,
  }) {
    // Placeholder - should not be called after migration
    throw UnimplementedError('Legacy suspendGoal deprecated - use suspendGoalFCP');
  }
}
