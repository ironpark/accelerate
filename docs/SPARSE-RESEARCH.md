# Accelerate Sparse Solvers — binding feasibility

Research note, 2026-08-20. Investigates whether `Accelerate/Sparse/Solve.h`
("Sparse Solvers") can be bound from Zig the same way `vdsp`, `vforce` and
`vimage` are.

**Conclusion: yes, and the whole surface is reachable — but not by the route the
other three modules use.** The public API is `static inline`, so there is
nothing to link against. Bindings must target the underscore-prefixed
implementation symbols that the inline wrappers dispatch to, and re-implement
the wrappers' argument validation in Zig. Every claim below was checked by
running code, not by reading the header; the probes are reproduced at the end.

Header paths are relative to
`…/vecLib.framework/Versions/A/Headers/Sparse/` in the macOS 15.4 SDK.

---

## 1. There are two unrelated "sparse" APIs. Only one is worth binding.

| | `Sparse/BLAS.h` | `Sparse/Solve.h` |
|---|---|---|
| Matrix type | opaque handle (`sparse_matrix_double`) | transparent struct (block CSC) |
| Symbols | 69, plain `extern "C"` | see §2 |
| Solvers | triangular solve only | Cholesky, LDL^T (4 pivoting modes), QR, CG, GMRES, LSMR |
| Status | superseded; Apple's docs steer to `Solve.h` | current |

`BLAS.h` is trivially bindable — it is ordinary C — but it does not solve
general systems. "Sparse Solvers" in the question means `Solve.h`, and the rest
of this note is about that.

Note that `Sparse/Sparse.h` includes only `Types.h` and `BLAS.h`. `Solve.h` is
**not** reachable through it; it comes in via `Accelerate/Accelerate.h`.

---

## 2. The public API has no symbols. This is the whole problem.

Every public entry point is declared:

```c
#define SPARSE_PUBLIC_INTERFACE __attribute__((overloadable))   // Solve.h:235

static inline SPARSE_PUBLIC_INTERFACE
void SparseSolve(SparseOpaqueFactorization_Double Factored,
                 DenseMatrix_Double B, DenseMatrix_Double X) { … }
```

`static inline` means each C translation unit gets its own copy. There is no
`SparseSolve` in the dylib for a Zig `extern fn` to resolve. Two consequences:

**`@cImport` cannot be used at all.** `__attribute__((overloadable))` lets one
name be declared many times; Zig has no overloading, and translate-c gives up on
the second declaration:

```
./ov.h:2:49: error: redefinition of 'f'
__attribute__((overloadable)) static inline int f(double x) { … }
```

This is not specific to Accelerate — it is a plain translate-c limitation, and
it kills the whole header, since `SparseSolve` alone has 78 overloads.

**The real entry points are the `_Sparse*` functions.** `libSparse.tbd` exports
61 of them, and they are declared — as `extern`, in the public SDK headers
`SolveImplementation.h` and `SolveImplementationTyped.h`, under
`API_AVAILABLE(macos(10.13), …)`:

```c
extern SparseOpaqueFactorization_Double _SparseFactorSymmetric_Double(
    SparseFactorization_t factorType,
    const SparseMatrix_Double *Matrix,
    const SparseSymbolicFactorOptions *sfoptions,
    const SparseNumericFactorOptions *nfoptions);
```

The inline wrappers are thin: validate arguments, size and `malloc` a workspace,
call one `_Sparse*` function, `free`. Zig binds the `_Sparse*` symbol and
re-implements the wrapper. That is the entire strategy.

### The caveat, stated plainly

These headers open with `#error "Do not include this header directly."` and the
symbols are spelled as private. Against that:

- They are declared in a shipped public SDK header, not reverse-engineered.
- They carry `API_AVAILABLE` availability annotations back to macOS 10.13.
- They are load-bearing ABI: every binary that ever compiled `SparseSolve()`
  inlined a call to them, so Apple cannot remove or re-signature them without
  breaking already-shipped apps.

So the risk is real but bounded, and it is the *same* risk every existing
non-C/C++ consumer of this API carries — there is no alternative route. It
should be documented in the module rather than hidden.

