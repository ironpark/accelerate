# LAPACK binding plan

Status: **planning**. Nothing under `src/lapack/` exists yet.

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

- [ ] `tools/gen_lapack.py` — parse `lapack.h`, emit `c.zig`
- [ ] `src/lapack/types.zig` — `Int`, `Bool` (8 bytes under ILP64, see 2.2), `alias_suffix`, `Complex`, option enums
- [ ] `src/lapack/c.zig` — 2032 externs + all-symbols link test
- [ ] `cladiv`/`zladiv` override + regression test pinning the by-value ABI (see 2.4)
- [ ] `src/lapack/info.zig` — `info` → error mapping
- [ ] `src/lapack/work.zig` — `lwork = -1` query helper
- [ ] wire into `src/root.zig`, `README.md` module table, `CHANGELOG.md`

### T1 Linear systems — drivers

`36` base routines, `110` symbols.

Includes the mixed-precision iterative-refinement drivers `dsgesv`, `zcgesv`,
`dsposv`, `zcposv`, which factor in single and refine in double. Their base
names appear below as `sgesv`/`cgesv`/`sposv`/`cposv` because the precision
prefix is two characters, not one — a naming trap for the generator.

- [ ] `cgesv` <sub>z</sub>
- [ ] `cposv` <sub>z</sub>
- [ ] `csum1` <sub>s</sub>
- [ ] `gbsv` <sub>cdsz</sub>
- [ ] `gbsvx` <sub>cdsz</sub>
- [ ] `gesv` <sub>cdsz</sub>
- [ ] `gesvx` <sub>cdsz</sub>
- [ ] `gtsv` <sub>cdsz</sub>
- [ ] `gtsvx` <sub>cdsz</sub>
- [ ] `hesv` <sub>cz</sub>
- [ ] `hesv_aa` <sub>cz</sub>
- [ ] `hesv_aa_2stage` <sub>cz</sub>
- [ ] `hesv_rk` <sub>cz</sub>
- [ ] `hesv_rook` <sub>cz</sub>
- [ ] `hesvx` <sub>cz</sub>
- [ ] `hpsv` <sub>cz</sub>
- [ ] `hpsvx` <sub>cz</sub>
- [ ] `pbsv` <sub>cdsz</sub>
- [ ] `pbsvx` <sub>cdsz</sub>
- [ ] `posv` <sub>cdsz</sub>
- [ ] `posvx` <sub>cdsz</sub>
- [ ] `ppsv` <sub>cdsz</sub>
- [ ] `ppsvx` <sub>cdsz</sub>
- [ ] `ptsv` <sub>cdsz</sub>
- [ ] `ptsvx` <sub>cdsz</sub>
- [ ] `sgesv` <sub>d</sub>
- [ ] `sposv` <sub>d</sub>
- [ ] `spsv` <sub>cdsz</sub>
- [ ] `spsvx` <sub>cdsz</sub>
- [ ] `sysv` <sub>cdsz</sub>
- [ ] `sysv_aa` <sub>cdsz</sub>
- [ ] `sysv_aa_2stage` <sub>cdsz</sub>
- [ ] `sysv_rk` <sub>cdsz</sub>
- [ ] `sysv_rook` <sub>cdsz</sub>
- [ ] `sysvx` <sub>cdsz</sub>
- [ ] `zsum1` <sub>d</sub>

### T2 Linear systems — computational

`141` base routines, `502` symbols.

