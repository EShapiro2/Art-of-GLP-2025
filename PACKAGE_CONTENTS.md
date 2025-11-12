# Claude Web Package Contents

**Package**: `claude_web_package_20251112_082029.tar.gz`
**Created**: November 12, 2025
**Size**: 53 KB

---

## How to Use This Package

### For Claude Web (Recommended Reading Order)

1. **START HERE**: `STATUS_REPORT_FOR_CLAUDE_WEB.md` (13 KB)
   - Executive summary of test status
   - Critical issues requiring architectural guidance
   - Questions for Claude Web
   - Recommended action plan

2. **DETAILS**: `TEST_BASELINE.md` (11 KB)
   - Complete test inventory
   - Detailed failure analysis
   - Migration path to 170 tests

3. **QUICK REF**: `BASELINE_SUMMARY.txt` (2.6 KB)
   - One-page overview
   - Test counts by category
   - Known issues at a glance

### Specifications (For Reference)

Located in `docs/` directory:

1. **SPEC_GUIDE.md** - Overview of GLP execution model
2. **glp-bytecode-v216-complete.md** - Complete instruction set specification
3. **glp-runtime-spec.txt** - Dart runtime architecture
4. **single-id-migration.md** - Single-ID variable system design

### Runtime Source Code (High Priority Files)

Located in `runtime/` directory:

1. **commit.dart** - Commit operation (⚠️ BUG HERE - reactivation issue)
2. **roq.dart** - ROQ suspension/reactivation mechanism
3. **heap.dart** - Single-ID heap implementation
4. **runtime.dart** - Main GlpRuntime class
5. **scheduler.dart** - Goal scheduling and FIFO queue

### Failing Test Files

Located in `tests/` directory:

1. **metainterp_merge_test.dart** - API migration needed (quick fix)
2. **metainterp_circular_merge_test.dart** - API migration needed (quick fix)
3. **union_end_to_end_test.dart** - Reactivation bug test
4. **asm_smoke_test.dart** - Reactivation bug test

---

## Critical Issues Summary

### Issue #1: Goal Reactivation Bug (HIGH PRIORITY)
**Status**: ❌ Blocking 2 tests
**Severity**: High - Core runtime feature broken

**Symptom**:
```
Expected: [3000, 4000]  // Goal IDs
Actual:   []            // Empty
```

**Files to Review**:
- `runtime/commit.dart` - Check `CommitOps.applySigmaHat()`
- `runtime/roq.dart` - Check `processOnBind()`
- `tests/union_end_to_end_test.dart` - Test case
- `tests/asm_smoke_test.dart` - Test case

**Questions**:
1. In single-ID system, should `heap.getReaderIdForWriter(writerId)` just return `writerId`?
2. Is `roq.processOnBind(readerId)` being called for each bound writer?
3. Are reactivated goals being enqueued to the goal queue?

### Issue #2: API Migration (QUICK FIX)
**Status**: ⚠️ Blocking 4 tests
**Severity**: Low - Easy mechanical fix
**Time**: 15-20 minutes

**Files to Fix**:
- `tests/metainterp_merge_test.dart` (8 lines)
  - `isVarBound()` → `isBound()`
  - `valueOfVar()` → `getValue()`

- `tests/metainterp_circular_merge_test.dart` (2 lines)
  - `.readerId` → `.varId`

**Action**: Claude Code can execute these fixes immediately upon approval.

### Issue #3: Compiler Integration (MEDIUM PRIORITY)
**Status**: ⚠️ Blocking 5 tests
**Severity**: Medium - Affects compilation pipeline
**Time**: 4-8 hours

**Issues**:
1. Type mismatches: Tests expect `PutReader`, get `PutVariable`
2. Suspension notes not created during compilation

**Action**: Requires architectural guidance on v1/v2 instruction migration strategy.

---

## Test Status Overview

| Category | Passing | Total | Rate |
|----------|---------|-------|------|
| Linter Tests | 3 | 3 | 100% ✅ |
| Smoke Tests | 3 | 3 | 100% ✅ |
| Bytecode Instructions | 48 | 50 | 96% ✅ |
| Conformance Tests | 8 | 8 | 100% ✅ |
| System Predicates | 22 | 22 | 100% ✅ |
| Custom Tests | 40 | 60 | 67% ⚠️ |
| Refactoring Tests | 12 | 15 | 80% ⚠️ |
| Compiler Tests | 0 | 5 | 0% ❌ |
| **TOTAL** | **136** | **169** | **80.5%** |

**Baseline**: Commit 7be7d83 had ~170 tests passing
**Current**: Commit 36349ed has 136 tests passing
**Gap**: 34 tests (mostly due to incomplete migration)

---

## Known Working Features ✅