---

## 3. Every type maps to Zig with no ABI trickery

Checked by compiling a C program against the real headers and asserting the same
numbers from Zig (`test "layout"`, §7). All matched on arm64:

| C type | size | Zig |
|---|---|---|
| `SparseAttributes_t` | 4 | `packed struct(u32)` — same shape as `vimage.Options` |
| `SparseMatrixStructure` | 32 | `extern struct` |
| `SparseMatrix_Double` | 40 | `extern struct` |
| `DenseVector_Double` | 16 | `extern struct` |
| `DenseMatrix_Double` | 24 | `extern struct` |
| `SparseSymbolicFactorOptions` | 48 | `extern struct` (2 fn ptrs + 1 nullable) |
| `SparseNumericFactorOptions` | 32 | `extern struct` |
| `SparseOpaqueSymbolicFactorization` | 64 | `extern struct` |
| `SparseOpaqueFactorization_Double` | 104 | `extern struct` |
| `SparseOpaqueSubfactor_Double` | 128 | `extern struct` |
| `SparseIterativeMethod` | 264 | `extern struct` w/ `extern union` |

No bitfield beyond `SparseAttributes_t`, no unions needing care except the
256-byte-padded `SparseIterativeMethod.options`, no struct-return quirks —
`_SparseFactorSymmetric_Double` returns 104 bytes by value and Zig's C ABI
handles the indirect return correctly (proven in §7).

`sparse_index`/`sparse_dimension` from `Types.h` belong to the *other* API;
`Solve.h` uses plain `int` for counts and `long` for `columnStarts`.

---

## 4. The iterative solvers require an Objective-C block. Zig can build one.

This was the one finding that could have blocked the project, so it was checked
first. All six iterative entry points take a **mandatory `_Nonnull` block**:

```c
extern SparseIterativeStatus_t _SparseCGSolve_Double(
    const SparseCGOptions *options,
    DenseMatrix_Double *X, DenseMatrix_Double *B,
    void (^_Nonnull ApplyOperator)(bool, enum CBLAS_TRANSPOSE,
                                   DenseMatrix_Double, DenseMatrix_Double),
    const SparseOpaquePreconditioner_Double *_Nullable);
```

There is no block-free variant — the matrix-taking `SparseSolve(method, A, b, x)`
overloads construct the block inside the inline wrapper.

Zig has no block syntax, but a block is just a struct with a documented layout
(`Block_private.h`). A ~20-line `extern struct` with `isa = &_NSConcreteStackBlock`
and a `callconv(.c)` `invoke` is enough. **This works** — CG converged to the
right answer through a hand-built block (§7). The captured context can be
anything, which means the Zig API can accept a plain function pointer, or a
matrix, or a closure struct, and hide the block entirely.

Two details worth pinning in tests if this is built: the block must not be
assumed non-escaping (give the descriptor a correct `size` so `Block_copy` is
safe), and `flags = 0` with a stack `isa` was sufficient — no signature string
was needed.

---

## 5. One function needs its C++-mangled name

`SparseGetInertia` (Solve.h:2416, 2445) is `overloadable` but **not**
`static inline`, so it exists out-of-line — and therefore only under a mangled
symbol. Binding it works:

```zig
extern fn @"_Z16SparseGetInertia32SparseOpaqueFactorization_DoublePiS0_S0_"(
    Factored: OpaqueFactorizationD,
    num_positive: *c_int, num_zero: *c_int, num_negative: *c_int,
) c_int;
```

Verified against `diag(2, -3, 4, -5)` → `pos=2 zero=0 neg=2` (§7).

This is more fragile than the `_Sparse*` route — the mangling encodes the struct
*names*, so a renamed type would break it — and it applies to exactly this one
function. `SparseCreateSubfactor` looked similar but is pure inline over
`_SparseGetWorkspaceRequired_*`, so it needs no mangled symbol.

---

## 6. Scope, and where it fits this library

