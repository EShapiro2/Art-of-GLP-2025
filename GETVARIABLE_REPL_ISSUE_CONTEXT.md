# GetVariable/REPL Issue - Context for Claude Web

**Date**: November 14, 2025
**Issue**: REPL shows `X = <unbound>` for all queries after VarRef changes
**Test Suite**: 85/87 passing (runtime works correctly)

## Problem Statement

After implementing VarRef changes to fix guard dereferencing, the REPL stopped displaying variable bindings correctly. All queries show variables as `<unbound>` even though the runtime is binding them correctly (proven by passing tests).

## What Changed

### Guard Dereferencing Fix (Working)

**Problem**: Guards were comparing variable IDs instead of values:
- Guard saw `1000 < 2` instead of `1 < 2`
- Insertion sort failed because guards couldn't extract actual values

**Solution**: Changed clauseVars to store VarRef objects instead of bare IDs:
```dart
// BEFORE (guards broken):
cx.clauseVars[op.varIndex] = arg.writerId;  // Bare int

// AFTER (guards working):
cx.clauseVars[op.varIndex] = VarRef(arg.writerId!, isReader: false);
```

**Result**: Guards now properly dereference values. Test suite improved from 84 to 85 passing.

### REPL Broken (Side Effect)

**Symptom**: REPL shows `X = <unbound>` for queries like `merge([],[a],X).`

**Expected**: REPL should show `X = [a]`

**Evidence that runtime works**:
- 85/87 tests pass
- Tests verify variable bindings directly via runtime IDs
- Only REPL display is broken

## Code Flow Analysis

### 1. REPL Setup (glp_repl.dart lines 313-331)

```dart
// REPL creates variable and tracks it
final (writerId, readerId) = runtime.heap.allocateFreshPair();
// In single-ID: writerId == readerId (e.g., both = 1000)

runtime.heap.addWriter(WriterCell(writerId, readerId));
runtime.heap.addReader(ReaderCell(readerId));

// Track for display
queryVarWriters['X'] = writerId;  // Store 1000

// Set up CallEnv
final env = CallEnv(readers: readers, writers: writers);
// writers: {2: 1000} (argSlot 2 → writerId 1000)
```

### 2. GetVariable Execution (runner.dart lines 684-707)

```dart
if (op is GetVariable) {
  // get_variable X0, A2
  final arg = _getArg(cx, op.argSlot);
  // Returns: _ArgInfo(writerId: 1000)

  // NOW STORES VarRef:
  if (arg.isWriter) {
    cx.clauseVars[op.varIndex] = VarRef(arg.writerId!, isReader: false);
    // clauseVars[0] = VarRef(1000, isReader: false)
  }
}
```

### 3. HEAD Phase Binding

HEAD instructions read from clauseVars and build σ̂w (sigma-hat).

**Question**: Do HEAD instructions properly extract varId from VarRef when building σ̂w?

**Example from HeadNil** (lines 2506-2527):
```dart
} else if (clauseVarValue is VarRef) {
  final varId = clauseVarValue.varId;  // Extracts ID ✓
  if (cx.rt.heap.isBound(varId)) {
    // ...
  } else {
    cx.sigmaHat[varId] = ConstTerm('nil');  // Uses varId as key ✓
  }
}
```

This shows HeadNil **correctly** unwraps VarRef. But need to verify ALL HEAD instructions.

### 4. Commit Phase (runner.dart lines 1246-1371)

```dart
if (op is Commit) {
  // Convert tentative structures
  final convertedSigmaHat = <int, Object?>{};
  for (final entry in cx.sigmaHat.entries) {
    final writerId = entry.key;  // Should be bare int (1000)
    final value = entry.value;   // Should be ConstTerm('a')
    convertedSigmaHat[writerId] = value;
  }

  // Apply σ̂w to heap
  final acts = CommitOps.applySigmaHatV216(
    heap: cx.rt.heap,
    roq: cx.rt.roq,
    sigmaHat: convertedSigmaHat,
  );
}
```

**Question**: What are the actual keys in σ̂w? Bare ints or VarRef objects?

### 5. Heap Binding (commit.dart lines 29-37)

```dart
if (value is ConstTerm) {
  heap.bindWriterConst(writerId, value.value);
  // Calls: heap.bindVariableConst(writerId, v)
  // Which calls: heap.bindVariable(writerId, ConstTerm(v))
}
```

This sets `_vars[1000].value = ConstTerm('a')`.

### 6. REPL Check (glp_repl.dart lines 214-230)

