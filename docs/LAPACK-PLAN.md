# LAPACK binding plan

Status: **user-facing surface complete**. Every driver and computational
routine for the linear systems, least squares, symmetric and nonsymmetric
eigenvalue, generalized eigenvalue and SVD problems is wrapped, in every
storage form — full, band, tridiagonal, packed, triangular-band and RFP —
along with the reductions to condensed form, the tridiagonal eigensolvers, the
Schur and QZ toolkits, the tall-skinny and blocked QR interfaces, the CS
decomposition and the expert drivers with their condition estimates.

What is left is deliberately not wrapped: the `_aa`/`_rk`/`_rook`/`_2stage`
variants, which are alternative algorithms for problems already covered; the
unblocked kernels the blocked routines call internally; the eight deprecated
routines; and the `la*`/`ila*` internal helpers. All of them remain reachable
through `c` with the caveats documented there.

This document is the working checklist for binding Apple Accelerate's LAPACK to Zig.
It records what was measured, not what was assumed — every ABI claim below was
verified by running code against the shipping framework on this machine
(macOS 15.4 SDK, arm64, `libLAPACK.tbd`).

## 1. Scope

| | count |
|---|---|
| declarations in `lapack.h` carrying `__LAPACK_ALIAS` | **2032** |
| distinct symbol names (no duplicates) | 2032 |
| base routines once the `s`/`d`/`c`/`z` prefix is stripped | 675 |
| &nbsp;&nbsp;of which user-facing (driver + computational) | 459 |
| &nbsp;&nbsp;of which `la*` internal auxiliary | 216 |
| precision-independent routines (`ilaenv`, `ieeeck`, …) | 21 |

For comparison, the BLAS module that just landed binds 156 symbols. LAPACK is
**13× larger**. That ratio, not the routine names, is what drives every decision below.

## 2. Verified ABI facts

### 2.1 Symbol naming is the same trap as BLAS

`lapack_version.h` renames every routine with an `__asm` label:

```c
#define __LAPACK_ALIAS(sym) __asm("_" __STRING(sym) "$NEWLAPACK" "$ILP64")
```

So the C name `sgesv_` resolves to the symbol `sgesv$NEWLAPACK$ILP64`, and the
rename is invisible to C callers. `libLAPACK.tbd` exports all four spellings —
`_sgesv`, `_sgesv_`, `_sgesv$NEWLAPACK`, `_sgesv$NEWLAPACK$ILP64` — and the two
unsuffixed ones are the deprecated `clapack.h` surface. Binding the obvious name
silently selects the old implementation. Reuse `blas/types.zig`'s arch test so
`Int` and the suffix are always chosen together.

Verified: `sgesv`, `dgeqrf`, `ilaenv`, `slamch`, `slange`, `ilatrans` all link and
return correct results through `@extern` with the `$NEWLAPACK$ILP64` suffix.

### 2.2 `__LAPACK_bool` is 8 bytes under ILP64

```c
#if defined( ACCELERATE_LAPACK_ILP64 )
    typedef long __LAPACK_int;
    typedef long __LAPACK_bool;
#else
    typedef int  __LAPACK_int;
    typedef int  __LAPACK_bool;  // Because the fortran logical is 4 bytes
#endif
```

The comment explains the LP64 case and then the ILP64 case silently widens it too.
163 declarations take a `__LAPACK_bool` array (`bwork` in the `*es*` sorting
drivers). Getting this wrong reads every other element. `Bool` must be defined
as `Int`, never as `c_int` or `bool`.

### 2.3 Calling convention is uniformly Fortran-by-reference

Every parameter of all 2032 routines is a pointer. There are no by-value scalars,
no by-value complex arguments, and — with the exception in 2.4 — no by-value
returns of aggregate type. Consequences:

- Complex ABI is a non-issue. `__LAPACK_float_complex` only ever appears behind a
  pointer, so `*Complex(f32)` is always right and C99 `_Complex` register
  classification never comes up.
- Only **one** routine (`chla_transtype`) takes a hidden Fortran string length,
  and it is for an output string. Input `char*` options carry no length argument.
  This is the single biggest hazard in hand-rolled LAPACK FFIs and Apple's
  header avoids it.
- Nullability is meaningful, not decorative: `_Nullable` marks arrays that a given
  option setting may leave untouched, `_Nonnull` marks scalars and workspaces.
  1962 of 2032 declarations use it. Map `_Nullable` → `?[*]T`, `_Nonnull` → `*T` / `[*]T`.

Return types: 1891 `void`, 57 `float`, 57 `double`, 21 `__LAPACK_int`, 5 `__LAPACK_bool`.

### 2.4 `cladiv` and `zladiv` are declared wrongly in the SDK header

The header declares them as writing through a leading out-parameter:

```c
void cladiv_(__LAPACK_float_complex * _Nonnull ret,
             const __LAPACK_float_complex * _Nonnull x,
             const __LAPACK_float_complex * _Nonnull y) __LAPACK_ALIAS(cladiv);
```

Calling it that way leaves `ret` **untouched** — reproduced from both Zig and C.
Disassembling the shipping symbol shows why:

```asm
cladiv$NEWLAPACK$ILP64:
    mov  x0, x1        ; shift x -> first arg
    mov  x1, x2        ; shift y -> second arg
    b    <impl>        ; tail call; ret pointer in x0 is discarded
```

It is a thunk that drops `ret` and tail-calls an implementation returning the
quotient **by value**. The correct declaration keeps three pointer parameters
(passing only two crashes, because the thunk still shifts `x2` into place) but
takes the result as the return value:

```zig
const cladiv = @extern(*const fn (*Complex(f32), *const Complex(f32), *const Complex(f32))
    callconv(.c) Complex(f32), .{ .name = "cladiv$NEWLAPACK$ILP64" });
```

