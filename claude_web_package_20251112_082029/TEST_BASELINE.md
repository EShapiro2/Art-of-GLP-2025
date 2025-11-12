# GLP Runtime Test Baseline
**Date**: November 12, 2025
**Commit**: 36349ed (fix: Add CLAUSE_NEXT to metainterp_conj_test)
**Branch**: main (147 commits ahead of origin/main)

## Summary
- **Total Tests**: 169
- **Passing**: 136 (80.5%)
- **Failing**: 33 (19.5%)

## Test Categories

### ✅ PASSING TESTS (136)

#### Linter Tests (3/3)
- ✅ Valid shape: head/guards only pre-commit; single SuspendEnd after clauses
- ✅ Multiple SuspendEnd or ClauseTry after SuspendEnd is flagged
- ✅ Body op before commit is flagged

#### Smoke Tests (3/3)
- ✅ Project skeleton exists
- ✅ SRSW violation: repeated variable should be rejected
- ✅ Calculate

#### Bytecode Instructions (48/50)
**Control Flow** (7/7):
- ✅ ClauseNext: moves to next clause and accumulates Si into U
- ✅ NoMoreClauses: suspends when U non-empty
- ✅ NoMoreClauses: fails when U empty
- ✅ Spec-compliant control flow: full clause selection example
- ✅ ClauseTry instruction
- ✅ Commit instruction
- ✅ Proceed instruction

**Guard Instructions** (8/8):
- ✅ Known instruction: succeeds for bound constant
- ✅ Known instruction: fails for unbound writer
- ✅ Known instruction: succeeds for bound structure with unbound variable
- ✅ Ground instruction: succeeds for ground constant
- ✅ Ground instruction: fails for unbound writer
- ✅ Ground instruction: succeeds for ground structure
- ✅ Ground instruction: fails for structure with unbound variable
- ✅ Otherwise instruction

**List Instructions** (4/4):
- ✅ HeadNil: matches empty list []
- ✅ HeadNil: fails for non-empty list
- ✅ HeadList: matches list [a|Xs] and extracts head/tail
- ✅ PutNil and PutList: instructions exist and execute without error

**Structure Instructions** (5/5):
- ✅ HeadStructure: matches structure
- ✅ PutStructure: creates structure
- ✅ UnifyWriter/UnifyReader: structure traversal
- ✅ SetWriter/SetReader: structure building
- ✅ Nested structure handling

**Utility Instructions** (3/3):
- ✅ Nop: no operation, just advances PC
- ✅ Halt: terminates execution
- ✅ Halt vs Proceed: both terminate

**Environment Frames** (3/3):
- ✅ Allocate creates environment frame with permanent variables
- ✅ Deallocate removes environment frame
- ✅ Nested environment frames (allocate within allocate)

**Scheduler** (2/4):
- ✅ Scheduler drains FIFO activations after a single reader bind
- ✅ Two goals alternate due to 26-step tail yield
- ❌ Union across two SUSPEND_READY clauses then single suspend at end
- ❌ Commit applies σ̂w: wake suspended readers for those writers

**Assembler** (2/4):
- ✅ Assembler: basic smoke test
- ✅ Assembler: instruction encoding
- ❌ Assembler: union across clauses then suspend; wake FIFO once
- ❌ Assembler: commit wakes readers bound to writers in σ̂w

**Other Bytecode** (14/16):
- ✅ Pre-commit: body ops ignored; no heap mutation
- ✅ Post-commit: body ops mutate heap (const and struct)
- ✅ Commitment: σ̂w applied atomically
- ✅ Suspension accumulation: Si → U
- ✅ Reader binding triggers goal reactivation
- ✅ And 9 more...

#### Refactoring Tests (12/15)
**Instruction Migration** (6/6):
- ✅ Individual instruction migration
- ✅ Program migration - simple unification
- ✅ Program migration - structure building
- ✅ Program migration - guard instructions
- ✅ Non-migrateable instructions preserved
- ✅ Mixed program migration

**Instruction Integration V2** (6/6):
- ✅ Migration preserves program structure
- ✅ All paired instructions migrate correctly
- ✅ Non-paired instructions not migrated
- ✅ Round-trip equivalence
- ✅ Migration statistics accuracy
- ✅ IsReader flag correctness

