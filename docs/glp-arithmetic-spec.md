# GLP Arithmetic Assignment Specification (Normative)

**Version**: 1.0
**Status**: Draft
**Date**: 2025-11-21

## 1. Overview

GLP provides the **arithmetic assignment operator `:=`** for evaluating arithmetic expressions and binding results in clause bodies. This operator follows FCP's model but leverages GLP's SRSW (Single-Reader Single-Writer) constraint to simplify implementation.

### 1.1 Key Differences from `execute('evaluate', ...)`

| Feature | `:=` Operator | `execute('evaluate', ...)` |
|---------|--------------|---------------------------|
| **Semantics** | Three-valued (success/suspend/fail) | Two-valued (success/abort) |
| **Unbound readers** | Suspends goal | Aborts with error |
| **Type errors** | Fails (try next clause) | Aborts with error |
| **Usage location** | Body goals only | Body goals only |
| **Syntax** | Infix: `Z := X? + Y?` | System call: `execute('evaluate', [+(X?, Y?), Z])` |

### 1.2 Design Rationale

**FCP Model**: In FCP, `:=` compiles to Ask/3 guard kernel predicates (`plus/3`, `diff/3`, `times/3`, etc.) which provide three-valued semantics with suspension support.

**GLP Simplification**: Due to SRSW, the target writer variable is guaranteed unbound at assignment time, so binding always succeeds. However, operand evaluation still requires three-valued semantics (suspend on unbound readers, fail on type errors).

---

## 2. Syntax

### 2.1 Operator Definition

**Form**: `WriterVar := Expression`

**Precedence**: 700 (same as comparison operators)

**Associativity**: Right-associative

**Context**: Body goals only (appears after `|` guard separator)

### 2.2 Components

**WriterVar**:
- Must be a writer variable (no `?` suffix in source)
- Must be unbound (guaranteed by SRSW in well-formed programs)

**Expression**:
- Arithmetic expression using supported operators
- Can contain reader variables (with `?` suffix)
- Can contain constants (integers, floats)
- Can be nested

### 2.3 Examples

```glp
% Simple arithmetic
increment(N, N1) :-
  N > 0 |
  N1 := N? + 1.

% Nested expression
compute(X, Y, Result) :-
  X > 0, Y > 0 |
  Result := (X? * 2) + (Y? * 3).

% Using intermediate results
factorial(N, F?) :-
  N > 1 |
  N1 := N? - 1,
  factorial(N1?, F1),
  F := N? * F1?.

% Multiple assignments
test(A, B, C?, D?) :-
  A > 0, B > 0 |
  C := A? + B?,
  D := C? * 2.
```

---

## 3. Supported Operators

### 3.1 Binary Operators

| Operator | Name | Example | Notes |
|----------|------|---------|-------|
| `+` | Addition | `Z := X? + Y?` | Integer or float |
| `-` | Subtraction | `Z := X? - Y?` | Integer or float |
| `*` | Multiplication | `Z := X? * Y?` | Integer or float |
| `/` | Division | `Z := X? / Y?` | Float result; fails on divide-by-zero |
| `mod` | Modulo | `Z := X? mod Y?` | Integer only; fails on divide-by-zero |
| `//` | Integer division | `Z := X? // Y?` | Integer result; fails on divide-by-zero |

### 3.2 Unary Operators

| Operator | Name | Example | Notes |
|----------|------|---------|-------|
| `-` | Negation | `Z := -X?` | Unary minus |
| `abs` | Absolute value | `Z := abs(X?)` | Integer or float |

### 3.3 Mathematical Functions

| Function | Example | Notes |
|----------|---------|-------|
| `sqrt(X)` | `Z := sqrt(X?)` | Square root; fails if X < 0 |
| `sin(X)` | `Z := sin(X?)` | Trigonometric sine |
| `cos(X)` | `Z := cos(X?)` | Trigonometric cosine |
| `tan(X)` | `Z := tan(X?)` | Trigonometric tangent |
| `exp(X)` | `Z := exp(X?)` | Exponential (e^X) |
| `ln(X)` | `Z := ln(X?)` | Natural logarithm; fails if X ≤ 0 |
| `pow(X, Y)` | `Z := pow(X?, Y?)` | Exponentiation (X^Y) |

### 3.4 Type Conversions

| Function | Example | Notes |
|----------|---------|-------|
| `integer(X)` | `Z := integer(X?)` | Convert to integer (truncate) |
| `real(X)` | `Z := real(X?)` | Convert to float |
| `round(X)` | `Z := round(X?)` | Round to nearest integer |

### 3.5 Operator Precedence (High to Low)

1. Function calls: `sqrt(...)`, `sin(...)`, etc. (highest)
2. Unary operators: `-X`
3. `*`, `/`, `mod`, `//`
4. `+`, `-`
5. `:=` (lowest)

