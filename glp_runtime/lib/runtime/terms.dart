abstract class Term {}

class ConstTerm implements Term {
  final Object? value;
  ConstTerm(this.value);
  @override
  String toString() => 'Const($value)';
}

class StructTerm implements Term {
  final String functor;
  final List<Term> args;
  StructTerm(this.functor, this.args);
  @override
  String toString() => '$functor(${args.join(",")})';
}

/// Unified variable reference (single-ID system)
/// Replaces the old two-ID WriterTerm/ReaderTerm system
///
/// In the single-ID system:
/// - Each variable has ONE ID (varId)
/// - isReader flag indicates access mode:
///   - false (writer): Can bind the variable
///   - true (reader): Can read or suspend on the variable
class VarRef implements Term {
  final int varId;
  final bool isReader;

  VarRef(this.varId, {required this.isReader});

  @override
  String toString() => isReader ? 'R$varId?' : 'W$varId';

  @override
  bool operator ==(Object other) =>
      other is VarRef &&
      other.varId == varId &&
      other.isReader == isReader;

  @override
  int get hashCode => Object.hash(varId, isReader);
}

/// DEPRECATED: Old two-ID system - being migrated to VarRef
/// Reader reference in a structure - just holds the reader ID
/// The actual value is obtained by dereferencing through the heap
@Deprecated('Use VarRef(varId, isReader: true) instead')
class ReaderTerm implements Term {
  final int readerId;
  ReaderTerm(this.readerId);
  @override
  String toString() => 'R$readerId';
}

/// DEPRECATED: Old two-ID system - being migrated to VarRef
/// Writer reference in a structure - just holds the writer ID
/// Used when a structure contains an unbound writer variable
@Deprecated('Use VarRef(varId, isReader: false) instead')
class WriterTerm implements Term {
  final int writerId;
  WriterTerm(this.writerId);
  @override
  String toString() => 'W$writerId';
}
