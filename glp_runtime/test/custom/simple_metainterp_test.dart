import 'package:test/test.dart';
import 'package:glp_runtime/bytecode/opcodes.dart';
import 'package:glp_runtime/bytecode/asm.dart';
import 'package:glp_runtime/bytecode/runner.dart';
import 'package:glp_runtime/runtime/runtime.dart';
import 'package:glp_runtime/runtime/cells.dart';
import 'package:glp_runtime/runtime/terms.dart';
import 'package:glp_runtime/runtime/machine_state.dart';
import 'package:glp_runtime/runtime/scheduler.dart';

void main() {
  test('Simple metainterpreter: run(p(X)) with clause(p(a), true)', () {
    print('\n' + '=' * 70);
    print('SIMPLE METAINTERPRETER TEST');
    print('Object program: clause(p(a), true).');
    print('Metainterpreter: run(true). run(A) :- otherwise | clause(A?,B), run(B?).');
    print('Goal: run(p(X))');
    print('Expected: X binds to a');
    print('=' * 70 + '\n');

    final rt = GlpRuntime();

    // Setup: Variable X (single-ID: writer and reader use same ID)
    const varX = 1;  // Single ID for X variable
    rt.heap.addWriter(WriterCell(varX, varX));  // Same ID
    rt.heap.addReader(ReaderCell(varX));

    print('HEAP SETUP:');
    print('  Variable $varX (X) - single ID for writer and reader');
    print('');

    // Build combined program with clause/2 and run/1
    final prog = BC.prog([
      // ===== CLAUSE/2: clause(p(a), true) =====
      BC.L('clause/2'),
      BC.TRY(),
      // Match first argument: p(a)
      BC.headStruct('p', 1, 0),      // arg0 must be p(_) structure
      BC.unifyConst('a'),             // first subterm must be 'a'
      // Match second argument: true
      BC.headConst('true', 1),        // arg1 must be 'true'
      BC.COMMIT(),
      BC.PROCEED(),

      BC.L('clause/2_end'),
      BC.SUSP(),

      // ===== RUN/1 =====
      // Clause 1: run(true).
      BC.L('run/1'),
      BC.TRY(),
      BC.headConst('true', 0),        // arg0 = 'true'
      BC.COMMIT(),
      BC.PROCEED(),
      BC.CLAUSE_NEXT('run/1_clause2'),  // If clause 1 fails, try clause 2

      // Clause 2: run(A) :- otherwise | clause(A?, B), run(B?).
      BC.L('run/1_clause2'),
      BC.TRY(),
      BC.otherwise(),                 // otherwise guard
      BC.getVar(0, 0),                // Get A from arg0
      BC.COMMIT(),
      // BODY: call clause(A?, B), then tail-call run(B?)
      BC.putReader(0, 0),             // arg0 = A? (reader of A)
      BC.putWriter(1, 1),             // arg1 = B (fresh writer)
      BC.spawn('clause/2', 2),        // Call clause(A?, B)
      BC.putReader(1, 0),             // arg0 = B? (reader of B)
      BC.requeue('run/1', 1),         // Tail call run(B?)

      BC.L('run/1_end'),
      BC.SUSP(),
    ]);

    final runner = BytecodeRunner(prog);
    final sched = Scheduler(rt: rt, runner: runner);

    print('PROGRAM LABELS:');
    for (final entry in prog.labels.entries) {
      print('  ${entry.key} => PC ${entry.value}');
    }
    print('');

    // Build p(X) structure (single-ID: writer and reader use same ID)
    const varPX = 10;  // Single ID for p(X) variable
    rt.heap.addWriter(WriterCell(varPX, varPX));  // Same ID for writer and reader
    rt.heap.addReader(ReaderCell(varPX));
    rt.heap.bindWriterStruct(varPX, 'p', [VarRef(varX, isReader: false)]);

    // Goal: run(p(X))
    const goalId = 100;
    final env = CallEnv(readers: {0: varPX});
    rt.setGoalEnv(goalId, env);
    rt.gq.enqueue(GoalRef(goalId, prog.labels['run/1']!));

    print('Goal: run(p(X)) at PC ${prog.labels['run/1']}');
    print('');

    final ran = sched.drain(maxCycles: 50);

    print('Goals executed: $ran');
    print('Total executions: ${ran.length}');
    print('');

    print('=' * 70);
    print('RESULTS');
    print('=' * 70);
    print('X (Var$varX) bound: ${rt.heap.isWriterBound(varX)}');

    expect(rt.heap.isWriterBound(varX), true, reason: 'X should be bound');

    if (rt.heap.isWriterBound(varX)) {
      final xValue = rt.heap.valueOfWriter(varX);
      print('X value: $xValue');
      expect(xValue, isA<ConstTerm>(), reason: 'X should be ConstTerm');
      if (xValue is ConstTerm) {
        expect(xValue.value, 'a', reason: 'X should be bound to a');
        print('✓ X correctly bound to a');
      }
    }
    print('');

    print('✓ Metainterpreter successfully executed!');
  });
}
