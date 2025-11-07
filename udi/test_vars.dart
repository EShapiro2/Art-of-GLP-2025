import 'package:glp_runtime/compiler/compiler.dart';
import 'package:glp_runtime/compiler/analyzer.dart';

void main() {
  final compiler = GlpCompiler();
  final source = "merge([a], [b], X).";
  
  final program = compiler.compile(source);
  
  print('Compiled goal: $source');
  print('Instructions: ${program.ops.length}');
  
  // Try to access variable table
  print('\nChecking for variable tracking...');
}