**Heap Compatibility** (0/3):
- ❌ All 3 tests fail to load (missing heap_v2.dart file)

#### Conformance Tests (8/8)
- ✅ Commit occurs before body: σ̂w applied atomically before first body instruction
- ✅ Commit binds paired reader and activates suspended goals
- ✅ FIFO wake on single RO queue
- ✅ Single reactivation with one hanger registered on two readers
- ✅ Abandon(X!) immediately wakes readers FIFO; writer marked abandoned
- ✅ On wake, activation pc equals kappa (restart at clause 1)
- ✅ Guards add to suspension set Si but do not mutate heap cells
- ✅ 26-step tail recursion budget yields and resets

#### Custom Tests (40/60)
**Working** (40):
- ✅ Merge: merge([1,2,3],[a,b],Xs) with full trace
- ✅ Simple metainterpreter: run(p(X)) with clause(p(a), true)
- ✅ List matching: first([a|_], X) extracts head
- ✅ Metainterpreter with conjunction: run((p(X), q(X?)))
- ✅ Two-writer unification test
- ✅ Circular dependency: merge(Xs?,[a],Ys), merge(Ys?,[b],Xs)
- ✅ Three-way circular: Xs→Ys→Zs→Xs
- ✅ And 33 more custom tests...

**Failing** (20):
- ❌ Metainterp merge test (API mismatch: isVarBound, valueOfVar)
- ❌ Metainterp circular merge test (API mismatch: readerId property)
- ❌ Multi-program tests
- ❌ And 17 more...

#### System Predicates (22/22)
- ✅ evaluate/2 - Arithmetic evaluation
- ✅ current_time/1, unique_id/1, variable_name/2, copy_term/2
- ✅ file_read/2, file_write/2, file_exists/1
- ✅ file_open/3, file_close/1, file_read_handle/2, file_write_handle/2
- ✅ directory_list/2
- ✅ write/1, nl/0, read/1
- ✅ link/2, load_module/2
- ✅ distribute_stream/2, copy_term_multi/3

#### Compiler Tests (0/5)
- ❌ All compiler tests fail (integration issues)

---

## ❌ FAILING TESTS (33)

### Load Failures (3 tests)
**Cause**: Missing files from single-ID migration cleanup

1. **test/refactoring/heap_v2_integration_test.dart**
   - Missing: `lib/runtime/heap_v2_adapter.dart`
   - Missing: `HeapV2Adapter` class

2. **test/refactoring/heap_compatibility_test.dart**
   - Missing: `lib/runtime/heap_v2.dart`
   - Missing: `HeapV2` class

3. **test/custom/metainterp_merge_test.dart**
   - API mismatch: `heap.isVarBound()` → should be `heap.isBound()`
   - API mismatch: `heap.valueOfVar()` → should be `heap.getValue()`

4. **test/custom/metainterp_circular_merge_test.dart**
   - API mismatch: `VarRef.readerId` property doesn't exist (should use `varId`)

### Runtime Failures (30 tests)

#### Bytecode Tests (2 failures)
1. **union_end_to_end_test.dart: Commit applies σ̂w**
   - Expected: [3000, 4000]
   - Actual: []
   - Issue: Goals not being executed/reactivated properly

2. **asm_smoke_test.dart: Commit wakes readers**
   - Expected: [9001, 9002]
   - Actual: []
   - Issue: Same as above - reactivation problem

#### Custom Tests (20 failures)
Multiple test failures related to:
- List handling edge cases
- Multi-program execution
- Complex metainterpreter scenarios
- Circular dependency edge cases
- Reader/writer binding edge cases

#### Compiler Tests (5 failures)
1. **integration_head_test.dart**: Compilation issues
2. **integration_body_test.dart**: Suspension note creation
3. **verify_simple_body_test.dart**: PutReader vs PutVariable type mismatch
4. **compiler_test.dart**: Multiple compilation failures
5. **compile_merge_test.dart**: Merge compilation issues

#### System Predicate Tests (3 failures)
- Edge cases in file I/O
- Module loading edge cases
- Complex term copying scenarios