- ✅ Single-ID variable system (VarRef with isReader flag)
- ✅ Three-phase execution (HEAD/GUARDS/BODY)
- ✅ σ̂w tentative writer substitution
- ✅ Si/U suspension accumulation
- ✅ All guard instructions (ground, known, otherwise)
- ✅ All list operations (HeadNil, HeadList, PutNil, PutList)
- ✅ All structure operations (HeadStructure, PutStructure, unify, set)
- ✅ Environment frames (allocate, deallocate, nesting)
- ✅ Scheduler FIFO ordering
- ✅ Tail recursion budget (26 steps)
- ✅ All 22 system predicates

---

## Recommended Action Plan

### Phase 1: Quick Wins (30 min → 140 passing)
1. Fix metainterp API calls (+2 tests)
2. Delete obsolete heap_v2 tests (+2 tests)
3. **Action**: Claude Code ready to execute

### Phase 2: Critical Bug (2-4 hours → 142 passing)
1. Debug reactivation bug (+2 tests)
2. **Action**: Needs architectural guidance from Claude Web

### Phase 3: Compiler Integration (4-8 hours → 147 passing)
1. Fix compiler tests (+5 tests)
2. **Action**: Needs strategy decision from Claude Web

### Phase 4: Edge Cases (variable → 169 passing)
1. Fix remaining edge cases (+22 tests)
2. **Action**: After core issues resolved

---

## Files Included in Package

```
claude_web_package_20251112_082029/
├── README.md                               # Package overview
├── STATUS_REPORT_FOR_CLAUDE_WEB.md         # Executive summary (START HERE)
├── CLAUDE.md                               # Project guide
├── TEST_BASELINE.md                        # Detailed test analysis
├── BASELINE_SUMMARY.txt                    # Quick reference
│
├── docs/                                   # Specifications
│   ├── SPEC_GUIDE.md                       # Execution model overview
│   ├── glp-bytecode-v216-complete.md       # Instruction set spec
│   ├── glp-runtime-spec.txt                # Runtime architecture
│   └── single-id-migration.md              # Single-ID design
│
├── runtime/                                # Runtime source (high priority)
│   ├── commit.dart                         # ⚠️ BUG HERE
│   ├── roq.dart                            # ROQ implementation
│   ├── heap.dart                           # Single-ID heap
│   ├── runtime.dart                        # Main runtime
│   └── scheduler.dart                      # Goal scheduling
│
└── tests/                                  # Failing tests
    ├── metainterp_merge_test.dart          # API fix needed
    ├── metainterp_circular_merge_test.dart # API fix needed
    ├── union_end_to_end_test.dart          # Reactivation bug
    └── asm_smoke_test.dart                 # Reactivation bug
```

**Total**: 19 files, 53 KB compressed

---

## Questions for Claude Web

### 1. Reactivation Bug (Critical)
In single-ID system where `writerId == readerId`:
- Should `heap.getReaderIdForWriter(writerId)` just return `writerId`?
- Or is there still a pairing mechanism we're missing?
- Should we add debug logging to trace the commit→bind→reactivate flow?

### 2. API Migration (Quick)
Confirm these fixes are correct:
- `heap.isVarBound(varId)` → `heap.isBound(varId)` ✓
- `heap.valueOfVar(varId)` → `heap.getValue(varId)` ✓
- `varRef.readerId` → `varRef.varId` ✓

### 3. Compiler Tests (Medium)
Strategy decision needed:
- Should tests accept both v1 and v2 instruction types?
- Or complete migration to v2 only?
- What's causing suspension notes to not be created?

### 4. Obsolete Tests (Cleanup)
Confirm deletion of:
- `test/refactoring/heap_v2_integration_test.dart`
- `test/refactoring/heap_compatibility_test.dart`

---

## Next Steps

### Immediate (Awaiting User Direction)
1. Should Claude Code execute Phase 1 quick fixes? (+4 tests, 30 min)
2. Should we add debug logging for reactivation bug investigation?

### After Architectural Guidance
1. Implement fixes for reactivation bug
2. Update compiler tests based on strategy decision
3. Clean up obsolete tests

---

## Coordination Notes

**Claude Code** (this session) handles:
- Test execution and reporting
- Small, directed fixes
- Debug logging and diagnostics
- Git operations

**Claude Web** (you) handles:
- Architecture decisions
- Code generation for complex fixes
- Debugging logic from error messages
- Design guidance

**Current State**: Awaiting architectural guidance on reactivation bug before proceeding with fixes.

---

## Contact Information

**Package Location**: `/Users/udi/GLP/claude_web_package_20251112_082029.tar.gz`
**Repository**: `/Users/udi/GLP/glp_runtime/`
**Branch**: main
**Commit**: 36349ed

For questions or clarifications, refer to `STATUS_REPORT_FOR_CLAUDE_WEB.md` in this package.

---

**End of Package Contents Documentation**