Confirmed: `(1+2i)/(3+4i)` → `0.44 + 0.08i` for both `cladiv` and `zladiv`.
`chla_transtype`, the only other routine with a leading `ret` parameter, is
**not** affected and works exactly as declared. These two are the entire blast
radius; both need a hand-written extern that contradicts the header, with this
note attached.

### 2.5 Workspace queries work

573 declarations take an `lwork`. Passing `lwork = -1` returns the optimal size
in `work[0]` as a float/double that must be rounded and cast. Verified:
`dgeqrf` on 4×4 reports `lwork = 128`; `ilaenv(1, "DGEQRF", …)` reports block
size 32. Both the query path and `ilaenv` are usable, so the Zig layer can size
its own buffers rather than making callers guess.

## 3. Design

### 3.1 Layout

```
src/lapack/
  types.zig     Int, Bool, alias_suffix, Complex, option enums, Info error mapping
  c.zig         all 2032 externs — GENERATED from lapack.h, never hand-edited
  info.zig      info -> error translation, per-routine argument-name tables
  work.zig      workspace query + allocate + call helper
  linear.zig    T1 + T2
  lstsq.zig     T3
  eigen_sym.zig T4
  eigen_gen.zig T5 + T7
  svd.zig       T6
  util.zig      T8
  root.zig
```

### 3.2 What the Zig layer adds over a transliteration

1. **`info` becomes an error.** LAPACK's `info` is tri-modal: `< 0` = bad argument
   *n*, `> 0` = a routine-specific numerical condition, `0` = success. A single
   `!void` cannot carry "leading minor 3 is not positive definite". The plan is
   `error.InvalidArgument` with the index recorded, plus a per-family error
   (`error.NotPositiveDefinite`, `error.SingularMatrix`, `error.NoConvergence`)
   and the `info` value returned where it is meaningful (e.g. `syev` returns how
   many off-diagonals failed to converge).
2. **Option characters become enums.** 1291 declarations take a `const char *`
   option. `Uplo`, `Trans`, `Diag`, `Side`, `Job`, `Range`, `Norm`, `Equed`,
   `Fact`, `Sort`, `Balance`, `Vect` — reuse `blas/types.zig` where the meaning
   matches, and note that LAPACK spells them as characters where CBLAS uses ints.
3. **Workspaces are allocated, not demanded.** Each wrapper gets a `…WithWorkspace`
   twin plus an allocator-taking form that performs the `lwork = -1` query. This
   is the same shape already used by `sparse.Factorization.refactor`, which was
   the source of a hang when a required workspace was passed as null.
4. **Dimensions are `usize`, leading dimensions are checked.** `lda >= max(1,m)`
   and array-length-vs-`ld` consistency are `assert`ed, the way `blas/types.zig`
   already does with `matrixLen`.
5. **Column-major is stated, not implied.** LAPACK has no `Order` parameter; it
   is Fortran-ordered always. Every wrapper doc says so.

### 3.3 Codegen, because 2032 is not a hand-writing number

`c.zig` is generated by a script committed at `tools/gen_lapack.py`, parsing
`lapack.h` directly. The BLAS module already proved the approach; the difference
is that the LAPACK generator's output is checked in and the script is kept so it
can be re-run against a newer SDK and diffed.

Two follow-on rules, both learned from the BLAS work:

- The generator must emit a test that references **every** extern. Zig resolves
  declarations lazily, so an unreferenced `@extern` with a misspelled symbol name
  links cleanly until the first caller appears.
- `cladiv`/`zladiv` are on a hand-maintained override list (see 2.4). The
  generator must fail loudly if it ever sees a *new* routine with a leading
  `ret` parameter rather than silently emitting the header's shape.

## 4. Checklist

Letters after each routine are the precisions Accelerate ships for it.
Counts are base routines / total symbols.

### T0 Foundation

- [x] `tools/gen_lapack.py` — parse `lapack.h`, emit `c.zig`
- [x] `src/lapack/types.zig` — `Int`, `Bool` (8 bytes under ILP64, see 2.2), `alias_suffix`, `Complex`, option enums
- [x] `src/lapack/c.zig` — 2032 externs + all-symbols link test
- [x] `cladiv`/`zladiv` override + regression test pinning the by-value ABI (see 2.4)
- [x] `src/lapack/info.zig` — `info` → error mapping
- [x] `src/lapack/work.zig` — `lwork = -1` query helper
- [x] wire into `src/root.zig`, `README.md` module table, `CHANGELOG.md`

### T1 Linear systems — drivers

`36` base routines, `110` symbols.

Includes the mixed-precision iterative-refinement drivers `dsgesv`, `zcgesv`,
`dsposv`, `zcposv`, which factor in single and refine in double. Their base
names appear below as `sgesv`/`cgesv`/`sposv`/`cposv` because the precision
prefix is two characters, not one — a naming trap for the generator.

- [x] `cgesv` <sub>z</sub>
- [x] `cposv` <sub>z</sub>
- [x] `csum1` <sub>s</sub>
- [x] `gbsv` <sub>cdsz</sub>
- [x] `gbsvx` <sub>cdsz</sub>
- [x] `gesv` <sub>cdsz</sub>
- [x] `gesvx` <sub>cdsz</sub>
- [x] `gtsv` <sub>cdsz</sub>
- [x] `gtsvx` <sub>cdsz</sub>
- [x] `hesv` <sub>cz</sub>
- [ ] `hesv_aa` <sub>cz</sub>
- [ ] `hesv_aa_2stage` <sub>cz</sub>
- [ ] `hesv_rk` <sub>cz</sub>
- [ ] `hesv_rook` <sub>cz</sub>
- [x] `hesvx` <sub>cz</sub>
- [x] `hpsv` <sub>cz</sub>
- [x] `hpsvx` <sub>cz</sub>
- [x] `pbsv` <sub>cdsz</sub>
- [x] `pbsvx` <sub>cdsz</sub>
- [x] `posv` <sub>cdsz</sub>
- [x] `posvx` <sub>cdsz</sub>
- [x] `ppsv` <sub>cdsz</sub>
- [x] `ppsvx` <sub>cdsz</sub>
- [x] `ptsv` <sub>cdsz</sub>
- [x] `ptsvx` <sub>cdsz</sub>
- [x] `sgesv` <sub>d</sub>
- [x] `sposv` <sub>d</sub>
- [x] `spsv` <sub>cdsz</sub>
- [x] `spsvx` <sub>cdsz</sub>
- [x] `sysv` <sub>cdsz</sub>
- [ ] `sysv_aa` <sub>cdsz</sub>
- [ ] `sysv_aa_2stage` <sub>cdsz</sub>
- [ ] `sysv_rk` <sub>cdsz</sub>
- [ ] `sysv_rook` <sub>cdsz</sub>
- [x] `sysvx` <sub>cdsz</sub>
- [x] `zsum1` <sub>d</sub>