- [ ] `gbcon` <sub>cdsz</sub>
- [ ] `gbequ` <sub>cdsz</sub>
- [ ] `gbequb` <sub>cdsz</sub>
- [ ] `gbrfs` <sub>cdsz</sub>
- [ ] `gbtf2` <sub>cdsz</sub>
- [ ] `gbtrf` <sub>cdsz</sub>
- [ ] `gbtrs` <sub>cdsz</sub>
- [ ] `gecon` <sub>cdsz</sub>
- [ ] `geequ` <sub>cdsz</sub>
- [ ] `geequb` <sub>cdsz</sub>
- [ ] `gerfs` <sub>cdsz</sub>
- [ ] `gesc2` <sub>cdsz</sub>
- [ ] `getc2` <sub>cdsz</sub>
- [ ] `getf2` <sub>cdsz</sub>
- [ ] `getrf` <sub>cdsz</sub>
- [ ] `getrf2` <sub>cdsz</sub>
- [ ] `getri` <sub>cdsz</sub>
- [ ] `getrs` <sub>cdsz</sub>
- [ ] `gtcon` <sub>cdsz</sub>
- [ ] `gtrfs` <sub>cdsz</sub>
- [ ] `gttrf` <sub>cdsz</sub>
- [ ] `gttrs` <sub>cdsz</sub>
- [ ] `gtts2` <sub>cdsz</sub>
- [ ] `hecon` <sub>cz</sub>
- [ ] `hecon_3` <sub>cz</sub>
- [ ] `hecon_rook` <sub>cz</sub>
- [ ] `heequb` <sub>cz</sub>
- [ ] `herfs` <sub>cz</sub>
- [ ] `heswapr` <sub>cz</sub>
- [ ] `hetf2` <sub>cz</sub>
- [ ] `hetf2_rk` <sub>cz</sub>
- [ ] `hetf2_rook` <sub>cz</sub>
- [ ] `hetrf` <sub>cz</sub>
- [ ] `hetrf_aa` <sub>cz</sub>
- [ ] `hetrf_aa_2stage` <sub>cz</sub>
- [ ] `hetrf_rk` <sub>cz</sub>
- [ ] `hetrf_rook` <sub>cz</sub>
- [ ] `hetri` <sub>cz</sub>
- [ ] `hetri2` <sub>cz</sub>
- [ ] `hetri2x` <sub>cz</sub>
- [ ] `hetri_3` <sub>cz</sub>
- [ ] `hetri_3x` <sub>cz</sub>
- [ ] `hetri_rook` <sub>cz</sub>
- [ ] `hetrs` <sub>cz</sub>
- [ ] `hetrs2` <sub>cz</sub>
- [ ] `hetrs_3` <sub>cz</sub>
- [ ] `hetrs_aa` <sub>cz</sub>
- [ ] `hetrs_aa_2stage` <sub>cz</sub>
- [ ] `hetrs_rook` <sub>cz</sub>
- [ ] `hpcon` <sub>cz</sub>
- [ ] `hprfs` <sub>cz</sub>
- [ ] `hptrf` <sub>cz</sub>
- [ ] `hptri` <sub>cz</sub>
- [ ] `hptrs` <sub>cz</sub>
- [ ] `pbcon` <sub>cdsz</sub>
- [ ] `pbequ` <sub>cdsz</sub>
- [ ] `pbrfs` <sub>cdsz</sub>
- [ ] `pbstf` <sub>cdsz</sub>
- [ ] `pbtf2` <sub>cdsz</sub>
- [ ] `pbtrf` <sub>cdsz</sub>
- [ ] `pbtrs` <sub>cdsz</sub>
- [ ] `pftrf` <sub>cdsz</sub>
- [ ] `pftri` <sub>cdsz</sub>
- [ ] `pftrs` <sub>cdsz</sub>
- [ ] `pocon` <sub>cdsz</sub>
- [ ] `poequ` <sub>cdsz</sub>
- [ ] `poequb` <sub>cdsz</sub>
- [ ] `porfs` <sub>cdsz</sub>
- [ ] `potf2` <sub>cdsz</sub>
- [ ] `potrf` <sub>cdsz</sub>
- [ ] `potrf2` <sub>cdsz</sub>
- [ ] `potri` <sub>cdsz</sub>
- [ ] `potrs` <sub>cdsz</sub>
- [ ] `ppcon` <sub>cdsz</sub>
- [ ] `ppequ` <sub>cdsz</sub>
- [ ] `pprfs` <sub>cdsz</sub>
- [ ] `pptrf` <sub>cdsz</sub>
- [ ] `pptri` <sub>cdsz</sub>
- [ ] `pptrs` <sub>cdsz</sub>
- [ ] `pstf2` <sub>cdsz</sub>
- [ ] `pstrf` <sub>cdsz</sub>
- [ ] `ptcon` <sub>cdsz</sub>
- [ ] `ptrfs` <sub>cdsz</sub>
- [ ] `pttrf` <sub>cdsz</sub>
- [ ] `pttrs` <sub>cdsz</sub>
- [ ] `ptts2` <sub>cdsz</sub>
- [ ] `spcon` <sub>cdsz</sub>
- [ ] `sprfs` <sub>cdsz</sub>
- [ ] `sptrf` <sub>cdsz</sub>
- [ ] `sptri` <sub>cdsz</sub>
- [ ] `sptrs` <sub>cdsz</sub>
- [ ] `sycon` <sub>cdsz</sub>
- [ ] `sycon_3` <sub>cdsz</sub>
- [ ] `sycon_rook` <sub>cdsz</sub>
- [ ] `syconv` <sub>cdsz</sub>
- [ ] `syconvf` <sub>cdsz</sub>
- [ ] `syconvf_rook` <sub>cdsz</sub>
- [ ] `syequb` <sub>cdsz</sub>
- [ ] `syrfs` <sub>cdsz</sub>
- [ ] `syswapr` <sub>cdsz</sub>
- [ ] `sytf2` <sub>cdsz</sub>
- [ ] `sytf2_rk` <sub>cdsz</sub>
- [ ] `sytf2_rook` <sub>cdsz</sub>
- [ ] `sytrf` <sub>cdsz</sub>
- [ ] `sytrf_aa` <sub>cdsz</sub>
- [ ] `sytrf_aa_2stage` <sub>cdsz</sub>
- [ ] `sytrf_rk` <sub>cdsz</sub>
- [ ] `sytrf_rook` <sub>cdsz</sub>
- [ ] `sytri` <sub>cdsz</sub>
- [ ] `sytri2` <sub>cdsz</sub>
- [ ] `sytri2x` <sub>cdsz</sub>
- [ ] `sytri_3` <sub>cdsz</sub>
- [ ] `sytri_3x` <sub>cdsz</sub>
- [ ] `sytri_rook` <sub>cdsz</sub>
- [ ] `sytrs` <sub>cdsz</sub>
- [ ] `sytrs2` <sub>cdsz</sub>
- [ ] `sytrs_3` <sub>cdsz</sub>
- [ ] `sytrs_aa` <sub>cdsz</sub>
- [ ] `sytrs_aa_2stage` <sub>cdsz</sub>
- [ ] `sytrs_rook` <sub>cdsz</sub>
- [ ] `tbcon` <sub>cdsz</sub>
- [ ] `tbrfs` <sub>cdsz</sub>
- [ ] `tbtrs` <sub>cdsz</sub>
- [ ] `tfsm` <sub>cdsz</sub>
- [ ] `tftri` <sub>cdsz</sub>
- [ ] `tfttp` <sub>cdsz</sub>
- [ ] `tfttr` <sub>cdsz</sub>
- [ ] `tpcon` <sub>cdsz</sub>
- [ ] `tprfb` <sub>cdsz</sub>
- [ ] `tprfs` <sub>cdsz</sub>
- [ ] `tptri` <sub>cdsz</sub>
- [ ] `tptrs` <sub>cdsz</sub>
- [ ] `tpttf` <sub>cdsz</sub>
- [ ] `tpttr` <sub>cdsz</sub>
- [ ] `trcon` <sub>cdsz</sub>
- [ ] `trrfs` <sub>cdsz</sub>
- [ ] `trti2` <sub>cdsz</sub>
- [ ] `trtri` <sub>cdsz</sub>
- [ ] `trtrs` <sub>cdsz</sub>
- [ ] `trttf` <sub>cdsz</sub>
- [ ] `trttp` <sub>cdsz</sub>

