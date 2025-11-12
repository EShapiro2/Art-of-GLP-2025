#!/bin/bash
# Prepare package for Claude Web with all necessary context

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PACKAGE_DIR="claude_web_package_${TIMESTAMP}"

echo "Creating Claude Web package: $PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

# Core documentation
echo "Copying core documentation..."
cp CLAUDE.md "$PACKAGE_DIR/"
cp STATUS_REPORT_FOR_CLAUDE_WEB.md "$PACKAGE_DIR/"

# Test baseline
echo "Copying test baseline..."
cp glp_runtime/TEST_BASELINE.md "$PACKAGE_DIR/"
cp glp_runtime/BASELINE_SUMMARY.txt "$PACKAGE_DIR/"

# Specifications
echo "Copying specifications..."
mkdir -p "$PACKAGE_DIR/docs"
cp docs/SPEC_GUIDE.md "$PACKAGE_DIR/docs/"
cp docs/glp-bytecode-v216-complete.md "$PACKAGE_DIR/docs/"
cp docs/glp-runtime-spec.txt "$PACKAGE_DIR/docs/"
cp docs/single-id-migration.md "$PACKAGE_DIR/docs/"

# Runtime source (high priority files)
echo "Copying runtime source..."
mkdir -p "$PACKAGE_DIR/runtime"
cp glp_runtime/lib/runtime/commit.dart "$PACKAGE_DIR/runtime/" 2>/dev/null || echo "  (commit.dart not found)"
cp glp_runtime/lib/runtime/roq.dart "$PACKAGE_DIR/runtime/" 2>/dev/null || echo "  (roq.dart not found)"
cp glp_runtime/lib/runtime/heap.dart "$PACKAGE_DIR/runtime/" 2>/dev/null || echo "  (heap.dart not found)"
cp glp_runtime/lib/runtime/runtime.dart "$PACKAGE_DIR/runtime/" 2>/dev/null || echo "  (runtime.dart not found)"
cp glp_runtime/lib/runtime/scheduler.dart "$PACKAGE_DIR/runtime/" 2>/dev/null || echo "  (scheduler.dart not found)"

# Failing test files
echo "Copying failing test files..."
mkdir -p "$PACKAGE_DIR/tests"
cp glp_runtime/test/custom/metainterp_merge_test.dart "$PACKAGE_DIR/tests/" 2>/dev/null
cp glp_runtime/test/custom/metainterp_circular_merge_test.dart "$PACKAGE_DIR/tests/" 2>/dev/null
cp glp_runtime/test/bytecode/union_end_to_end_test.dart "$PACKAGE_DIR/tests/" 2>/dev/null
cp glp_runtime/test/bytecode/asm_smoke_test.dart "$PACKAGE_DIR/tests/" 2>/dev/null

# Create README for the package
cat > "$PACKAGE_DIR/README.md" << 'EOREADME'
# Claude Web Package

This package contains all files needed for Claude Web to review the GLP runtime status.

## Quick Start

1. **Read First**: `STATUS_REPORT_FOR_CLAUDE_WEB.md` (executive summary)
2. **Test Details**: `TEST_BASELINE.md` (comprehensive analysis)
3. **Quick Ref**: `BASELINE_SUMMARY.txt` (one-page overview)

## Critical Issues

### Issue #1: Goal Reactivation Bug (HIGH PRIORITY)
- **Files**: `runtime/commit.dart`, `runtime/roq.dart`
- **Tests**: `tests/union_end_to_end_test.dart`, `tests/asm_smoke_test.dart`
- **Symptom**: Suspended goals not reactivating when writers bind

### Issue #2: API Migration (QUICK FIX)
- **Files**: `tests/metainterp_merge_test.dart`, `tests/metainterp_circular_merge_test.dart`
- **Fix**: Update old two-ID API to new single-ID API

## Documentation Structure

```
claude_web_package_*/
├── README.md                          # This file
├── STATUS_REPORT_FOR_CLAUDE_WEB.md   # Executive summary
├── CLAUDE.md                          # Project guide
├── TEST_BASELINE.md                   # Detailed test analysis
├── BASELINE_SUMMARY.txt               # Quick reference
├── docs/                              # Specifications
│   ├── SPEC_GUIDE.md
│   ├── glp-bytecode-v216-complete.md
│   ├── glp-runtime-spec.txt
│   └── single-id-migration.md
├── runtime/                           # Runtime source (high priority)
│   ├── commit.dart                    # Commit operation (BUG HERE)
│   ├── roq.dart                       # Suspension/reactivation
│   ├── heap.dart                      # Single-ID heap
│   ├── runtime.dart                   # Main runtime
│   └── scheduler.dart                 # Goal scheduling
└── tests/                             # Failing tests
    ├── metainterp_merge_test.dart     # API migration needed
    ├── metainterp_circular_merge_test.dart  # API migration needed
    ├── union_end_to_end_test.dart     # Reactivation bug
    └── asm_smoke_test.dart            # Reactivation bug
```

## Questions for Claude Web

1. **Goal Reactivation Bug**: 
   - Should `heap.getReaderIdForWriter(writerId)` just return `writerId` in single-ID system?
   - Is `roq.processOnBind()` being called correctly in `commit.dart`?

2. **API Migration**: 
   - Confirm quick fixes for metainterp tests?

3. **Obsolete Tests**: 
   - Confirm deletion of heap_v2 compatibility tests?

## Context

- **System**: GLP (Grassroots Logic Programs) runtime in Dart
- **Current State**: 136/169 tests passing (80.5%)
- **Known Good**: Commit 7be7d83 (~170 tests)
- **Architecture**: Single-ID variable system (VarRef), three-phase execution, ROQ suspension

## Coordination

- Claude Code: Execution, testing, small fixes
- Claude Web: Architecture decisions, code generation, debugging logic
EOREADME

# Create tarball
echo "Creating tarball..."
tar -czf "${PACKAGE_DIR}.tar.gz" "$PACKAGE_DIR"

# Summary
echo ""
echo "=========================================="
echo "Package created successfully!"
echo "=========================================="
echo "Directory: $PACKAGE_DIR"
echo "Tarball:   ${PACKAGE_DIR}.tar.gz"
echo ""
echo "To share with Claude Web:"
echo "  1. Upload ${PACKAGE_DIR}.tar.gz, or"
echo "  2. Upload individual files from $PACKAGE_DIR/"
echo ""
echo "Start with: STATUS_REPORT_FOR_CLAUDE_WEB.md"
echo "=========================================="

ls -lh "$PACKAGE_DIR"
ls -lh "${PACKAGE_DIR}.tar.gz"
