# GLP Runtime Status Report
**Date**: November 12, 2025  
**Prepared by**: Claude Code  
**For**: Claude Web (Architecture & Code Generation)

---

## Executive Summary

The GLP runtime has **136/169 tests passing (80.5%)** after the single-ID variable migration. The core system is working well, but there are **33 failing tests** primarily due to:
1. Incomplete API migration (4 tests - quick fix)
2. Goal reactivation bug (2 tests - critical)
3. Compiler integration issues (5 tests)
4. Edge case failures (22 tests)

**Known good baseline**: Commit 7be7d83 had ~170 tests passing.

---

## Current Status

### Repository State
- **Branch**: main
- **Latest Commit**: 36349ed (fix: Add CLAUSE_NEXT to metainterp_conj_test)
- **Uncommitted Changes**:
  - Modified: `test/custom/metainterp_merge_test.dart` (API migration needed)
  - Modified: `CLAUDE.md` (documentation updates)

### Test Results Breakdown

| Category | Passing | Total | Rate |
|----------|---------|-------|------|
| Linter Tests | 3 | 3 | 100% |
| Smoke Tests | 3 | 3 | 100% |
| Bytecode Instructions | 48 | 50 | 96% |
| Conformance Tests | 8 | 8 | 100% |
| System Predicates | 22 | 22 | 100% |
| Custom Tests | 40 | 60 | 67% |
| Refactoring Tests | 12 | 15 | 80% |
| Compiler Tests | 0 | 5 | 0% |
| **TOTAL** | **136** | **169** | **80.5%** |

---

## What's Working Well ✅

### Core Runtime Components
1. **Single-ID Variable System** (VarRef with isReader flag)
   - Migration from WriterTerm/ReaderTerm complete
   - Heap operations simplified
   - FCP-aligned design

2. **Three-Phase Execution** (HEAD/GUARDS/BODY)
   - σ̂w tentative writer substitution
   - Si/U suspension accumulation
   - Commit applies σ̂w atomically

3. **Instruction Set** (v2.16)
   - All control flow instructions (ClauseTry, ClauseNext, Commit, NoMoreClauses)
   - All guard instructions (ground, known, otherwise)
   - All list operations (HeadNil, HeadList, PutNil, PutList)
   - All structure operations (HeadStructure, PutStructure, unify_*, set_*)
   - Environment frames (allocate, deallocate, nesting)

4. **Scheduler**
   - FIFO ordering working correctly
   - Tail recursion budget (26 steps) functional
   - Multi-goal execution

5. **System Predicates** (All 22 implemented)
   - Arithmetic: evaluate/2
   - Utilities: current_time/1, unique_id/1, variable_name/2, copy_term/2
   - File I/O: file_read/2, file_write/2, file_open/3, etc.
   - Terminal: write/1, nl/0, read/1
   - Modules: link/2, load_module/2
   - Channels: distribute_stream/2, copy_term_multi/3

---

## Critical Issues Requiring Attention ❌

### 1. Goal Reactivation Bug (HIGH PRIORITY)

**Affected Tests**: 2
- `test/bytecode/union_end_to_end_test.dart`: Commit applies σ̂w
- `test/bytecode/asm_smoke_test.dart`: Commit wakes readers

**Symptom**:
```dart
Expected: [3000, 4000]  // Goal IDs that should execute
Actual:   []            // No goals executed
```

**Analysis**:
When `commit` binds writers in σ̂w, the paired readers should bind and trigger reactivation of suspended goals. Goals are being suspended correctly (ROQ has suspension notes), but they're not being reactivated when writers bind.

**Likely Root Cause**:
The ROQ processing in `CommitOps.applySigmaHat()` may not be:
1. Looking up the correct paired reader IDs, OR
2. Calling `roq.processOnBind()` for each bound writer's paired reader, OR
3. Enqueuing reactivated goals to the GQ (goal queue)

**Investigation Needed**:
1. Check `lib/runtime/commit.dart` - `CommitOps.applySigmaHat()`
2. Verify `roq.processOnBind(readerId)` is called for each writer in σ̂w
3. Verify `heap.getReaderIdForWriter(writerId)` returns correct reader ID
4. Check that suspension notes have armed hangers
5. Verify reactivated goals are added to scheduler's goal queue

**Code Location**: `glp_runtime/lib/runtime/commit.dart`

---

### 2. Incomplete Single-ID API Migration (QUICK FIX)

**Affected Tests**: 4 tests fail to load

**Files Needing Updates**:

1. **test/custom/metainterp_merge_test.dart** (lines 219, 220, 237, 238, 249, 250, 264, 265)
   ```dart
   // OLD API (two-ID system)
   if (rt.heap.isVarBound(varId)) {
     final value = rt.heap.valueOfVar(varId);
   }
   
   // NEW API (single-ID system)
   if (rt.heap.isBound(varId)) {
     final value = rt.heap.getValue(varId);
   }
   ```