### T3 Least squares & orthogonal factorizations

`122` base routines, `332` symbols.

- [ ] `gelq` <sub>cdsz</sub>
- [ ] `gelq2` <sub>cdsz</sub>
- [ ] `gelqf` <sub>cdsz</sub>
- [ ] `gelqt` <sub>cdsz</sub>
- [ ] `gelqt3` <sub>cdsz</sub>
- [ ] `gels` <sub>cdsz</sub>
- [ ] `gelsd` <sub>cdsz</sub>
- [ ] `gelss` <sub>cdsz</sub>
- [ ] `gelst` <sub>cdsz</sub>
- [ ] `gelsx` <sub>cdsz</sub>
- [ ] `gelsy` <sub>cdsz</sub>
- [ ] `gemlq` <sub>cdsz</sub>
- [ ] `gemlqt` <sub>cdsz</sub>
- [ ] `gemqr` <sub>cdsz</sub>
- [ ] `gemqrt` <sub>cdsz</sub>
- [ ] `geql2` <sub>cdsz</sub>
- [ ] `geqlf` <sub>cdsz</sub>
- [ ] `geqp3` <sub>cdsz</sub>
- [ ] `geqpf` <sub>cdsz</sub>
- [ ] `geqr` <sub>cdsz</sub>
- [ ] `geqr2` <sub>cdsz</sub>
- [ ] `geqr2p` <sub>cdsz</sub>
- [ ] `geqrf` <sub>cdsz</sub>
- [ ] `geqrfp` <sub>cdsz</sub>
- [ ] `geqrt` <sub>cdsz</sub>
- [ ] `geqrt2` <sub>cdsz</sub>
- [ ] `geqrt3` <sub>cdsz</sub>
- [ ] `gerq2` <sub>cdsz</sub>
- [ ] `gerqf` <sub>cdsz</sub>
- [ ] `getsls` <sub>cdsz</sub>
- [ ] `getsqrhrt` <sub>cdsz</sub>
- [ ] `ggglm` <sub>cdsz</sub>
- [ ] `gglse` <sub>cdsz</sub>
- [ ] `ggqrf` <sub>cdsz</sub>
- [ ] `ggrqf` <sub>cdsz</sub>
- [ ] `opgtr` <sub>ds</sub>
- [ ] `opmtr` <sub>ds</sub>
- [ ] `orbdb` <sub>ds</sub>
- [ ] `orbdb1` <sub>ds</sub>
- [ ] `orbdb2` <sub>ds</sub>
- [ ] `orbdb3` <sub>ds</sub>
- [ ] `orbdb4` <sub>ds</sub>
- [ ] `orbdb5` <sub>ds</sub>
- [ ] `orbdb6` <sub>ds</sub>
- [ ] `orcsd` <sub>ds</sub>
- [ ] `orcsd2by1` <sub>ds</sub>
- [ ] `org2l` <sub>ds</sub>
- [ ] `org2r` <sub>ds</sub>
- [ ] `orgbr` <sub>ds</sub>
- [ ] `orghr` <sub>ds</sub>
- [ ] `orgl2` <sub>ds</sub>
- [ ] `orglq` <sub>ds</sub>
- [ ] `orgql` <sub>ds</sub>
- [ ] `orgqr` <sub>ds</sub>
- [ ] `orgr2` <sub>ds</sub>
- [ ] `orgrq` <sub>ds</sub>
- [ ] `orgtr` <sub>ds</sub>
- [ ] `orgtsqr` <sub>ds</sub>
- [ ] `orgtsqr_row` <sub>ds</sub>
- [ ] `orhr_col` <sub>ds</sub>
- [ ] `orm22` <sub>ds</sub>
- [ ] `orm2l` <sub>ds</sub>
- [ ] `orm2r` <sub>ds</sub>
- [ ] `ormbr` <sub>ds</sub>
- [ ] `ormhr` <sub>ds</sub>
- [ ] `orml2` <sub>ds</sub>
- [ ] `ormlq` <sub>ds</sub>
- [ ] `ormql` <sub>ds</sub>
- [ ] `ormqr` <sub>ds</sub>
- [ ] `ormr2` <sub>ds</sub>
- [ ] `ormr3` <sub>ds</sub>
- [ ] `ormrq` <sub>ds</sub>
- [ ] `ormrz` <sub>ds</sub>
- [ ] `ormtr` <sub>ds</sub>
- [ ] `tplqt` <sub>cdsz</sub>
- [ ] `tplqt2` <sub>cdsz</sub>
- [ ] `tpmlqt` <sub>cdsz</sub>
- [ ] `tpmqrt` <sub>cdsz</sub>
- [ ] `tpqrt` <sub>cdsz</sub>
- [ ] `tpqrt2` <sub>cdsz</sub>
- [ ] `tprfb` <sub>cdsz</sub>
- [ ] `tzrqf` <sub>cdsz</sub>
- [ ] `tzrzf` <sub>cdsz</sub>
- [ ] `unbdb` <sub>cz</sub>
- [ ] `unbdb1` <sub>cz</sub>
- [ ] `unbdb2` <sub>cz</sub>
- [ ] `unbdb3` <sub>cz</sub>
- [ ] `unbdb4` <sub>cz</sub>
- [ ] `unbdb5` <sub>cz</sub>
- [ ] `unbdb6` <sub>cz</sub>
- [ ] `uncsd` <sub>cz</sub>
- [ ] `uncsd2by1` <sub>cz</sub>
- [ ] `ung2l` <sub>cz</sub>
- [ ] `ung2r` <sub>cz</sub>
- [ ] `ungbr` <sub>cz</sub>
- [ ] `unghr` <sub>cz</sub>
- [ ] `ungl2` <sub>cz</sub>
- [ ] `unglq` <sub>cz</sub>
- [ ] `ungql` <sub>cz</sub>
- [ ] `ungqr` <sub>cz</sub>
- [ ] `ungr2` <sub>cz</sub>
- [ ] `ungrq` <sub>cz</sub>
- [ ] `ungtr` <sub>cz</sub>
- [ ] `ungtsqr` <sub>cz</sub>
- [ ] `ungtsqr_row` <sub>cz</sub>
- [ ] `unhr_col` <sub>cz</sub>
- [ ] `unm22` <sub>cz</sub>
- [ ] `unm2l` <sub>cz</sub>
- [ ] `unm2r` <sub>cz</sub>
- [ ] `unmbr` <sub>cz</sub>
- [ ] `unmhr` <sub>cz</sub>
- [ ] `unml2` <sub>cz</sub>
- [ ] `unmlq` <sub>cz</sub>
- [ ] `unmql` <sub>cz</sub>
- [ ] `unmqr` <sub>cz</sub>
- [ ] `unmr2` <sub>cz</sub>
- [ ] `unmr3` <sub>cz</sub>
- [ ] `unmrq` <sub>cz</sub>
- [ ] `unmrz` <sub>cz</sub>
- [ ] `unmtr` <sub>cz</sub>
- [ ] `upgtr` <sub>cz</sub>
- [ ] `upmtr` <sub>cz</sub>

