# GLP Book Examples Catalog

This document catalogs all code examples in "The Art of Grassroots Logic Programming" book, organized by chapter, with goals/queries for testing and a catalog of unification/activation cases.

---

## Part I: Foundations

### Chapter 1: Introduction

#### merge/3 - Fair Stream Merger
```glp
merge([X|Xs],Ys,[X?|Zs?]) :- merge(Ys?,Xs?,Zs).
merge(Xs,[Y|Ys],[Y?|Zs?]) :- merge(Xs?,Ys?,Zs).
merge([],[],[]).
```
**Goal:** `merge([1,2,3], [a,b,c], Out)`
**Expected:** `Out = [1,a,2,b,3,c]` (or fair interleaving)

---

### Chapter 2: Logic Programs

#### append/3 - List Concatenation (LP version)
```prolog
append([X|Xs], Ys, [X|Zs]) :- append(Xs, Ys, Zs).
append([], Ys, Ys).
```
**Goal:** `append([1,2], [3,4], R)`
**Expected:** `R = [1,2,3,4]`

---

### Chapter 3: GLP Core

#### Writer Unification Cases Table
| Head | Goal | Result |
|------|------|--------|
| c | c | succeeds |
| c | d | fails |
| c | X | succeeds: {X := c} |
| c | X? | suspends on {X?} |
| V | c | succeeds: {V := c} |
| V | X | succeeds: {V := X} |
| V | X? | succeeds: {V := X?} |
| V? | c | succeeds: {V := c} |
| V? | X | succeeds: {V := X} |
| V? | X? | succeeds: {V := X?} |

#### Two-Phase Unification Algorithm
For compound terms:
1. **Collection phase:** Process arguments left-to-right, accumulating tentative writer bindings and preliminary suspension set
2. **Resolution phase:** Compute S' = {X? in S : X not in dom(sigma)}. If S' = empty, succeed. Otherwise suspend on S'.

#### Worked Example: p(X?,X) against p(a,a)
- Collection: X? vs a -> add X? to S; X vs a -> add X:=a to sigma
- Resolution: S' = {X? : X not in dom({X:=a})} = {} (empty)
- Result: succeeds with {X := a}

---

### Chapter 4: Programming with Constants

#### Unary Predicates
```glp
zero(0).
one(1).
positive(1).
default_value(42?).
initial_state(ready?).
```
**Goal:** `zero(0)` -> succeeds
**Goal:** `default_value(X)` -> `X = 42`

#### successor/2
```glp
successor(0, 1?).
successor(1, 2?).
successor(2, 3?).
```
**Goal:** `successor(0, X)` -> `X = 1`

#### color_code/2
```glp
color_code(red, 1?).
color_code(green, 2?).
color_code(blue, 3?).
```
**Goal:** `color_code(red, X)` -> `X = 1`

#### combine/3
```glp
combine(red, blue, purple?).
combine(red, yellow, orange?).
combine(blue, yellow, green?).
```
**Goal:** `combine(red, blue, X)` -> `X = purple`

#### Logic Gates
```glp
and(1,1,1). and(1,0,0). and(0,1,0). and(0,0,0).
or(1,1,1). or(1,0,1). or(0,1,1). or(0,0,0).
not(1,0). not(0,1).
xor(1,1,0). xor(1,0,1). xor(0,1,1). xor(0,0,0).
```
**Goal:** `and(1,1,X)` -> `X = 1`

#### nand/3
```glp
nand(A,B,Z?) :- and(A?,B?,W), not(W?,Z).
```
**Goal:** `nand(1,1,X)` -> `X = 0`

#### half_adder/4
```glp
half_adder(A,B,Sum?,Carry?) :-
    ground(A?), ground(B?) |
    xor(A?,B?,Sum), and(A?,B?,Carry).
```
**Goal:** `half_adder(1,1,S,C)` -> `S = 0, C = 1`

#### full_adder/5
```glp
full_adder(A,B,Cin,Sum?,Cout?) :-
    half_adder(A?,B?,S1,C1),
    half_adder(S1?,Cin?,Sum,C2),
    or(C1?,C2?,Cout).
```
**Goal:** `full_adder(1,1,1,S,C)` -> `S = 1, C = 1`