2. **test/custom/metainterp_circular_merge_test.dart** (lines 232, 250)
   ```dart
   // OLD: VarRef doesn't have readerId property
   final wid = rt.heap.writerIdForReader(head.readerId);
   
   // NEW: Use varId directly (single-ID system)
   final wid = rt.heap.writerIdForReader(head.varId);
   ```

3. **test/refactoring/heap_v2_integration_test.dart**
   - Missing file: `lib/runtime/heap_v2_adapter.dart`
   - **Recommendation**: DELETE this test file (obsolete)

4. **test/refactoring/heap_compatibility_test.dart**
   - Missing file: `lib/runtime/heap_v2.dart`
   - **Recommendation**: DELETE this test file (obsolete)

**Estimated Fix Time**: 15-20 minutes

---

### 3. Compiler Integration Issues (MEDIUM PRIORITY)

**Affected Tests**: 5 compiler tests fail

**Issues**:
1. **Type Mismatches** - Tests expect old instruction types:
   ```dart
   // Test expects:
   Expected: <Instance of 'PutReader'>
   // But gets v2 migrated instruction:
   Actual: PutVariable:<put_reader(X0, A0)>
   ```

2. **Suspension Note Creation**:
   ```dart
   Expected: true  // Should have suspension note
   Actual: <false>
   ```

**Files**:
- `test/compiler/integration_head_test.dart`
- `test/compiler/integration_body_test.dart`
- `test/compiler/verify_simple_body_test.dart`
- `test/compiler/compiler_test.dart`
- `test/compiler/compile_merge_test.dart`

**Investigation Needed**:
1. Update test expectations to accept both v1 and v2 instruction types
2. Debug why suspension notes aren't being created during compilation
3. Verify compiler produces correct bytecode for v2 instructions

**Code Locations**: 
- `glp_runtime/lib/compiler/` - Compiler source
- `glp_runtime/test/compiler/` - Failing tests

---

### 4. Custom Test Edge Cases (LOWER PRIORITY)

**Affected Tests**: 22 custom tests with various edge case failures

**Categories**:
- Complex metainterpreter scenarios
- Multi-program execution edge cases
- Circular dependency variations
- List handling edge cases
- Reader/writer binding edge cases

**Status**: These are less critical and can be addressed after fixing the core issues above.

---

## Architecture Overview (For Reference)

### Single-ID Variable System
```dart
// ONE variable ID, TWO access modes
final varId = 1000;

// Writer access (can bind)
final writer = VarRef(varId, isReader: false);

// Reader access (can read/suspend)
final reader = VarRef(varId, isReader: true);

// Heap operations use varId directly
heap.isBound(varId)
heap.getValue(varId)
heap.bindVariable(varId, term)
```

### Three-Phase Execution Model
```
For each clause Ci:
  1. clause_try Ci
     - Clear Si (clause-local suspension set)
     - Clear σ̂w (tentative writer substitution)
  
  2. HEAD Phase (tentative)
     - Build σ̂w without heap mutation
     - Add blocked readers to Si
     - May fail → try next clause
  
  3. GUARDS Phase (pure tests)
     - Execute guards without side effects
     - May add to Si or fail
  
  4. Decision:
     - If FAILED → clause_next: discard σ̂w, Si→U, next clause
     - If Si non-empty → clause_next: discard σ̂w, Si→U, next clause
     - If Si empty → commit: apply σ̂w, wake goals, enter BODY
  
  5. BODY Phase (after commit)
     - Heap mutations allowed
     - spawn/requeue for goal creation
     - proceed to complete

After all clauses:
  no_more_clauses:
    - If U non-empty → SUSPEND goal on U
    - If U empty → FAIL goal definitively
```

### ROQ (Read-Only Queue) Suspension/Reactivation
```dart
// Suspension (during no_more_clauses with U ≠ ∅)
for (final readerId in U) {
  roq.addSuspension(readerId, SuspensionNote(
    goalId: goalId,
    kappa: kappa,  // Entry PC to restart at
    hanger: Hanger(armed: true)  // Single-shot reactivation
  ));
}

// Reactivation (during commit when writer binds)
for (final (writerId, term) in sigmaHat.entries) {
  heap.bindVariable(writerId, term);
  final readerId = heap.getReaderIdForWriter(writerId);
  roq.processOnBind(readerId);  // Wake suspended goals
}

// processOnBind implementation
void processOnBind(int readerId) {
  final queue = _queues[readerId];
  if (queue == null) return;
  
  for (final note in queue) {
    if (note.hanger.armed) {
      note.hanger.armed = false;  // Single-shot
      gq.enqueue(GoalRef(note.goalId, note.kappa));
    }
  }
  queue.clear();
}
```

---

## Recommended Action Plan

### Phase 1: Quick Wins (30 minutes → +4 tests = 140 passing)

1. **Fix metainterp_merge_test.dart** (15 min)
   - Line 219, 237, 249, 264: `isVarBound(varId)` → `isBound(varId)`
   - Line 220, 238, 250, 265: `valueOfVar(varId)` → `getValue(varId)`