### T4 Symmetric / Hermitian eigenproblems

`97` base routines, `208` symbols.

- [ ] `disna` <sub>ds</sub>
- [ ] `hb2st_kernels` <sub>cz</sub>
- [ ] `hbev` <sub>cz</sub>
- [ ] `hbev_2stage` <sub>cz</sub>
- [ ] `hbevd` <sub>cz</sub>
- [ ] `hbevd_2stage` <sub>cz</sub>
- [ ] `hbevx` <sub>cz</sub>
- [ ] `hbevx_2stage` <sub>cz</sub>
- [ ] `hbgst` <sub>cz</sub>
- [ ] `hbgv` <sub>cz</sub>
- [ ] `hbgvd` <sub>cz</sub>
- [ ] `hbgvx` <sub>cz</sub>
- [ ] `hbtrd` <sub>cz</sub>
- [ ] `heequb` <sub>cz</sub>
- [ ] `heev` <sub>cz</sub>
- [ ] `heev_2stage` <sub>cz</sub>
- [ ] `heevd` <sub>cz</sub>
- [ ] `heevd_2stage` <sub>cz</sub>
- [ ] `heevr` <sub>cz</sub>
- [ ] `heevr_2stage` <sub>cz</sub>
- [ ] `heevx` <sub>cz</sub>
- [ ] `heevx_2stage` <sub>cz</sub>
- [ ] `hegs2` <sub>cz</sub>
- [ ] `hegst` <sub>cz</sub>
- [ ] `hegv` <sub>cz</sub>
- [ ] `hegv_2stage` <sub>cz</sub>
- [ ] `hegvd` <sub>cz</sub>
- [ ] `hegvx` <sub>cz</sub>
- [ ] `hetd2` <sub>cz</sub>
- [ ] `hetrd` <sub>cz</sub>
- [ ] `hetrd_2stage` <sub>cz</sub>
- [ ] `hetrd_hb2st` <sub>cz</sub>
- [ ] `hetrd_he2hb` <sub>cz</sub>
- [ ] `hpev` <sub>cz</sub>
- [ ] `hpevd` <sub>cz</sub>
- [ ] `hpevx` <sub>cz</sub>
- [ ] `hpgst` <sub>cz</sub>
- [ ] `hpgv` <sub>cz</sub>
- [ ] `hpgvd` <sub>cz</sub>
- [ ] `hpgvx` <sub>cz</sub>
- [ ] `hptrd` <sub>cz</sub>
- [ ] `opgtr` <sub>ds</sub>
- [ ] `opmtr` <sub>ds</sub>
- [ ] `pteqr` <sub>cdsz</sub>
- [ ] `sb2st_kernels` <sub>ds</sub>
- [ ] `sbev` <sub>ds</sub>
- [ ] `sbev_2stage` <sub>ds</sub>
- [ ] `sbevd` <sub>ds</sub>
- [ ] `sbevd_2stage` <sub>ds</sub>
- [ ] `sbevx` <sub>ds</sub>
- [ ] `sbevx_2stage` <sub>ds</sub>
- [ ] `sbgst` <sub>ds</sub>
- [ ] `sbgv` <sub>ds</sub>
- [ ] `sbgvd` <sub>ds</sub>
- [ ] `sbgvx` <sub>ds</sub>
- [ ] `sbtrd` <sub>ds</sub>
- [ ] `spev` <sub>ds</sub>
- [ ] `spevd` <sub>ds</sub>
- [ ] `spevx` <sub>ds</sub>
- [ ] `spgst` <sub>ds</sub>
- [ ] `spgv` <sub>ds</sub>
- [ ] `spgvd` <sub>ds</sub>
- [ ] `spgvx` <sub>ds</sub>
- [ ] `sptrd` <sub>ds</sub>
- [ ] `stebz` <sub>ds</sub>
- [ ] `stedc` <sub>cdsz</sub>
- [ ] `stegr` <sub>cdsz</sub>
- [ ] `stein` <sub>cdsz</sub>
- [ ] `stemr` <sub>cdsz</sub>
- [ ] `steqr` <sub>cdsz</sub>
- [ ] `sterf` <sub>ds</sub>
- [ ] `stev` <sub>ds</sub>
- [ ] `stevd` <sub>ds</sub>
- [ ] `stevr` <sub>ds</sub>
- [ ] `stevx` <sub>ds</sub>
- [ ] `syequb` <sub>cdsz</sub>
- [ ] `syev` <sub>ds</sub>
- [ ] `syev_2stage` <sub>ds</sub>
- [ ] `syevd` <sub>ds</sub>
- [ ] `syevd_2stage` <sub>ds</sub>
- [ ] `syevr` <sub>ds</sub>
- [ ] `syevr_2stage` <sub>ds</sub>
- [ ] `syevx` <sub>ds</sub>
- [ ] `syevx_2stage` <sub>ds</sub>
- [ ] `sygs2` <sub>ds</sub>
- [ ] `sygst` <sub>ds</sub>
- [ ] `sygv` <sub>ds</sub>
- [ ] `sygv_2stage` <sub>ds</sub>
- [ ] `sygvd` <sub>ds</sub>
- [ ] `sygvx` <sub>ds</sub>
- [ ] `sytd2` <sub>ds</sub>
- [ ] `sytrd` <sub>ds</sub>
- [ ] `sytrd_2stage` <sub>ds</sub>
- [ ] `sytrd_sb2st` <sub>ds</sub>
- [ ] `sytrd_sy2sb` <sub>ds</sub>
- [ ] `upgtr` <sub>cz</sub>
- [ ] `upmtr` <sub>cz</sub>

