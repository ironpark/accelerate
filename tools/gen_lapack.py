#!/usr/bin/env python3
"""Generate src/lapack/c.zig from Accelerate's lapack.h.

There are 2032 aliased declarations in that header. Transcribing them by hand
is not a plausible plan, and neither is auditing a hand transcription. This
script parses the header instead, so re-running it against a newer SDK produces
a diff rather than a rewrite.

Usage:
    python3 tools/gen_lapack.py [path/to/lapack.h] > src/lapack/c.zig

The declarations are extremely regular -- every parameter of every routine is a
pointer, and Apple annotates each one `_Nonnull` or `_Nullable` -- which is what
makes mechanical translation safe here. Two things are deliberately *not*
mechanical:

  * `cladiv` and `zladiv` are declared wrongly in the header (see OVERRIDES).
  * Any *new* routine with a leading `ret` out-parameter aborts the run rather
    than being emitted from the header's shape, because that is the exact
    signature pattern the two known-broken routines have.
"""

import re
import sys

DEFAULT_HEADER = (
    "/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk/System/Library"
    "/Frameworks/Accelerate.framework/Versions/A/Frameworks/vecLib.framework"
    "/Versions/A/Headers/lapack.h"
)

# Routines whose header declaration does not match the shipping symbol.
#
# cladiv/zladiv are typed as `void f(complex *ret, const complex *x, const
# complex *y)`, and calling them that way leaves `ret` untouched. The shipping
# symbol is a thunk -- `mov x0, x1; mov x1, x2; b <impl>` -- that discards the
# first argument and tail-calls an implementation returning the quotient by
# value. All three pointers must still be passed (a two-argument call crashes,
# because the thunk shifts x2 into place regardless), but the result arrives in
# registers. Verified against the shipping framework from both C and Zig.
OVERRIDES = {
    "cladiv": (
        "*const fn ([*]Complex(f32), [*]const Complex(f32), [*]const Complex(f32)) "
        "callconv(.c) Complex(f32)"
    ),
    "zladiv": (
        "*const fn ([*]Complex(f64), [*]const Complex(f64), [*]const Complex(f64)) "
        "callconv(.c) Complex(f64)"
    ),
}

# Routines allowed to have a leading `ret` parameter. chla_transtype writes
# through it exactly as declared; it was tested alongside cladiv and is fine.
RET_PARAM_ALLOWED = {"chla_transtype", "cladiv", "zladiv"}

SCALARS = {
    "float": "f32",
    "double": "f64",
    "__LAPACK_float_complex": "Complex(f32)",
    "__LAPACK_double_complex": "Complex(f64)",
    "__LAPACK_int": "Int",
    "__LAPACK_bool": "Bool",
    "char": "u8",
}

FUNC_PTR = re.compile(r"__LAPACK_(\w)(gees|gges)_func_ptr")

DECL = re.compile(
    r"^(?P<ret>[A-Za-z_][\w]*)\s*\n"
    r"(?P<name>\w+)_\(\s*(?P<params>[^)]*)\)\s*\n"
    r"__LAPACK_ALIAS\((?P<alias>\w+)\)",
    re.M,
)


def zig_param(raw: str) -> str:
    """Translate one C parameter declaration into a Zig type."""
    text = " ".join(raw.split())

    m = FUNC_PTR.search(text)
    if m:
        prec, kind = m.group(1), m.group(2)
        elem = {"s": "f32", "d": "f64", "c": "Complex(f32)", "z": "Complex(f64)"}[prec]
        # Passed as null when SORT = 'N', so it has to be optional.
        return f"?types.Select{'Schur' if kind == 'gees' else 'Generalized'}Fn({elem})"

    is_const = bool(re.match(r"\bconst\b", text))
    nullable = "_Nullable" in text

    base = None
    for c_type, zig_type in SCALARS.items():
        if re.search(r"\b" + re.escape(c_type) + r"\b", text):
            base = zig_type
            break
    if base is None:
        raise SystemExit(f"unknown parameter type: {raw!r}")

    # The one by-value parameter in the header: chla_transtype's output-string
    # length. Everything else is Fortran-style by reference.
    if "*" not in text:
        return base

    if "_Nullable" not in text and "_Nonnull" not in text:
        raise SystemExit(f"unannotated pointer parameter: {raw!r}")

    if text.count("*") != 1:
        raise SystemExit(f"unexpected pointer depth: {raw!r}")

    # Every LAPACK parameter is passed by reference, so a many-item pointer is
    # always ABI-correct and never implies a length of one. Nullability is
    # meaningful in this header -- `_Nullable` marks arrays a given option
    # setting may leave untouched -- so it is preserved rather than flattened.
    inner = f"const {base}" if is_const else base
    return f"?[*]{inner}" if nullable else f"[*]{inner}"