```dart
for (final entry in queryVarWriters.entries) {
  final varName = entry.key;   // 'X'
  final writerId = entry.value; // 1000

  // Single-ID API:
  if (rt.heap.isBound(writerId)) {
    final value = rt.heap.getValue(writerId);
    print('  $varName = ${_formatTerm(value, rt)}');
  } else {
    print('  $varName = <unbound>');  // THIS IS PRINTED
  }
}
```

**Question**: Why does `isBound(1000)` return false?

## Heap Implementation (heap.dart)

```dart
// Single-ID heap
final Map<int, VariableCell> _vars = {};

bool isBound(int varId) {
  return _vars[varId]?.value != null;
}

Term? getValue(int varId) {
  return _vars[varId]?.value;
}

void bindVariable(int varId, Term value) {
  final cell = _vars[varId];
  if (cell != null && cell.value == null) {
    cell.value = value;
    _processROQ(varId);
  }
}
```

**Critical checks**:
1. Does `_vars[1000]` exist? (Was `addVariable(1000)` called?)
2. Is `_vars[1000].value` set to ConstTerm('a')?
3. Is REPL checking the right ID (1000)?

## Claude Web's Hypothesis

"The code doesn't unwrap VarRef properly when binding, causing the REPL's original writer to never get bound."

**Specific claim**: Some HEAD instruction uses VarRef as a σ̂w key instead of extracting varId first.

**If true**: σ̂w would contain `{VarRef(1000): ConstTerm('a')}` instead of `{1000: ConstTerm('a')}`, causing commit to bind a VarRef object instead of variable 1000.

## Proposed Fix

Revert GetVariable to store bare IDs:
```dart
if (arg.isWriter) {
  cx.clauseVars[op.varIndex] = arg.writerId!;  // Bare int
} else if (arg.isReader) {
  cx.clauseVars[op.varIndex] = arg.readerId!;  // Bare int
}
```

**Rationale**: Guards already check for VarRef first, then int. Storing bare ints would restore REPL while keeping guards working.

**Concern**: This treats the symptom, not the cause. If HEAD instructions don't handle VarRef, they should be fixed, not GetVariable reverted.

## Questions for Claude Web

### Question 1: HEAD Instruction Audit

Do ALL HEAD instructions properly unwrap VarRef when building σ̂w?

**Need to check**:
- HeadConstant (line 313+)
- HeadStructure (line 380+)
- HeadList (line 2620+)
- HeadWriter
- HeadReader
- GetValue (line 709+)

**What to look for**:
```dart
// WRONG: Uses VarRef as σ̂w key
cx.sigmaHat[clauseVarValue] = ConstTerm('a');

// CORRECT: Extracts varId first
if (clauseVarValue is VarRef) {
  cx.sigmaHat[clauseVarValue.varId] = ConstTerm('a');
}
```

### Question 2: Root Cause

Is the issue:
1. HEAD instructions not unwrapping VarRef (fix HEAD instructions)
2. Commit not handling VarRef keys (fix commit)
3. REPL checking wrong ID (fix REPL)
4. Heap cell not created (fix REPL setup)

### Question 3: Proper Fix

Should we:
1. **Revert GetVariable** - Store bare IDs (quick fix, may hide bugs)
2. **Fix HEAD instructions** - Make them all handle VarRef properly (correct fix)
3. **Hybrid approach** - Something else?

## Files Affected

**Core Runtime**:
- `glp_runtime/lib/bytecode/runner.dart` - GetVariable handler (lines 684-707)
- `glp_runtime/lib/runtime/heap.dart` - Single-ID heap implementation
- `glp_runtime/lib/runtime/commit.dart` - Commit operation

**REPL**:
- `udi/glp_repl.dart` - Variable tracking and display (lines 213-230, 298-335)

**Tests**:
- All 85 passing tests verify runtime works correctly
- REPL is the only thing broken

## Package Contents

This package includes:
- `CLAUDE.md` - Project guide
- `docs/` - All specifications
- `glp_runtime/lib/` - Complete runtime source
- This context document

## Next Steps

1. **Audit HEAD instructions** - Check if they all unwrap VarRef
2. **Trace actual σ̂w keys** - Add logging to see what's actually stored
3. **Verify REPL IDs** - Check if queryVarWriters has correct IDs
4. **Decide on fix** - Revert GetVariable vs fix HEAD instructions

## References

- **Single-ID Migration**: `docs/single-id-migration.md`
- **Runtime Spec**: `docs/glp-runtime-spec.txt`
- **Bytecode Spec**: `docs/glp-bytecode-v216-complete.md`
- **GetVariable Spec**: Section 12.1 in bytecode spec