### T5 Nonsymmetric eigenproblems & Schur

`17` base routines, `68` symbols.

- [ ] `gebak` <sub>cdsz</sub>
- [ ] `gebal` <sub>cdsz</sub>
- [ ] `gees` <sub>cdsz</sub>
- [ ] `geesx` <sub>cdsz</sub>
- [ ] `geev` <sub>cdsz</sub>
- [ ] `geevx` <sub>cdsz</sub>
- [ ] `gehd2` <sub>cdsz</sub>
- [ ] `gehrd` <sub>cdsz</sub>
- [ ] `hsein` <sub>cdsz</sub>
- [ ] `hseqr` <sub>cdsz</sub>
- [ ] `trevc` <sub>cdsz</sub>
- [ ] `trevc3` <sub>cdsz</sub>
- [ ] `trexc` <sub>cdsz</sub>
- [ ] `trsen` <sub>cdsz</sub>
- [ ] `trsna` <sub>cdsz</sub>
- [ ] `trsyl` <sub>cdsz</sub>
- [ ] `trsyl3` <sub>cdsz</sub>

### T6 Singular value decomposition

`14` base routines, `52` symbols.

- [ ] `bdsdc` <sub>ds</sub>
- [ ] `bdsqr` <sub>cdsz</sub>
- [ ] `bdsvdx` <sub>ds</sub>
- [ ] `gbbrd` <sub>cdsz</sub>
- [ ] `gebd2` <sub>cdsz</sub>
- [ ] `gebrd` <sub>cdsz</sub>
- [ ] `gejsv` <sub>cdsz</sub>
- [ ] `gesdd` <sub>cdsz</sub>
- [ ] `gesvd` <sub>cdsz</sub>
- [ ] `gesvdq` <sub>cdsz</sub>
- [ ] `gesvdx` <sub>cdsz</sub>
- [ ] `gesvj` <sub>cdsz</sub>
- [ ] `gsvj0` <sub>cdsz</sub>
- [ ] `gsvj1` <sub>cdsz</sub>

