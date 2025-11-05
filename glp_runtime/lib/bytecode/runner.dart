import 'package:glp_runtime/runtime/runtime.dart';
import 'package:glp_runtime/runtime/machine_state.dart';
import 'package:glp_runtime/runtime/terms.dart';
import 'package:glp_runtime/runtime/commit.dart';
import 'opcodes.dart';

enum RunResult { terminated, suspended, yielded }

/// Unification mode for structure traversal (WAM-style)
enum UnifyMode { read, write }

typedef LabelName = String;

class BytecodeProgram {
  final List<Op> ops;
  final Map<LabelName, int> labels;
  BytecodeProgram(this.ops) : labels = _indexLabels(ops);
  static Map<LabelName, int> _indexLabels(List<Op> ops) {
    final m = <LabelName,int>{};
    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      if (op is Label) m[op.name] = i;
    }
    return m;
  }
}

/// Goal-call environment: maps arg slots to WR/RO ids (set at run time).
class CallEnv {
  final Map<int,int> writerBySlot;
  final Map<int,int> readerBySlot;
  CallEnv({Map<int,int>? writers, Map<int,int>? readers})
      : writerBySlot = writers ?? <int,int>{},
        readerBySlot = readers ?? <int,int>{};
  int? w(int slot) => writerBySlot[slot];
  int? r(int slot) => readerBySlot[slot];
}

class RunnerContext {
  final GlpRuntime rt;
  final int goalId;
  final int kappa;
  final CallEnv env;
  final Map<int, Object?> sigmaHat = <int, Object?>{}; // σ̂w: tentative writer bindings
  final Set<int> si = <int>{};       // clause-local blockers (reader IDs)
  final Set<int> U = <int>{};        // union across clauses (reader IDs)
  bool inBody = false;

  // WAM-style structure traversal state
  UnifyMode mode = UnifyMode.read;   // Current unification mode
  int S = 0;                          // Structure pointer (current position in structure)
  Object? currentStructure;           // Current structure being traversed
  final Map<int, Object?> clauseVars = {}; // Clause variable bindings (varIndex → value)

  final void Function(GoalRef)? onActivation; // host log hook

  RunnerContext({
    required this.rt,
    required this.goalId,
    required this.kappa,
    CallEnv? env,
    this.onActivation,
  }) : env = env ?? CallEnv();

  void clearClause() {
    sigmaHat.clear();
    si.clear();
    inBody = false;
    mode = UnifyMode.read;
    S = 0;
    currentStructure = null;
    clauseVars.clear();
  }
}

class BytecodeRunner {
  final BytecodeProgram prog;
  BytecodeRunner(this.prog);

  void run(RunnerContext cx) { runWithStatus(cx); }

  /// Helper: find next ClauseTry instruction after current PC
  int _findNextClauseTry(int fromPc) {
    for (var i = fromPc + 1; i < prog.ops.length; i++) {
      if (prog.ops[i] is ClauseTry) return i;
    }
    return prog.ops.length; // End of program if no more clauses
  }

  /// Soft-fail to next clause: union Si to U, clear clause state, jump to next ClauseTry
  void _softFailToNextClause(RunnerContext cx, int currentPc) {
    // Union Si into U
    if (cx.si.isNotEmpty) cx.U.addAll(cx.si);
    // Clear clause-local state
    cx.clearClause();
    // Jump to next clause (will be handled by returning new PC)
  }