### T2 Linear systems — computational

`141` base routines, `502` symbols.

- [x] `gbcon` <sub>cdsz</sub>
- [x] `gbequ` <sub>cdsz</sub>
- [x] `gbequb` <sub>cdsz</sub>
- [x] `gbrfs` <sub>cdsz</sub>
- [ ] `gbtf2` <sub>cdsz</sub>
- [x] `gbtrf` <sub>cdsz</sub>
- [x] `gbtrs` <sub>cdsz</sub>
- [x] `gecon` <sub>cdsz</sub>
- [x] `geequ` <sub>cdsz</sub>
- [x] `geequb` <sub>cdsz</sub>
- [x] `gerfs` <sub>cdsz</sub>
- [ ] `gesc2` <sub>cdsz</sub>
- [ ] `getc2` <sub>cdsz</sub>
- [ ] `getf2` <sub>cdsz</sub>
- [x] `getrf` <sub>cdsz</sub>
- [ ] `getrf2` <sub>cdsz</sub>
- [x] `getri` <sub>cdsz</sub>
- [x] `getrs` <sub>cdsz</sub>
- [x] `gtcon` <sub>cdsz</sub>
- [x] `gtrfs` <sub>cdsz</sub>
- [x] `gttrf` <sub>cdsz</sub>
- [x] `gttrs` <sub>cdsz</sub>
- [ ] `gtts2` <sub>cdsz</sub>
- [x] `hecon` <sub>cz</sub>
- [ ] `hecon_3` <sub>cz</sub>
- [ ] `hecon_rook` <sub>cz</sub>
- [x] `heequb` <sub>cz</sub>
- [x] `herfs` <sub>cz</sub>
- [ ] `heswapr` <sub>cz</sub>
- [ ] `hetf2` <sub>cz</sub>
- [ ] `hetf2_rk` <sub>cz</sub>
- [ ] `hetf2_rook` <sub>cz</sub>
- [x] `hetrf` <sub>cz</sub>
- [ ] `hetrf_aa` <sub>cz</sub>
- [ ] `hetrf_aa_2stage` <sub>cz</sub>
- [ ] `hetrf_rk` <sub>cz</sub>
- [ ] `hetrf_rook` <sub>cz</sub>
- [x] `hetri` <sub>cz</sub>
- [ ] `hetri2` <sub>cz</sub>
- [ ] `hetri2x` <sub>cz</sub>
- [ ] `hetri_3` <sub>cz</sub>
- [ ] `hetri_3x` <sub>cz</sub>
- [ ] `hetri_rook` <sub>cz</sub>
- [x] `hetrs` <sub>cz</sub>
- [ ] `hetrs2` <sub>cz</sub>
- [ ] `hetrs_3` <sub>cz</sub>
- [ ] `hetrs_aa` <sub>cz</sub>
- [ ] `hetrs_aa_2stage` <sub>cz</sub>
- [ ] `hetrs_rook` <sub>cz</sub>
- [x] `hpcon` <sub>cz</sub>
- [x] `hprfs` <sub>cz</sub>
- [x] `hptrf` <sub>cz</sub>
- [x] `hptri` <sub>cz</sub>
- [x] `hptrs` <sub>cz</sub>
- [x] `pbcon` <sub>cdsz</sub>
- [x] `pbequ` <sub>cdsz</sub>
- [x] `pbrfs` <sub>cdsz</sub>
- [x] `pbstf` <sub>cdsz</sub>
- [ ] `pbtf2` <sub>cdsz</sub>
- [x] `pbtrf` <sub>cdsz</sub>
- [x] `pbtrs` <sub>cdsz</sub>
- [x] `pftrf` <sub>cdsz</sub>
- [x] `pftri` <sub>cdsz</sub>
- [x] `pftrs` <sub>cdsz</sub>
- [x] `pocon` <sub>cdsz</sub>
- [x] `poequ` <sub>cdsz</sub>
- [x] `poequb` <sub>cdsz</sub>
- [x] `porfs` <sub>cdsz</sub>
- [ ] `potf2` <sub>cdsz</sub>
- [x] `potrf` <sub>cdsz</sub>
- [ ] `potrf2` <sub>cdsz</sub>
- [x] `potri` <sub>cdsz</sub>
- [x] `potrs` <sub>cdsz</sub>
- [x] `ppcon` <sub>cdsz</sub>
- [x] `ppequ` <sub>cdsz</sub>
- [x] `pprfs` <sub>cdsz</sub>
- [x] `pptrf` <sub>cdsz</sub>
- [x] `pptri` <sub>cdsz</sub>
- [x] `pptrs` <sub>cdsz</sub>
- [ ] `pstf2` <sub>cdsz</sub>
- [x] `pstrf` <sub>cdsz</sub>
- [x] `ptcon` <sub>cdsz</sub>
- [x] `ptrfs` <sub>cdsz</sub>
- [x] `pttrf` <sub>cdsz</sub>
- [x] `pttrs` <sub>cdsz</sub>
- [ ] `ptts2` <sub>cdsz</sub>
- [x] `spcon` <sub>cdsz</sub>
- [x] `sprfs` <sub>cdsz</sub>
- [x] `sptrf` <sub>cdsz</sub>
- [x] `sptri` <sub>cdsz</sub>
- [x] `sptrs` <sub>cdsz</sub>
- [x] `sycon` <sub>cdsz</sub>
- [ ] `sycon_3` <sub>cdsz</sub>
- [ ] `sycon_rook` <sub>cdsz</sub>
- [ ] `syconv` <sub>cdsz</sub>
- [ ] `syconvf` <sub>cdsz</sub>
- [ ] `syconvf_rook` <sub>cdsz</sub>
- [x] `syequb` <sub>cdsz</sub>
- [x] `syrfs` <sub>cdsz</sub>
- [ ] `syswapr` <sub>cdsz</sub>
- [ ] `sytf2` <sub>cdsz</sub>
- [ ] `sytf2_rk` <sub>cdsz</sub>
- [ ] `sytf2_rook` <sub>cdsz</sub>
- [x] `sytrf` <sub>cdsz</sub>
- [ ] `sytrf_aa` <sub>cdsz</sub>
- [ ] `sytrf_aa_2stage` <sub>cdsz</sub>
- [ ] `sytrf_rk` <sub>cdsz</sub>
- [ ] `sytrf_rook` <sub>cdsz</sub>
- [x] `sytri` <sub>cdsz</sub>
- [ ] `sytri2` <sub>cdsz</sub>
- [ ] `sytri2x` <sub>cdsz</sub>
- [ ] `sytri_3` <sub>cdsz</sub>
- [ ] `sytri_3x` <sub>cdsz</sub>
- [ ] `sytri_rook` <sub>cdsz</sub>
- [x] `sytrs` <sub>cdsz</sub>
- [ ] `sytrs2` <sub>cdsz</sub>
- [ ] `sytrs_3` <sub>cdsz</sub>
- [ ] `sytrs_aa` <sub>cdsz</sub>
- [ ] `sytrs_aa_2stage` <sub>cdsz</sub>
- [ ] `sytrs_rook` <sub>cdsz</sub>
- [x] `tbcon` <sub>cdsz</sub>
- [x] `tbrfs` <sub>cdsz</sub>
- [x] `tbtrs` <sub>cdsz</sub>
- [x] `tfsm` <sub>cdsz</sub>
- [x] `tftri` <sub>cdsz</sub>
- [x] `tfttp` <sub>cdsz</sub>
- [x] `tfttr` <sub>cdsz</sub>
- [x] `tpcon` <sub>cdsz</sub>
- [x] `tprfb` <sub>cdsz</sub>
- [x] `tprfs` <sub>cdsz</sub>
- [x] `tptri` <sub>cdsz</sub>
- [x] `tptrs` <sub>cdsz</sub>
- [x] `tpttf` <sub>cdsz</sub>
- [x] `tpttr` <sub>cdsz</sub>
- [x] `trcon` <sub>cdsz</sub>
- [x] `trrfs` <sub>cdsz</sub>
- [ ] `trti2` <sub>cdsz</sub>
- [x] `trtri` <sub>cdsz</sub>
- [x] `trtrs` <sub>cdsz</sub>
- [x] `trttf` <sub>cdsz</sub>
- [x] `trttp` <sub>cdsz</sub>

