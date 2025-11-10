# Single-ID Variable Migration - Status Report

**Date:** November 11, 2025
**Branch:** `single-id-migration`
**Status:** In Progress - Preparation Complete

---

## Progress Summary

### ✅ Completed (Steps 2.0.1 - 2.0.3)

1. **Branch Created** - `single-id-migration` from commit 0af4d64
2. **VarRef Moved to terms.dart** - Now first-class term type
3. **Old types deprecated** - WriterTerm/ReaderTerm marked @Deprecated
4. **Migration helpers created** - lib/bytecode/migration_helper.dart

### 📊 Discovery: Scope Larger Than Expected

**Original estimate:** 53 occurrences of WriterTerm/ReaderTerm
**Actual finding:** Much larger scope:

- `allocateFreshPair`: **19 occurrences** (not 5 as estimated)
- WriterTerm/ReaderTerm references: 53 occurrences
- Total migration points: **70+ occurrences**

---

## Next Steps (When Resuming)

### Group 2.3.1: Variable Allocation (19 occurrences)

**Pattern to replace:**
```dart
// OLD:
final (freshWriterId, freshReaderId) = cx.rt.heap.allocateFreshPair();
cx.rt.heap.addWriter(WriterCell(freshWriterId, freshReaderId));
cx.rt.heap.addReader(ReaderCell(freshReaderId));

// NEW:
final varId = cx.rt.heap.allocateFreshVar();
cx.rt.heap.addVariable(varId);
// Use VarRef(varId, isReader: false) for writer
// Use VarRef(varId, isReader: true) for reader
```

**Locations in runner.dart:**
- Line 963, 984, 1068, 1078, 1105
- Line 1237, 1252
- Line 1438, 1447, 1485, 1493, 1504
- Line 1534, 1550, 1601, 1717
- Line 2438, 2451, 2463

**Strategy:**
1. Convert allocateFreshPair → allocateFreshVar
2. Replace WriterTerm(freshWriterId) → VarRef(varId, isReader: false)
3. Replace ReaderTerm(freshReaderId) → VarRef(varId, isReader: true)
4. Test after each block of 5 changes

---

## Revised Time Estimate

**Original:** 8-12 hours
**Revised:** 12-16 hours (due to larger scope)

**Breakdown:**
- Group 2.3.1: 2-3 hours (19 occurrences)
- Group 2.3.2-2.3.7: 6-8 hours (remaining 51+ occurrences)
- Step 2.4 (Remove adapter): 1-2 hours
- Step 2.5 (Cleanup): 1 hour
- Testing & debugging: 2-3 hours

---

## Critical Files

### Modified So Far
- `lib/runtime/terms.dart` - VarRef added, old types deprecated
- `lib/bytecode/migration_helper.dart` - Helper functions created

### To Be Modified
- `lib/bytecode/runner.dart` - 70+ occurrences to migrate
- `lib/runtime/heap_v2_adapter.dart` - Remove duplicate storage
- `lib/runtime/runtime.dart` - Switch to HeapV2 directly

### To Be Deleted
- `lib/runtime/heap.dart` - Old two-ID heap
- `lib/runtime/heap_v2_adapter.dart` - After migration complete
- `lib/bytecode/migration_helper.dart` - Temporary, delete after done

---

## Risk Assessment

**Low Risk:**
- Incremental approach with testing
- Can rollback at any checkpoint
- Deprecation warnings guide remaining work

**Medium Risk:**
- Larger scope than expected (70+ changes)
- Time required longer than estimated

**Mitigation:**
- Commit after each group (already doing)
- Test after every 5 changes
- Keep migration branch separate from main

---

## Commits So Far

1. `0af4d64` - Bug fixes (parent context + heap consistency)
2. `521a80d` - Checkpoint before migration
3. `5859b94` - VarRef preparation (Steps 2.0.2-2.0.3)

---

## When Resuming

**Test baseline:**
```bash
cd /Users/udi/GLP/glp_runtime
dart test test/bytecode/asm_smoke_test.dart
```

**Start with Group 2.3.1:**
- Read runner.dart lines 960-970 (first occurrence context)
- Make systematic changes to allocateFreshPair calls
- Test after each 5 changes
- Commit when group complete

**Expected result after Group 2.3.1:**
- All variable allocation uses single-ID
- No more allocateFreshPair calls in runner.dart
- Tests still passing

---

## Notes

- Approval prompts still active (will be disabled after restart)
- VarRef now compiles cleanly
- Migration helpers ready to use
- Branch ready for systematic work

---

**Status:** Ready to continue with Group 2.3.1
**Blocker:** None
**Next Action:** Migrate first 5 allocateFreshPair calls (lines 963-1105)