### T7 Generalized eigen / CS decomposition

`33` base routines, `115` symbols.

- [ ] `bbcsd` <sub>cdsz</sub>
- [ ] `combssq` <sub>ds</sub>
- [ ] `drscl` <sub>z</sub>
- [ ] `gegs` <sub>cdsz</sub>
- [ ] `gegv` <sub>cdsz</sub>
- [ ] `ggbak` <sub>cdsz</sub>
- [ ] `ggbal` <sub>cdsz</sub>
- [ ] `gges` <sub>cdsz</sub>
- [ ] `gges3` <sub>cdsz</sub>
- [ ] `ggesx` <sub>cdsz</sub>
- [ ] `ggev` <sub>cdsz</sub>
- [ ] `ggev3` <sub>cdsz</sub>
- [ ] `ggevx` <sub>cdsz</sub>
- [ ] `gghd3` <sub>cdsz</sub>
- [ ] `gghrd` <sub>cdsz</sub>
- [ ] `ggsvd` <sub>cdsz</sub>
- [ ] `ggsvd3` <sub>cdsz</sub>
- [ ] `ggsvp` <sub>cdsz</sub>
- [ ] `ggsvp3` <sub>cdsz</sub>
- [ ] `hfrk` <sub>cz</sub>
- [ ] `hgeqz` <sub>cdsz</sub>
- [ ] `hla_transtype` <sub>c</sub>
- [ ] `rscl` <sub>ds</sub>
- [ ] `sfrk` <sub>ds</sub>
- [ ] `srscl` <sub>c</sub>
- [ ] `tgevc` <sub>cdsz</sub>
- [ ] `tgex2` <sub>cdsz</sub>
- [ ] `tgexc` <sub>cdsz</sub>
- [ ] `tgsen` <sub>cdsz</sub>
- [ ] `tgsja` <sub>cdsz</sub>
- [ ] `tgsna` <sub>cdsz</sub>
- [ ] `tgsy2` <sub>cdsz</sub>
- [ ] `tgsyl` <sub>cdsz</sub>

