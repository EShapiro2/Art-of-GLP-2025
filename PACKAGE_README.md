# GLP Full Context Package - Quick Start Guide

**Package**: `glp_full_20251114_0749.zip`
**Date**: November 14, 2025
**Issue**: GetVariable/REPL variable display bug
**Size**: 728 KB

## What's This About?

After implementing VarRef changes to fix guard dereferencing, the REPL stopped displaying variable bindings. All queries show `X = <unbound>` even though the runtime correctly binds variables (85/87 tests pass).

## Start Here

### 1. Read the Issue Context (5 minutes)
**File**: `GETVARIABLE_REPL_ISSUE_CONTEXT.md`

This document provides:
- Complete problem statement
- Code flow analysis (REPL → GetVariable → HEAD → Commit → Heap)
- Claude Web's hypothesis
- Proposed fix and concerns
- Specific questions for you

### 2. Review Key Code Sections

**GetVariable handler** - The change that may have broken REPL:
- File: `glp_runtime/lib/bytecode/runner.dart`
- Lines: 684-707
- Changed from storing bare IDs to storing VarRef objects

**REPL variable tracking**:
- File: `udi/glp_repl.dart` (if included)
- Setup: lines 313-331
- Display: lines 214-230

**Heap binding**:
- File: `glp_runtime/lib/runtime/heap.dart`
- Methods: `isBound()`, `getValue()`, `bindVariable()`

### 3. Review Specifications

**Must read** (in order):
1. `docs/SPEC_GUIDE.md` - Overview of GLP execution model
2. `docs/glp-bytecode-v216-complete.md` - GetVariable specification (section 12.1)
3. `docs/glp-runtime-spec.txt` - Runtime architecture
4. `docs/single-id-migration.md` - Single-ID variable system

## The Core Question

**Do HEAD instructions properly unwrap VarRef when building σ̂w (sigma-hat)?**

If any HEAD instruction uses `clauseVars[i]` directly as a σ̂w key without checking for VarRef first, that would cause:
- σ̂w: `{VarRef(1000): ConstTerm('a')}` ❌ Wrong
- Should be: `{1000: ConstTerm('a')}` ✓ Correct

This would bind the VarRef object instead of variable ID 1000, making the REPL unable to find the binding.

## HEAD Instructions to Audit

Check these handlers in `runner.dart` to see if they unwrap VarRef:

1. **HeadConstant** (line 313+)
2. **HeadStructure** (line 380+)
3. **HeadList** (line 2620+)
4. **HeadWriter** (need to find)
5. **HeadReader** (need to find)
6. **GetValue** (line 709+)

**HeadNil is already correct** (lines 2506-2527):
```dart
} else if (clauseVarValue is VarRef) {
  final varId = clauseVarValue.varId;  // ✓ Unwraps correctly
  cx.sigmaHat[varId] = ConstTerm('nil');  // ✓ Uses bare ID as key
}
```

## Proposed Solutions

### Option 1: Revert GetVariable (Quick Fix)
```dart
// Store bare IDs instead of VarRef
cx.clauseVars[op.varIndex] = arg.writerId!;
```

**Pros**: Quick, restores REPL
**Cons**: May hide bugs in HEAD instructions, treats symptom not cause

### Option 2: Fix HEAD Instructions (Proper Fix)
Make all HEAD instructions check for VarRef and unwrap it before using as σ̂w key.

**Pros**: Correct architectural fix
**Cons**: More work, need to audit all HEAD instructions

### Option 3: Hybrid
Keep VarRef in GetVariable but add unwrapping helper used by all HEAD instructions.

## Package Contents

```
glp_full_20251114_0749.zip
├── CLAUDE.md                              # Project guide (mandatory reading)
├── GETVARIABLE_REPL_ISSUE_CONTEXT.md      # This issue's complete context
├── docs/
│   ├── SPEC_GUIDE.md                      # Start here for specs
│   ├── glp-bytecode-v216-complete.md      # Instruction set (GetVariable: §12.1)
│   ├── glp-runtime-spec.txt               # Runtime architecture
│   ├── single-id-migration.md             # Single-ID variable system
│   └── [other documentation]
└── glp_runtime/lib/
    ├── bytecode/
    │   ├── runner.dart                    # ⭐ GetVariable handler (lines 684-707)
    │   ├── opcodes.dart                   # Instruction definitions
    │   └── asm.dart                       # Assembly helpers
    ├── runtime/
    │   ├── heap.dart                      # ⭐ Single-ID heap implementation
    │   ├── commit.dart                    # ⭐ Commit operation
    │   ├── runtime.dart                   # Main runtime
    │   ├── roq.dart                       # Suspension/reactivation
    │   └── [other runtime files]
    └── compiler/
        └── [compiler implementation]
```

⭐ = Critical files for this issue

## Key Context

- **System**: GLP (Grassroots Logic Programs) runtime in Dart
- **Test Status**: 85/87 passing (runtime works, only REPL display broken)
- **Architecture**: Single-ID variable system (writerId == readerId)
- **VarRef**: Wraps `(varId, isReader: bool)` to distinguish access modes
- **Three-phase execution**: HEAD (tentative) → GUARDS (tests) → BODY (mutations)
- **σ̂w (sigma-hat)**: Tentative writer substitution built during HEAD, applied at COMMIT

## Questions for Claude Web

1. **HEAD Instruction Audit**: Do all HEAD instructions properly unwrap VarRef when building σ̂w?

2. **Root Cause**: Is the issue:
   - HEAD instructions not unwrapping VarRef?
   - Commit not handling VarRef keys?
   - REPL checking wrong ID?
   - Heap cell not created?

3. **Proper Fix**: Should we:
   - Revert GetVariable (quick fix)?
   - Fix HEAD instructions (proper fix)?
   - Hybrid approach?

4. **Architecture**: Is storing VarRef in clauseVars the right design, or should clauseVars always contain bare IDs?

## Response Format

Please provide:

1. **Diagnosis**: What's the actual root cause?
2. **Fix**: Complete code for the proper solution
3. **Rationale**: Why this fix is architecturally correct
4. **Testing**: How to verify the fix works

## Coordination Model

- **Claude Code** (me): Execution, testing, small fixes
- **Claude Web** (you): Architecture decisions, code generation, debugging logic

This division is intentional - you have deep architectural understanding, I handle the mechanical work.

## Ready to Go

Everything you need is in this package. Start with `GETVARIABLE_REPL_ISSUE_CONTEXT.md` and refer to the specifications as needed.

Good luck! 🚀