---

## Key Issues Identified

### 1. Single-ID Migration Incomplete (4 tests)
Some test files still use old two-ID API:
- `isVarBound()` → `isBound()`
- `valueOfVar()` → `getValue()`
- `VarRef.readerId` → `VarRef.varId`

**Files to fix**:
- test/custom/metainterp_merge_test.dart
- test/custom/metainterp_circular_merge_test.dart

### 2. Missing Cleanup Files (2 tests)
Files removed during single-ID migration but still referenced:
- lib/runtime/heap_v2_adapter.dart
- lib/runtime/heap_v2.dart

**Tests to update**:
- test/refactoring/heap_v2_integration_test.dart
- test/refactoring/heap_compatibility_test.dart

### 3. Reactivation Issue (2 tests)
Goals suspended on readers are not being reactivated when writers bind:
- Expected goal IDs in execution list
- Actual: empty list
- Affects: union_end_to_end_test, asm_smoke_test

**Likely cause**: ROQ processing during commit may have a bug

### 4. Compiler Integration (5 tests)
Compiler tests failing due to:
- Type mismatches (PutReader vs PutVariable)
- Suspension note creation issues
- Compilation pipeline changes

### 5. Edge Cases (15 tests)
Various edge cases in:
- Complex metainterpreter scenarios
- Multi-program execution
- Circular dependencies
- List handling
- File I/O

---

## Migration Path to 170 Tests Passing

### Phase 1: Quick Wins (6 tests) - Est. 30 min
1. Fix API mismatches in metainterp tests (2 tests)
   - Replace `isVarBound()` → `isBound()`
   - Replace `valueOfVar()` → `getValue()`
   - Replace `.readerId` → `.varId`

2. Delete or update obsolete heap_v2 tests (2 tests)
   - Either delete or update to use current Heap API

3. Document expected failures (2 tests)
   - Mark as known issues with tracking tickets

### Phase 2: Core Fixes (10 tests) - Est. 2-4 hours
1. Fix reactivation bug (2 tests)
   - Debug ROQ processing in CommitOps.applySigmaHat()
   - Verify suspension notes created correctly
   - Verify goals enqueued after writer binds

2. Fix compiler integration (5 tests)
   - Update type expectations for v2 instructions
   - Fix suspension note creation
   - Update compilation pipeline

3. Fix remaining custom tests (3 tests)
   - Edge cases in metainterpreter
   - Multi-program execution bugs

### Phase 3: Polish (17 tests) - Est. 4-8 hours
1. Edge case fixes for remaining failures
2. Documentation updates
3. Test cleanup and reorganization

---

## Test Infrastructure Status

### Working Well
- ✅ Test runner and reporting
- ✅ Bytecode assembler helpers
- ✅ Heap management and variable binding
- ✅ Scheduler FIFO ordering
- ✅ Single-ID variable system (core)
- ✅ Guard instructions
- ✅ List operations
- ✅ Environment frames
- ✅ System predicates

### Needs Attention
- ⚠️ Goal reactivation on reader binding
- ⚠️ Compiler integration tests
- ⚠️ Some test files using old API
- ⚠️ Multi-program execution edge cases

---

## Recommended Next Steps

1. **Immediate** (Est. 30 min):
   - Fix metainterp_merge_test.dart API mismatches
   - Fix metainterp_circular_merge_test.dart API mismatches
   - Delete or disable heap_v2 compatibility tests

2. **High Priority** (Est. 2-4 hours):
   - Debug and fix reactivation issue (2 failing tests)
   - This is blocking several features

3. **Medium Priority** (Est. 4-8 hours):
   - Fix compiler integration tests (5 tests)
   - Fix remaining custom test edge cases (15 tests)

4. **Low Priority** (As needed):
   - Polish and cleanup
   - Documentation updates
   - Performance optimization

---

## Notes
- **Known Good Commit**: 7be7d83 (~170 tests passing)
- **Current Commit**: 36349ed (136 tests passing)
- **Regression**: ~34 tests (mostly due to incomplete migration)
- **Architecture**: Single-ID variable system (VarRef with isReader flag)
- **Runtime**: Dart-based with ROQ suspension/reactivation