**Example**: `Z := X? + Y? * 2` parses as `Z := X? + (Y? * 2)`

---

## 4. Semantics (Three-Valued)

### 4.1 Evaluation Model

**Phase 1: Operand Evaluation**

For each operand in the expression:

1. **Constant** → Use value directly
2. **Reader Variable** → Dereference to writer:
   - Writer bound → Use bound value
   - Writer unbound → **SUSPEND** (add reader to suspension set)
3. **Nested Expression** → Recursively evaluate

**Phase 2: Computation**

If all operands ground:
- Perform arithmetic operation
- **Type error** (e.g., atom + integer) → **FAIL**
- **Domain error** (e.g., divide by zero, sqrt of negative) → **FAIL**
- Success → Proceed to Phase 3

**Phase 3: Binding**

Bind writer variable to computed result:
- SRSW guarantee → Writer always unbound → Binding **always succeeds**

### 4.2 Suspension Semantics

When `:=` encounters an unbound reader variable:

1. Add reader ID to goal's suspension set
2. Return control to scheduler
3. Scheduler suspends goal on that reader's suspension list
4. When reader's writer is bound, goal reactivates
5. Execution resumes at the SAME `:=` instruction

**Example**:
```glp
test(X, Y?) :-
  true |
  Y := X? + 1,      % If X unbound, suspend here
  write('done').    % This executes only after X is bound
```

**Timeline**:
1. `Y := X? + 1` executed
2. X unbound → goal suspends, added to X's suspension list
3. Another goal binds X to 5
4. This goal reactivates
5. `Y := X? + 1` re-executed: X now bound to 5 → Y := 6
6. `write('done')` executes

### 4.3 Failure Semantics

When `:=` fails:

**Causes**:
- Type error: operand is not a number (e.g., atom, string)
- Domain error: invalid operation (e.g., `5 / 0`, `sqrt(-4)`)
- Unification failure: writer already bound to different value (should not occur with SRSW)

**Behavior**:
- Clause fails
- Backtrack to next clause (if ClauseTry)
- If last clause, goal fails

**Example**:
```glp
% Clause 1: Fails if X is not a number
safe_compute(X, Y?) :-
  true |
  Y := X? + 1.      % Fails if X = atom

% Clause 2: Fallback
safe_compute(X, error).
```

---

## 5. Type System

### 5.1 Numeric Types

**Integer**:
- Dart `int` (64-bit signed)
- Literals: `0`, `42`, `-17`
- Operations: all operators supported

**Float**:
- Dart `double` (IEEE 754 double-precision)
- Literals: `3.14`, `-0.5`, `2.0`
- Operations: all operators supported

### 5.2 Type Coercion Rules

**Mixed integer/float operations**:
- Integer `op` Float → result is Float
- Float `op` Integer → result is Float
- Integer `op` Integer → result is Integer (except `/` which always returns Float)

**Examples**:
```glp
X := 5 + 3          % X = 8 (integer)
X := 5.0 + 3        % X = 8.0 (float)
X := 5 + 3.0        % X = 8.0 (float)
X := 10 / 2         % X = 5.0 (float, even though exact)
X := 10 // 2        % X = 5 (integer division)
X := 10 mod 3       % X = 1 (integer)
```

### 5.3 Type Errors

**Non-numeric operands**:
```glp
X := atom + 5       % FAIL: atom is not a number
X := "hello" * 2    % FAIL: string is not a number
X := [1,2,3] + 1    % FAIL: list is not a number
```

**Type checking happens at runtime**, not compile-time.

---

## 6. SRSW Guarantees

### 6.1 Writer Uniqueness

In well-formed GLP programs with SRSW:

**Guarantee**: The writer variable on the left-hand side of `:=` appears exactly once in the clause body as a writer.

**Example (valid)**:
```glp
test(X, Y?) :-
  true |
  Y := X? + 1.      % Y appears once as writer
```

**Example (invalid - SRSW violation)**:
```glp
test(X, Y?) :-
  true |
  Y := X? + 1,      % Y appears as writer
  Y := X? + 2.      % ERROR: Y appears again as writer (SRSW violation)
```

### 6.2 Binding Guarantee

**Consequence**: When `:=` executes, the writer variable is guaranteed unbound, so binding always succeeds.

**No unification needed**: Unlike FCP's Tell operations, GLP `:=` performs direct binding without unification checks.

---

## 7. Comparison with FCP

### 7.1 Similarities

- Syntax: `Var := Expr`
- Three-valued semantics (success/suspend/fail)
- Suspends on unbound readers
- Used in body goals only

### 7.2 Differences

