import 'package:test/test.dart';
import 'package:glp_runtime/runtime/runtime.dart';
import 'package:glp_runtime/runtime/cells.dart';
import 'package:glp_runtime/runtime/terms.dart';
import 'package:glp_runtime/runtime/machine_state.dart';
import 'package:glp_runtime/bytecode/runner.dart';
import 'package:glp_runtime/bytecode/opcodes.dart';
import 'package:glp_runtime/bytecode/asm.dart';

void main() {
  test('Three-way circular: merge(Xs?,[a],Ys), merge(Ys?,[b],Zs), merge(Zs?,[c],Xs)', () {
    print('\n' + '=' * 70);
    print('THREE-WAY CIRCULAR MERGE');
    print('Goal 100: merge(Xs?, [a], Ys)');
    print('Goal 200: merge(Ys?, [b], Zs)');
    print('Goal 300: merge(Zs?, [c], Xs)  <- Completes the cycle: Xs→Ys→Zs→Xs');
    print('Reduction budget: 100 per goal execution');
    print('=' * 70 + '\n');

    final rt = GlpRuntime();

    // Build list [a]
    const wListA = 10;
    const rListA = 11;
    rt.heap.addWriter(WriterCell(wListA, rListA));
    rt.heap.addReader(ReaderCell(rListA));
    rt.heap.bindWriterStruct(wListA, '.', [
      ConstTerm('a'),
      ConstTerm(null),
    ]);

    // Build list [b]
    const wListB = 20;
    const rListB = 21;
    rt.heap.addWriter(WriterCell(wListB, rListB));
    rt.heap.addReader(ReaderCell(rListB));
    rt.heap.bindWriterStruct(wListB, '.', [
      ConstTerm('b'),
      ConstTerm(null),
    ]);

    // Build list [c]
    const wListC = 30;
    const rListC = 31;
    rt.heap.addWriter(WriterCell(wListC, rListC));
    rt.heap.addReader(ReaderCell(rListC));
    rt.heap.bindWriterStruct(wListC, '.', [
      ConstTerm('c'),
      ConstTerm(null),
    ]);

    // Variables
    const wXs = 40;
    const rXs = 41;
    rt.heap.addWriter(WriterCell(wXs, rXs));
    rt.heap.addReader(ReaderCell(rXs));

    const wYs = 50;
    const rYs = 51;
    rt.heap.addWriter(WriterCell(wYs, rYs));
    rt.heap.addReader(ReaderCell(rYs));

    const wZs = 60;
    const rZs = 61;
    rt.heap.addWriter(WriterCell(wZs, rZs));
    rt.heap.addReader(ReaderCell(rZs));

    print('HEAP SETUP:');
    print('  [a] at W$wListA/R$rListA');
    print('  [b] at W$wListB/R$rListB');
    print('  [c] at W$wListC/R$rListC');
    print('  Xs: W$wXs/R$rXs (unbound)');
    print('  Ys: W$wYs/R$rYs (unbound)');
    print('  Zs: W$wZs/R$rZs (unbound)');
    print('');

    // Full merge program
    final prog = BC.prog([
      BC.L('merge/3_start'),

      // Clause 1: merge([X|Xs],Ys,[X?|Zs?]) :- merge(Ys?,Xs?,Zs).
      BC.TRY(),
      BC.headStruct('.', 2, 0),
      BC.headWriter(0),
      BC.headWriter(1),
      BC.getVar(2, 1),
      BC.headStruct('.', 2, 2),
      BC.headReader(0),
      BC.headWriter(3),
      BC.COMMIT(),
      BC.putReader(2, 0),
      BC.putReader(1, 1),
      BC.putWriter(3, 2),
      BC.requeue('merge/3_start', 3),

      // Clause 2: merge(Xs,[Y|Ys],[Y?|Zs?]) :- merge(Xs?,Ys?,Zs).
      BC.L('merge/3_clause2'),
      BC.TRY(),
      BC.getVar(0, 0),
      BC.headStruct('.', 2, 1),
      BC.headWriter(1),
      BC.headWriter(2),
      BC.headStruct('.', 2, 2),
      BC.headReader(1),
      BC.headWriter(3),
      BC.COMMIT(),
      BC.putReader(0, 0),
      BC.putReader(2, 1),
      BC.putWriter(3, 2),
      BC.requeue('merge/3_start', 3),

      // Clause 3: merge([],[],[]).
      BC.L('merge/3_clause3'),
      BC.TRY(),
      BC.headConst(null, 0),
      BC.headConst(null, 1),
      BC.headConst(null, 2),
      BC.COMMIT(),
      BC.PROCEED(),

      BC.L('merge/3_end'),
      BC.SUSP(),
    ]);

    final runner = BytecodeRunner(prog);

    print('=' * 70);
    print('EXECUTION TRACE');
    print('=' * 70 + '\n');

    // Goal 100: merge(Xs?, [a], Ys)
    print('--- GOAL 100: merge(Xs?, [a], Ys) ---');
    const goal1 = 100;
    final env1 = CallEnv(readers: {0: rXs, 1: rListA}, writers: {2: wYs});
    rt.setGoalEnv(goal1, env1);

    final cx1 = RunnerContext(
      rt: rt,
      goalId: goal1,
      kappa: 0,
      env: env1,
      reductionBudget: 100,
    );
    runner.runWithStatus(cx1);
    print('');

    // Goal 200: merge(Ys?, [b], Zs)
    print('--- GOAL 200: merge(Ys?, [b], Zs) ---');
    const goal2 = 200;
    final env2 = CallEnv(readers: {0: rYs, 1: rListB}, writers: {2: wZs});
    rt.setGoalEnv(goal2, env2);

    final cx2 = RunnerContext(
      rt: rt,
      goalId: goal2,
      kappa: 0,
      env: env2,
      reductionBudget: 100,
    );
    runner.runWithStatus(cx2);
    print('');

    // Goal 300: merge(Zs?, [c], Xs) - Completes the cycle!
    print('--- GOAL 300: merge(Zs?, [c], Xs) ---');
    print('    Note: Creates cycle Xs→Ys→Zs→Xs');
    const goal3 = 300;
    final env3 = CallEnv(readers: {0: rZs, 1: rListC}, writers: {2: wXs});
    rt.setGoalEnv(goal3, env3);

    final cx3 = RunnerContext(
      rt: rt,
      goalId: goal3,
      kappa: 0,
      env: env3,
      reductionBudget: 100,
    );
    runner.runWithStatus(cx3);
    print('');

    print('=' * 70);
    print('INITIAL STATE SUMMARY');
    print('=' * 70);
    print('Xs bound: ${rt.heap.isWriterBound(wXs)}');
    if (rt.heap.isWriterBound(wXs)) {
      print('Xs value: ${rt.heap.valueOfWriter(wXs)}');
    }
    print('Ys bound: ${rt.heap.isWriterBound(wYs)}');
    if (rt.heap.isWriterBound(wYs)) {
      print('Ys value: ${rt.heap.valueOfWriter(wYs)}');
    }
    print('Zs bound: ${rt.heap.isWriterBound(wZs)}');
    if (rt.heap.isWriterBound(wZs)) {
      print('Zs value: ${rt.heap.valueOfWriter(wZs)}');
    }
    print('Goals in queue: ${rt.gq.length}');
    print('');

    // Run cycles
    print('=' * 70);
    print('REACTIVATION CYCLES');
    print('=' * 70 + '\n');

    var cycle = 0;
    while (rt.gq.length > 0 && cycle < 20) {
      final act = rt.gq.dequeue();
      if (act == null) break;
      cycle++;

      print('CYCLE $cycle: Goal ${act.id}');

      final env = rt.getGoalEnv(act.id);
      final cx = RunnerContext(
        rt: rt,
        goalId: act.id,
        kappa: act.pc,
        env: env,
        reductionBudget: 100,
      );
      runner.runWithStatus(cx);
      print('  Queue now has ${rt.gq.length} goals');
      print('');
    }

    print('=' * 70);
    print('FINAL STATE AFTER $cycle CYCLES');
    print('=' * 70);
    print('Xs bound: ${rt.heap.isWriterBound(wXs)}');
    if (rt.heap.isWriterBound(wXs)) {
      print('Xs value: ${rt.heap.valueOfWriter(wXs)}');
    }
    print('Ys bound: ${rt.heap.isWriterBound(wYs)}');
    if (rt.heap.isWriterBound(wYs)) {
      print('Ys value: ${rt.heap.valueOfWriter(wYs)}');
    }
    print('Zs bound: ${rt.heap.isWriterBound(wZs)}');
    if (rt.heap.isWriterBound(wZs)) {
      print('Zs value: ${rt.heap.valueOfWriter(wZs)}');
    }
    print('Goals remaining in queue: ${rt.gq.length}');
    print('');

    print('✓ Three-way circular merge test complete');
    print('  Note: Creates circular dependency chain: Xs→Ys→Zs→Xs');
  });
}
