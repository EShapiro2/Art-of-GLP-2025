/// GLP REPL (Read-Eval-Print Loop) for udi workspace
///
/// Interactive GLP interpreter with file loading support
/// Run from /Users/udi/GLP/udi with: dart run glp_repl.dart
library;

import 'dart:io';
import 'package:glp_runtime/compiler/compiler.dart';
import 'package:glp_runtime/bytecode/runner.dart';
import 'package:glp_runtime/bytecode/opcodes.dart';
import 'package:glp_runtime/runtime/runtime.dart';
import 'package:glp_runtime/runtime/machine_state.dart';
import 'package:glp_runtime/runtime/scheduler.dart';
import 'package:glp_runtime/runtime/system_predicates_impl.dart';

void main() {
  print('╔════════════════════════════════════════╗');
  print('║   GLP REPL - Interactive Interpreter   ║');
  print('╚════════════════════════════════════════╝');
  print('');
  print('Working directory: udi/');
  print('Source files: glp/*.glp');
  print('Compiled files: bin/*.glpc');
  print('');
  print('Input: filename.glp to load, or goal. to execute');
  print('Commands: :quit, :help');
  print('');

  final compiler = GlpCompiler();
  final rt = GlpRuntime();
  registerStandardPredicates(rt.systemPredicates);

  // Track loaded programs
  final loadedPrograms = <String, BytecodeProgram>{};

  var goalId = 1;

  while (true) {
    stdout.write('GLP> ');
    final input = stdin.readLineSync();

    if (input == null) {
      break;
    }

    if (input.trim().isEmpty) {
      continue;
    }

    final trimmed = input.trim();

    // Handle commands
    if (trimmed == ':quit' || trimmed == ':q') {
      print('Goodbye!');
      break;
    }

    if (trimmed == ':help' || trimmed == ':h') {
      printHelp();
      continue;
    }

    // Check if input is a .glp file to load
    if (trimmed.endsWith('.glp') && !trimmed.contains(' ')) {
      final filename = trimmed;
      if (!loadProgram(filename, compiler, loadedPrograms)) {
        continue;
      }
      print('✓ Loaded: $filename');
      continue;
    }

    // Compile and run the goal
    try {
      // Compile the input as a goal with metadata
      final goalResult = compiler.compileWithMetadata(trimmed);
      final goalProgram = goalResult.program;
      final variableMap = goalResult.variableMap;

      // Combine loaded programs with the goal
      final allOps = <Op>[];

      // Add all loaded programs first
      for (final loaded in loadedPrograms.values) {
        allOps.addAll(loaded.ops);
      }

      // Add the goal program
      allOps.addAll(goalProgram.ops);

      // Create combined program
      final combinedProgram = BytecodeProgram(allOps);

      // Create a scheduler with the combined program
      final runner = BytecodeRunner(combinedProgram);
      final scheduler = Scheduler(rt: rt, runners: {'main': runner});

      // Set up initial goal
      final env = CallEnv();
      rt.setGoalEnv(goalId, env);
      rt.setGoalProgram(goalId, 'main');

      // Enqueue the goal at PC 0
      rt.gq.enqueue(GoalRef(goalId, 0));
      final currentGoalId = goalId;
      goalId++;

      // Run scheduler
      final ran = scheduler.drain(maxCycles: 10000);

      // Report result
      print('→ Executed ${ran.length} goals');

      // Show any new bindings created during execution
      final finalEnv = rt.getGoalEnv(currentGoalId);
      if (finalEnv != null && variableMap.isNotEmpty) {
        _displayBindings(rt, finalEnv, variableMap);
      }

    } catch (e) {
      print('Error: $e');
    }

    print('');
  }
}

bool loadProgram(String filename, GlpCompiler compiler, Map<String, BytecodeProgram> loadedPrograms) {
  try {
    // Try to load source file from glp/
    final sourceFile = File('glp/$filename');

    if (!sourceFile.existsSync()) {
      print('Error: File not found: glp/$filename');
      return false;
    }

    final source = sourceFile.readAsStringSync();
    final program = compiler.compile(source);

    loadedPrograms[filename] = program;
    return true;
  } catch (e) {
    print('Error loading $filename: $e');
    return false;
  }
}


void printHelp() {
  print('');
  print('GLP REPL Usage:');
  print('  filename.glp           Load and compile glp/<filename>');
  print('  goal.                  Execute a goal (must end with .)');
  print('  :help, :h              Show this help');
  print('  :quit, :q              Exit REPL');
  print('');
  print('File Organization:');
  print('  glp/           GLP source files (.glp)');
  print('  bin/           Compiled bytecode files (.glpc)');
  print('');
  print('Examples:');
  print('  GLP> hello.glp                        # Load program');
  print('  GLP> hello.                           # Execute goal');
  print("  GLP> execute('write', ['Hello']).");
  print('  GLP> merge([1,2,3], [a,b], Xs).');
  print('');
}

void _displayBindings(GlpRuntime rt, CallEnv env, Map<String, int> variableMap) {
  // Display bindings for all variables in the query
  print('');

  for (final entry in variableMap.entries) {
    final varName = entry.key;
    final registerIndex = entry.value;

    // Check both writerBySlot and readerBySlot
    int? writerId;

    if (env.writerBySlot.containsKey(registerIndex)) {
      writerId = env.writerBySlot[registerIndex]!;
    } else if (env.readerBySlot.containsKey(registerIndex)) {
      // This is a reader - we need to find its paired writer
      // For now, search through all writers to find the one bound to a value
      // that corresponds to this variable
      //
      // Fallback: just show that the variable is present but untrackable
      print('  $varName = <unable to track reader variable>');
      continue;
    } else {
      print('  $varName = <not found in environment>');
      continue;
    }

    // Check if this writer is bound
    if (rt.heap.writerValue.containsKey(writerId)) {
      final value = rt.heap.writerValue[writerId];
      print('  $varName = ${_formatTerm(value)}');
    } else {
      print('  $varName = <unbound>');
    }
  }
}

String _formatTerm(Object? term) {
  if (term == null) return '[]';

  // Use the term's built-in toString()
  // This will properly format ConstTerm, WriterTerm, ReaderTerm, StructTerm, etc.
  return term.toString();
}