def zig_return(c_type: str) -> str:
    if c_type == "void":
        return "void"
    if c_type not in SCALARS:
        raise SystemExit(f"unknown return type: {c_type}")
    return SCALARS[c_type]


def main() -> None:
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_HEADER
    with open(path) as fh:
        src = fh.read()

    out = []
    count = 0
    for m in DECL.finditer(src):
        alias = m.group("alias")
        count += 1

        params = [p for p in m.group("params").split(",") if p.strip()]
        first = params[0] if params else ""
        if re.search(r"\bret(_val)?\b", first) and alias not in RET_PARAM_ALLOWED:
            raise SystemExit(
                f"{alias} has a leading `ret` out-parameter, the same shape as the "
                "known-broken cladiv/zladiv. Disassemble the shipping symbol before "
                "trusting the header, then add it to RET_PARAM_ALLOWED or OVERRIDES."
            )

        if alias in OVERRIDES:
            sig = OVERRIDES[alias]
        else:
            arg_types = [zig_param(p) for p in params]
            sig = (
                f"*const fn ({', '.join(arg_types)}) "
                f"callconv(.c) {zig_return(m.group('ret'))}"
            )

        out.append(
            f'pub const {alias} = @extern({sig}, '
            f'.{{ .name = "{alias}" ++ types.alias_suffix }});'
        )

    if count != 2032:
        print(
            f"warning: parsed {count} declarations, expected 2032 "
            "(SDK change? check the DECL regex)",
            file=sys.stderr,
        )

    print(PREAMBLE.format(count=count))
    print("\n".join(out))
    print(EPILOGUE)


PREAMBLE = '''\
//! LAPACK extern declarations, generated from `vecLib/lapack.h`.
//!
//! Do not edit by hand. Regenerate with:
//!
//! ```sh
//! python3 tools/gen_lapack.py > src/lapack/c.zig && zig fmt src/lapack/c.zig
//! ```
//!
//! {count} declarations. Every symbol carries the `$NEWLAPACK[$ILP64]` suffix
//! `__LAPACK_ALIAS` applies in the header - binding the plain `sgesv_` spelling
//! would silently select the deprecated `clapack.h` implementation instead.
//! See `types.zig`.
//!
//! ## Reading these signatures
//!
//! LAPACK is Fortran, so *every* parameter is a pointer - there are no by-value
//! scalars anywhere in the interface. A scalar argument like `n` or `lda` is
//! `[*]const Int`, and callers pass `@ptrCast(&n)`. That uniformity is why this
//! file can be generated at all.
//!
//! Nullability is preserved from the header because it carries real
//! information: `_Nullable` marks arrays that some option settings leave
//! untouched (`jobz = 'N'` never writes `z`), while `_Nonnull` marks scalars and
//! workspaces that are always dereferenced. Note that `work` is `_Nonnull` even
//! for a workspace query, since the query writes the optimal size to `work[0]`.
//!
//! There are no hidden Fortran string-length arguments. `chla_transtype` is the
//! only routine in the entire header that takes a length, and it is for an
//! output string.
//!
//! Prefer the checked wrappers over these declarations.

const types = @import("types.zig");

const Int = types.Int;
const Bool = types.Bool;
const Complex = types.Complex;
'''

EPILOGUE = '''
// Zig resolves container declarations lazily, so an `@extern` nobody references
// is never checked and a misspelled symbol would link fine right up until the
// first caller. With 2032 of them generated from a regex, that is not a
// theoretical concern. Referencing every one forces resolution and turns a bad
// name - or a `$NEWLAPACK[$ILP64]` suffix a future SDK stops exporting - into a
// link error the suite catches.
test "every declared symbol resolves and links" {
    const std = @import("std");
    // One branch per declaration, and there are 2032 of them.
    @setEvalBranchQuota(20000);
    var sink: usize = 0;
    inline for (@typeInfo(@This()).@"struct".decls) |decl| {
        const field = @field(@This(), decl.name);
        if (@typeInfo(@TypeOf(field)) == .pointer) {
            sink +%= @intFromPtr(field);
        }
    }
    try std.testing.expect(sink != 0);
}'''


if __name__ == "__main__":
    main()