  RunResult runWithStatus(RunnerContext cx) {
    var pc = 0;
    while (pc < prog.ops.length) {
      final op = prog.ops[pc];

      if (op is Label) { pc++; continue; }
      if (op is ClauseTry) { cx.clearClause(); pc++; continue; }
      if (op is GuardFail) { pc++; continue; }

      // Mode selection (Arg)
      if (op is RequireWriterArg) {
        final wid = cx.env.w(op.slot);
        if (wid == null) { pc = prog.labels[op.failLabel]!; continue; }
        pc++; continue;
      }
      if (op is RequireReaderArg) {
        final rid = cx.env.r(op.slot);
        if (rid == null) { pc = prog.labels[op.failLabel]!; continue; }
        pc++; continue;
      }

      // ===== v2.16 HEAD instructions =====
      if (op is HeadConstant) {
        final arg = _getArg(cx, op.argSlot);
        if (arg == null) { pc++; continue; } // No argument at this slot

        if (arg.isWriter) {
          // Writer: record tentative binding in σ̂w
          cx.sigmaHat[arg.writerId!] = op.value;
        } else if (arg.isReader) {
          // Reader: check if bound, else add to Si
          final wid = cx.rt.heap.writerIdForReader(arg.readerId!);
          if (wid == null || !cx.rt.heap.isWriterBound(wid)) {
            cx.si.add(arg.readerId!);
          }
          // TODO: if bound, check value matches op.value
        } else {
          // Ground: check if value matches
          // TODO: implement proper ground term matching
        }
        pc++; continue;
      }

      if (op is HeadStructure) {
        final arg = _getArg(cx, op.argSlot);
        if (arg == null) {
          // No argument - soft fail to next clause
          _softFailToNextClause(cx, pc);
          pc = _findNextClauseTry(pc);
          continue;
        }

        if (arg.isWriter) {
          // WRITE mode: create tentative structure for writer
          final struct = _TentativeStruct(op.functor, op.arity, List.filled(op.arity, null));
          cx.sigmaHat[arg.writerId!] = struct;
          cx.currentStructure = struct;
          cx.mode = UnifyMode.write;
          cx.S = 0; // Start at first arg
          pc++; continue;
        }

        if (arg.isReader) {
          // Reader: check if bound and has matching structure
          final wid = cx.rt.heap.writerIdForReader(arg.readerId!);
          if (wid == null || !cx.rt.heap.isWriterBound(wid)) {
            // Unbound reader - add to Si and soft fail
            cx.si.add(arg.readerId!);
            _softFailToNextClause(cx, pc);
            pc = _findNextClauseTry(pc);
            continue;
          }

          // Bound reader - get value and check if it's a matching structure
          final value = cx.rt.heap.valueOfWriter(wid);
          if (value is StructTerm && value.functor == op.functor && value.args.length == op.arity) {
            // Matching structure - enter READ mode
            cx.currentStructure = value;
            cx.mode = UnifyMode.read;
            cx.S = 0;
            pc++; continue;
          } else {
            // Non-matching structure or not a structure - soft fail
            _softFailToNextClause(cx, pc);
            pc = _findNextClauseTry(pc);
            continue;
          }
        }

        // Ground term case (not writer or reader)
        // TODO: Handle ground structures when CallEnv supports them
        _softFailToNextClause(cx, pc);
        pc = _findNextClauseTry(pc);
        continue;
      }

      if (op is HeadWriter) {
        // Process writer variable in structure (at S position)
        if (cx.mode == UnifyMode.write) {
          // WRITE mode: Building a structure - create placeholder for writer variable
          if (cx.currentStructure is _TentativeStruct) {
            final struct = cx.currentStructure as _TentativeStruct;
            // Store clause variable reference as placeholder
            final placeholder = _ClauseVar(op.varIndex, isWriter: true);
            struct.args[cx.S] = placeholder;
            cx.clauseVars[op.varIndex] = placeholder;
            cx.S++; // Advance to next arg
          }
        } else {
          // READ mode: Extract value from structure at S position into clause variable
          if (cx.currentStructure is StructTerm) {
            final struct = cx.currentStructure as StructTerm;
            if (cx.S < struct.args.length) {
              final value = struct.args[cx.S];
              cx.clauseVars[op.varIndex] = value;
              cx.S++; // Advance to next arg
            } else {
              // Structure arity mismatch - soft fail
              _softFailToNextClause(cx, pc);
              pc = _findNextClauseTry(pc);
              continue;
            }
          } else {
            // Not a structure - soft fail
            _softFailToNextClause(cx, pc);
            pc = _findNextClauseTry(pc);
            continue;
          }
        }
        pc++; continue;
      }

      if (op is HeadReader) {
        // Process reader variable in structure (at S position)
        if (cx.mode == UnifyMode.write) {
          // WRITE mode: Building structure - add reader placeholder
          if (cx.currentStructure is _TentativeStruct) {
            final struct = cx.currentStructure as _TentativeStruct;
            final placeholder = _ClauseVar(op.varIndex, isWriter: false);
            struct.args[cx.S] = placeholder;
            cx.clauseVars[op.varIndex] = placeholder;
            cx.S++; // Advance to next arg
          }
        } else {
          // READ mode: Verify value at S matches paired writer in tentative state
          if (cx.currentStructure is StructTerm) {
            final struct = cx.currentStructure as StructTerm;
            if (cx.S < struct.args.length) {
              final value = struct.args[cx.S];
              // Check if value matches the tentative writer binding (if any)
              // For now, just store the value and continue
              // TODO: implement proper reader verification against writer
              cx.clauseVars[op.varIndex] = value;
              cx.S++; // Advance to next arg
            } else {
              // Structure arity mismatch - soft fail
              _softFailToNextClause(cx, pc);
              pc = _findNextClauseTry(pc);
              continue;
            }
          } else {
            // Not a structure - soft fail
            _softFailToNextClause(cx, pc);
            pc = _findNextClauseTry(pc);
            continue;
          }
        }
        pc++; continue;
      }

      // ===== Structure subterm matching instructions =====
      if (op is UnifyConstant) {
        // Match constant at current S position
        if (cx.mode == UnifyMode.write) {
          // WRITE mode: Add constant to structure being built
          if (cx.currentStructure is _TentativeStruct) {
            final struct = cx.currentStructure as _TentativeStruct;
            struct.args[cx.S] = op.value;
            cx.S++; // Advance to next arg
          }
        } else {
          // READ mode: Verify value at S position matches constant
          if (cx.currentStructure is StructTerm) {
            final struct = cx.currentStructure as StructTerm;
            if (cx.S < struct.args.length) {
              final value = struct.args[cx.S];
              // Check if value is a constant term matching op.value
              if (value is ConstTerm && value.value == op.value) {
                cx.S++; // Match successful, advance
              } else {
                // Mismatch - soft fail
                _softFailToNextClause(cx, pc);
                pc = _findNextClauseTry(pc);
                continue;
              }
            } else {
              // Structure arity mismatch - soft fail
              _softFailToNextClause(cx, pc);
              pc = _findNextClauseTry(pc);
              continue;
            }
          } else {
            // Not a structure - soft fail
            _softFailToNextClause(cx, pc);
            pc = _findNextClauseTry(pc);
            continue;
          }
        }
        pc++; continue;
      }

      if (op is UnifyVoid) {
        // Skip/create void (anonymous) variables
        if (cx.mode == UnifyMode.write) {
          // WRITE mode: Create fresh unbound variables
          if (cx.currentStructure is _TentativeStruct) {
            final struct = cx.currentStructure as _TentativeStruct;
            for (var i = 0; i < op.count && cx.S < struct.args.length; i++) {
              struct.args[cx.S] = null; // Void/unbound
              cx.S++;
            }
          }
        } else {
          // READ mode: Skip over positions
          cx.S += op.count;
        }
        pc++; continue;
      }

      // Legacy HEAD opcodes (for backward compatibility)
      if (op is HeadBindWriter) {
        // Mark writer as involved (no value binding for legacy opcode)
        cx.sigmaHat[op.writerId] = null;
        pc++; continue;
      }
      if (op is HeadBindWriterArg) {
        final wid = cx.env.w(op.slot);
        if (wid != null) cx.sigmaHat[wid] = null;
        pc++; continue;
      }
      if (op is GuardNeedReader) {
        final rid = op.readerId;
        final wid = cx.rt.heap.writerIdForReader(rid);
        final bound = (wid != null) && cx.rt.heap.isWriterBound(wid);
        if (!bound) cx.si.add(rid);
        pc++; continue;
      }
      if (op is GuardNeedReaderArg) {
        final rid = cx.env.r(op.slot);
        if (rid != null) {
          final wid = cx.rt.heap.writerIdForReader(rid);
          final bound = (wid != null) && cx.rt.heap.isWriterBound(wid);
          if (!bound) cx.si.add(rid);
        }
        pc++; continue;
      }

      // Commit (apply σ̂w and wake suspended goals) - v2.16 semantics
      if (op is Commit) {
        // Convert tentative structures to real Terms before committing
        final convertedSigmaHat = <int, Object?>{};
        for (final entry in cx.sigmaHat.entries) {
          final writerId = entry.key;
          final value = entry.value;

          if (value is _TentativeStruct) {
            // Convert tentative structure to StructTerm
            final termArgs = <Term>[];
            for (final arg in value.args) {
              if (arg is _ClauseVar) {
                // TODO: resolve clause variables to actual writer/reader IDs
                // For now, leave as placeholder
                termArgs.add(ConstTerm('${arg.toString()}'));
              } else if (arg == null) {
                // Void/unbound - create fresh writer?
                // For now, leave as null constant
                termArgs.add(ConstTerm(null));
              } else {
                // Direct constant value
                termArgs.add(ConstTerm(arg));
              }
            }
            convertedSigmaHat[writerId] = StructTerm(value.functor, termArgs);
          } else {
            // Direct value (constant)
            convertedSigmaHat[writerId] = value;
          }
        }

        // Apply σ̂w: bind writers to tentative values, then wake suspended goals
        final acts = CommitOps.applySigmaHatV216(
          heap: cx.rt.heap,
          roq: cx.rt.roq,
          sigmaHat: convertedSigmaHat,
        );
        for (final a in acts) {
          cx.rt.gq.enqueue(a);
          if (cx.onActivation != null) cx.onActivation!(a);
        }
        cx.sigmaHat.clear();
        cx.inBody = true;
        pc++; continue;
      }

      // Clause control / suspend
      if (op is UnionSiAndGoto) {
        if (cx.si.isNotEmpty) cx.U.addAll(cx.si);
        cx.clearClause();
        pc = prog.labels[op.label]!;
        continue;
      }
      if (op is ResetAndGoto) { cx.clearClause(); pc = prog.labels[op.label]!; continue; }

      if (op is SuspendEnd) {
        if (cx.U.isNotEmpty) {
          cx.rt.suspendGoal(goalId: cx.goalId, kappa: cx.kappa, readers: cx.U);
          cx.U.clear();
          cx.inBody = false;
          return RunResult.suspended;
        }
        cx.inBody = false;
        pc++; continue;
      }

      // Body (bind then wake + log)
      if (op is BodySetConst) {
        if (cx.inBody) {
          cx.rt.heap.bindWriterConst(op.writerId, op.value);
          final w = cx.rt.heap.writer(op.writerId);
          if (w != null) {
            final acts = cx.rt.roq.processOnBind(w.readerId);
            for (final a in acts) {
              cx.rt.gq.enqueue(a);
              if (cx.onActivation != null) cx.onActivation!(a);
            }
          }
        }
        pc++; continue;
      }
      if (op is BodySetStructConstArgs) {
        if (cx.inBody) {
          final args = <Term>[for (final v in op.constArgs) ConstTerm(v)];
          cx.rt.heap.bindWriterStruct(op.writerId, op.functor, args);
          final w = cx.rt.heap.writer(op.writerId);
          if (w != null) {
            final acts = cx.rt.roq.processOnBind(w.readerId);
            for (final a in acts) {
              cx.rt.gq.enqueue(a);
              if (cx.onActivation != null) cx.onActivation!(a);
            }
          }
        }
        pc++; continue;
      }
      if (op is BodySetConstArg) {
        final wid = cx.env.w(op.slot);
        if (cx.inBody && wid != null) {
          cx.rt.heap.bindWriterConst(wid, op.value);
          final w = cx.rt.heap.writer(wid);
          if (w != null) {
            final acts = cx.rt.roq.processOnBind(w.readerId);
            for (final a in acts) {
              cx.rt.gq.enqueue(a);
              if (cx.onActivation != null) cx.onActivation!(a);
            }
          }
        }
        pc++; continue;
      }

      // Fairness
      if (op is TailStep) {
        final shouldYield = cx.rt.tailReduce(cx.goalId);
        if (shouldYield) {
          cx.rt.gq.enqueue(GoalRef(cx.goalId, cx.kappa));
          return RunResult.yielded;
        } else {
          pc = prog.labels[op.label]!;
          continue;
        }
      }

      if (op is Proceed) {
        // Complete current procedure - terminate execution
        return RunResult.terminated;
      }

      pc++; // default progress
    }
    return RunResult.terminated;
  }