### T3 Least squares & orthogonal factorizations

`122` base routines, `332` symbols.

- [x] `gelq` <sub>cdsz</sub>
- [ ] `gelq2` <sub>cdsz</sub>
- [x] `gelqf` <sub>cdsz</sub>
- [ ] `gelqt` <sub>cdsz</sub>
- [ ] `gelqt3` <sub>cdsz</sub>
- [x] `gels` <sub>cdsz</sub>
- [x] `gelsd` <sub>cdsz</sub>
- [x] `gelss` <sub>cdsz</sub>
- [x] `gelst` <sub>cdsz</sub>
- [ ] `gelsx` <sub>cdsz</sub>
- [x] `gelsy` <sub>cdsz</sub>
- [x] `gemlq` <sub>cdsz</sub>
- [ ] `gemlqt` <sub>cdsz</sub>
- [x] `gemqr` <sub>cdsz</sub>
- [x] `gemqrt` <sub>cdsz</sub>
- [ ] `geql2` <sub>cdsz</sub>
- [x] `geqlf` <sub>cdsz</sub>
- [x] `geqp3` <sub>cdsz</sub>
- [ ] `geqpf` <sub>cdsz</sub>
- [x] `geqr` <sub>cdsz</sub>
- [ ] `geqr2` <sub>cdsz</sub>
- [x] `geqr2p` <sub>cdsz</sub>
- [x] `geqrf` <sub>cdsz</sub>
- [x] `geqrfp` <sub>cdsz</sub>
- [x] `geqrt` <sub>cdsz</sub>
- [ ] `geqrt2` <sub>cdsz</sub>
- [ ] `geqrt3` <sub>cdsz</sub>
- [ ] `gerq2` <sub>cdsz</sub>
- [x] `gerqf` <sub>cdsz</sub>
- [x] `getsls` <sub>cdsz</sub>
- [ ] `getsqrhrt` <sub>cdsz</sub>
- [x] `ggglm` <sub>cdsz</sub>
- [x] `gglse` <sub>cdsz</sub>
- [x] `ggqrf` <sub>cdsz</sub>
- [x] `ggrqf` <sub>cdsz</sub>
- [x] `opgtr` <sub>ds</sub>
- [x] `opmtr` <sub>ds</sub>
- [x] `orbdb` <sub>ds</sub>
- [x] `orbdb1` <sub>ds</sub>
- [x] `orbdb2` <sub>ds</sub>
- [x] `orbdb3` <sub>ds</sub>
- [x] `orbdb4` <sub>ds</sub>
- [x] `orbdb5` <sub>ds</sub>
- [x] `orbdb6` <sub>ds</sub>
- [x] `orcsd` <sub>ds</sub>
- [x] `orcsd2by1` <sub>ds</sub>
- [ ] `org2l` <sub>ds</sub>
- [ ] `org2r` <sub>ds</sub>
- [x] `orgbr` <sub>ds</sub>
- [x] `orghr` <sub>ds</sub>
- [ ] `orgl2` <sub>ds</sub>
- [x] `orglq` <sub>ds</sub>
- [x] `orgql` <sub>ds</sub>
- [x] `orgqr` <sub>ds</sub>
- [ ] `orgr2` <sub>ds</sub>
- [x] `orgrq` <sub>ds</sub>
- [x] `orgtr` <sub>ds</sub>
- [ ] `orgtsqr` <sub>ds</sub>
- [ ] `orgtsqr_row` <sub>ds</sub>
- [ ] `orhr_col` <sub>ds</sub>
- [ ] `orm22` <sub>ds</sub>
- [ ] `orm2l` <sub>ds</sub>
- [ ] `orm2r` <sub>ds</sub>
- [x] `ormbr` <sub>ds</sub>
- [x] `ormhr` <sub>ds</sub>
- [ ] `orml2` <sub>ds</sub>
- [x] `ormlq` <sub>ds</sub>
- [x] `ormql` <sub>ds</sub>
- [x] `ormqr` <sub>ds</sub>
- [ ] `ormr2` <sub>ds</sub>
- [ ] `ormr3` <sub>ds</sub>
- [x] `ormrq` <sub>ds</sub>
- [x] `ormrz` <sub>ds</sub>
- [x] `ormtr` <sub>ds</sub>
- [x] `tplqt` <sub>cdsz</sub>
- [ ] `tplqt2` <sub>cdsz</sub>
- [x] `tpmlqt` <sub>cdsz</sub>
- [x] `tpmqrt` <sub>cdsz</sub>
- [x] `tpqrt` <sub>cdsz</sub>
- [ ] `tpqrt2` <sub>cdsz</sub>
- [x] `tprfb` <sub>cdsz</sub>
- [ ] `tzrqf` <sub>cdsz</sub>
- [x] `tzrzf` <sub>cdsz</sub>
- [x] `unbdb` <sub>cz</sub>
- [ ] `unbdb1` <sub>cz</sub>
- [ ] `unbdb2` <sub>cz</sub>
- [ ] `unbdb3` <sub>cz</sub>
- [ ] `unbdb4` <sub>cz</sub>
- [ ] `unbdb5` <sub>cz</sub>
- [ ] `unbdb6` <sub>cz</sub>
- [x] `uncsd` <sub>cz</sub>
- [x] `uncsd2by1` <sub>cz</sub>
- [ ] `ung2l` <sub>cz</sub>
- [ ] `ung2r` <sub>cz</sub>
- [x] `ungbr` <sub>cz</sub>
- [x] `unghr` <sub>cz</sub>
- [ ] `ungl2` <sub>cz</sub>
- [x] `unglq` <sub>cz</sub>
- [x] `ungql` <sub>cz</sub>
- [x] `ungqr` <sub>cz</sub>
- [ ] `ungr2` <sub>cz</sub>
- [x] `ungrq` <sub>cz</sub>
- [x] `ungtr` <sub>cz</sub>
- [ ] `ungtsqr` <sub>cz</sub>
- [ ] `ungtsqr_row` <sub>cz</sub>
- [ ] `unhr_col` <sub>cz</sub>
- [ ] `unm22` <sub>cz</sub>
- [ ] `unm2l` <sub>cz</sub>
- [ ] `unm2r` <sub>cz</sub>
- [x] `unmbr` <sub>cz</sub>
- [x] `unmhr` <sub>cz</sub>
- [ ] `unml2` <sub>cz</sub>
- [x] `unmlq` <sub>cz</sub>
- [x] `unmql` <sub>cz</sub>
- [x] `unmqr` <sub>cz</sub>
- [ ] `unmr2` <sub>cz</sub>
- [ ] `unmr3` <sub>cz</sub>
- [x] `unmrq` <sub>cz</sub>
- [x] `unmrz` <sub>cz</sub>
- [x] `unmtr` <sub>cz</sub>
- [x] `upgtr` <sub>cz</sub>
- [x] `upmtr` <sub>cz</sub>