#### adder/4 - Ripple-Carry Adder
```glp
adder([],[],Cin,[Cin?]).
adder([A|As],[B|Bs],Cin,[S?|Ss?]) :-
    full_adder(A?,B?,Cin?,S,Cout),
    adder(As?,Bs?,Cout?,Ss).
```
**Goal:** `adder([1,0,1],[1,1,0],0,R)` -> `R = [0,0,0,1]` (5+6=11)

---

## Part II: Programming with Streams

### Chapter 5: Streams

#### producer/2 - Countdown Producer
```glp
producer([], 0).
producer([N?|Xs?], N) :- N? > 0 | N1 := N? - 1, producer(Xs, N1?).
```
**Goal:** `producer(H, 5)` -> `H = [5,4,3,2,1]`

#### consumer/3 - Sum Consumer
```glp
consumer([], Sum, Sum?).
consumer([X|Xs], Sum, Result?) :- ground(X?) |
    Sum1 := Sum? + X?,
    consumer(Xs?, Sum1?, Result).
```
**Goal:** `producer(H, 5), consumer(H?, 0, R)` -> `R = 15`

#### reverse/2 - Naive Reverse
```glp
reverse([], []).
reverse([X|Xs], Ys?) :-
    reverse(Xs?, Zs),
    append(Zs?, [X?], Ys).
```

#### reverse/2 - Accumulator Version
```glp
reverse(Xs, Ys?) :- reverse_acc(Xs?, [], Ys).

reverse_acc([], Acc, Acc?).
reverse_acc([X|Xs], Acc, Ys?) :- reverse_acc(Xs?, [X?|Acc?], Ys).
```
**Goal:** `reverse([a,b,c], R)` -> `R = [c,b,a]`

#### merge/4 - Simple Fair Merge
```glp
merge([X|Xs], Ys, [X?|Zs?]) :- merge(Ys?, Xs?, Zs).
merge(Xs, [Y|Ys], [Y?|Zs?]) :- merge(Xs?, Ys?, Zs).
merge([], Ys, Ys?).
merge(Xs, [], Xs?).
```
**Goal:** `merge([a,b,c], [1,2,3], Out)` -> `Out = [a,1,b,2,c,3]`

#### dmerge/3 - Dynamic Merge
```glp
dmerge([merge(Ws)|Xs], Ys, Zs?) :-
    dmerger(Ws?, Xs?, Xs1), dmerge(Xs1?, Ys?, Zs).
dmerge(Xs, [merge(Ws)|Ys], Zs?) :-
    dmerger(Ws?, Ys?, Ys1), dmerge(Xs?, Ys1?, Zs).
dmerge([X|Xs], Ys, [X?|Zs?]) :-
    otherwise | dmerge(Ys?, Xs?, Zs).
dmerge(Xs, [Y|Ys], [Y?|Zs?]) :-
    otherwise | dmerge(Xs?, Ys?, Zs).
dmerge([], [], []).

dmerger(Ws, Xs, Out?) :- dmerge(Ws?, Xs?, Out).
```
**Goal:** `dmerge([a, merge([x,y]), b], [1, 2], Out)` -> `Out = [a, 1, x, 2, b, y]`

#### merge_tree/2 - Balanced Merge Tree
```glp
merge_tree([Xs], Xs?).
merge_tree([X,Y|Rest], Out?) :-
    merge_layer([X?,Y?|Rest?], Layer),
    merge_tree(Layer?, Out).

merge_layer([], []).
merge_layer([Xs], [Xs?]).
merge_layer([Xs,Ys|Rest], [Zs?|Layer?]) :-
    merge(Xs?, Ys?, Zs),
    merge_layer(Rest?, Layer).
```
**Goal:** `merge_tree([[a,b], [1,2], [x,y], [p,q]], Out)`

#### mwm/2 - Multiway Merge (Constant Delay)
```glp
mwm(In, Out?) :-
    allocate_mutual_reference(Ref, Out),
    mwm1(In?, Ref?, done, Done),
    close_when_done(Done?, Ref?).

mwm1([stream(Xs)|Streams], Ref, L, R?) :-
    is_mutual_ref(Ref?) |
    mwm_copy(Xs?, Ref?, L?, M),
    mwm1(Streams?, Ref?, M?, R).
mwm1([], _, L, L?).

mwm_copy([X|Xs], Ref, L, R?) :-
    is_mutual_ref(Ref?) |
    stream_append(X?, Ref?, Ref1),
    mwm_copy(Xs?, Ref1?, L?, R).
mwm_copy([], _, L, L?).
```
**Goal:** `mwm([stream([a,b]), stream([1,2])], Out)`

