//! Translating LAPACK's `info` into Zig errors.
//!
//! Every LAPACK routine reports through a single `info` integer with three
//! distinct meanings:
//!
//! | `info` | meaning |
//! |---|---|
//! | `0` | success |
//! | `< 0` | argument `-info` was illegal; nothing was computed |
//! | `> 0` | a routine-specific numerical condition |
//!
//! The negative case is uniform and always a programming error. The positive
//! case is not uniform at all - it is a pivot index for `getrf`, a leading
//! minor order for `potrf`, a count of unconverged off-diagonals for `syev`,
//! and an index into an eigenvalue cluster for `trsen`. There is no general
//! rule, so this module deliberately does not provide one `check` function.
//! Each wrapper picks the checker matching its routine's documented meaning.
//!
//! A Zig error cannot carry a payload, so the offending `info` is stashed in a
//! threadlocal that `lastInfo()` reads back. The same shape as the `reportError`
//! plumbing in `sparse/types.zig`.

const std = @import("std");
const types = @import("types.zig");

const Int = types.Int;

pub const Error = error{
    /// `info < 0`: argument `-info` was illegal. Always a caller bug - a
    /// mismatched leading dimension, a negative extent, an option character the
    /// routine does not accept. `lastInfo()` returns the negative value, so the
    /// argument position is `-lastInfo()`.
    InvalidArgument,

    /// A factorization completed but the factor is exactly singular, so it
    /// cannot be used to solve. `lastInfo()` gives the position of the zero
    /// pivot (`getrf`, `gbtrf`, `gttrf`, `sytrf`, `hetrf`).
    SingularMatrix,

    /// The matrix is not positive definite, so the Cholesky factorization could
    /// not complete. `lastInfo()` gives the order of the leading minor that
    /// failed (`potrf`, `pptrf`, `pbtrf`, `pftrf`, `pstrf`).
    NotPositiveDefinite,

    /// An iterative phase hit its limit. What `lastInfo()` counts depends on
    /// the routine: unconverged off-diagonal elements for `syev`/`heev`,
    /// unconverged superdiagonals for `gesvd`, the index past which the Schur
    /// form failed for `hseqr`/`geev`.
    NoConvergence,

    /// The problem is rank-deficient or otherwise degenerate in a way the
    /// routine reports rather than failing: a zero pivot in a generalized
    /// problem, a `tgsyl` common eigenvalue, a `trsyl` perturbed solution.
    Degenerate,
};

threadlocal var last_info: Int = 0;

/// The `info` value behind the most recent error on this thread.
///
/// Only meaningful immediately after a wrapper returned an error; the value is
/// not cleared on success, because clearing it would cost a write on every call
/// for the benefit of a caller who has no reason to look.
pub fn lastInfo() Int {
    return last_info;
}

fn fail(info: Int, err: Error) Error {
    last_info = info;
    return err;
}

/// For routines whose `info` is only ever negative - the many computational
/// routines that cannot fail numerically (`getrs`, `lacpy`, `orgqr`, ...).
///
/// A positive `info` from one of these means this binding is wrong about the
/// routine, so it is reported as `InvalidArgument` rather than silently ignored.
pub fn checkArgs(info: Int) Error!void {
    if (info != 0) return fail(info, error.InvalidArgument);
}

/// `getrf`, `gbtrf`, `gttrf`, `gesv` and the other LU paths: `info > 0` is the
/// index of an exactly-zero pivot.
pub fn checkLu(info: Int) Error!void {
    if (info < 0) return fail(info, error.InvalidArgument);
    if (info > 0) return fail(info, error.SingularMatrix);
}

/// `potrf`, `posv`, `pptrf`, `pbtrf` and the other Cholesky paths: `info > 0`
/// is the order of the leading minor that was not positive definite.
pub fn checkCholesky(info: Int) Error!void {
    if (info < 0) return fail(info, error.InvalidArgument);
    if (info > 0) return fail(info, error.NotPositiveDefinite);
}

/// The symmetric-indefinite paths (`sytrf`, `hetrf`, `sysv`, ...): `info > 0`
/// is the index of a zero block in D.
pub fn checkIndefinite(info: Int) Error!void {
    if (info < 0) return fail(info, error.InvalidArgument);
    if (info > 0) return fail(info, error.SingularMatrix);
}

/// Eigenvalue and SVD routines: `info > 0` means the iteration did not
/// converge. `lastInfo()` carries the routine-specific count.
pub fn checkConvergence(info: Int) Error!void {
    if (info < 0) return fail(info, error.InvalidArgument);
    if (info > 0) return fail(info, error.NoConvergence);
}

/// Routines that report a degenerate-but-computed outcome (`trsyl` perturbing
/// to avoid a common eigenvalue, `tgsyl`, `gesc2`).
pub fn checkDegenerate(info: Int) Error!void {
    if (info < 0) return fail(info, error.InvalidArgument);
    if (info > 0) return fail(info, error.Degenerate);
}

test "negative info reports the argument position" {
    try std.testing.expectError(error.InvalidArgument, checkArgs(-4));
    try std.testing.expectEqual(@as(Int, -4), lastInfo());
    // The caller reads the argument index as -lastInfo().
    try std.testing.expectEqual(@as(Int, 4), -lastInfo());
}

test "positive info means different things to different checkers" {
    try std.testing.expectError(error.SingularMatrix, checkLu(3));
    try std.testing.expectEqual(@as(Int, 3), lastInfo());

    try std.testing.expectError(error.NotPositiveDefinite, checkCholesky(3));
    try std.testing.expectEqual(@as(Int, 3), lastInfo());

    try std.testing.expectError(error.NoConvergence, checkConvergence(3));

    // checkArgs is for routines that document no positive outcome at all, so a
    // positive value there indicates a mis-bound routine, not a live condition.
    try std.testing.expectError(error.InvalidArgument, checkArgs(3));
}

test "zero info is success everywhere" {
    try checkArgs(0);
    try checkLu(0);
    try checkCholesky(0);
    try checkIndefinite(0);
    try checkConvergence(0);
    try checkDegenerate(0);
}