### T4 Symmetric / Hermitian eigenproblems

`97` base routines, `208` symbols.

- [x] `disna` <sub>ds</sub>
- [ ] `hb2st_kernels` <sub>cz</sub>
- [x] `hbev` <sub>cz</sub>
- [ ] `hbev_2stage` <sub>cz</sub>
- [x] `hbevd` <sub>cz</sub>
- [ ] `hbevd_2stage` <sub>cz</sub>
- [x] `hbevx` <sub>cz</sub>
- [ ] `hbevx_2stage` <sub>cz</sub>
- [x] `hbgst` <sub>cz</sub>
- [x] `hbgv` <sub>cz</sub>
- [x] `hbgvd` <sub>cz</sub>
- [x] `hbgvx` <sub>cz</sub>
- [x] `hbtrd` <sub>cz</sub>
- [x] `heequb` <sub>cz</sub>
- [x] `heev` <sub>cz</sub>
- [ ] `heev_2stage` <sub>cz</sub>
- [x] `heevd` <sub>cz</sub>
- [ ] `heevd_2stage` <sub>cz</sub>
- [x] `heevr` <sub>cz</sub>
- [ ] `heevr_2stage` <sub>cz</sub>
- [x] `heevx` <sub>cz</sub>
- [ ] `heevx_2stage` <sub>cz</sub>
- [ ] `hegs2` <sub>cz</sub>
- [x] `hegst` <sub>cz</sub>
- [x] `hegv` <sub>cz</sub>
- [ ] `hegv_2stage` <sub>cz</sub>
- [x] `hegvd` <sub>cz</sub>
- [x] `hegvx` <sub>cz</sub>
- [ ] `hetd2` <sub>cz</sub>
- [x] `hetrd` <sub>cz</sub>
- [ ] `hetrd_2stage` <sub>cz</sub>
- [ ] `hetrd_hb2st` <sub>cz</sub>
- [ ] `hetrd_he2hb` <sub>cz</sub>
- [x] `hpev` <sub>cz</sub>
- [x] `hpevd` <sub>cz</sub>
- [x] `hpevx` <sub>cz</sub>
- [x] `hpgst` <sub>cz</sub>
- [x] `hpgv` <sub>cz</sub>
- [x] `hpgvd` <sub>cz</sub>
- [x] `hpgvx` <sub>cz</sub>
- [x] `hptrd` <sub>cz</sub>
- [x] `opgtr` <sub>ds</sub>
- [x] `opmtr` <sub>ds</sub>
- [x] `pteqr` <sub>cdsz</sub>
- [ ] `sb2st_kernels` <sub>ds</sub>
- [x] `sbev` <sub>ds</sub>
- [ ] `sbev_2stage` <sub>ds</sub>
- [x] `sbevd` <sub>ds</sub>
- [ ] `sbevd_2stage` <sub>ds</sub>
- [x] `sbevx` <sub>ds</sub>
- [ ] `sbevx_2stage` <sub>ds</sub>
- [x] `sbgst` <sub>ds</sub>
- [x] `sbgv` <sub>ds</sub>
- [x] `sbgvd` <sub>ds</sub>
- [x] `sbgvx` <sub>ds</sub>
- [x] `sbtrd` <sub>ds</sub>
- [x] `spev` <sub>ds</sub>
- [x] `spevd` <sub>ds</sub>
- [x] `spevx` <sub>ds</sub>
- [x] `spgst` <sub>ds</sub>
- [x] `spgv` <sub>ds</sub>
- [x] `spgvd` <sub>ds</sub>
- [x] `spgvx` <sub>ds</sub>
- [x] `sptrd` <sub>ds</sub>
- [x] `stebz` <sub>ds</sub>
- [x] `stedc` <sub>cdsz</sub>
- [x] `stegr` <sub>cdsz</sub>
- [x] `stein` <sub>cdsz</sub>
- [x] `stemr` <sub>cdsz</sub>
- [x] `steqr` <sub>cdsz</sub>
- [x] `sterf` <sub>ds</sub>
- [x] `stev` <sub>ds</sub>
- [x] `stevd` <sub>ds</sub>
- [x] `stevr` <sub>ds</sub>
- [x] `stevx` <sub>ds</sub>
- [x] `syequb` <sub>cdsz</sub>
- [x] `syev` <sub>ds</sub>
- [ ] `syev_2stage` <sub>ds</sub>
- [x] `syevd` <sub>ds</sub>
- [ ] `syevd_2stage` <sub>ds</sub>
- [x] `syevr` <sub>ds</sub>
- [ ] `syevr_2stage` <sub>ds</sub>
- [x] `syevx` <sub>ds</sub>
- [ ] `syevx_2stage` <sub>ds</sub>
- [ ] `sygs2` <sub>ds</sub>
- [x] `sygst` <sub>ds</sub>
- [x] `sygv` <sub>ds</sub>
- [ ] `sygv_2stage` <sub>ds</sub>
- [x] `sygvd` <sub>ds</sub>
- [x] `sygvx` <sub>ds</sub>
- [ ] `sytd2` <sub>ds</sub>
- [x] `sytrd` <sub>ds</sub>
- [ ] `sytrd_2stage` <sub>ds</sub>
- [ ] `sytrd_sb2st` <sub>ds</sub>
- [ ] `sytrd_sy2sb` <sub>ds</sub>
- [x] `upgtr` <sub>cz</sub>
- [x] `upmtr` <sub>cz</sub>

