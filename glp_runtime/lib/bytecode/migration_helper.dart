/// Temporary helpers during Phase 2 single-ID migration
/// Will be deleted after migration complete
library;

import '../runtime/terms.dart';

class MigrationHelper {
  /// Convert old term types to VarRef
  static Term toVarRef(Term t) {
    if (t is WriterTerm) return VarRef(t.writerId, isReader: false);
    if (t is ReaderTerm) return VarRef(t.readerId, isReader: true);
    if (t is VarRef) return t; // Already converted
    return t;
  }

  /// Convert VarRef back to old types (for compatibility during migration)
  static Term fromVarRef(Term t) {
    if (t is VarRef) {
      return t.isReader
        ? ReaderTerm(t.varId)
        : WriterTerm(t.varId);
    }
    return t;
  }

  /// Check if term is any variable type
  static bool isVariable(Term t) {
    return t is VarRef || t is WriterTerm || t is ReaderTerm;
  }

  /// Check if term is a writer (any type)
  static bool isWriter(Object? t) {
    if (t is WriterTerm) return true;
    if (t is VarRef && !t.isReader) return true;
    return false;
  }

  /// Check if term is a reader (any type)
  static bool isReader(Object? t) {
    if (t is ReaderTerm) return true;
    if (t is VarRef && t.isReader) return true;
    return false;
  }

  /// Get variable ID from any variable type
  static int? getVarId(Object? t) {
    if (t is WriterTerm) return t.writerId;
    if (t is ReaderTerm) return t.readerId;
    if (t is VarRef) return t.varId;
    return null;
  }
}
