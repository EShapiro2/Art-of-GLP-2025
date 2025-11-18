# GLP Bug Report: Variable Binding Issue in reduce/2

**Date**: 2025-11-18
**Commit**: 7371d7b (test: Minimal test case for reduce/2 variable binding bug)

## Problem

Variables not binding correctly in the `reduce/2` predicate.

**Test File**: `/Users/udi/GLP/udi/glp/cx.glp`
```prolog
reduce(partition ([X | Xs], A, Smaller?, [X? | Larger?]),
       partition (Xs?, A?, Smaller, Larger)) :-
	A? < X? | true.
```

**Query**: `reduce(partition([2,3],1,X14,X15), X21).`

**Expected Result**:
- `X14 = []` (empty list)
- `X15 = [2, 3]` (list with two elements)
- `X21 = partition([3]?, 1?, Smaller, Larger)` (body term)

**Actual Result**:
```
X14 = <unbound>
X15 = [2 | X8?]
X21 = partition(R1009?,R1010?,W1006,W1008)
```

## Semantic Analysis

### Clause Structure

The `reduce/2` clause has TWO structures in its head:
1. **First arg** (pattern): `partition([X|Xs], A, Smaller?, [X?|Larger?])`
2. **Second arg** (body): `partition(Xs?, A?, Smaller, Larger)`

### Query Matching

When querying `reduce(partition([2,3],1,X14,X15), X21)`:

**First argument unification** - `partition([X|Xs], A, Smaller?, [X?|Larger?])` with `partition([2,3],1,X14,X15)`:
- Arg 1: `[X|Xs]` matches `[2,3]` → X=2, Xs=[3]
- Arg 2: `A` matches `1` → A=1
- Arg 3: `Smaller?` matches `X14` (unbound writer)
- Arg 4: `[X?|Larger?]` matches `X15` (unbound writer)

**For Arg 3**: `Smaller?` (reader) matching `X14` (unbound writer):
- Should bind `X14` to fresh reader variable (mode conversion)
- Expected: Create fresh var V, bind X14=V?, leave V unbound initially

**For Arg 4**: `[X?|Larger?]` matching `X15` (unbound writer):
- Should build list structure and bind to X15
- Head: `X?` is reader of X (bound to 2) → should resolve to 2
- Tail: `Larger?` is reader of Larger (unbound) → should be fresh reader
- Expected: X15 = [2 | Larger?] where Larger is fresh variable

### Variable Name Sharing Issue

In the clause:
- `Smaller?` (reader, arg 3 of first partition)
- `Smaller` (writer, arg 3 of second partition)

Both have base name "Smaller", so compiler assigns same varIndex (e.g., X3).

**Question**: When UnifyReader processes `Smaller?` and stores something at `clauseVars[3]`, then UnifyWriter processes `Smaller` at the same `clauseVars[3]`, should it:
1. **Reuse the value** (they're the same variable, different modes) - current spec interpretation
2. **Create fresh variable** (they're different logical variables that happen to share an index)

## Bytecode Inspection Needed

Please analyze:
1. What bytecode is generated for this clause?
2. What does `clauseVars[3]` contain after UnifyReader processes `Smaller?`?
3. What should UnifyWriter do when it finds that value?

## Runtime Code Location

File: `/Users/udi/GLP/glp_runtime/lib/bytecode/runner.dart`

**UnifyWriter handler** (lines ~1555-1603):
```dart
if (value is VarRef) {
  // Subsequent use: extract varId, create writer VarRef (per spec 8.1)
  struct.args[cx.S] = VarRef(value.varId, isReader: false);
}
```

Currently, if `clauseVars[3]` contains a VarRef from the reader, UnifyWriter extracts the varId and creates a writer VarRef with the same varId.

## Spec References

**Bytecode Spec v2.16** (`/Users/udi/GLP/docs/glp-bytecode-v216-complete.md`):
- Section 8.1 (writer Xi): Lines 395-401
- Section 8.2 (reader Xi): Lines 405-423
- Section 12 (mode-aware loading): Lines 802-1157

**Key Question**: Is the current behavior (reusing varId across reader/writer at same index) correct per spec, or should fresh variables be created?

## Test Execution

```bash
cd /Users/udi/GLP/udi
echo -e "cx.glp\nreduce(partition([2,3],1,X14,X15), X21)." | ./glp_repl
```

## Additional Context

- This is NOT specific to metainterpreters - `reduce/2` is just a regular predicate
- SRSW constraint: Each variable occurs at most once as writer, once as reader per clause
- Variables with same base name (e.g., "Smaller" and "Smaller?") share varIndex
- Current implementation: Single-ID variable system (varId, not separate writer/reader IDs)