The 208 declarations in `Solve.h` collapse hard in Zig. They are
`float`×`double` (→ one `comptime T`), `DenseVector`×`DenseMatrix` (→ one type,
or a slice), and with-workspace × without-workspace (→ one function taking an
`Allocator`). Estimate: **~30 public Zig functions**, on the order of
`src/vimage/conversion.zig`.

Three places where a Zig binding is meaningfully better than the C API, not just
a translation:

- **Workspace sizing is exposed as struct fields**
  (`solveWorkspaceRequiredStatic + nrhs * solveWorkspaceRequiredPerRHS`), so the
  scratch allocation the C wrappers hide behind `malloc` becomes an ordinary
  `std.mem.Allocator` parameter.
- ~~**`SparseSymbolicFactorOptions` takes `malloc`/`free` function pointers**, so
  the *solver's internal* allocations are redirectable too.~~ **Withdrawn.** The
  hooks have the signatures `void *(*)(size_t)` and `void (*)(void *)` - no
  context parameter on either. There is nowhere to put a `std.mem.Allocator`,
  so routing them would need a process-global, which is worse than libc.
  Implementation passes libc's and says so.
- **Errors currently trap.** With `options.reportError == NULL` the C macros call
  `_SparseTrap()` — `__builtin_trap()`. A `sparse.Error` error set in the style of
  `vimage.Error` turns an abort into a `try`, and the `status` fields
  (`SparseStatusOK`, `SparseMatrixIsSingular`, …) are already there to map from.

CSC/block-CSC construction is the other design question: `SparseConvertFromCoordinate`
handles COO input and is the friendly entry point, but the raw
`columnStarts`/`rowIndices` form is what most callers already have.

### Status

**All three stages are implemented** in `src/sparse/`. The staging below was
the original plan and is kept for the reasoning; the risk ordering it describes
turned out to be right - the block shim in stage 3 was the only part that could
have failed outright, and it did not.

Two things the research note did not predict, both found during
implementation and both now pinned by tests:

- `Solve.h`'s description of the `PLPS` round-trip order is **wrong**; the
  measured order is the opposite of the documented one.
- The iterative solvers route *ordinary* outcomes ("Exceeded maximum iteration
  limit.") through the `reportError` callback, not just parameter errors - so
  a binding that treats any reported message as failure turns non-convergence
  into an error.

1. **Direct solvers** — Cholesky / LDL^T / QR, factor → solve → cleanup, plus
   `SparseMultiply`. Entirely block-free, all `_Sparse*` symbols, lowest risk.
   This is the part most people mean by "sparse solver".
2. **Subfactors and inertia** — `SparseCreateSubfactor`, `SparseGetInertia`
   (mangled symbol), refactorization.
3. **Iterative solvers** — CG / GMRES / LSMR, needs the block shim from §4.

---

## 7. Reproducing the probes

Four independent checks, all run on macOS 15.4 / arm64, Zig 0.16. As with the
FFT thread-safety work, the platform-independence of these results is an
assumption: the ABI facts should hold on any Apple platform, but only arm64
macOS was measured.

**Layouts.** A C program prints `sizeof`/`offsetof` for all 11 types against the
real headers; the Zig `test "layout"` asserts the same constants. Both agree.

**Direct solve.** 4×4 SPD system in lower-triangular CSC, Cholesky via
`_SparseFactorSymmetric_Double`, solved via `_SparseSolveOpaque_Double` with a
Zig-allocated 32-byte workspace:

```
workspace = 32 bytes; x = { 1, 1.9999999999999996, 3.0000000000000013, 3.999999999999999 }
```

**Iterative solve.** Same system through `_SparseCGSolve_Double` with a
hand-built block: `status = 0` (converged), `x` correct to 1e-9.

**Inertia.** `diag(2, -3, 4, -5)` factored LDL^T, then the mangled
`SparseGetInertia` → `pos=2 zero=0 neg=2`.

The probe sources are not checked in; they are ~250 lines total and are quicker
to rewrite from this note than to maintain. If step 1 above is undertaken, the
layout assertions in particular should become permanent tests, so the ABI
assumptions are re-checked on every platform that runs the suite — the same
reasoning that put the FFT setup-immutability check in `src/vdsp/fft.zig`.
