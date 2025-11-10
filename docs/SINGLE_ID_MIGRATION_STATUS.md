# Single-ID Variable Migration - Status Report

**Date:** November 11, 2025 (Updated)
**Branch:** `single-id-migration`
**Status:** In Progress - Categories 1-2 Complete ✅, Ready for Step 2.4

---

## Progress Summary

### ✅ Completed (Steps 2.0.1 - 2.0.3, Group 2.3.1, Categories 1-2)

1. **Branch Created** - `single-id-migration` from commit 0af4d64
2. **VarRef Moved to terms.dart** - Now first-class term type
3. **Old types deprecated** - WriterTerm/ReaderTerm marked @Deprecated
4. **Migration helpers created** - lib/bytecode/migration_helper.dart
5. **Heap interface extended** - Added allocateFreshVar() and addVariable()
6. **Group 2.3.1 Complete** - All 19 allocateFreshPair calls migrated ✅
7. **Category 1 Complete** - All 22 type checks migrated to dual-type support ✅
8. **Category 2 Complete** - Analyzed, no migration needed (0 refs) ✅

### 📊 Discovery: Scope Larger Than Expected

**Original estimate:** 53 occurrences of WriterTerm/ReaderTerm
**Actual finding:** Much larger scope:

- `allocateFreshPair`: **19 occurrences** (not 5 as estimated)
- WriterTerm/ReaderTerm references: 53 occurrences
- Total migration points: **70+ occurrences**

---

## Category-Based Migration Complete ✅

### ✅ Category 1: Type Checks (22 references) - COMPLETE

**Pattern migrated:** `if (term is WriterTerm/ReaderTerm)` → `if (MigrationHelper.isWriter/isReader(term))`

**Locations migrated:**
- Guard instructions: IfWriter, IfReader, IfVariable (lines 237, 252, 271, 281)
- Format/debug: _formatTerm function (lines 168, 175)
- Structure unification: HeadStructure, UnifyConstant, UnifyWriter/UnifyReader (lines 430, 731, 749, 863, 884, 1013, 1016, 1061, 1096, 1128, 1135, 1490)
- Suspension: collectUnbound helper (lines 2046, 2053)
- System predicates: variable_name/2 (lines 2155, 2157)

**Strategy:** Dual-type support using MigrationHelper - both WriterTerm/ReaderTerm AND VarRef work

**Commit:** 9209865 - "refactor: Category 1 - Migrate all type checks to dual-type support"

### ✅ Category 2: Property Access (0 references) - NO MIGRATION NEEDED

**Analysis:** All `.writerId` and `.readerId` accesses are on `arg` objects from `_getArg()`, NOT on WriterTerm/ReaderTerm types. These are part of the argument unification system and do not require migration.

### ⏸️ Category 3: Compatibility Code (14 references) - DEFER TO STEP 2.4

**Pattern:** `WriterTerm(id)` and `ReaderTerm(id)` construction

**Locations:**
- Lines 625, 958, 978, 1059, 1093, 1228, 1230, 1637, 1717, 1753, 1883, 1885, 1928, 1930

**Decision:** KEEP AS-IS during migration. These constructions maintain backward compatibility with the dual-heap system. Will migrate to VarRef construction in Step 2.4 when removing HeapV2Adapter.

### ⏸️ Category 4: Adapter Bridging (~11 references) - PART OF STEP 2.4

**Pattern:** Conversion logic in HeapV2Adapter (_convertToV2, _convertFromV2)

**Decision:** KEEP AS-IS. These are the adapter's core functionality for bridging the two systems. Will be removed entirely in Step 2.4.

---

## Completed: Group 2.3.1 (Variable Allocation)

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
4. `c6dc067` - docs: Single-ID migration status and scope update
5. `b37789b` - fix: Remove duplicate VarRef definition and update constructor calls
6. `d42d4e9` - refactor: Add single-ID methods and migrate first 5 allocateFreshPair calls
7. `d001bba` - refactor: Migrate next 7 allocateFreshPair calls (Group 2.3.1 continued)
8. `f09f0db` - refactor: Complete Group 2.3.1 - all 19 allocateFreshPair calls migrated
9. `9209865` - refactor: Category 1 - Migrate all type checks to dual-type support

---

## When Resuming

**Test baseline:**
```bash
cd /Users/udi/GLP/glp_runtime
dart test test/bytecode/asm_smoke_test.dart
# Should show: All tests passed!
dart test
# Should show: +197 -24 (same as before migration)
```

**Current State:**
- ✅ All variable allocation uses single-ID (Group 2.3.1)
- ✅ All type checks use dual-type support (Category 1)
- ✅ Zero allocateFreshPair calls in runner.dart
- ✅ Tests stable (197 passing, 24 pre-existing failures)
- ✅ Categories 1-2 complete
- ⏸️ Categories 3-4 deferred to Step 2.4 (adapter removal)

**Next Session Tasks:**

**Option A: Continue to Step 2.4 (Remove Adapter)**
- All runner.dart migrations complete
- Ready to remove HeapV2Adapter
- Switch Runtime to use HeapV2 directly
- Migrate Category 3 construction sites during adapter removal

**Option B: Additional Cleanup Before Step 2.4**
- Review for any edge cases
- Add more tests for VarRef/dual-type scenarios
- Document the migration helpers

---

## Notes

- Group 2.3.1 took ~3 hours (as estimated)
- Pattern proven: mechanical replacements work well
- Complexity discovered: remaining refs need architectural decisions
- HeapV2Adapter bridges two systems - needs careful handling
- Clean git state with good checkpoints

---

**Status:** Categories 1-2 Complete ✅ - Ready for Step 2.4 (Adapter Removal)
**No Blockers:** Category 1 (type checks) fully migrated, Category 2 (none needed)
**Next Action:** Decide between Option A (proceed to Step 2.4) or Option B (additional cleanup)