| Aspect | FCP | GLP |
|--------|-----|-----|
| **Implementation** | Compiles to Ask/3 guard kernels | Direct bytecode instruction |
| **Writer binding** | Uses unification (can fail) | Direct binding (always succeeds) |
| **SRSW** | No constraint | Required (enforced by compiler) |
| **Guard vs Body** | Arithmetic in guards via Ask/3 | Arithmetic only in bodies via `:=` |

### 7.3 Why the Difference?

**FCP without SRSW**:
- Variables can have multiple writers
- Binding can conflict → needs unification
- Uses guard kernels for both guards and bodies

**GLP with SRSW**:
- Each variable has one writer
- No binding conflicts possible
- Simpler implementation: direct binding

---

## 8. Guard Arithmetic (Future Extension)

**Current Status**: GLP does not yet support arithmetic in guards.

**FCP Model**: FCP allows arithmetic tests in guards:
```prolog
% FCP code
test(X, Y) :- X + Y > 10 | ...
```

**Future GLP Extension**: Guard arithmetic predicates with three-valued semantics:
```glp
% Future GLP syntax
test(X, Y, Z?) :-
  plus(X?, Y?, Temp),    % Three-valued: suspend if X or Y unbound
  Temp? > 10 |           % Test
  Z := X? + Y?.
```

**Design Note**: These would be separate guard predicates (`plus/3`, `times/3`, etc.) distinct from the `:=` operator.

---

## 9. Implementation Model

### 9.1 Compilation Strategy

**Source**:
```glp
Z := X? + Y?
```

**Bytecode** (conceptual):
```
ArithAssign(op: ADD, left: X, right: Y, result: Z)
```

**Alternative (using system predicate)**:
```
Execute('arith_add', [X?, Y?, Z])
```

### 9.2 Runtime Execution

**Pseudocode**:
```dart
Result executeArithAssign(op, left, right, resultWriter) {
  // Phase 1: Evaluate operands
  leftVal = dereferenceReader(left);
  if (leftVal == UNBOUND) {
    return SUSPEND(left);
  }

  rightVal = dereferenceReader(right);
  if (rightVal == UNBOUND) {
    return SUSPEND(right);
  }

  // Phase 2: Type check
  if (!isNumber(leftVal) || !isNumber(rightVal)) {
    return FAIL;  // Type error
  }

  // Phase 3: Compute
  try {
    result = compute(op, leftVal, rightVal);
  } catch (ArithmeticError e) {
    return FAIL;  // e.g., divide by zero
  }

  // Phase 4: Bind (always succeeds due to SRSW)
  bindWriter(resultWriter, result);
  return SUCCESS;
}
```

### 9.3 Bytecode Instructions (Proposed)

**Option 1: Specialized instructions per operator**
```
ArithAdd(left_reg, right_reg, result_reg)
ArithSub(left_reg, right_reg, result_reg)
ArithMul(left_reg, right_reg, result_reg)
ArithDiv(left_reg, right_reg, result_reg)
ArithMod(left_reg, right_reg, result_reg)
```

**Option 2: Generic instruction with operator tag**
```
ArithBinary(op_tag, left_reg, right_reg, result_reg)
  where op_tag ∈ {ADD, SUB, MUL, DIV, MOD, ...}
```

**Option 3: System predicate calls**
```
Execute('arith_add', [left, right, result])
Execute('arith_sub', [left, right, result])
...
```

**Recommendation**: Option 2 (generic instruction) for simplicity and extensibility.

---

## 10. Examples

### 10.1 Basic Arithmetic

```glp
% Addition
add(X, Y, Z?) :- Z := X? + Y?.

% Multiplication
mul(X, Y, Z?) :- Z := X? * Y?.

% Safe division (guards ensure no divide-by-zero)
safe_div(X, Y, Z?) :-
  Y? > 0 |
  Z := X? / Y?.

safe_div(X, Y, error) :-
  Y? =:= 0 |
  true.
```

### 10.2 Factorial

```glp
% Base case
fact(0, 1).

% Recursive case
fact(N, F?) :-
  N? > 0 |
  N1 := N? - 1,
  fact(N1?, F1),
  F := N? * F1?.
```

### 10.3 Fibonacci

```glp
% Base cases
fib(0, 0).
fib(1, 1).

% Recursive case
fib(N, F?) :-
  N? > 1 |
  N1 := N? - 1,
  N2 := N? - 2,
  fib(N1?, F1),
  fib(N2?, F2),
  F := F1? + F2?.
```

### 10.4 Quadratic Formula

```glp
% Solve ax^2 + bx + c = 0
quadratic(A, B, C, X1?, X2?) :-
  Disc := B? * B? - 4 * A? * C?,
  Disc? >= 0 |
  SqrtDisc := sqrt(Disc?),
  X1 := (-B? + SqrtDisc?) / (2 * A?),
  X2 := (-B? - SqrtDisc?) / (2 * A?).

quadratic(A, B, C, no_solution, no_solution) :-
  Disc := B? * B? - 4 * A? * C?,
  Disc? < 0 |
  true.
```

