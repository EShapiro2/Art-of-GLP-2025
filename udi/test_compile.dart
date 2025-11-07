import 'package:glp_runtime/compiler/compiler.dart';

void main() {
  final compiler = GlpCompiler();
  final source = """
hello :-
  execute('write', ['Hello from GLP!']),
  execute('nl', []).
""";
  
  final program = compiler.compile(source);
  
  print('Generated ${program.ops.length} instructions:');
  for (var i = 0; i < program.ops.length; i++) {
    print('  [$i] ${program.ops[i]}');
  }
}