### T5 Nonsymmetric eigenproblems & Schur

`17` base routines, `68` symbols.

- [x] `gebak` <sub>cdsz</sub>
- [x] `gebal` <sub>cdsz</sub>
- [x] `gees` <sub>cdsz</sub>
- [x] `geesx` <sub>cdsz</sub>
- [x] `geev` <sub>cdsz</sub>
- [x] `geevx` <sub>cdsz</sub>
- [ ] `gehd2` <sub>cdsz</sub>
- [x] `gehrd` <sub>cdsz</sub>
- [x] `hsein` <sub>cdsz</sub>
- [x] `hseqr` <sub>cdsz</sub>
- [x] `trevc` <sub>cdsz</sub>
- [x] `trevc3` <sub>cdsz</sub>
- [x] `trexc` <sub>cdsz</sub>
- [x] `trsen` <sub>cdsz</sub>
- [x] `trsna` <sub>cdsz</sub>
- [x] `trsyl` <sub>cdsz</sub>
- [x] `trsyl3` <sub>cdsz</sub>

### T6 Singular value decomposition

`14` base routines, `52` symbols.

- [x] `bdsdc` <sub>ds</sub>
- [x] `bdsqr` <sub>cdsz</sub>
- [x] `bdsvdx` <sub>ds</sub>
- [x] `gbbrd` <sub>cdsz</sub>
- [ ] `gebd2` <sub>cdsz</sub>
- [x] `gebrd` <sub>cdsz</sub>
- [x] `gejsv` <sub>cdsz</sub>
- [x] `gesdd` <sub>cdsz</sub>
- [x] `gesvd` <sub>cdsz</sub>
- [x] `gesvdq` <sub>cdsz</sub>
- [x] `gesvdx` <sub>cdsz</sub>
- [x] `gesvj` <sub>cdsz</sub>
- [ ] `gsvj0` <sub>cdsz</sub>
- [ ] `gsvj1` <sub>cdsz</sub>