### 10.5 Suspension and Dataflow

```glp
% Producer-consumer pattern
test(X?) :-
  consumer(X),
  producer(X).

% Consumer suspends waiting for X
consumer(X) :-
  true |
  Y := X? + 1,      % Suspends if X unbound
  write(Y?).

% Producer binds X
producer(X) :-
  true |
  X = 42.           % Binds X, reactivates consumer
```

**Execution order**:
1. `consumer(X)` starts, reaches `Y := X? + 1`
2. X unbound → consumer suspends
3. `producer(X)` starts, binds X to 42
4. Consumer reactivates, computes Y := 43
5. Writes 43

---

## 11. Error Conditions

### 11.1 Type Errors

**Condition**: Operand is not a number

**Result**: Clause fails (try next clause)

**Example**:
```glp
% First clause fails if X is atom
test(X, Y?) :- Y := X? + 1.

% Second clause handles non-numeric X
test(X, error).

% Query: test(atom, R)
% Result: R = error (first clause failed, second succeeded)
```

### 11.2 Domain Errors

**Condition**: Invalid operation for given values

**Result**: Clause fails

**Examples**:
```glp
X := 5 / 0           % FAIL: division by zero
X := 10 mod 0        % FAIL: modulo by zero
X := sqrt(-4)        % FAIL: negative square root
X := ln(0)           % FAIL: logarithm of zero
X := ln(-5)          % FAIL: logarithm of negative
```

### 11.3 SRSW Violations (Compile-Time)

**Condition**: Writer variable appears multiple times

**Result**: Compilation error

**Example**:
```glp
% INVALID: Y appears twice as writer
test(X, Y?) :-
  true |
  Y := X? + 1,      % First use of Y as writer
  Y := X? * 2.      % ERROR: Second use of Y as writer
```

**Compiler Error**: "SRSW violation: variable Y used as writer multiple times in clause body"

---

## 12. Future Extensions

### 12.1 Bitwise Operations

```glp
X := Y? /\ Z?        % Bitwise AND
X := Y? \/ Z?        % Bitwise OR
X := Y? xor Z?       % Bitwise XOR
X := ~Y?             % Bitwise NOT
X := Y? << Z?        % Left shift
X := Y? >> Z?        % Right shift
```

### 12.2 Additional Math Functions

```glp
X := floor(Y?)       % Floor
X := ceil(Y?)        % Ceiling
X := min(Y?, Z?)     % Minimum
X := max(Y?, Z?)     % Maximum
X := atan2(Y?, Z?)   % Two-argument arctangent
```

### 12.3 String Arithmetic

```glp
X := string_length(S?)      % Length of string
X := ascii(C?)              % ASCII code of character
```

### 12.4 List Arithmetic

```glp
X := length(L?)      % Length of list
```

---

## 13. Open Questions

1. **Should `:=` support complex expressions as LHS?**
   - Current: `Z := X? + Y?` (simple writer)
   - Possible: `f(Z) := X? + Y?` (structure pattern)
   - **Decision**: Keep simple for now (SRSW compatibility)

2. **Should we support parallel assignment?**
   - Syntax: `(X, Y) := (A? + 1, B? * 2)`
   - **Decision**: Defer to future extension

3. **Should arithmetic errors be catchable?**
   - FCP: Errors cause clause failure
   - Alternative: Exception mechanism
   - **Decision**: Follow FCP model (clause failure)

4. **Should we add arithmetic comparison guards?**
   - Example: `X? + Y? > 10` in guard position
   - **Decision**: Yes, but as separate feature (guard predicates)

---

## 14. References

1. **FCP Implementation**: `/home/user/FCP/Savannah/Logix/EMULATOR/emulate.c`
   - `plus` kernel (line 5454): Three-valued arithmetic in guards
   - `plusnum_reg_reg` opcode (line 2430): Optimized body arithmetic

2. **FCP Source Examples**: `/home/user/FCP/Savannah/Logix/utils.cp`
   - `compute_value/2` procedure (line 587): Expression evaluation
   - Usage examples (lines 240, 592, 1026): `:=` in body goals

3. **GLP Bytecode Spec**: `glp-bytecode-v216-complete.md`
   - Section 18.2: System predicates (including `evaluate/2`)
   - Current two-valued arithmetic via `execute/2`

4. **GLP Runtime Spec**: `glp-runtime-spec.txt`
   - SRSW variable model
   - Suspension and reactivation semantics

---

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-21 | Initial draft based on FCP analysis and GLP requirements |

---

**End of Specification**