#### distribute/3 - Broadcast Distribution
```glp
distribute([X|Xs], [X?|Ys?], [X?|Zs?]) :- ground(X?) | distribute(Xs?, Ys, Zs).
distribute([], [], []).
```
**Goal:** `distribute([a,b,c], Y, Z)` -> `Y = [a,b,c], Z = [a,b,c]`

#### distribute_indexed/3 - Indexed Distribution
```glp
distribute_indexed([send(1,X)|In], [X?|Out1?], Out2) :-
    distribute_indexed(In?, Out1, Out2).
distribute_indexed([send(2,X)|In], Out1, [X?|Out2?]) :-
    distribute_indexed(In?, Out1, Out2).
distribute_indexed([], [], []).
```
**Goal:** `distribute_indexed([send(1,a), send(2,b), send(1,c)], Y, Z)` -> `Y = [a,c], Z = [b]`

#### Cooperative Stream Production
```glp
bob([a,a|Tail?], Result?) :- alice(Tail, Result).
alice([b,b,b|Tail?], Result?) :- bob_finish(Tail, Result).
bob_finish([a,a], done).
```
**Goal:** `bob(Stream, Done)` -> `Stream = [a,a,b,b,b,a,a], Done = done`

#### Difference Lists
```glp
create_dl(0, H?, H).
create_dl(N, [_|H?], T) :- N? > 0 | N1 := N? - 1, create_dl(N1?, H, T?).

list_to_dl([], T?, T).
list_to_dl([X|Xs], [X?|Ys?], T) :- list_to_dl(Xs?, Ys, T?).

close_dl(H, T, H?) :- T? = [].

append_dl(H1, T1?, T1, T2?, H1?, T2).
```
**Goal:** `list_to_dl([1,2], H, T), list_to_dl([3,4], H2, T2), append_dl(H?, T, H2?, T2, R, T3?), close_dl(R?, T3, Result)` -> `Result = [1,2,3,4]`

#### Stream Transducers
```glp
copier([], []).
copier([X|Xs], [X?|Ys?]) :- copier(Xs?, Ys).

duplicator([], []).
duplicator([X|Xs], [X?,X?|Ys?]) :- ground(X?) | duplicator(Xs?, Ys).

separator([], []).
separator([X|Xs], [X?,0|Ys?]) :- separator(Xs?, Ys).

differentiator([], []).
differentiator([_], []).
differentiator([X,Y|Xs], [D?|Ds?]) :- ground(X?), ground(Y?) |
    D := Y? - X?,
    differentiator([Y?|Xs?], Ds).

integrator(Xs, Ys?) :- integrator_acc(Xs?, 0, Ys).
integrator_acc([], _, []).
integrator_acc([X|Xs], Acc, Out?) :- ground(X?) |
    Sum := Acc? + X?,
    emit_sum(Sum?, Xs?, Out).
emit_sum(V, Xs, [V?|Ys?]) :- ground(V?) | integrator_acc(Xs?, V?, Ys).
```
**Goal:** `duplicator([1,2], Out)` -> `Out = [1,1,2,2]`
**Goal:** `differentiator([1,4,7], Out)` -> `Out = [3,3]`
**Goal:** `integrator([1,2,3,4], Out)` -> `Out = [1,3,6,10]`

#### Stream Observers
```glp
observer([X|Xs], [X?|Ys?], [X?|Zs?]) :- ground(X?) | observer(Xs?, Ys, Zs).
observer([], [], []).

observe([X|Xs], Ys?, [X?|Zs?]) :- ground(X?) |
    Ys = [X?|Ys1?], observe(Xs?, Ys1, Zs).
observe([X|Xs?], Ys, [X?|Zs?]) :- ground(X?) |
    Ys = [X?|Ys1], observe(Ys1?, Xs, Zs).
observe([], [], []).
```

---

### Chapter 6: Buffered Communication