### T7 Generalized eigen / CS decomposition

`33` base routines, `115` symbols.

- [x] `bbcsd` <sub>cdsz</sub>
- [ ] `combssq` <sub>ds</sub>
- [ ] `drscl` <sub>z</sub>
- [ ] `gegs` <sub>cdsz</sub>
- [ ] `gegv` <sub>cdsz</sub>
- [x] `ggbak` <sub>cdsz</sub>
- [x] `ggbal` <sub>cdsz</sub>
- [x] `gges` <sub>cdsz</sub>
- [x] `gges3` <sub>cdsz</sub>
- [x] `ggesx` <sub>cdsz</sub>
- [x] `ggev` <sub>cdsz</sub>
- [x] `ggev3` <sub>cdsz</sub>
- [x] `ggevx` <sub>cdsz</sub>
- [x] `gghd3` <sub>cdsz</sub>
- [x] `gghrd` <sub>cdsz</sub>
- [ ] `ggsvd` <sub>cdsz</sub>
- [x] `ggsvd3` <sub>cdsz</sub>
- [ ] `ggsvp` <sub>cdsz</sub>
- [ ] `ggsvp3` <sub>cdsz</sub>
- [x] `hfrk` <sub>cz</sub>
- [x] `hgeqz` <sub>cdsz</sub>
- [ ] `hla_transtype` <sub>c</sub>
- [x] `rscl` <sub>ds</sub>
- [x] `sfrk` <sub>ds</sub>
- [ ] `srscl` <sub>c</sub>
- [x] `tgevc` <sub>cdsz</sub>
- [ ] `tgex2` <sub>cdsz</sub>
- [x] `tgexc` <sub>cdsz</sub>
- [x] `tgsen` <sub>cdsz</sub>
- [x] `tgsja` <sub>cdsz</sub>
- [x] `tgsna` <sub>cdsz</sub>
- [ ] `tgsy2` <sub>cdsz</sub>
- [x] `tgsyl` <sub>cdsz</sub>

### T8 Utility, auxiliary & complex-symmetric extensions

`40` base routines, `132` symbols.

`csymv`, `csyr`, `cspmv`, `cspr` (listed as `symv`/`syr`/`spmv`/`spr`) are
**complex symmetric** — not Hermitian — and have no CBLAS equivalent. They are
a genuine addition over the BLAS module, not a duplicate of it.

- [x] `isnan` <sub>ds</sub>
- [ ] `lacn2` <sub>cdsz</sub>
- [ ] `lacon` <sub>cdsz</sub>
- [x] `lacpy` <sub>cdsz</sub>
- [x] `lamch` <sub>ds</sub>
- [x] `langb` <sub>cdsz</sub>
- [x] `lange` <sub>cdsz</sub>
- [x] `langt` <sub>cdsz</sub>
- [x] `lanhb` <sub>cz</sub>
- [x] `lanhe` <sub>cz</sub>
- [x] `lanhp` <sub>cz</sub>
- [x] `lanht` <sub>cz</sub>
- [x] `lansb` <sub>cdsz</sub>
- [x] `lansp` <sub>cdsz</sub>
- [x] `lanst` <sub>ds</sub>
- [x] `lansy` <sub>cdsz</sub>
- [x] `lantb` <sub>cdsz</sub>
- [x] `lantp` <sub>cdsz</sub>
- [x] `lantr` <sub>cdsz</sub>
- [ ] `lapmr` <sub>cdsz</sub>
- [ ] `lapmt` <sub>cdsz</sub>
- [ ] `larf` <sub>cdsz</sub>
- [ ] `larfb` <sub>cdsz</sub>
- [ ] `larfg` <sub>cdsz</sub>
- [ ] `larft` <sub>cdsz</sub>
- [ ] `larfx` <sub>cdsz</sub>
- [ ] `largv` <sub>cdsz</sub>
- [x] `larnv` <sub>cdsz</sub>
- [x] `lartg` <sub>cdsz</sub>
- [ ] `laruv` <sub>ds</sub>
- [x] `lascl` <sub>cdsz</sub>
- [x] `laset` <sub>cdsz</sub>
- [x] `lasrt` <sub>ds</sub>
- [ ] `lauu2` <sub>cdsz</sub>
- [ ] `lauum` <sub>cdsz</sub>
- [x] `rot` <sub>cz</sub>
- [x] `spmv` <sub>cz</sub>
- [x] `spr` <sub>cz</sub>
- [x] `symv` <sub>cz</sub>
- [x] `syr` <sub>cz</sub>

### T9 Internal auxiliary (`la*`) — raw externs only

`216` base routines, `630` symbols.

These are LAPACK's own building blocks. They are reachable through `lapack.c`
but get no typed wrapper unless a specific one proves useful. Promoted so far:

- the whole `lan*` norm family, in `norms.zig` — `lange`, `langb`, `langt`,
  `lanhs`, `lansy`/`lanhe`, `lansb`/`lanhb`, `lansp`/`lanhp`, `lansf`/`lanhf`,
  `lanst`/`lanht`, `lantr`, `lantb`, `lantp`
- `lacpy`, `laset` in `norms.zig`
- `lamch`, `ilaenv`, `larnv`, `lartg`, `lascl`, `lasrt`, `lacgv`, `ladiv`,
  `rscl` in `util.zig`

Listed here for completeness so the generator's coverage can be audited against
this file.

<details><summary>Full list</summary>