2. **Fix metainterp_circular_merge_test.dart** (5 min)
   - Line 232, 250: `head.readerId` → `head.varId`

3. **Delete obsolete heap tests** (5 min)
   - Delete `test/refactoring/heap_v2_integration_test.dart`
   - Delete `test/refactoring/heap_compatibility_test.dart`

### Phase 2: Critical Bug Fix (2-4 hours → +2 tests = 142 passing)

**Debug Goal Reactivation**:

1. Add debug logging to `CommitOps.applySigmaHat()`:
   ```dart
   print('>>> COMMIT: Binding ${sigmaHat.length} writers');
   for (final entry in sigmaHat.entries) {
     final writerId = entry.key;
     final readerId = heap.getReaderIdForWriter(writerId);
     print('>>> Writer $writerId → Reader $readerId');
     final hasNotes = roq.hasNotesFor(readerId);
     print('>>> Reader $readerId has suspension notes: $hasNotes');
   }
   ```

2. Check if `heap.getReaderIdForWriter()` returns correct ID in single-ID system
   - In single-ID: writerId == readerId, so should return writerId
   - Verify implementation

3. Verify `roq.processOnBind()` is called for each reader
   - Add logging to see if it's called
   - Check if suspension notes have armed hangers

4. Verify goals are enqueued to GQ (goal queue)
   - Check scheduler's goal queue after commit
   - Ensure reactivated goals appear in execution list

### Phase 3: Compiler Integration (4-8 hours → +5 tests = 147 passing)

1. Update compiler test expectations for v2 instructions
2. Debug suspension note creation during compilation
3. Verify bytecode generation for v2 instructions

### Phase 4: Edge Cases (variable time → +22 tests = 169 passing)

1. Fix remaining custom test edge cases
2. Multi-program execution debugging
3. Complex metainterpreter scenarios

---

## Questions for Claude Web

### Critical Decision Needed

**Goal Reactivation Bug**: Should I:
1. Provide detailed debug logs and wait for analysis?
2. Investigate the code myself and suggest a fix?
3. Create a minimal reproducible test case?

**Recommendation**: Option 1 - Let Claude Web analyze the ROQ/commit interaction architecture since this is a core runtime behavior.

### Clarifications Needed

1. **Heap API in Single-ID System**: 
   - Is `heap.getReaderIdForWriter(writerId)` supposed to return `writerId` (since writerId == readerId)?
   - Or should this method be removed entirely?

2. **Compiler Tests**: 
   - Should tests accept both v1 and v2 instruction types?
   - Or should we complete migration to v2 only?

3. **Obsolete Tests**:
   - Confirmed deletion of heap_v2_integration_test.dart and heap_compatibility_test.dart?

---

## Files for Review

### High Priority
1. `glp_runtime/lib/runtime/commit.dart` - Commit operation (reactivation bug)
2. `glp_runtime/lib/runtime/roq.dart` - ROQ suspension/reactivation
3. `glp_runtime/lib/runtime/heap.dart` - Single-ID heap API
4. `glp_runtime/test/custom/metainterp_merge_test.dart` - API migration needed
5. `glp_runtime/test/custom/metainterp_circular_merge_test.dart` - API migration needed

### Documentation
1. `glp_runtime/TEST_BASELINE.md` - Full test analysis (300+ lines)
2. `glp_runtime/BASELINE_SUMMARY.txt` - Quick reference
3. `CLAUDE.md` - Project guide and instructions

### Specs (For Reference)
1. `docs/SPEC_GUIDE.md` - Overview of GLP execution model
2. `docs/glp-bytecode-v216-complete.md` - Complete instruction set spec
3. `docs/glp-runtime-spec.txt` - Dart runtime architecture
4. `docs/single-id-migration.md` - Single-ID variable design

---

## Git Status

```
On branch main
Your branch is ahead of 'origin/main' by 147 commits.

Changes staged for commit:
  new file:   BASELINE_SUMMARY.txt
  new file:   TEST_BASELINE.md

Changes not staged for commit:
  modified:   ../CLAUDE.md
  modified:   test/custom/metainterp_merge_test.dart

Untracked files:
  ../docs/main_GLP_to_Dart (1).tex
  test_baseline_compact.txt
  test_baseline_output.txt
```

---

## Next Steps (Awaiting Direction)

Claude Code is ready to:
1. ✅ Execute quick fixes (+4 tests, 30 min)
2. ✅ Add debug logging for reactivation bug
3. ✅ Create minimal reproducible test cases
4. ⏳ Implement fixes (after architectural guidance from Claude Web)

**Awaiting**: Architectural guidance on reactivation bug and clarification on questions above.

---

## Contact & Coordination

- Claude Code handles: execution, testing, small fixes, git operations
- Claude Web handles: architecture decisions, code generation, debugging logic
- For this session: Ready to execute quick fixes and gather diagnostic data

**End of Status Report**