#### Bounded Buffer Operations
```glp
send(Msg, [Msg|NBuf?], NBuf).
receive(Msg, [Msg|NBuf]--[_|NTail?], NBuf--NTail).
close([end_of_stream|_]).
closed(end_of_stream).

open(0, X--X).
open(N, [_|Y]--Z) :- N > 0 | N1 := N? - 1, open(N1?, Y--Z).
```

#### sq_num_buffered/3
```glp
sq_num_buffered(N, Ss, Size) :-
    open(Size?, Buf--Tail),
    integers(1, N?, Buf?),
    square(Buf?--Tail, Ss).

integers(I, N, Buf) :-
    I =< N |
    J := I? + 1,
    send(I?, Buf?, NBuf),
    integers(J?, N?, NBuf?).
integers(I, N, Buf) :-
    I > N |
    close(Buf?).

square(Buf, Ss) :-
    receive(I, Buf?, NBuf),
    square2(I?, NBuf?, Ss).

square2(I, _, []) :- closed(I?) | true.
square2(I, Buf, [I2|Ss?]) :-
    number(I?) |
    I2 := I? * I?,
    square(Buf?, Ss).
```

#### switch2x2/4 - Network Switch
```glp
switch2x2(In1, In2, Out1, Out2) :-
    receive(M, In1?, Ins1), send(M?, Out1?, Outs1) |
    switch2x2(Ins1?, In2?, Outs1?, Out2?).
switch2x2(In1, In2, Out1, Out2) :-
    receive(M, In2?, Ins2), send(M?, Out1?, Outs1) |
    switch2x2(In1?, Ins2?, Outs1?, Out2?).
switch2x2(In1, In2, Out1, Out2) :-
    receive(M, In1?, Ins1), send(M?, Out2?, Outs2) |
    switch2x2(Ins1?, In2?, Out1?, Outs2?).
switch2x2(In1, In2, Out1, Out2) :-
    receive(M, In2?, Ins2), send(M?, Out2?, Outs2) |
    switch2x2(In1?, Ins2?, Out1?, Outs2?).
```

---

### Chapter 7: Monitors and Stateful Servers

#### counter/1 - Counter Monitor
```glp
counter(In) :- counter_loop(In?, 0).

counter_loop([clear|In], _) :- counter_loop(In?, 0).
counter_loop([add|In], C) :- C1 := C? + 1, counter_loop(In?, C1?).
counter_loop([read(V)|In], C) :- ground(C?) | V = C?, counter_loop(In?, C?).
counter_loop([], _).
```
**Goal:** `counter([add,add,add,read(V)])` -> `V = 3`

#### queue/1 - Shared Queue Monitor
```glp
queue(In) :- queue_loop(In?, Q, Q).

queue_loop([dequeue(X)|In], H, T) :-
    H = [X|H1?],
    queue_loop(In?, H1, T?).
queue_loop([enqueue(X)|In], H, T) :-
    T = [X|T1?],
    queue_loop(In?, H?, T1).
queue_loop([], _, _).
```
**Goal:** `queue([enqueue(a), enqueue(b), dequeue(X), dequeue(Y)])` -> `X = a, Y = b`

#### duplicate/3 - For Observing Monitors
```glp
duplicate(X, X?, X?) :- ground(X?) | true.
```

#### observe_accum/3 - Type-Aware Monitor Observer
```glp
observe_accum([add(N)|In], [add(N?)|Out?], [add(N?)|Log?]) :-
    ground(N?) | observe_accum(In?, Out, Log).
observe_accum([subtract(N)|In], [subtract(N?)|Out?], [subtract(N?)|Log?]) :-
    ground(N?) | observe_accum(In?, Out, Log).
observe_accum([value(V1?)|In], [value(V)|Out?], [value(V2?)|Log?]) :-
    duplicate(V?, V1, V2),
    observe_accum(In?, Out, Log).
observe_accum([], [], []).
```