### T8 Utility, auxiliary & complex-symmetric extensions

`40` base routines, `132` symbols.

`csymv`, `csyr`, `cspmv`, `cspr` (listed as `symv`/`syr`/`spmv`/`spr`) are
**complex symmetric** — not Hermitian — and have no CBLAS equivalent. They are
a genuine addition over the BLAS module, not a duplicate of it.

- [ ] `isnan` <sub>ds</sub>
- [ ] `lacn2` <sub>cdsz</sub>
- [ ] `lacon` <sub>cdsz</sub>
- [ ] `lacpy` <sub>cdsz</sub>
- [ ] `lamch` <sub>ds</sub>
- [ ] `langb` <sub>cdsz</sub>
- [ ] `lange` <sub>cdsz</sub>
- [ ] `langt` <sub>cdsz</sub>
- [ ] `lanhb` <sub>cz</sub>
- [ ] `lanhe` <sub>cz</sub>
- [ ] `lanhp` <sub>cz</sub>
- [ ] `lanht` <sub>cz</sub>
- [ ] `lansb` <sub>cdsz</sub>
- [ ] `lansp` <sub>cdsz</sub>
- [ ] `lanst` <sub>ds</sub>
- [ ] `lansy` <sub>cdsz</sub>
- [ ] `lantb` <sub>cdsz</sub>
- [ ] `lantp` <sub>cdsz</sub>
- [ ] `lantr` <sub>cdsz</sub>
- [ ] `lapmr` <sub>cdsz</sub>
- [ ] `lapmt` <sub>cdsz</sub>
- [ ] `larf` <sub>cdsz</sub>
- [ ] `larfb` <sub>cdsz</sub>
- [ ] `larfg` <sub>cdsz</sub>
- [ ] `larft` <sub>cdsz</sub>
- [ ] `larfx` <sub>cdsz</sub>
- [ ] `largv` <sub>cdsz</sub>
- [ ] `larnv` <sub>cdsz</sub>
- [ ] `lartg` <sub>cdsz</sub>
- [ ] `laruv` <sub>ds</sub>
- [ ] `lascl` <sub>cdsz</sub>
- [ ] `laset` <sub>cdsz</sub>
- [ ] `lasrt` <sub>ds</sub>
- [ ] `lauu2` <sub>cdsz</sub>
- [ ] `lauum` <sub>cdsz</sub>
- [ ] `rot` <sub>cz</sub>
- [ ] `spmv` <sub>cz</sub>
- [ ] `spr` <sub>cz</sub>
- [ ] `symv` <sub>cz</sub>
- [ ] `syr` <sub>cz</sub>

### T9 Internal auxiliary (`la*`) — raw externs only

`216` base routines, `630` symbols.

These are LAPACK's own building blocks. They are reachable through `lapack.c`
but get no typed wrapper unless a specific one proves useful (`lamch`, `lange`,
`lacpy`, `laset`, `larnv`, `lartg` are already promoted into T8). Listed here for
completeness so the generator's coverage can be audited against this file.

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
- [ ] `ilaenv`
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
