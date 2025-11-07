import 'package:glp_runtime/compiler/compiler.dart';

void main() {
  final compiler = GlpCompiler();
  final result = compiler.compileWithMetadata('merge([1,2,3], [a,b], Xs).');

  print('Variable map: ${result.variableMap}');
  print('');
  print('Bytecode:');
  for (int i = 0; i < result.program.ops.length; i++) {
    print('  $i: ${result.program.ops[i]}');
  }
}