#### Four-Actor Play
```glp
alice(V, [add(10), add(5), value(V?)|Xs?]) :- alice_done(Xs).
alice_done([]).

bob(V, Ys?) :-
    wait(50) |
    Ys = [subtract(3), value(V?)|Ys1?],
    bob_done(Ys1).
bob_done([]).

carol(V, Zs?) :-
    wait(100) |
    Zs = [add(20), value(V?)|Zs1?],
    carol_done(Zs1).
carol_done([]).

diana(V, Ws?) :-
    wait(150) |
    Ws = [value(V?)|Ws1?],
    diana_done(Ws1).
diana_done([]).

play_accum(VA?, VB?, VC?, VD?, Log?) :-
    alice(VA, As), bob(VB, Bs), carol(VC, Cs), diana(VD, Ds),
    merge(As?, Bs?, AB), merge(Cs?, Ds?, CD), merge(AB?, CD?, All),
    observe_accum(All?, Reqs, Log),
    monitor(Reqs?).
```

---

## Part III: Recursive Programming

### Chapter 8: List Programming
[Placeholder - To be developed]

---

### Chapter 9: Sorting

#### insertion_sort/2
```glp
insertion_sort([], []).
insertion_sort([X|Xs], Sorted?) :-
    insertion_sort(Xs?, SortedTail),
    insert(X?, SortedTail?, Sorted).

insert(X, [], [X?]).
insert(X, [Y|Ys], [X?|[Y?|Ys?]]) :- X? < Y? | true.
insert(X, [Y|Ys], [Y?|Zs?]) :- X? >= Y? | insert(X?, Ys?, Zs).
```
**Goal:** `insertion_sort([3,1,4,1,5], R)` -> `R = [1,1,3,4,5]`

#### mergesort/2
```glp
mergesort([], []).
mergesort([X], [X?]).
mergesort(Xs, Sorted?) :-
    split(Xs?, Left, Right),
    mergesort(Left?, SortedL),
    mergesort(Right?, SortedR),
    merge_sorted(SortedL?, SortedR?, Sorted).

split([], [], []).
split([X], [X?], []).
split([X,Y|Xs], [X?|Left?], [Y?|Right?]) :- split(Xs?, Left, Right).

merge_sorted([], Ys, Ys?).
merge_sorted(Xs, [], Xs?).
merge_sorted([X|Xs], [Y|Ys], [X?|Zs?]) :-
    X? =< Y? |
    merge_sorted(Xs?, [Y?|Ys?], Zs).
merge_sorted([X|Xs], [Y|Ys], [Y?|Zs?]) :-
    Y? < X? |
    merge_sorted([X?|Xs?], Ys?, Zs).
```
**Goal:** `mergesort([3,1,4,1,5,9,2,6], R)` -> `R = [1,1,2,3,4,5,6,9]`

#### quicksort/2
```glp
quicksort(Unsorted, Sorted?) :- qsort(Unsorted?, Sorted, []).

qsort([X|Unsorted], Sorted?, Rest) :-
    number(X?) |
    partition(Unsorted?, X?, Smaller, Larger),
    qsort(Smaller?, Sorted, [X?|Sorted1?]),
    qsort(Larger?, Sorted1, Rest?).
qsort([], Rest?, Rest).

partition([X|Xs], A, Smaller?, [X?|Larger?]) :-
    A? < X? | partition(Xs?, A?, Smaller, Larger).
partition([X|Xs], A, [X?|Smaller?], Larger?) :-
    A? >= X? | partition(Xs?, A?, Smaller, Larger).
partition([], A, [], []) :- number(A?) | true.
```
**Goal:** `quicksort([3,1,4,1,5,9,2,6], R)` -> `R = [1,1,2,3,4,5,6,9]`

---

### Chapter 10: Arithmetic

#### Peano Arithmetic
```glp
plus(0, Y, Y?).
plus(s(X), Y, s(Z?)) :- plus(X?, Y?, Z).

times(0, _, 0).
times(s(X), Y, Z?) :- times(X?, Y?, P), plus(Y?, P?, Z).

less(0, s(_)).
less(s(X), s(Y)) :- less(X?, Y?).
```
**Goal:** `plus(s(s(0)), s(s(s(0))), R)` -> `R = s(s(s(s(s(0)))))` (2+3=5)