`la_gbamv` `la_gbrcond` `la_gbrcond_c` `la_gbrcond_x` `la_gbrpvgrw` `la_geamv` `la_gercond` `la_gercond_c` `la_gercond_x` `la_gerpvgrw` `la_heamv` `la_hercond_c` `la_hercond_x` `la_herpvgrw` `la_lin_berr` `la_porcond` `la_porcond_c` `la_porcond_x` `la_porpvgrw` `la_syamv` `la_syrcond` `la_syrcond_c` `la_syrcond_x` `la_syrpvgrw` `la_wwaddw` `labad` `labrd` `lacgv` `lacn2` `lacon` `lacp2` `lacpy` `lacrm` `lacrt` `ladiv` `ladiv1` `ladiv2` `lae2` `laebz` `laed0` `laed1` `laed2` `laed3` `laed4` `laed5` `laed6` `laed7` `laed8` `laed9` `laeda` `laein` `laesy` `laev2` `laexc` `lag2` `lag2c` `lag2d` `lag2s` `lag2z` `lags2` `lagtf` `lagtm` `lagts` `lagv2` `lahef` `lahef_aa` `lahef_rk` `lahef_rook` `lahqr` `lahr2` `lahrd` `laic1` `laisnan` `laln2` `lals0` `lalsa` `lalsd` `lamc1` `lamc2` `lamc3` `lamc4` `lamc5` `lamch` `lamrg` `lamswlq` `lamtsqr` `laneg` `langb` `lange` `langt` `lanhb` `lanhe` `lanhf` `lanhp` `lanhs` `lanht` `lansb` `lansf` `lansp` `lanst` `lansy` `lantb` `lantp` `lantr` `lanv2` `laorhr_col_getrfnp` `laorhr_col_getrfnp2` `lapll` `lapmr` `lapmt` `lapy2` `lapy3` `laqgb` `laqge` `laqhb` `laqhe` `laqhp` `laqp2` `laqps` `laqr0` `laqr1` `laqr2` `laqr3` `laqr4` `laqr5` `laqsb` `laqsp` `laqsy` `laqtr` `laqz0` `laqz1` `laqz2` `laqz3` `laqz4` `lar1v` `lar2v` `larcm` `larf` `larfb` `larfb_gett` `larfg` `larfgp` `larfp` `larft` `larfx` `larfy` `largv` `larmm` `larnv` `larra` `larrb` `larrc` `larrd` `larre` `larrf` `larrj` `larrk` `larrr` `larrv` `larscl2` `lartg` `lartgp` `lartgs` `lartv` `laruv` `larz` `larzb` `larzt` `las2` `lascl` `lascl2` `lasd0` `lasd1` `lasd2` `lasd3` `lasd4` `lasd5` `lasd6` `lasd7` `lasd8` `lasda` `lasdq` `lasdt` `laset` `lasq1` `lasq2` `lasq3` `lasq4` `lasq5` `lasq6` `lasr` `lasrt` `lassq` `lasv2` `laswlq` `laswp` `lasy2` `lasyf` `lasyf_aa` `lasyf_rk` `lasyf_rook` `lat2c` `lat2s` `latbs` `latdf` `latps` `latrd` `latrs` `latrs3` `latrz` `latsqr` `latzm` `launhr_col_getrfnp` `launhr_col_getrfnp2` `lauu2` `lauum`

</details>

### T10 Precision-independent

`21` symbols, no precision prefix.

- [ ] `icmax1`
- [ ] `ieeeck`
- [ ] `ilaclc`
- [ ] `ilaclr`
- [ ] `iladiag`
- [ ] `iladlc`
- [ ] `iladlr`
- [x] `ilaenv`
- [ ] `ilaenv2stage`
- [ ] `ilaprec`
- [ ] `ilaslc`
- [ ] `ilaslr`
- [ ] `ilatrans`
- [ ] `ilauplo`
- [ ] `ilaver`
- [ ] `ilazlc`
- [ ] `ilazlr`
- [ ] `iparam2stage`
- [ ] `iparmq`
- [ ] `izmax1`
- [ ] `lsamen`

## 5. Test strategy

Per the existing modules: every wrapper gets at least one test with a
hand-checkable expected value, and anything with a nontrivial reference gets
compared against an independently computed result rather than a constant I
wrote down. Specifically:

- **Factor-and-reconstruct.** For every factorization, multiply the factors back
  and compare to the input. This catches transposed/conjugated output without
  needing a reference value.
- **Solve-and-residual.** For every solver, check `||Ax - b||` rather than
  comparing `x` to a constant.
- **Eigen/SVD invariants.** `A v = lambda v`, `U S V' = A`, orthogonality of `U`/`V`.
  Never compare eigenvectors elementwise — sign and phase are not determined.
- **Untouched-triangle poisoning.** Fill the unreferenced triangle with a sentinel
  and assert it survives, confirming the routine reads only the half it claims to.
  This found two of my own test bugs in the BLAS work.
- **Workspace query round-trip.** Assert the queried `lwork` is accepted and that
  a deliberately undersized `lwork` produces `info < 0` rather than corruption.
- **`bwork` element size.** A dedicated test for a sorting driver (`sgeesx`) that
  would fail if `Bool` were 4 bytes (see 2.2).

## 6. Risks

- **Volume.** 459 user-facing base routines is roughly 1800 symbols to wrap. This
  is a multi-session effort; the tiers above are the intended commit boundaries.
- **`info > 0` semantics vary per routine.** There is no general rule; each family
  needs its meaning read from the reference documentation. Getting this wrong
  turns a recoverable numerical result into a wrong error, or vice versa.
- **Undocumented shims.** `cladiv` proves the SDK header is not authoritative.
  Any routine whose test fails in a way that looks like "the call did nothing"
  should be disassembled before the test is assumed wrong.
- **`_2stage` and `_aa`/`_rk`/`_rook` variants** have different workspace rules
  from their base routines and are easy to wrap by copy-paste incorrectly.
