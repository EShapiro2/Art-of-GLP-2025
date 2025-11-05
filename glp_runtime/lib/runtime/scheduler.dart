import 'runtime.dart';
import '../bytecode/runner.dart';

class Scheduler {
  final GlpRuntime rt;
  final Map<Object?, BytecodeRunner> runners;

  Scheduler({required this.rt, BytecodeRunner? runner, Map<Object?, BytecodeRunner>? runners})
      : runners = runners ?? (runner != null ? {null: runner} : {});

  List<int> drain({int maxCycles = 1000}) {
    final ran = <int>[];
    var cycles = 0;
    while (rt.gq.length > 0 && cycles < maxCycles) {
      final act = rt.gq.dequeue();
      if (act == null) break;
      ran.add(act.id);
      final env = rt.getGoalEnv(act.id);
      final program = rt.getGoalProgram(act.id);
      final runner = runners[program];
      if (runner == null) {
        throw StateError('No runner found for program $program for goal ${act.id}');
      }
      final cx = RunnerContext(rt: rt, goalId: act.id, kappa: act.pc, env: env);
      runner.run(cx);
      cycles++;
    }
    return ran;
  }
}