#### factorial/2
```glp
factorial(0, 1).
factorial(N, F?) :-
    N? > 0 |
    N1 := N? - 1,
    factorial(N1?, F1),
    F := N? * F1?.

%% Tail-recursive version
factorial(N, F?) :- fact_acc(N?, 1, F).

fact_acc(0, Acc, Acc?).
fact_acc(N, Acc, F?) :-
    N? > 0 |
    Acc1 := Acc? * N?,
    N1 := N? - 1,
    fact_acc(N1?, Acc1?, F).
```
**Goal:** `factorial(5, F)` -> `F = 120`

#### fib/2 - Fibonacci
```glp
fib(0, 0).
fib(1, 1).
fib(N, F?) :-
    N? > 1 |
    N1 := N? - 1,
    N2 := N? - 2,
    fib(N1?, F1),
    fib(N2?, F2),
    F := F1? + F2?.

%% Linear version
fib_linear(N, F?) :- fib_acc(N?, 0, 1, F).

fib_acc(0, A, _, A?).
fib_acc(N, A, B, F?) :-
    N? > 0 |
    N1 := N? - 1,
    AB := A? + B?,
    fib_acc(N1?, B?, AB?, F).
```
**Goal:** `fib(10, F)` -> `F = 55`
**Goal:** `fib_linear(10, F)` -> `F = 55`

#### flatten/2
```glp
flatten(Xs, Ys?) :- flatten_dl(Xs?, Ys, []).

flatten_dl([], Front?, Front).
flatten_dl([X|Xs], Front?, Back) :-
    ground(X?), is_list(X?) |
    flatten_dl(X?, Front, Mid?),
    flatten_dl(Xs?, Mid, Back?).
flatten_dl([X|Xs], [X?|Front?], Back) :-
    otherwise |
    flatten_dl(Xs?, Front, Back?).
```
**Goal:** `flatten([[1,2],[3,[4,5]],6], F)` -> `F = [1,2,3,4,5,6]`

#### Binary Tree Operations
```glp
in_order(empty, []).
in_order(node(V, L, R), Vs?) :-
    in_order(L?, Ls),
    in_order(R?, Rs),
    append(Ls?, [V?|Rs?], Vs).

tree_sum(empty, 0).
tree_sum(node(V, L, R), S?) :-
    tree_sum(L?, SL),
    tree_sum(R?, SR),
    S := V? + SL? + SR?.

tree_height(empty, 0).
tree_height(node(_, L, R), H?) :-
    tree_height(L?, HL),
    tree_height(R?, HR),
    H := 1 + max(HL?, HR?).

bst_member(V, node(V, _, _)).
bst_member(V, node(N, L, _)) :- V? < N? | bst_member(V?, L?).
bst_member(V, node(N, _, R)) :- V? > N? | bst_member(V?, R?).

bst_insert(V, empty, node(V?, empty, empty)).
bst_insert(V, node(N, L, R), node(N?, L1?, R?)) :-
    V? < N? |
    bst_insert(V?, L?, L1).
bst_insert(V, node(N, L, R), node(N?, L?, R1?)) :-
    V? > N? |
    bst_insert(V?, R?, R1).
bst_insert(V, node(V, L, R), node(V?, L?, R?)).
```

#### gcd/3 (Exercise)
```glp
gcd(X, 0, X?).
gcd(X, Y, G?) :- Y? > 0 | R := X? mod Y?, gcd(Y?, R?, G).
```
**Goal:** `gcd(48, 18, G)` -> `G = 6`

---

## Part IV: Objects and Processes

### Chapter 11: Objects and Processes

#### Object Pattern
```glp
object(State, [Msg | Msgs?], Responses?) :-
    handle(Msg?, State?, NewState, Response),
    Responses = [Response? | RestResponses?],
    object(NewState?, Msgs?, RestResponses).
```

#### counter/2 - Counter Object
```glp
counter([clear|S?], _) :-
    counter(S?, 0).
counter([up|S?], State) :-
    NewState := State? + 1,
    counter(S?, NewState?).
counter([down|S?], State) :-
    NewState := State? - 1,
    counter(S?, NewState?).
counter([show(State?)|S?], State) :-
    counter(S?, State?).
counter([], _).
```
**Goal:** `counter([up,up,up,show(V)])` -> `V = 3`

#### qm/3 - Queue Manager
```glp
qm([dequeue(X)|S?], [X|Head?], Tail) :-
    qm(S?, Head?, Tail?).

qm([enqueue(X)|S?], Head, [X|Tail?]) :-
    qm(S?, Head?, Tail?).
```