  /// Helper to get argument info from call environment
  _ArgInfo? _getArg(RunnerContext cx, int slot) {
    final wid = cx.env.w(slot);
    if (wid != null) return _ArgInfo(writerId: wid);

    final rid = cx.env.r(slot);
    if (rid != null) return _ArgInfo(readerId: rid);

    // TODO: Handle ground terms
    return null;
  }
}

/// Helper class to represent argument information
class _ArgInfo {
  final int? writerId;
  final int? readerId;

  _ArgInfo({this.writerId, this.readerId});

  bool get isWriter => writerId != null;
  bool get isReader => readerId != null;
}

/// Tentative structure during HEAD phase (before commit)
class _TentativeStruct {
  final String functor;
  final int arity;
  final List<Object?> args;

  _TentativeStruct(this.functor, this.arity, this.args);

  @override
  String toString() => '$functor/${arity}(${args.join(", ")})';
}

/// Helper to represent clause variables (before actual binding)
class _ClauseVar {
  final int varIndex;
  final bool isWriter;

  _ClauseVar(this.varIndex, {required this.isWriter});

  @override
  String toString() => isWriter ? 'W$varIndex' : 'R$varIndex';
}

/// Helper to represent list structures
class _ListStruct {
  final Object? head;
  final Object? tail;

  _ListStruct(this.head, this.tail);

  @override
  String toString() => '[$head|$tail]';
}