#### Multiple Counter Instances
```glp
use_many_counters([create(Name)|Input?], List_of_counters) :-
    counter(Com?, 0),
    use_many_counters(Input?, [(Name?, Com)|List_of_counters?]).

use_many_counters([(Name, Cmd)|Input?], List_of_counters) :-
    send(List_of_counters?, Name?, Cmd?, NewList) |
    use_many_counters(Input?, NewList?).

send([(Name, [Message|Y?])|List?], Name, Message, [(Name?, Y)|List]).
send([C|List?], Name, Message, [C?|L1?]) :-
    send(List?, Name?, Message?, L1).
```

---

### Chapter 12: Inheritance and Delegation
[Placeholder - To be developed]

---

## Part V: Metaprogramming

### Chapter 13: Metaprogramming

#### Vanilla Meta-Interpreter
```glp
solve(true).
solve((A, B)) :- solve(A), solve(B).
solve(A) :- clause(A, B), solve(B).
```

#### GLP Plain Meta-Interpreter
```glp
run(true).
run((A,B)) :- run(A?), run(B?).
run(A) :- known(A) | reduce(A?,B), run(B?).
```

#### reduce/2 Encoding
```glp
reduce(merge([X|Xs],Ys,[X?|Zs?]), merge(Xs?,Ys?,Zs)).
reduce(merge(Xs,[Y|Ys],[Y?|Zs?]), merge(Xs?,Ys?,Zs)).
reduce(merge([],[],[]), true).
```
**Goal:** `run(merge([1,2],[3,4],Z))` -> `Z` is merged list

#### Fail-Safe Meta-Interpreter
```glp
run(true, []).
run((A,B), Zs?) :-
    run(A?, Xs), run(B?, Ys),
    merge(Xs?, Ys?, Zs).
run(fail(A), [fail(A?)]).
run(A, Xs?) :- known(A) | reduce(A?,B), run(B?,Xs).
```

#### Termination Detection (Short-Circuit)
```glp
reduce(P, true, Chain--Chain?).
reduce(P, (A, B), Left--Right) :-
    reduce(P?, A?, Left?--Middle),
    reduce(P?, B?, Middle?--Right).
reduce(P, Goal, Left--Right) :-
    Goal =\= true, Goal =\= (_, _),
    clause(Goal?, P?, Body) |
    reduce(P?, Body?, Left?--Right).
```

---

### Chapter 14: Enhanced Metaprogramming

#### Tracing Meta-Interpreter
```glp
run(true, true).
run((A,B), (TA?,TB?)) :- run(A?,TA), run(B?,TB).
run(A, ((I?:Time?):-TB?)) :- known(A) |
    time(Time), reduce(A?,B,I), run(B?, TB).
```

#### Control Meta-Interpreter
```glp
run(true, _).
run((A,B), Cs) :-
    distribute(Cs?,Cs1,Cs2),
    run(A?,Cs1?), run(B?,Cs2?).
run(A, [suspend|Cs]) :- suspended_run(A,Cs?).
run(A, Cs) :- known(A) |
    distribute(Cs?,Cs1,Cs2),
    reduce(A?,B,Cs1?), run(B?,Cs2?).

suspended_run(A, [resume|Cs]) :- run(A,Cs?).
suspended_run(A, [abort|_]).
```

#### Snapshot Collection
```glp
suspended_run(A, [resume|Cs], L, R?) :- run(A,Cs?,L?,R).
suspended_run(A, [abort|_], L, [A?|L?]).
```

#### Debugger Meta-Interpreter
```glp
debug(true, _, _, true).
debug((A,B), Cs, Budget, (TA?,TB?)) :-
    distribute(Cs?, Cs1, Cs2),
    split_budget(Budget?, B1, B2),
    debug(A?, Cs1?, B1?, TA),
    debug(B?, Cs2?, B2?, TB).
debug(A, [step|Cs], Budget, ((I?:A?):-TB?)) :-
    Budget? > 0, known(A) |
    B1 := Budget? - 1,
    reduce(A?,B,I),
    debug(B?, Cs?, B1?, TB).
debug(A, [suspend|Cs], Budget, Trace?) :-
    suspended_debug(A, Cs?, Budget?, Trace).
```

---

### Chapter 15: Debugging and Development Tools
[Placeholder - To be developed]

---

## Part VI: Grassroots Protocols

### Chapter 16: The Grassroots Social Graph
[Placeholder - To be developed]

### Chapter 17: Befriending Protocols
[Placeholder - To be developed]

### Chapter 18: Grassroots Social Networking

#### Channels (Generalized Streams)
```glp
read(Message, [Message|Channel?], Channel).
read(Message, branch(Left1, Right?), branch(Left2, Right)) :-
    read(Message?, Left1?, Left2).
read(Message, branch(Left?, Right1), branch(Left, Right2)) :-
    read(Message?, Right1?, Right2).

write(Message, Channel, Left) :-
    Channel = branch([Message|Left?], _) | true.
write(Message, Channel, Out) :-
    Channel? = branch(_, Right?) |
    write(Message?, Right?, Out).

empty([]).
empty(branch(Left, Right)) :-
    empty(Left?), empty(Right?) | true.

serialize(Channel, [Message|Stream?]) :-
    min(Message?, Channel?, Channel2) |
    serialize(Channel2?, Stream).
serialize(Channel, Stream) :-
    branches(Channel?, C1, C2) |
    serialize(C1?, S1),
    serialize(C2?, S2),
    merge(S1?, S2?, Stream).
serialize(Channel, []) :-
    empty(Channel?) | true.
```

### Chapter 19: Security
[Placeholder - To be developed]

---

## Catalog of Unification/Activation Cases

### Already Documented in Book

| Case | Location | First Use |
|------|----------|-----------|
| Atomic term unification (constants) | glp_core.tex Table | constants.tex |
| Compound term / two-phase algorithm | glp_core.tex | streams.tex (merge) |
| Writer-to-writer failure | glp_core.tex | streams.tex (observe) |

### Cases Needing Documentation

| Case | Description | First Use |
|------|-------------|-----------|
| Body activation (parallel spawn) | When `run((A,B))` spawns concurrent processes | plain_meta.tex |
| Difference list threading | Unification pattern for O(1) append | streams.tex (append_dl) |
| Guard evaluation | When/how guards suspend or commit | constants.tex (logic gates) |
| Incomplete messages | Variable passed in message, filled by server | monitors.tex (counter read) |
| Short-circuit termination | Difference list for termination detection | plain_meta.tex |

---

## Programs NOT YET in Book

These programs exist in `/home/user/GLP/AofGLP/` but are not incorporated in the book:

### 1. Logic Gates (11_logic_gates/gates)
- File: `gates.glp`
- Description: AND/OR gate simulation on bit streams
- Potential chapter: constants.tex or new hardware simulation chapter

### 2. Tower of Hanoi (12_puzzles/hanoi)
- File: `hanoi.glp`
- Description: Classic recursive puzzle
- Potential chapter: arithmetic.tex or new puzzles chapter

### 3. Constraint Objects (14_objects/constraints)
- Directory: `14_objects/constraints/`
- Description: Constraint propagation using objects
- Potential chapter: objects.tex

### 4. Frame-Based Inheritance (14_objects/inheritance)
- Directory: `14_objects/inheritance/`
- Description: Prototype/frame-based inheritance patterns
- Potential chapter: inheritance.tex (currently placeholder)

### 5. Blocklace / Interlaced Streams (21_social_networking/blocklace)
- File: `interlaced_streams.glp`
- Description: Distributed blocklace data structure
- Potential chapter: networking.tex

### 6. Non-Ground Term Replication (21_social_networking/replication)
- File: `replicate.glp`
- Description: Replicating terms with unbound variables
- Potential chapter: networking.tex

---

## Usage Notes for Claude Web

1. **For each example:** Identify which goal/head unifications occur and which body activations occur
2. **Check if any case is new:** Compare against the catalog above
3. **If new:** Draft explanation text to add at the first use point
4. **Update catalog:** Add to "First Use" column

### Key Questions to Answer for Each Example:
- Does it use atomic unification? Compound term unification?
- Does it use the two-phase algorithm (reader before its paired writer)?
- Does it spawn parallel processes (conjunction in body)?
- Does it use difference lists?
- Does it use guards? Which guards?
- Does it use incomplete messages?
