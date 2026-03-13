/*
    File:       vecLib/vDSP.h
    Contains:   AltiVec DSP Interfaces
    Version:    vecLib-1123.40
    Copyright:  Copyright (c) 2000-2025 by Apple Inc. All rights reserved.
    For vDSP documentation, search for "vDSP" at <http://developer.apple.com>
    or search for one of the routine names below.
    Some documentation for vDSP routines is provided below.
    To report bugs, please use <http://developer.apple.com/bugreporter>.
*/
#ifndef __VDSP__
#define __VDSP__

// Tell compiler this file is idempotent (no need to process it more than once).
#if PRAGMA_ONCE
#pragma once
#endif

/*  Documentation conventions:
        Many of the routines below are documented with C-like pseudocode that
        describes what they do.  For example, vDSP_vadd is declared with:
            extern void vDSP_vadd(
                const float *__A,
                vDSP_Stride  __IA,
                const float *__B,
                vDSP_Stride  __IB,
                float       *__C,
                vDSP_Stride  __IC,
                vDSP_Length  __N)
                                        API_AVAILABLE(macos(10.0), ios(4.0));

        and is described with:
            for (n = 0; n < N; ++n)
                C[n] = A[n] + B[n];
        The pseudocode uses two important simplifications:
            Names are shortened.
                The prefix "__" is removed.  This prefix is used in this
                header file so that Apple parameter names do not conflict with
                other developer macro names that might be used in source files
                that include this header, as when a program might use "#define
                N 1024" to set a preprocessor macro "N" to expand to "1024".
            Vectors are simplified by omitting strides.
                The parameters A and IA (with the prefix omitted) represent a
                vector with its elements at memory locations A[i*IA], for
                appropriate values of i.  In the pseudocode, the stride IA
                is omitted; the vector is treated as a simple mathematical
                vector with elements A[i].

                This default map is assumed for all vDSP routines unless stated
                otherwise.  An array without a stride parameter has unit
                stride.  Some routines have more complicated maps.  These are
                documented with each routine.

    Default maps:

        These default maps are used unless documented otherwise for a routine.
        For real vectors:

            Pseudocode:     Memory:
            C[n]            C[n*IC]

        For complex vectors:

            Pseudocode:     Memory:
            C[n]            C->realp[n*IC] + i * C->imagp[n*IC]

        Observe that C[n] in the pseudocode is a complex number, with a real
        component and an imaginary component.


    Pseudocode:

        The pseudo-code used to describe routines is largely C with some
        additions:

            e, pi, and i are the usual mathematical constants, approximately
            2.71828182845, 3.1415926535, and sqrt(-1).

            "**" is exponentiation.  3**4 is 81.

            Re and Im are the real and imaginary parts of a complex number.
            Re(3+4*i) is 3, and Im(3+4*i) is 4.

            sum(f(j), 0 <= j < N) is the sum of f(j) evaluated for each integer
            j from 0 (inclusive) to N (exclusive).  sum(j**2, 0 <= j < 4) is
            0 + 1 + 4 + 9 = 14.  Multiple dimensions may be used.  Thus,
            sum(f(j, k), 0 <= j < M, 0 <= k < N) is the sum of f(j, k)
            evaluated for each pair of integers (j, k) satisfying the
            constraints.

            conj(z) is the complex conjugate of z (the imaginary part is
            negated).

            |x| is the absolute value of x.

   Exactness, IEEE 754 conformance:

        vDSP routines are not expected to produce results identical to the
        pseudo-code in the descriptions, because vDSP routines are free to
        rearrange calculations for better performance.  These rearrangements
        are mathematical identities, so they would produce identical results
        if exact arithmetic were used.  However, floating-point arithmetic
        is approximate, and the rounding errors will often be different when
        operations are rearranged.

        Generally, vDSP routines are not expected to conform to IEEE 754.
        Notably, results may be not correctly rounded to the last bit even for
        elementary operations, and operations involving infinities and NaNs may
        be handled differently than IEEE 754 specifies.

    Const:

        vDSP does not modify the contents of input arrays (including input
        scalars passed by address).  If the specification of a routine does not
        state that it alters the memory that a parameter points to, then the
        routine does not alter that memory through that parameter.  (It may of
        course alter the same memory if it is also pointed to by an output
        parameter.  Such in-place operation is permitted for some vDSP routines
        and not for others.)

        Unfortunately, C semantics make it impractical to add "const" to
        pointers inside structs, because such structs are type-incompatible
        with structs containing pointers that are not const.  Thus, vDSP
        routines with complex parameters accept those parameters via
        DSPSplitComplex and DSPDoubleSplitComplex structs (among other types)
        and not via const versions of those structures.

    Strides:

        (Note:  This section introduces strides.  For an issue using strides
        with complex data, see "Complex strides" below.)

        Many vDSP routines use strides, which specify that the vector operated
        on is embedded in a larger array in memory.  Consider an array A of
        1024 elements.  Then:

            Passing a vDSP routine:     Says to operate on:

            Address A and stride 1      Each element A[j]

            Address A and stride 2      Every other element, A[j*2]

            Address A+1 and stride 2    Every other element, starting
                                        with A[1], so A[j*2+1]

        Strides may be used to operate on columns of multi-dimensional arrays.
        For example, consider a 32*64 element array, A[32][64].  Then passing
        address A+13 and stride 64 instructs vDSP to operate on the elements of
        column 13.

        When strides are used, generally there is some accompanying parameter
        that specifies the length of the operation.  This length is typically
        the number of elements to be processed, not the number in the larger
        array.  (Some vDSP routines have interactions between parameters so
        that the length may specify some number of output elements but requires
        a different numbe of input elements.  This is documented with each
        routine.)

    Complex strides:

        Strides with complex data (interleaved complex data, not split
        complex data) are complicated by a legacy issue.  Originally, complex
        data was regarded as an array of individual elements, so that memory
        containing values to represent complex numbers 2 + 3i, 4 + 5i, 6 + 7i,
        and so on, contained individual floating-point elements:

            A[0] A[1] A[2] A[3] A[4] A[5]…
             2    3    4    5    6    7  …

        This arrangement was said to have a stride of two, indicating that a
        new complex number starts every two elements.  In the modern view, we
        would regard this as an array of struct with a stride of one struct.
        Unfortunately, the vDSP interface is bound by requirements of backward
        compatibility and must retain the original use.

        Adding to this issue, a parameter is declared as a pointer to DSPComplex
        or DSPDoubleComplex (both structures of two floating-point elements),
        but its stride is still passed as a stride of floating-point elements.
        This means that, in C, to refer to complex element i of a vector C with
        stride IC, you must divide the stride by 2, using C[i*IC/2].
        Essentially, the floating-point element stride passed to the vDSP
        routine, IA, should be twice the complex-number struct stride.
*/

#if __has_include(<os/availability.h>)
#include <os/availability.h>
#else // __has_include(<os/availability.h>)
#if !defined API_AVAILABLE
#define API_AVAILABLE(...)
#endif

#if !defined API_DEPRECATED_WITH_REPLACEMENT
#define API_DEPRECATED_WITH_REPLACEMENT(...)
#endif
#endif // __has_include(<os/availability.h>)

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#include <TargetConditionals.h>
#if !0 && !0 && (__STDC_HOSTED__ == 1)

#include <CoreFoundation/CFAvailability.h>
#define vDSP_ENUM CF_ENUM
#else
#define __vDSP_ENUM_GET_MACRO(_1, _2, NAME, ...) NAME
#define __vDSP_NAMED_ENUM(_type, _name)                                        \
  _type _name;                                                                 \
  enum
#define __vDSP_ANON_ENUM(_type) enum
#define vDSP_ENUM(...)                                                         \
  __vDSP_ENUM_GET_MACRO(__VA_ARGS__, __vDSP_NAMED_ENUM,                        \
                        __vDSP_ANON_ENUM)(__VA_ARGS__)
#endif

#if !defined __has_feature
#define __has_feature(f) 0
#endif
#if __has_feature(assume_nonnull)
_Pragma("clang assume_nonnull begin")
#else
#define __nullable
#define __nonnull
#endif

#pragma options align = power

/*  These symbols describe the vecLib version associated with this header.

    vDSP_Version0 is a major version number.
    vDSP_Version1 is a minor version number.
*/
#define vDSP_Version0 1123
#define vDSP_Version1 40

    /*  Define types:

            vDSP_Length for numbers of elements in arrays and for indices of
            elements in arrays.  (It is also used for the base-two logarithm of
            numbers of elements, although a much smaller type is suitable for
            that.)

            vDSP_Stride for differences of indices of elements (which of course
            includes strides).
    */
    typedef unsigned long vDSP_Length;
#if defined __arm64__ && !defined __LP64__
typedef long long vDSP_Stride;
#else
typedef long vDSP_Stride;
#endif

/*  A DSPComplex or DSPDoubleComplex is a pair of float or double values that
    together represent a complex value.
*/
typedef struct DSPComplex {
  float real;
  float imag;
} DSPComplex;
typedef struct DSPDoubleComplex {
  double real;
  double imag;
} DSPDoubleComplex;

/*  A DSPSplitComplex or DSPDoubleSplitComplex is a structure containing
    two pointers, each to an array of float or double.  These represent arrays
    of complex values, with the real components of the values stored in one
    array and the imaginary components of the values stored in a separate
    array.
*/
typedef struct DSPSplitComplex {
  float *__nonnull realp;
  float *__nonnull imagp;
} DSPSplitComplex;
typedef struct DSPDoubleSplitComplex {
  double *__nonnull realp;
  double *__nonnull imagp;
} DSPDoubleSplitComplex;

/*  The following statements declare a few simple types and constants used by
    various vDSP routines.
*/
typedef int FFTDirection;
typedef int FFTRadix;
enum { kFFTDirection_Forward = +1, kFFTDirection_Inverse = -1 };
enum { kFFTRadix2 = 0, kFFTRadix3 = 1, kFFTRadix5 = 2 };
enum { vDSP_HALF_WINDOW = 1, vDSP_HANN_DENORM = 0, vDSP_HANN_NORM = 2 };

/*  The following types define 24-bit data.
 */
typedef struct {
  uint8_t bytes[3];
} vDSP_uint24; // Unsigned 24-bit integer.
typedef struct {
  uint8_t bytes[3];
} vDSP_int24; // Signed 24-bit integer.

/*  The following types are pointers to structures that contain data used
    inside vDSP routines to assist FFT and biquad filter operations.  The
    contents of these structures may change from release to release, so
    applications should manipulate the values only via the corresponding vDSP
    setup and destroy routines.
*/
typedef struct OpaqueFFTSetup *FFTSetup;
typedef struct OpaqueFFTSetupD *FFTSetupD;
typedef struct vDSP_biquad_SetupStruct *vDSP_biquad_Setup;
typedef struct vDSP_biquad_SetupStructD *vDSP_biquad_SetupD;

/*  vDSP_biquadm_Setup or vDSP_biquadm_SetupD is a pointer to a filter object
    to be used with a multi-channel cascaded biquad IIR.  This object carries
    internal state which may be modified by any routine which uses it.  Upon
    creation, the state is initialized such that all delay elements are zero.

    Each filter object should only be used in a single thread at a time.
*/
typedef struct vDSP_biquadm_SetupStruct *vDSP_biquadm_Setup;
typedef struct vDSP_biquadm_SetupStructD *vDSP_biquadm_SetupD;

/*  vDSP_create_fftsetup and vDSP_create_ffsetupD allocate memory and prepare
    constants used by single- and double-precision FFT routines, respectively.

    vDSP_destroy_fftsetup and vDSP_destroy_fftsetupD free the memory.  They
    may be passed a null pointer, in which case they have no effect.
*/
extern __nullable FFTSetup vDSP_create_fftsetup(vDSP_Length __Log2n,
                                                FFTRadix __Radix)
    API_AVAILABLE(macos(10.0), ios(4.0));

extern void vDSP_destroy_fftsetup(__nullable FFTSetup __setup)
    API_AVAILABLE(macos(10.0), ios(4.0));

extern __nullable FFTSetupD vDSP_create_fftsetupD(vDSP_Length __Log2n,
                                                  FFTRadix __Radix)
    API_AVAILABLE(macos(10.2), ios(4.0));

extern void vDSP_destroy_fftsetupD(__nullable FFTSetupD __setup)
    API_AVAILABLE(macos(10.2), ios(4.0));

/*  vDSP_biquad_CreateSetup allocates memory and prepares the coefficients for
    processing a cascaded biquad IIR filter.

    vDSP_biquad_DestroySetup frees the memory allocated by
    vDSP_biquad_CreateSetup.
*/
extern __nullable vDSP_biquad_Setup
vDSP_biquad_CreateSetup(const double *__Coefficients, vDSP_Length __M)
    API_AVAILABLE(macos(10.9), ios(6.0));
extern __nullable vDSP_biquad_SetupD
vDSP_biquad_CreateSetupD(const double *__Coefficients, vDSP_Length __M)
    API_AVAILABLE(macos(10.9), ios(6.0));

/*
    vDSP_biquad_SetCoefficientsDouble will
    update the filter coefficients within a valid vDSP_biquad_Setup object.

    Coefficients are specified in double precision.
 */
extern void vDSP_biquad_SetCoefficientsDouble(vDSP_biquad_Setup __setup,
                                              const double *__coeffs,
                                              vDSP_Length __start_sec,
                                              vDSP_Length __nsec)
    API_AVAILABLE(macos(12.0), ios(15.0));

/*
    vDSP_biquad_SetCoefficientsSingle will
    update the filter coefficients within a valid vDSP_biquad_Setup object.

    Coefficients are specified in single precision.
 */
extern void vDSP_biquad_SetCoefficientsSingle(vDSP_biquad_Setup __setup,
                                              const float *__coeffs,
                                              vDSP_Length __start_sec,
                                              vDSP_Length __nsec)
    API_AVAILABLE(macos(12.0), ios(15.0));

extern void vDSP_biquad_DestroySetup(__nullable vDSP_biquad_Setup __setup)
    API_AVAILABLE(macos(10.9), ios(6.0));
extern void vDSP_biquad_DestroySetupD(__nullable vDSP_biquad_SetupD __setup)
    API_AVAILABLE(macos(10.9), ios(6.0));

/*  vDSP_biquadm_CreateSetup (for float) or vDSP_biquadm_CreateSetupD (for
    double) allocates memory and prepares the coefficients for processing a
    multi-channel cascaded biquad IIR filter.  Delay values are set to zero.

    Unlike some other setup objects in vDSP, a vDSP_biquadm_Setup or
    vDSP_biquadm_SetupD contains data that is modified during a vDSP_biquadm or
    vDSP_biquadmD call, and it therefore may not be used more than once
    simultaneously, as in multiple threads.

    vDSP_biquadm_DestroySetup (for single) or vDSP_biquadm_DestroySetupD (for
    double) frees the memory allocated by the corresponding create-setup
    routine.
*/
extern __nullable vDSP_biquadm_Setup vDSP_biquadm_CreateSetup(
    const double *__coeffs, vDSP_Length __M, vDSP_Length __N)
    API_AVAILABLE(macos(10.9), ios(7.0));
extern __nullable vDSP_biquadm_SetupD vDSP_biquadm_CreateSetupD(
    const double *__coeffs, vDSP_Length __M, vDSP_Length __N)
    API_AVAILABLE(macos(10.10), ios(8.0));
extern void vDSP_biquadm_DestroySetup(vDSP_biquadm_Setup __setup)
    API_AVAILABLE(macos(10.9), ios(7.0));
extern void vDSP_biquadm_DestroySetupD(vDSP_biquadm_SetupD __setup)
    API_AVAILABLE(macos(10.10), ios(8.0));

/*  vDSP_biquadm_CopyState (for float) or vDSP_biquadm_CopyStateD (for double)
    copies the current state between two biquadm setup objects.  The two
    objects must have been created with the same number of channels and
    sections.

    vDSP_biquadm_ResetState (for float) or vDSP_biquadm_ResetStateD (for
    double) sets the delay values of a biquadm setup object to zero.
*/
extern void vDSP_biquadm_CopyState(vDSP_biquadm_Setup __dest,
                                   const struct vDSP_biquadm_SetupStruct *__src)
    API_AVAILABLE(macos(10.9), ios(7.0));
extern void
vDSP_biquadm_CopyStateD(vDSP_biquadm_SetupD __dest,
                        const struct vDSP_biquadm_SetupStructD *__src)
    API_AVAILABLE(macos(10.10), ios(8.0));
extern void vDSP_biquadm_ResetState(vDSP_biquadm_Setup __setup)
    API_AVAILABLE(macos(10.9), ios(7.0));
extern void vDSP_biquadm_ResetStateD(vDSP_biquadm_SetupD __setup)
    API_AVAILABLE(macos(10.10), ios(8.0));

/*
    vDSP_biquadm_SetCoefficientsDouble will
    update the filter coefficients within a valid vDSP_biquadm_Setup object.
 */

extern void vDSP_biquadm_SetCoefficientsDouble(
    vDSP_biquadm_Setup __setup, const double *__coeffs, vDSP_Length __start_sec,
    vDSP_Length __start_chn, vDSP_Length __nsec, vDSP_Length __nchn)
    API_AVAILABLE(macos(10.11), ios(9.0));

/*
    vDSP_biquadm_SetCoefficientsDoubleD will
    update the filter coefficients within a valid vDSP_biquadm_SetupD object.
 */
extern void vDSP_biquadm_SetCoefficientsDoubleD(
    vDSP_biquadm_SetupD __setup, const double *__coeffs,
    vDSP_Length __start_sec, vDSP_Length __start_chn, vDSP_Length __nsec,
    vDSP_Length __nchn) API_AVAILABLE(macos(13.0), ios(16.0));

/*
    vDSP_biquadm_SetTargetsDouble will
    set the target coefficients within a valid vDSP_biquadm_Setup object.
 */

extern void vDSP_biquadm_SetTargetsDouble(
    vDSP_biquadm_Setup __setup, const double *__targets, float __interp_rate,
    float __interp_threshold, vDSP_Length __start_sec, vDSP_Length __start_chn,
    vDSP_Length __nsec, vDSP_Length __nchn)
    API_AVAILABLE(macos(10.11), ios(9.0));

/*
    vDSP_biquadm_SetTargetsDoubleD will
    set the target coefficients within a valid vDSP_biquadm_SetupD object.
 */
extern void vDSP_biquadm_SetTargetsDoubleD(
    vDSP_biquadm_SetupD __setup, const double *__targets, double __interp_rate,
    double __interp_threshold, vDSP_Length __start_sec, vDSP_Length __start_chn,
    vDSP_Length __nsec, vDSP_Length __nchn)
    API_AVAILABLE(macos(13.0), ios(16.0));

/*
    vDSP_biquadm_SetCoefficientsSingle will
    update the filter coefficients within a valid vDSP_biquadm_Setup object.

    Coefficients are specified in single precision.
 */

extern void vDSP_biquadm_SetCoefficientsSingle(
    vDSP_biquadm_Setup __setup, const float *__coeffs, vDSP_Length __start_sec,
    vDSP_Length __start_chn, vDSP_Length __nsec, vDSP_Length __nchn)
    API_AVAILABLE(macos(10.11), ios(9.0));

/*
    vDSP_biquadm_SetCoefficientsSingleD will
    update the filter coefficients within a valid vDSP_biquadm_SetupD object.

    Coefficients are specified in single precision.
 */
extern void vDSP_biquadm_SetCoefficientsSingleD(
    vDSP_biquadm_SetupD __setup, const float *__coeffs, vDSP_Length __start_sec,
    vDSP_Length __start_chn, vDSP_Length __nsec, vDSP_Length __nchn)
    API_AVAILABLE(macos(13.0), ios(16.0));

/*
    vDSP_biquadm_SetTargetsSingle will
    set the target coefficients within a valid vDSP_biquadm_Setup object.
    The target values are specified in single precision.
 */

extern void vDSP_biquadm_SetTargetsSingle(
    vDSP_biquadm_Setup __setup, const float *__targets, float __interp_rate,
    float __interp_threshold, vDSP_Length __start_sec, vDSP_Length __start_chn,
    vDSP_Length __nsec, vDSP_Length __nchn)
    API_AVAILABLE(macos(10.11), ios(9.0));

/*
    vDSP_biquadm_SetTargetsSingleD will
    set the target coefficients within a valid vDSP_biquadm_SetupD object.
    The target values are specified in single precision.
 */
extern void vDSP_biquadm_SetTargetsSingleD(
    vDSP_biquadm_SetupD __setup, const float *__targets, double __interp_rate,
    double __interp_threshold, vDSP_Length __start_sec, vDSP_Length __start_chn,
    vDSP_Length __nsec, vDSP_Length __nchn)
    API_AVAILABLE(macos(13.0), ios(16.0));

/*
    vDSP_biquadm_SetActiveFilters will set the overall active/inactive filter
    state of a valid vDSP_biquadm_Setup object.
 */
extern void vDSP_biquadm_SetActiveFilters(vDSP_biquadm_Setup __setup,
                                          const bool *__filter_states)
    API_AVAILABLE(macos(10.11), ios(9.0));

/*
    vDSP_biquadm_SetActiveFiltersD will set the overall active/inactive filter
    state of a valid vDSP_biquadm_SetupD object.
 */
extern void vDSP_biquadm_SetActiveFiltersD(vDSP_biquadm_SetupD __setup,
                                           const bool *__filter_states)
    API_AVAILABLE(macos(13.0), ios(16.0));

// Convert a complex array to a complex-split array.
extern void vDSP_ctoz(const DSPComplex *__C, vDSP_Stride __IC,
                      const DSPSplitComplex *__Z, vDSP_Stride __IZ,
                      vDSP_Length __N) API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_ctozD(const DSPDoubleComplex *__C, vDSP_Stride __IC,
                       const DSPDoubleSplitComplex *__Z, vDSP_Stride __IZ,
                       vDSP_Length __N) API_AVAILABLE(macos(10.2), ios(4.0));
/*  Map:

        Pseudocode:     Memory:
        C[n]            C[n*IC/2].real + i * C[n*IC/2].imag
        Z[n]            Z->realp[n*IZ] + i * Z->imagp[n*IZ]

    These compute:

        for (n = 0; n < N; ++n)
            Z[n] = C[n];
*/

//  Convert a complex-split array to a complex array.
extern void vDSP_ztoc(const DSPSplitComplex *__Z, vDSP_Stride __IZ,
                      DSPComplex *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_ztocD(const DSPDoubleSplitComplex *__Z, vDSP_Stride __IZ,
                       DSPDoubleComplex *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Map:

        Pseudocode:     Memory:
        Z[n]            Z->realp[n*IZ] + i * Z->imagp[n*IZ]
        C[n]            C[n*IC/2].real + i * C[n*IC/2].imag

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = Z[n];
*/

/*  In-place complex Discrete Fourier Transform routines, with and without
    temporary memory.  We suggest you use the DFT routines instead of these.
*/
extern void vDSP_fft_zip(FFTSetup __Setup, const DSPSplitComplex *__C,
                         vDSP_Stride __IC, vDSP_Length __Log2N,
                         FFTDirection __Direction)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_fft_zipD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__C,
                          vDSP_Stride __IC, vDSP_Length __Log2N,
                          FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_fft_zipt(FFTSetup __Setup, const DSPSplitComplex *__C,
                          vDSP_Stride __IC, const DSPSplitComplex *__Buffer,
                          vDSP_Length __Log2N, FFTDirection __Direction)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_fft_ziptD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__C,
                           vDSP_Stride __IC,
                           const DSPDoubleSplitComplex *__Buffer,
                           vDSP_Length __Log2N, FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:

        For this routine, strides are shown explicitly; the default maps
        are not used.

    These compute:

    N = 1 << Log2N;

    scale = 0 < Direction ? 1 : 1./N;

    // Define a complex vector, h:
    for (j = 0; j < N; ++j)
        h[j] = C->realp[j*IC] + i * C->imagp[j*IC];

    // Perform Discrete Fourier Transform.
    for (k = 0; k < N; ++k)
        H[k] = scale * sum(h[j] * e**(-Direction*2*pi*i*j*k/N), 0 <= j < N);

    // Store result.
    for (k = 0; k < N; ++k)
    {
        C->realp[k*IC] = Re(H[k]);
        C->imagp[k*IC] = Im(H[k]);
    }

    Setup must have been properly created by a call to vDSP_create_fftsetup
    (for single precision) or vDSP_create_fftsetupD (for double precision)
    and not subsequently destroyed.

    Direction must be +1 or -1.

    The temporary buffer versions perform the same operation but are
    permitted to use the temporary buffer for improved performance.  Each
    of Buffer->realp and Buffer->imagp must contain the lesser of 16,384
    bytes or N * sizeof *C->realp bytes and is preferably 16-byte aligned
    or better.
*/

/*  Out-of-place complex Discrete Fourier Transform routines, with and without
    temporary memory.  We suggest you use the DFT routines instead of these.
*/
extern void vDSP_fft_zop(FFTSetup __Setup, const DSPSplitComplex *__A,
                         vDSP_Stride __IA, const DSPSplitComplex *__C,
                         vDSP_Stride __IC, vDSP_Length __Log2N,
                         FFTDirection __Direction)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_fft_zopt(FFTSetup __Setup, const DSPSplitComplex *__A,
                          vDSP_Stride __IA, const DSPSplitComplex *__C,
                          vDSP_Stride __IC, const DSPSplitComplex *__Buffer,
                          vDSP_Length __Log2N, FFTDirection __Direction)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_fft_zopD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__A,
                          vDSP_Stride __IA, const DSPDoubleSplitComplex *__C,
                          vDSP_Stride __IC, vDSP_Length __Log2N,
                          FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_fft_zoptD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__A,
                           vDSP_Stride __IA, const DSPDoubleSplitComplex *__C,
                           vDSP_Stride __IC,
                           const DSPDoubleSplitComplex *__Buffer,
                           vDSP_Length __Log2N, FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:

        For this routine, strides are shown explicitly; the default maps
        are not used.

    These compute:

    N = 1 << Log2N;

    scale = 0 < Direction ? 1 : 1./N;

    // Define a complex vector, h:
    for (j = 0; j < N; ++j)
        h[j] = A->realp[j*IA] + i * A->imagp[j*IA];

    // Perform Discrete Fourier Transform.
    for (k = 0; k < N; ++k)
        H[k] = scale * sum(h[j] * e**(-Direction*2*pi*i*j*k/N), 0 <= j < N);

    // Store result.
    for (k = 0; k < N; ++k)
    {
        C->realp[k*IC] = Re(H[k]);
        C->imagp[k*IC] = Im(H[k]);
    }

    Setup must have been properly created by a call to vDSP_create_fftsetup
    (for single precision) or vDSP_create_fftsetupD (for double precision)
    and not subsequently destroyed.

    Direction must be +1 or -1.

    The temporary buffer versions perform the same operation but are
    permitted to use the temporary buffer for improved performance.  Each
    of Buffer->realp and Buffer->imagp must contain the lesser of 16,384
    bytes or N * sizeof *C->realp bytes and is preferably 16-byte aligned
    or better.
*/

/*  In-place real-to-complex Discrete Fourier Transform routines, with and
    without temporary memory.  We suggest you use the DFT routines instead of
    these.
*/
extern void vDSP_fft_zrip(FFTSetup __Setup, const DSPSplitComplex *__C,
                          vDSP_Stride __IC, vDSP_Length __Log2N,
                          FFTDirection __Direction)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_fft_zripD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__C,
                           vDSP_Stride __IC, vDSP_Length __Log2N,
                           FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_fft_zript(FFTSetup __Setup, const DSPSplitComplex *__C,
                           vDSP_Stride __IC, const DSPSplitComplex *__Buffer,
                           vDSP_Length __Log2N, FFTDirection __Direction)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_fft_zriptD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__C,
                            vDSP_Stride __IC,
                            const DSPDoubleSplitComplex *__Buffer,
                            vDSP_Length __Log2N, FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:

        For this routine, strides are shown explicitly; the default maps
        are not used.

    These compute:

    N = 1 << Log2N;

    If Direction is +1, a real-to-complex transform is performed, taking
    input from a real vector that has been coerced into the complex
    structure:

        scale = 2;

        // Define a real vector, h:
        for (j = 0; j < N/2; ++j)
        {
            h[2*j + 0] = C->realp[j*IC];
            h[2*j + 1] = C->imagp[j*IC];
        }

        // Perform Discrete Fourier Transform.
        for (k = 0; k < N; ++k)
            H[k] = scale *
                sum(h[j] * e**(-Direction*2*pi*i*j*k/N), 0 <= j < N);

        // Pack DC and Nyquist components into C->realp[0] and C->imagp[0].
        C->realp[0*IC] = Re(H[ 0 ]).
        C->imagp[0*IC] = Re(H[N/2]).

        // Store regular components:
        for (k = 1; k < N/2; ++k)
        {
            C->realp[k*IC] = Re(H[k]);
            C->imagp[k*IC] = Im(H[k]);
        }

        Note that, for N/2 < k < N, H[k] is not stored.  However, since
        the input is a real vector, the output has symmetry that allows the
        unstored elements to be derived from the stored elements:  H[k] =
        conj(H(N-k)).  This symmetry also implies the DC and Nyquist
        components are real, so their imaginary parts are zero.

    If Direction is -1, a complex-to-real inverse transform is performed,
    producing a real output vector coerced into the complex structure:

        scale = 1./N;

        // Define a complex vector, h:
        h[ 0 ] = C->realp[0*IC];
        h[N/2] = C->imagp[0*IC];
        for (j = 1; j < N/2; ++j)
        {
            h[ j ] = C->realp[j*IC] + i * C->imagp[j*IC];
            h[N-j] = conj(h[j]);
        }

        // Perform Discrete Fourier Transform.
        for (k = 0; k < N; ++k)
            H[k] = scale *
                sum(h[j] * e**(-Direction*2*pi*i*j*k/N), 0 <= j < N);

        // Coerce real results into complex structure:
        for (k = 0; k < N/2; ++k)
        {
            C->realp[k*IC] = H[2*k+0];
            C->imagp[k*IC] = H[2*k+1];
        }

        Note that, mathematically, the symmetry in the input vector compels
        every H[k] to be real, so there are no imaginary components to be
        stored.

    Setup must have been properly created by a call to vDSP_create_fftsetup
    (for single precision) or vDSP_create_fftsetupD (for double precision)
    and not subsequently destroyed.

    Direction must be +1 or -1.

    The temporary buffer versions perform the same operation but are
    permitted to use the temporary buffer for improved performance.  Each
    of Buffer->realp and Buffer->imagp must contain N/2 * sizeof *C->realp
    bytes and is preferably 16-byte aligned or better.
*/

/*  Out-of-place real-to-complex Discrete Fourier Transform routines, with and
    without temporary memory.  We suggest you use the DFT routines instead of
    these.
*/
extern void vDSP_fft_zrop(FFTSetup __Setup, const DSPSplitComplex *__A,
                          vDSP_Stride __IA, const DSPSplitComplex *__C,
                          vDSP_Stride __IC, vDSP_Length __Log2N,
                          FFTDirection __Direction)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_fft_zropD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__A,
                           vDSP_Stride __IA, const DSPDoubleSplitComplex *__C,
                           vDSP_Stride __IC, vDSP_Length __Log2N,
                           FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_fft_zropt(FFTSetup __Setup, const DSPSplitComplex *__A,
                           vDSP_Stride __IA, const DSPSplitComplex *__C,
                           vDSP_Stride __IC, const DSPSplitComplex *__Buffer,
                           vDSP_Length __Log2N, FFTDirection __Direction)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_fft_zroptD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__A,
                            vDSP_Stride __IA, const DSPDoubleSplitComplex *__C,
                            vDSP_Stride __IC,
                            const DSPDoubleSplitComplex *__Buffer,
                            vDSP_Length __Log2N, FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:

        For this routine, strides are shown explicitly; the default maps
        are not used.

    These compute:

    N = 1 << Log2N;

    If Direction is +1, a real-to-complex transform is performed, taking
    input from a real vector that has been coerced into the complex
    structure:

        scale = 2;

        // Define a real vector, h:
        for (j = 0; j < N/2; ++j)
        {
            h[2*j + 0] = A->realp[j*IA];
            h[2*j + 1] = A->imagp[j*IA];
        }

        // Perform Discrete Fourier Transform.
        for (k = 0; k < N; ++k)
            H[k] = scale *
                sum(h[j] * e**(-Direction*2*pi*i*j*k/N), 0 <= j < N);

        // Pack DC and Nyquist components into C->realp[0] and C->imagp[0].
        C->realp[0*IC] = Re(H[ 0 ]).
        C->imagp[0*IC] = Re(H[N/2]).

        // Store regular components:
        for (k = 1; k < N/2; ++k)
        {
            C->realp[k*IC] = Re(H[k]);
            C->imagp[k*IC] = Im(H[k]);
        }

        Note that, for N/2 < k < N, H[k] is not stored.  However, since
        the input is a real vector, the output has symmetry that allows the
        unstored elements to be derived from the stored elements:  H[k] =
        conj(H(N-k)).  This symmetry also implies the DC and Nyquist
        components are real, so their imaginary parts are zero.

    If Direction is -1, a complex-to-real inverse transform is performed,
    producing a real output vector coerced into the complex structure:

        scale = 1./N;

        // Define a complex vector, h:
        h[ 0 ] = A->realp[0*IA];
        h[N/2] = A->imagp[0*IA];
        for (j = 1; j < N/2; ++j)
        {
            h[ j ] = A->realp[j*IA] + i * A->imagp[j*IA];
            h[N-j] = conj(h[j]);
        }

        // Perform Discrete Fourier Transform.
        for (k = 0; k < N; ++k)
            H[k] = scale *
                sum(h[j] * e**(-Direction*2*pi*i*j*k/N), 0 <= j < N);

        // Coerce real results into complex structure:
        for (k = 0; k < N/2; ++k)
        {
            C->realp[k*IC] = H[2*k+0];
            C->imagp[k*IC] = H[2*k+1];
        }

        Note that, mathematically, the symmetry in the input vector compels
        every H[k] to be real, so there are no imaginary components to be
        stored.

    Setup must have been properly created by a call to vDSP_create_fftsetup
    (for single precision) or vDSP_create_fftsetupD (for double precision)
    and not subsequently destroyed.

    Direction must be +1 or -1.

    The temporary buffer versions perform the same operation but are
    permitted to use the temporary buffer for improved performance.  Each
    of Buffer->realp and Buffer->imagp must contain N/2 * sizeof *C->realp
    bytes and is preferably 16-byte aligned or better.
*/

/*  In-place two-dimensional complex Discrete Fourier Transform routines, with
    and without temporary memory.
*/
extern void vDSP_fft2d_zip(FFTSetup __Setup, const DSPSplitComplex *__C,
                           vDSP_Stride __IC0, vDSP_Stride __IC1,
                           vDSP_Length __Log2N0, vDSP_Length __Log2N1,
                           FFTDirection __Direction)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_fft2d_zipD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__C,
                            vDSP_Stride __IC0, vDSP_Stride __IC1,
                            vDSP_Length __Log2N0, vDSP_Length __Log2N1,
                            FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_fft2d_zipt(FFTSetup __Setup, const DSPSplitComplex *__C,
                            vDSP_Stride __IC1, vDSP_Stride __IC0,
                            const DSPSplitComplex *__Buffer,
                            vDSP_Length __Log2N0, vDSP_Length __Log2N1,
                            FFTDirection __Direction)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void
vDSP_fft2d_ziptD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__C,
                 vDSP_Stride __IC0, vDSP_Stride __IC1,
                 const DSPDoubleSplitComplex *__Buffer, vDSP_Length __Log2N0,
                 vDSP_Length __Log2N1, FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:

        For this routine, strides are shown explicitly; the default maps
        are not used.

    These compute:

    N0 = 1 << Log2N0;
    N1 = 1 << Log2N1;

    if (IC1 == 0) IC1 = IC0*N0;

    scale = 0 < Direction ? 1 : 1. / (N1*N0);

    // Define a complex matrix, h:
    for (j1 = 0; j1 < N1; ++j1)
    for (j0 = 0; j0 < N0; ++j0)
        h[j1][j0] = C->realp[j1*IC1 + j0*IC0]
              + i * C->imagp[j1*IC1 + j0*IC0];

    // Perform Discrete Fourier Transform.
    for (k1 = 0; k1 < N1; ++k1)
    for (k0 = 0; k0 < N0; ++k0)
        H[k1][k0] = scale * sum(sum(h[j1][j0]
            * e**(-Direction*2*pi*i*j0*k0/N0), 0 <= j0 < N0)
            * e**(-Direction*2*pi*i*j1*k1/N1), 0 <= j1 < N1);

    // Store result.
    for (k1 = 0; k1 < N1; ++k1)
    for (k0 = 0; k0 < N0; ++k0)
    {
        C->realp[k1*IC1 + k0*IC0] = Re(H[k1][k0]);
        C->imagp[k1*IC1 + k0*IC0] = Im(H[k1][k0]);
    }

    Note that the 0 and 1 dimensions are separate and identical, except
    that IC1 is set to a default, IC0*N0, if it is zero.  If IC1 is not
    zero, then the IC0 and N0 arguments may be swapped with the IC1 and N1
    arguments without affecting the results.

    Setup must have been properly created by a call to vDSP_create_fftsetup
    (for single precision) or vDSP_create_fftsetupD (for double precision)
    and not subsequently destroyed.

    Direction must be +1 or -1.

    The temporary buffer versions perform the same operation but are
    permitted to use the temporary buffer for improved performance.  Each
    of Buffer->realp and Buffer->imagp must contain the lesser of 16,384
    bytes or N1*N0 * sizeof *C->realp bytes and is preferably 16-byte
    aligned or better.
*/

/*  Out-of-place two-dimensional complex Discrete Fourier Transform routines,
    with and without temporary memory.
*/
extern void vDSP_fft2d_zop(FFTSetup __Setup, const DSPSplitComplex *__A,
                           vDSP_Stride __IA0, vDSP_Stride __IA1,
                           const DSPSplitComplex *__C, vDSP_Stride __IC0,
                           vDSP_Stride __IC1, vDSP_Length __Log2N0,
                           vDSP_Length __Log2N1, FFTDirection __Direction)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_fft2d_zopD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__A,
                            vDSP_Stride __IA0, vDSP_Stride __IA1,
                            const DSPDoubleSplitComplex *__C, vDSP_Stride __IC0,
                            vDSP_Stride __IC1, vDSP_Length __Log2N0,
                            vDSP_Length __Log2N1, FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_fft2d_zopt(FFTSetup __Setup, const DSPSplitComplex *__A,
                            vDSP_Stride __IA0, vDSP_Stride __IA1,
                            const DSPSplitComplex *__C, vDSP_Stride __IC0,
                            vDSP_Stride __IC1, const DSPSplitComplex *__Buffer,
                            vDSP_Length __Log2N0, vDSP_Length __Log2N1,
                            FFTDirection __Direction)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void
vDSP_fft2d_zoptD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__A,
                 vDSP_Stride __IA0, vDSP_Stride __IA1,
                 const DSPDoubleSplitComplex *__C, vDSP_Stride __IC0,
                 vDSP_Stride __IC1, const DSPDoubleSplitComplex *__Buffer,
                 vDSP_Length __Log2N0, vDSP_Length __Log2N1,
                 FFTDirection __Direction) API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:

        For this routine, strides are shown explicitly; the default maps
        are not used.

    These compute:

    N0 = 1 << Log2N0;
    N1 = 1 << Log2N1;

    if (IA1 == 0) IA1 = IA0*N0;
    if (IC1 == 0) IC1 = IC0*N0;

    scale = 0 < Direction ? 1 : 1. / (N1*N0);

    // Define a complex matrix, h:
    for (j1 = 0; j1 < N1; ++j1)
    for (j0 = 0; j0 < N0; ++j0)
        h[j1][j0] = A->realp[j1*IA1 + j0*IA0]
              + i * A->imagp[j1*IA1 + j0*IA0];

    // Perform Discrete Fourier Transform.
    for (k1 = 0; k1 < N1; ++k1)
    for (k0 = 0; k0 < N0; ++k0)
        H[k1][k0] = scale * sum(sum(h[j1][j0]
            * e**(-Direction*2*pi*i*j0*k0/N0), 0 <= j0 < N0)
            * e**(-Direction*2*pi*i*j1*k1/N1), 0 <= j1 < N1);

    // Store result.
    for (k1 = 0; k1 < N1; ++k1)
    for (k0 = 0; k0 < N0; ++k0)
    {
        C->realp[k1*IC1 + k0*IC0] = Re(H[k1][k0]);
        C->imagp[k1*IC1 + k0*IC0] = Im(H[k1][k0]);
    }

    Note that the 0 and 1 dimensions are separate and identical, except
    that IA1 or IC1 are set to defaults, IA0*N0 or IC0*N0, if either is
    zero.  If neither is zero, then the IA0, IC0, and N0 arguments may be
    swapped with the IA1, IC1 and N1 arguments without affecting the
    results.

    Setup must have been properly created by a call to vDSP_create_fftsetup
    (for single precision) or vDSP_create_fftsetupD (for double precision)
    and not subsequently destroyed.

    Direction must be +1 or -1.

    The temporary buffer versions perform the same operation but are
    permitted to use the temporary buffer for improved performance.  Each
    of Buffer->realp and Buffer->imagp must contain the lesser of 16,384
    bytes or N1*N0 * sizeof *C->realp bytes and is preferably 16-byte
    aligned or better.
*/

/*  In-place two-dimensional real-to-complex Discrete Fourier Transform
    routines, with and without temporary memory.
*/
extern void vDSP_fft2d_zrip(FFTSetup __Setup, const DSPSplitComplex *__C,
                            vDSP_Stride __IC0, vDSP_Stride __IC1,
                            vDSP_Length __Log2N0, vDSP_Length __Log2N1,
                            FFTDirection __Direction)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void
vDSP_fft2d_zripD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__C,
                 vDSP_Stride __IC0, vDSP_Stride __IC1, vDSP_Length __Log2N0,
                 vDSP_Length __Log2N1, FFTDirection __flag)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_fft2d_zript(FFTSetup __Setup, const DSPSplitComplex *__C,
                             vDSP_Stride __IC0, vDSP_Stride __IC1,
                             const DSPSplitComplex *__Buffer,
                             vDSP_Length __Log2N0, vDSP_Length __Log2N1,
                             FFTDirection __Direction)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void
vDSP_fft2d_zriptD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__C,
                  vDSP_Stride __IC0, vDSP_Stride __IC1,
                  const DSPDoubleSplitComplex *__Buffer, vDSP_Length __Log2N0,
                  vDSP_Length __Log2N1, FFTDirection __flag)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:

        For this routine, strides are shown explicitly; the default maps
        are not used.

    These compute:

    N0 = 1 << Log2N0;
    N1 = 1 << Log2N1;

    if (IC1 == 0) IC1 = IC0*N0/2;

    If Direction is +1, a real-to-complex transform is performed, taking
    input from a real vector that has been coerced into the complex
    structure:

        scale = 2;

        // Define a real matrix, h:
        for (j1 = 0; j1 < N1  ; ++j1)
        for (j0 = 0; j0 < N0/2; ++j0)
        {
            h[j1][2*j0+0] = C->realp[j1*IC1 + j0*IC0]
                      + i * C->imagp[j1*IC1 + j0*IC0];
            h[j1][2*j0+1] = C->realp[j1*IC1 + j0*IC0]
                      + i * C->imagp[j1*IC1 + j0*IC0];
        }

        // Perform Discrete Fourier Transform.
        for (k1 = 0; k1 < N1; ++k1)
        for (k0 = 0; k0 < N0; ++k0)
            H[k1][k0] = scale * sum(sum(h[j1][j0]
                * e**(-Direction*2*pi*i*j0*k0/N0), 0 <= j0 < N0)
                * e**(-Direction*2*pi*i*j1*k1/N1), 0 <= j1 < N1);

        // Pack special pure-real elements into output matrix:
        C->realp[0*IC1][0*IC0] = H[0   ][0   ].
        C->imagp[0*IC1][0*IC0] = H[0   ][N0/2]
        C->realp[1*IC1][0*IC0] = H[N1/2][0   ].
        C->imagp[1*IC1][0*IC0] = H[N1/2][N0/2]

        // Pack two vectors into output matrix "vertically":
        // (This awkward format is due to a legacy implementation.)
        for (k1 = 1; k1 < N1/2; ++k1)
        {
            C->realp[(2*k1+0)*IC1][0*IC0] = Re(H[k1][0   ]);
            C->realp[(2*k1+1)*IC1][0*IC0] = Im(H[k1][0   ]);
            C->imagp[(2*k1+0)*IC1][0*IC0] = Re(H[k1][N0/2]);
            C->imagp[(2*k1+1)*IC1][0*IC0] = Im(H[k1][N0/2]);
        }

        // Store regular elements:
        for (k1 = 0; k1 < N1  ; ++k1)
        for (k0 = 1; k0 < N0/2; ++k0)
        {
            C->realp[k1*IC1 + k0*IC0] = Re(H[k1][k0]);
            C->imagp[k1*IC1 + k0*IC0] = Im(H[k1][k0]);
        }

        Many elements of H are not stored.  However, since the input is a
        real matrix, H has symmetry that makes all the unstored elements of
        H functions of the stored elements of H.  So the data stored in C
        has complete information about the transform result.

    If Direction is -1, a complex-to-real inverse transform is performed,
    producing a real output vector coerced into the complex structure:

        scale = 1. / (N1*N0);

        // Define a complex matrix, h, in multiple steps:

        // Unpack the special elements:
        h[0   ][0   ] = C->realp[0*IC1][0*IC0];
        h[0   ][N0/2] = C->imagp[0*IC1][0*IC0];
        h[N1/2][0   ] = C->realp[1*IC1][0*IC0];
        h[N1/2][N0/2] = C->imagp[1*IC1][0*IC0];

        // Unpack the two vectors from "vertical" storage:
        for (j1 = 1; j1 < N1/2; ++j1)
        {
            h[j1][0   ] = C->realp[(2*j1+0)*IC1][0*IC0]
                    + i * C->realp[(2*j1+1)*IC1][0*IC0]
            h[j1][N0/2] = C->imagp[(2*j1+0)*IC1][0*IC0]
                    + i * C->imagp[(2*j1+1)*IC1][0*IC0]
        }

        // Take regular elements:
        for (j1 = 0; j1 < N1  ; ++j1)
        for (j0 = 1; j0 < N0/2; ++j0)
        {
            h[j1][j0   ] = C->realp[j1*IC1 + j0*IC0]
                     + i * C->imagp[j1*IC1 + j0*IC0];
            h[j1][N0-j0] = conj(h[j1][j0]);
        }

        // Perform Discrete Fourier Transform.
        for (k1 = 0; k1 < N1; ++k1)
        for (k0 = 0; k0 < N0; ++k0)
            H[k1][k0] = scale * sum(sum(h[j1][j0]
                * e**(-Direction*2*pi*i*j0*k0/N0), 0 <= j0 < N0)
                * e**(-Direction*2*pi*i*j1*k1/N1), 0 <= j1 < N1);

        // Store result.
        for (k1 = 0; k1 < N1  ; ++k1)
        for (k0 = 0; k0 < N0/2; ++k0)
        {
            C->realp[k1*IC1 + k0*IC0] = Re(H[k1][2*k0+0]);
            C->imagp[k1*IC1 + k0*IC0] = Im(H[k1][2*k0+1]);
        }

    Unlike the two-dimensional complex transform, the dimensions are not
    symmetric in this real-to-complex transform.

    Setup must have been properly created by a call to vDSP_create_fftsetup
    (for single precision) or vDSP_create_fftsetupD (for double precision)
    and not subsequently destroyed.

    Direction must be +1 or -1.

    The temporary buffer versions perform the same operation but are
    permitted to use the temporary buffer for improved performance.  Each
    of Buffer->realp and Buffer->imagp must contain space for the greater
    of N1 or N0/2 floating-point elements.  The addresses are preferably
    16-byte aligned or better.
*/

/*  Out-of-place two-dimensional real-to-complex Discrete Fourier Transform
    routines, with and without temporary memory.
*/
extern void vDSP_fft2d_zrop(FFTSetup __Setup, const DSPSplitComplex *__A,
                            vDSP_Stride __IA0, vDSP_Stride __IA1,
                            const DSPSplitComplex *__C, vDSP_Stride __IC0,
                            vDSP_Stride __IC1, vDSP_Length __Log2N0,
                            vDSP_Length __Log2N1, FFTDirection __Direction)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_fft2d_zropt(FFTSetup __Setup, const DSPSplitComplex *__A,
                             vDSP_Stride __IA0, vDSP_Stride __IA1,
                             const DSPSplitComplex *__C, vDSP_Stride __IC0,
                             vDSP_Stride __IC1, const DSPSplitComplex *__Buffer,
                             vDSP_Length __Log2N0, vDSP_Length __Log2N1,
                             FFTDirection __Direction)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void
vDSP_fft2d_zropD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__A,
                 vDSP_Stride __IA0, vDSP_Stride __IA1,
                 const DSPDoubleSplitComplex *__C, vDSP_Stride __IC0,
                 vDSP_Stride __IC1, vDSP_Length __Log2N0, vDSP_Length __Log2N1,
                 FFTDirection __Direction) API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_fft2d_zroptD(
    FFTSetupD __Setup, const DSPDoubleSplitComplex *__A, vDSP_Stride __IA0,
    vDSP_Stride __IA1, const DSPDoubleSplitComplex *__C, vDSP_Stride __IC0,
    vDSP_Stride __IC1, const DSPDoubleSplitComplex *__Buffer,
    vDSP_Length __Log2N0, vDSP_Length __Log2N1, FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:

        For this routine, strides are shown explicitly; the default maps
        are not used.

    These compute:

    N0 = 1 << Log2N0;
    N1 = 1 << Log2N1;

    if (IA1 == 0) IA1 = IA0*N0/2;
    if (IC1 == 0) IC1 = IC0*N0/2;

    If Direction is +1, a real-to-complex transform is performed, taking
    input from a real vector that has been coerced into the complex
    structure:

        scale = 2;

        // Define a real matrix, h:
        for (j1 = 0; j1 < N1  ; ++j1)
        for (j0 = 0; j0 < N0/2; ++j0)
        {
            h[j1][2*j0+0] = A->realp[j1*IA1 + j0*IA0]
                      + i * A->imagp[j1*IA1 + j0*IA0];
            h[j1][2*j0+1] = A->realp[j1*IA1 + j0*IA0]
                      + i * A->imagp[j1*IA1 + j0*IA0];
        }

        // Perform Discrete Fourier Transform.
        for (k1 = 0; k1 < N1; ++k1)
        for (k0 = 0; k0 < N0; ++k0)
            H[k1][k0] = scale * sum(sum(h[j1][j0]
                * e**(-Direction*2*pi*i*j0*k0/N0), 0 <= j0 < N0)
                * e**(-Direction*2*pi*i*j1*k1/N1), 0 <= j1 < N1);

        // Pack special pure-real elements into output matrix:
        C->realp[0*IC1][0*IC0] = H[0   ][0   ].
        C->imagp[0*IC1][0*IC0] = H[0   ][N0/2]
        C->realp[1*IC1][0*IC0] = H[N1/2][0   ].
        C->imagp[1*IC1][0*IC0] = H[N1/2][N0/2]

        // Pack two vectors into output matrix "vertically":
        // (This awkward format is due to a legacy implementation.)
        for (k1 = 1; k1 < N1/2; ++k1)
        {
            C->realp[(2*k1+0)*IC1][0*IC0] = Re(H[k1][0   ]);
            C->realp[(2*k1+1)*IC1][0*IC0] = Im(H[k1][0   ]);
            C->imagp[(2*k1+0)*IC1][0*IC0] = Re(H[k1][N0/2]);
            C->imagp[(2*k1+1)*IC1][0*IC0] = Im(H[k1][N0/2]);
        }

        // Store regular elements:
        for (k1 = 0; k1 < N1  ; ++k1)
        for (k0 = 1; k0 < N0/2; ++k0)
        {
            C->realp[k1*IC1 + k0*IC0] = Re(H[k1][k0]);
            C->imagp[k1*IC1 + k0*IC0] = Im(H[k1][k0]);
        }

        Many elements of H are not stored.  However, since the input is a
        real matrix, H has symmetry that makes all the unstored elements of
        H functions of the stored elements of H.  So the data stored in C
        has complete information about the transform result.

    If Direction is -1, a complex-to-real inverse transform is performed,
    producing a real output vector coerced into the complex structure:

        scale = 1. / (N1*N0);

        // Define a complex matrix, h, in multiple steps:

        // Unpack the special elements:
        h[0   ][0   ] = A->realp[0*IA1][0*IA0];
        h[0   ][N0/2] = A->imagp[0*IA1][0*IA0];
        h[N1/2][0   ] = A->realp[1*IA1][0*IA0];
        h[N1/2][N0/2] = A->imagp[1*IA1][0*IA0];

        // Unpack the two vectors from "vertical" storage:
        for (j1 = 1; j1 < N1/2; ++j1)
        {
            h[j1][0   ] = A->realp[(2*j1+0)*IA1][0*IA0]
                    + i * A->realp[(2*j1+1)*IA1][0*IA0]
            h[j1][N0/2] = A->imagp[(2*j1+0)*IA1][0*IA0]
                    + i * A->imagp[(2*j1+1)*IA1][0*IA0]
        }

        // Take regular elements:
        for (j1 = 0; j1 < N1  ; ++j1)
        for (j0 = 1; j0 < N0/2; ++j0)
        {
            h[j1][j0   ] = A->realp[j1*IA1 + j0*IA0]
                     + i * A->imagp[j1*IA1 + j0*IA0];
            h[j1][N0-j0] = conj(h[j1][j0]);
        }

        // Perform Discrete Fourier Transform.
        for (k1 = 0; k1 < N1; ++k1)
        for (k0 = 0; k0 < N0; ++k0)
            H[k1][k0] = scale * sum(sum(h[j1][j0]
                * e**(-Direction*2*pi*i*j0*k0/N0), 0 <= j0 < N0)
                * e**(-Direction*2*pi*i*j1*k1/N1), 0 <= j1 < N1);

        // Store result.
        for (k1 = 0; k1 < N1  ; ++k1)
        for (k0 = 0; k0 < N0/2; ++k0)
        {
            C->realp[k1*IC1 + k0*IC0] = Re(H[k1][2*k0+0]);
            C->imagp[k1*IC1 + k0*IC0] = Im(H[k1][2*k0+1]);
        }

    Unlike the two-dimensional complex transform, the dimensions are not
    symmetric in this real-to-complex transform.

    Setup must have been properly created by a call to vDSP_create_fftsetup
    (for single precision) or vDSP_create_fftsetupD (for double precision)
    and not subsequently destroyed.

    Direction must be +1 or -1.

    The temporary buffer versions perform the same operation but are
    permitted to use the temporary buffer for improved performance.  Each
    of Buffer->realp and Buffer->imagp must contain space for the greater
    of N1 or N0/2 floating-point elements.  The addresses are preferably
    16-byte aligned or better.
*/

/*  In-place multiple complex Discrete Fourier Transform routines, with and
    without temporary memory.
*/
extern void vDSP_fftm_zip(FFTSetup __Setup, const DSPSplitComplex *__C,
                          vDSP_Stride __IC, vDSP_Stride __IM,
                          vDSP_Length __Log2N, vDSP_Length __M,
                          FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_fftm_zipD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__C,
                           vDSP_Stride __IC, vDSP_Stride __IM,
                           vDSP_Length __Log2N, vDSP_Length __M,
                           FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_fftm_zipt(FFTSetup __Setup, const DSPSplitComplex *__C,
                           vDSP_Stride __IC, vDSP_Stride __IM,
                           const DSPSplitComplex *__Buffer, vDSP_Length __Log2N,
                           vDSP_Length __M, FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_fftm_ziptD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__C,
                            vDSP_Stride __IC, vDSP_Stride __IM,
                            const DSPDoubleSplitComplex *__Buffer,
                            vDSP_Length __Log2N, vDSP_Length __M,
                            FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:

        For this routine, strides are shown explicitly; the default maps
        are not used.

    These compute:

    N = 1 << Log2N;

    scale = 0 < Direction ? 1 : 1./N;

    // Repeat M times:
    for (m = 0; m < M; ++m)
    {

        // Define a complex vector, h:
        for (j = 0; j < N; ++j)
            h[j] = C->realp[m*IM + j*IC] + i * C->imagp[m*IM + j*IC];

        // Perform Discrete Fourier Transform.
        for (k = 0; k < N; ++k)
            H[k] = scale * sum(h[j]
                * e**(-Direction*2*pi*i*j*k/N), 0 <= j < N);

        // Store result.
        for (k = 0; k < N; ++k)
        {
            C->realp[m*IM + k*IC] = Re(H[k]);
            C->imagp[m*IM + k*IC] = Im(H[k]);
        }

    }

    Setup must have been properly created by a call to vDSP_create_fftsetup
    (for single precision) or vDSP_create_fftsetupD (for double precision)
    and not subsequently destroyed.

    Direction must be +1 or -1.

    The temporary buffer versions perform the same operation but are
    permitted to use the temporary buffer for improved performance.  Each
    of Buffer->realp and Buffer->imagp must contain space for N
    floating-point elements and is preferably 16-byte aligned or better.
*/

/*  Out-of-place multiple complex Discrete Fourier Transform routines, with and
    without temporary memory.
*/
extern void vDSP_fftm_zop(FFTSetup __Setup, const DSPSplitComplex *__A,
                          vDSP_Stride __IA, vDSP_Stride __IMA,
                          const DSPSplitComplex *__C, vDSP_Stride __IC,
                          vDSP_Stride __IMC, vDSP_Length __Log2N,
                          vDSP_Length __M, FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_fftm_zopD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__A,
                           vDSP_Stride __IA, vDSP_Stride __IMA,
                           const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                           vDSP_Stride __IMC, vDSP_Length __Log2N,
                           vDSP_Length __M, FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void
vDSP_fftm_zopt(FFTSetup __Setup, const DSPSplitComplex *__A, vDSP_Stride __IA,
               vDSP_Stride __IMA, const DSPSplitComplex *__C, vDSP_Stride __IC,
               vDSP_Stride __IMC, const DSPSplitComplex *__Buffer,
               vDSP_Length __Log2N, vDSP_Length __M, FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void
vDSP_fftm_zoptD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__A,
                vDSP_Stride __IA, vDSP_Stride __IMA,
                const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                vDSP_Stride __IMC, const DSPDoubleSplitComplex *__Buffer,
                vDSP_Length __Log2N, vDSP_Length __M, FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:

        For this routine, strides are shown explicitly; the default maps
        are not used.

    These compute:

    N = 1 << Log2N;

    scale = 0 < Direction ? 1 : 1./N;

    // Repeat M times:
    for (m = 0; m < M; ++m)
    {

        // Define a complex vector, h:
        for (j = 0; j < N; ++j)
            h[j] = A->realp[m*IMA + j*IA] + i * A->imagp[m*IMA + j*IA];

        // Perform Discrete Fourier Transform.
        for (k = 0; k < N; ++k)
            H[k] = scale * sum(h[j]
                * e**(-Direction*2*pi*i*j*k/N), 0 <= j < N);

        // Store result.
        for (k = 0; k < N; ++k)
        {
            C->realp[m*IM + k*IC] = Re(H[k]);
            C->imagp[m*IM + k*IC] = Im(H[k]);
        }

    }

    Setup must have been properly created by a call to vDSP_create_fftsetup
    (for single precision) or vDSP_create_fftsetupD (for double precision)
    and not subsequently destroyed.

    Direction must be +1 or -1.

    The temporary buffer versions perform the same operation but are
    permitted to use the temporary buffer for improved performance.  Each
    of Buffer->realp and Buffer->imagp must contain space for N
    floating-point elements and is preferably 16-byte aligned or better.
*/

/*  In-place multiple real-to-complex Discrete Fourier Transform routines, with
    and without temporary memory.  We suggest you use the DFT routines instead
    of these.
*/
extern void vDSP_fftm_zrip(FFTSetup __Setup, const DSPSplitComplex *__C,
                           vDSP_Stride __IC, vDSP_Stride __IM,
                           vDSP_Length __Log2N, vDSP_Length __M,
                           FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_fftm_zripD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__C,
                            vDSP_Stride __IC, vDSP_Stride __IM,
                            vDSP_Length __Log2N, vDSP_Length __M,
                            FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void
vDSP_fftm_zript(FFTSetup __Setup, const DSPSplitComplex *__C, vDSP_Stride __IC,
                vDSP_Stride __IM, const DSPSplitComplex *__Buffer,
                vDSP_Length __Log2N, vDSP_Length __M, FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void
vDSP_fftm_zriptD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__C,
                 vDSP_Stride __IC, vDSP_Stride __IM,
                 const DSPDoubleSplitComplex *__Buffer, vDSP_Length __Log2N,
                 vDSP_Length __M, FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:

        For this routine, strides are shown explicitly; the default maps
        are not used.

    These compute:

    N = 1 << Log2N;

    // Repeat M times:
    for (m = 0; m < M; ++m)
    {

        If Direction is +1, a real-to-complex transform is performed,
        taking input from a real vector that has been coerced into the
        complex structure:

            scale = 2;

            // Define a real vector, h:
            for (j = 0; j < N/2; ++j)
            {
                h[2*j + 0] = C->realp[m*IM + j*IC];
                h[2*j + 1] = C->imagp[m*IM + j*IC];
            }

            // Perform Discrete Fourier Transform.
            for (k = 0; k < N; ++k)
                H[k] = scale *
                    sum(h[j] * e**(-Direction*2*pi*i*j*k/N), 0 <= j < N);

            // Pack DC and Nyquist components into initial elements.
            C->realp[m*IM + 0*IC] = Re(H[ 0 ]).
            C->imagp[m*IM + 0*IC] = Re(H[N/2]).

            // Store regular components:
            for (k = 1; k < N/2; ++k)
            {
                C->realp[m*IM + k*IC] = Re(H[k]);
                C->imagp[m*IM + k*IC] = Im(H[k]);
            }

            Note that, for N/2 < k < N, H[k] is not stored.  However, since
            the input is a real vector, the output has symmetry that allows
            the unstored elements to be derived from the stored elements:
            H[k] = conj(H(N-k)).  This symmetry also implies the DC and
            Nyquist components are real, so their imaginary parts are zero.

        If Direction is -1, a complex-to-real inverse transform is
        performed, producing a real output vector coerced into the complex
        structure:

            scale = 1./N;

            // Define a complex vector, h:
            h[ 0 ] = C->realp[m*IM + 0*IC];
            h[N/2] = C->imagp[m*IM + 0*IC];
            for (j = 1; j < N/2; ++j)
            {
                h[ j ] = C->realp[m*IM + j*IC] + i * C->imagp[m*IM + j*IC];
                h[N-j] = conj(h[j]);
            }

            // Perform Discrete Fourier Transform.
            for (k = 0; k < N; ++k)
                H[k] = scale *
                    sum(h[j] * e**(-Direction*2*pi*i*j*k/N), 0 <= j < N);

            // Coerce real results into complex structure:
            for (k = 0; k < N/2; ++k)
            {
                C->realp[m*IM + k*IC] = H[2*k+0];
                C->imagp[m*IM + k*IC] = H[2*k+1];
            }

            Note that, mathematically, the symmetry in the input vector
            compels every H[k] to be real, so there are no imaginary
            components to be stored.

    }

    Setup must have been properly created by a call to vDSP_create_fftsetup
    (for single precision) or vDSP_create_fftsetupD (for double precision)
    and not subsequently destroyed.

    Direction must be +1 or -1.

    The temporary buffer versions perform the same operation but are
    permitted to use the temporary buffer for improved performance.  Each
    of Buffer->realp and Buffer->imagp must contain space for N/2
    floating-point elements and is preferably 16-byte aligned or better.
*/

/*  Out-of-place multiple real-to-complex Discrete Fourier Transform routines,
    with and without temporary memory.  We suggest you use the DFT routines
    instead of these.
*/
extern void vDSP_fftm_zrop(FFTSetup __Setup, const DSPSplitComplex *__A,
                           vDSP_Stride __IA, vDSP_Stride __IMA,
                           const DSPSplitComplex *__C, vDSP_Stride __IC,
                           vDSP_Stride __IMC, vDSP_Length __Log2N,
                           vDSP_Length __M, FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void
vDSP_fftm_zropt(FFTSetup __Setup, const DSPSplitComplex *__A, vDSP_Stride __IA,
                vDSP_Stride __IMA, const DSPSplitComplex *__C, vDSP_Stride __IC,
                vDSP_Stride __IMC, const DSPSplitComplex *__Buffer,
                vDSP_Length __Log2N, vDSP_Length __M, FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_fftm_zropD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__A,
                            vDSP_Stride __IA, vDSP_Stride __IMA,
                            const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                            vDSP_Stride __IMC, vDSP_Length __Log2N,
                            vDSP_Length __M, FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void
vDSP_fftm_zroptD(FFTSetupD __Setup, const DSPDoubleSplitComplex *__A,
                 vDSP_Stride __IA, vDSP_Stride __IMA,
                 const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                 vDSP_Stride __IMC, const DSPDoubleSplitComplex *__Buffer,
                 vDSP_Length __Log2N, vDSP_Length __M, FFTDirection __Direction)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:

        For this routine, strides are shown explicitly; the default maps
        are not used.

    These compute:

    N = 1 << Log2N;

    // Repeat M times:
    for (m = 0; m < M; ++m)
    {

        If Direction is +1, a real-to-complex transform is performed,
        taking input from a real vector that has been coerced into the
        complex structure:

            scale = 2;

            // Define a real vector, h:
            for (j = 0; j < N/2; ++j)
            {
                h[2*j + 0] = A->realp[m*IMA + j*IA];
                h[2*j + 1] = A->imagp[m*IMA + j*IA];
            }

            // Perform Discrete Fourier Transform.
            for (k = 0; k < N; ++k)
                H[k] = scale *
                    sum(h[j] * e**(-Direction*2*pi*i*j*k/N), 0 <= j < N);

            // Pack DC and Nyquist components into initial elements.
            C->realp[m*IMC + 0*IC] = Re(H[ 0 ]).
            C->imagp[m*IMC + 0*IC] = Re(H[N/2]).

            // Store regular components:
            for (k = 1; k < N/2; ++k)
            {
                C->realp[m*IMC + k*IC] = Re(H[k]);
                C->imagp[m*IMC + k*IC] = Im(H[k]);
            }

            Note that, for N/2 < k < N, H[k] is not stored.  However, since
            the input is a real vector, the output has symmetry that allows
            the unstored elements to be derived from the stored elements:
            H[k] = conj(H(N-k)).  This symmetry also implies the DC and
            Nyquist components are real, so their imaginary parts are zero.

        If Direction is -1, a complex-to-real inverse transform is
        performed, producing a real output vector coerced into the complex
        structure:

            scale = 1./N;

            // Define a complex vector, h:
            h[ 0 ] = A->realp[m*IMA + 0*IA];
            h[N/2] = A->imagp[m*IMA + 0*IA];
            for (j = 1; j < N/2; ++j)
            {
                h[ j ] = A->realp[m*IMA + j*IA]
                   + i * A->imagp[m*IMA + j*IA];
                h[N-j] = conj(h[j]);
            }

            // Perform Discrete Fourier Transform.
            for (k = 0; k < N; ++k)
                H[k] = scale *
                    sum(h[j] * e**(-Direction*2*pi*i*j*k/N), 0 <= j < N);

            // Coerce real results into complex structure:
            for (k = 0; k < N/2; ++k)
            {
                C->realp[m*IMC + k*IC] = H[2*k+0];
                C->imagp[m*IMC + k*IC] = H[2*k+1];
            }

            Note that, mathematically, the symmetry in the input vector
            compels every H[k] to be real, so there are no imaginary
            components to be stored.

    }

    Setup must have been properly created by a call to vDSP_create_fftsetup
    (for single precision) or vDSP_create_fftsetupD (for double precision)
    and not subsequently destroyed.

    Direction must be +1 or -1.

    The temporary buffer versions perform the same operation but are
    permitted to use the temporary buffer for improved performance.  Each
    of Buffer->realp and Buffer->imagp must contain space for N/2
    floating-point elements and is preferably 16-byte aligned or better.
*/

/*  Cascade biquadratic IIR filters.
 */
extern void vDSP_biquad(const struct vDSP_biquad_SetupStruct *__Setup,
                        float *__Delay, const float *__X, vDSP_Stride __IX,
                        float *__Y, vDSP_Stride __IY, vDSP_Length __N)
    API_AVAILABLE(macos(10.9), ios(6.0));
extern void vDSP_biquadD(const struct vDSP_biquad_SetupStructD *__Setup,
                         double *__Delay, const double *__X, vDSP_Stride __IX,
                         double *__Y, vDSP_Stride __IY, vDSP_Length __N)
    API_AVAILABLE(macos(10.9), ios(6.0));
/*  Maps:

        For this routine, strides are shown explicitly; the default maps
        are not used.

    These compute:

    S, B0, B1, B2, A1, and A2 are determined by Setup.
    S is the number of sections.

    X provides the bulk of the input signal.  Delay provides prior state
    data for S biquadratic filters.  The filters are applied to the data in
    turn.  The output of the final filter is stored in Y, and the final
    state data of the filters are stored in Delay.

    // Initialize the first row of a matrix x with data from X:
    for (n = 0; n < N; ++n)
        x[0][n ] = X[n*IX];

    // Initialize the "past" information, elements -2 and -1, from Delay:
    for (s = 0; s <= S; ++s)
    {
        x[s][-2] = Delay[2*s+0];
        x[s][-1] = Delay[2*s+1];
    }

    // Apply each filter:
    for (s = 1; s <= S; ++s)
        for (n = 0; n < N; ++n)
            x[s][n] =
                + B0[s] * x[s-1][n-0]
                + B1[s] * x[s-1][n-1]
                + B2[s] * x[s-1][n-2]
                - A1[s] * x[s  ][n-1]
                - A2[s] * x[s  ][n-2];

    // Save the updated state data from the end of each row:
    for (s = 0; s <= S; ++s)
    {
        Delay[2*s+0] = x[s][N-2];
        Delay[2*s+1] = x[s][N-1];
    }

    // Store the results of the final filter:
    for (n = 0; n < N; ++n)
        Y[n*IY] = x[S][n];
*/

/*  vDSP_biquadm (for float) or vDSP_biquadmD (for double) applies a
    multi-channel biquadm IIR filter created with vDSP_biquadm_CreateSetup or
    vDSP_biquadm_CreateSetupD, respectively.
 */
extern void vDSP_biquadm(vDSP_biquadm_Setup __Setup,
                         const float *__nonnull *__nonnull __X,
                         vDSP_Stride __IX, float *__nonnull *__nonnull __Y,
                         vDSP_Stride __IY, vDSP_Length __N)
    API_AVAILABLE(macos(10.9), ios(7.0));
extern void vDSP_biquadmD(vDSP_biquadm_SetupD __Setup,
                          const double *__nonnull *__nonnull __X,
                          vDSP_Stride __IX, double *__nonnull *__nonnull __Y,
                          vDSP_Stride __IY, vDSP_Length __N)
    API_AVAILABLE(macos(10.10), ios(8.0));
/*  These routines perform the same function as M calls to vDSP_biquad or
    vDSP_biquadD, where M, the delay values, and the biquad setups are
    derived from the biquadm setup:

        for (m = 0; m < M; ++M)
            vDSP_biquad(
                setup derived from vDSP_biquadm setup,
                delays derived from vDSP_biquadm setup,
                X[m], IX,
                Y[m], IY,
                N);
*/

/*  Convolution and correlation.
 */
extern void vDSP_conv(const float *__A, // Input signal.
                      vDSP_Stride __IA,
                      const float *__F, // Filter.
                      vDSP_Stride __IF,
                      float *__C, // Output signal.
                      vDSP_Stride __IC,
                      vDSP_Length __N, // Output length.
                      vDSP_Length __P) // Filter length.
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_convD(const double *__A, // Input signal.
                       vDSP_Stride __IA,
                       const double *__F, // Filter
                       vDSP_Stride __IF,
                       double *__C, // Output signal.
                       vDSP_Stride __IC,
                       vDSP_Length __N, // Output length.
                       vDSP_Length __P) // Filter length.
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_zconv(const DSPSplitComplex *__A, // Input signal.
                       vDSP_Stride __IA,
                       const DSPSplitComplex *__F, // Filter.
                       vDSP_Stride __IF,
                       const DSPSplitComplex *__C, // Output signal.
                       vDSP_Stride __IC,
                       vDSP_Length __N, // Output length.
                       vDSP_Length __P) // Filter length.
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_zconvD(const DSPDoubleSplitComplex *__A, // Input signal.
                        vDSP_Stride __IA,
                        const DSPDoubleSplitComplex *__F, // Filter.
                        vDSP_Stride __IF,
                        const DSPDoubleSplitComplex *__C, // Output signal.
                        vDSP_Stride __IC,
                        vDSP_Length __N, // Output length.
                        vDSP_Length __P) // Filter length.
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = sum(A[n+p] * F[p], 0 <= p < P);

    Commonly, this is called correlation if IF is positive and convolution
    if IF is negative.
*/

/*  3*3 and 5*5 convolutions.
 */
extern void vDSP_f3x3(const float *__A, vDSP_Length __NR, vDSP_Length __NC,
                      const float *__F, float *__C)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_f3x3D(const double *__A, vDSP_Length __NR, vDSP_Length __NC,
                       const double *__F, double *__C)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_f5x5(const float *__A, vDSP_Length __NR, vDSP_Length __NC,
                      const float *__F, float *__C)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_f5x5D(const double *__A, vDSP_Length __NR, vDSP_Length __NC,
                       const double *__F, double *__C)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:

        This routine does not have strides.

        A and C are regarded as two-dimensional matrices with dimensions
        [NR][NC].  F is regarded as a two-dimensional matrix with
        dimensions [P][P]:

        Pseudocode:     Memory:
        A[j][k]         A[j*NC + k]
        C[j][k]         C[j*NC + k]
        F[j][k]         F[j*P  + k]

    These compute:

        P = 3 or 5, according to the routine name.

        Below, "P/2" is evaluated using integer arithmetic, so it is 1 or 2
        (not 1.5 or 2.5).

        for (r = P/2; r < NR-P/2; ++r)
        for (c = P/2; c < NC-P/2; ++c)
            C[r][c] = sum(A[r+j][c+k] * F[j+P/2][k+P/2],
                -P/2 <= j <= P/2, -P/2 <= k <= P/2);

        All other elements of C (a border of P/2 elements around all four
        sides) are set to zero.
*/

/*  Two-dimensional (image) convolution.
 */
extern void vDSP_imgfir(const float *__A, // Input.
                        vDSP_Length __NR, // Number of image rows.
                        vDSP_Length __NC, // Number of image columns.
                        const float *__F, // Filter.
                        float *__C,       // Output.
                        vDSP_Length __P,  // Number of filter rows.
                        vDSP_Length __Q)  // Number of filter columns.
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_imgfirD(const double *__A, // Input.
                         vDSP_Length __NR,  // Number of image rows.
                         vDSP_Length __NC,  // Number of image columns.
                         const double *__F, // Filter.
                         double *__C,       // Output.
                         vDSP_Length __P,   // Number of filter rows.
                         vDSP_Length __Q)   // Number of filter columns.
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:

        This routine does not have strides.

        A and C are regarded as two-dimensional matrices with dimensions
        [NR][NC].  F is regarded as a two-dimensional matrix with
        dimensions [P][Q].

        A and C are regarded as two-dimensional matrices with dimensions
        [NR][NC].  F is regarded as a two-dimensional matrix with
        dimensions [P][P]:

        Pseudocode:     Memory:
        A[j][k]         A[j*NC + k]
        C[j][k]         C[j*NC + k]
        F[j][k]         F[j*Q  + k]

    These compute:

        P and Q must be odd.  "P/2" and "Q/2" are evaluated with integer
        arithmetic, so, if P is 3, P/2 is 1, not 1.5.

        for (r = P/2; r < NR-P/2; ++r)
        for (c = Q/2; c < NC-Q/2; ++c)
            C[r][c] = sum(A[r+j][c+k] * F[j+P/2][k+Q/2],
                -P/2 <= j <= P/2, -Q/2 <= k <= Q/2);

        All other elements of C (borders of P/2 elements at the top and
        bottom and Q/2 elements at the left and right) are set to zero.
*/

extern void vDSP_mtrans(const float *__A, vDSP_Stride __IA, float *__C,
                        vDSP_Stride __IC, vDSP_Length __M, vDSP_Length __N)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_mtransD(const double *__A, vDSP_Stride __IA, double *__C,
                         vDSP_Stride __IC, vDSP_Length __M, vDSP_Length __N)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:

        A is regarded as a two-dimensional matrix with dimemnsions
        [N][M] and stride IA.  C is regarded as a two-dimensional matrix
        with dimemnsions [M][N] and stride IC:

        Pseudocode:     Memory:
        A[n][m]         A[(n*M + m)*IA]
        C[m][n]         C[(m*N + n)*IC]

    These compute:

        for (m = 0; m < M; ++m)
        for (n = 0; n < N; ++n)
            C[m][n] = A[n][m];
*/

/*  Matrix multiply.
 */
extern void vDSP_mmul(const float *__A, vDSP_Stride __IA, const float *__B,
                      vDSP_Stride __IB, float *__C, vDSP_Stride __IC,
                      vDSP_Length __M, vDSP_Length __N, vDSP_Length __P)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_mmulD(const double *__A, vDSP_Stride __IA, const double *__B,
                       vDSP_Stride __IB, double *__C, vDSP_Stride __IC,
                       vDSP_Length __M, vDSP_Length __N, vDSP_Length __P)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:

        A is regarded as a two-dimensional matrix with dimemnsions [M][P]
        and stride IA.  B is regarded as a two-dimensional matrix with
        dimemnsions [P][N] and stride IB.  C is regarded as a
        two-dimensional matrix with dimemnsions [M][N] and stride IC.

        Pseudocode:     Memory:
        A[m][p]         A[(m*P+p)*IA]
        B[p][n]         B[(p*N+n)*IB]
        C[m][n]         C[(m*N+n)*IC]

    These compute:

        for (m = 0; m < M; ++m)
        for (n = 0; n < N; ++n)
            C[m][n] = sum(A[m][p] * B[p][n], 0 <= p < P);
*/

/*  Split-complex matrix multiply and add.
 */
extern void vDSP_zmma(const DSPSplitComplex *__A, vDSP_Stride __IA,
                      const DSPSplitComplex *__B, vDSP_Stride __IB,
                      const DSPSplitComplex *__C, vDSP_Stride __IC,
                      const DSPSplitComplex *__D, vDSP_Stride __ID,
                      vDSP_Length __M, vDSP_Length __N, vDSP_Length __P)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_zmmaD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                       const DSPDoubleSplitComplex *__B, vDSP_Stride __IB,
                       const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                       const DSPDoubleSplitComplex *__D, vDSP_Stride __ID,
                       vDSP_Length __M, vDSP_Length __N, vDSP_Length __P)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:

        Pseudocode:     Memory:
        A[m][p]         A->realp[(m*P+p)*IA] + i * A->imagp[(m*P+p)*IA].
        B[p][n]         B->realp[(p*N+n)*IB] + i * B->imagp[(p*N+n)*IB].
        C[m][n]         C->realp[(m*N+n)*IC] + i * C->imagp[(m*N+n)*IC].
        D[m][n]         D->realp[(m*N+n)*ID] + i * D->imagp[(m*N+n)*ID].

    These compute:

        for (m = 0; m < M; ++m)
        for (n = 0; n < N; ++n)
            D[m][n] = sum(A[m][p] * B[p][n], 0 <= p < P) + C[m][n];
*/

/*  Split-complex matrix multiply and subtract.
 */
extern void vDSP_zmms(const DSPSplitComplex *__A, vDSP_Stride __IA,
                      const DSPSplitComplex *__B, vDSP_Stride __IB,
                      const DSPSplitComplex *__C, vDSP_Stride __IC,
                      const DSPSplitComplex *__D, vDSP_Stride __ID,
                      vDSP_Length __M, vDSP_Length __N, vDSP_Length __P)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_zmmsD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                       const DSPDoubleSplitComplex *__B, vDSP_Stride __IB,
                       const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                       const DSPDoubleSplitComplex *__D, vDSP_Stride __ID,
                       vDSP_Length __M, vDSP_Length __N, vDSP_Length __P)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:

        Pseudocode:     Memory:
        A[m][p]         A->realp[(m*P+p)*IA] + i * A->imagp[(m*P+p)*IA].
        B[p][n]         B->realp[(p*N+n)*IB] + i * B->imagp[(p*N+n)*IB].
        C[m][n]         C->realp[(m*N+n)*IC] + i * C->imagp[(m*N+n)*IC].
        D[m][n]         D->realp[(m*N+n)*ID] + i * D->imagp[(m*N+n)*ID].

    These compute:

        for (m = 0; m < M; ++m)
        for (n = 0; n < N; ++n)
            D[m][n] = sum(A[m][p] * B[p][n], 0 <= p < P) - C[m][n];
*/

// Vector multiply, multiply, add, and add.
extern void vDSP_zvmmaa(const DSPSplitComplex *__A, vDSP_Stride __IA,
                        const DSPSplitComplex *__B, vDSP_Stride __IB,
                        const DSPSplitComplex *__C, vDSP_Stride __IC,
                        const DSPSplitComplex *__D, vDSP_Stride __ID,
                        const DSPSplitComplex *__E, vDSP_Stride __IE,
                        const DSPSplitComplex *__F, vDSP_Stride __IF,
                        vDSP_Length __N) API_AVAILABLE(macos(10.9), ios(7.0));
extern void vDSP_zvmmaaD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                         const DSPDoubleSplitComplex *__B, vDSP_Stride __IB,
                         const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                         const DSPDoubleSplitComplex *__D, vDSP_Stride __ID,
                         const DSPDoubleSplitComplex *__E, vDSP_Stride __IE,
                         const DSPDoubleSplitComplex *__F, vDSP_Stride __IF,
                         vDSP_Length __N) API_AVAILABLE(macos(10.10), ios(8.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            F[n] = A[n] * B[n] + C[n] * D[n] + E[n];
*/

/*  Split-complex matrix multiply and reverse subtract.
 */
extern void vDSP_zmsm(const DSPSplitComplex *__A, vDSP_Stride __IA,
                      const DSPSplitComplex *__B, vDSP_Stride __IB,
                      const DSPSplitComplex *__C, vDSP_Stride __IC,
                      const DSPSplitComplex *__D, vDSP_Stride __ID,
                      vDSP_Length __M, vDSP_Length __N, vDSP_Length __P)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_zmsmD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                       const DSPDoubleSplitComplex *__B, vDSP_Stride __IB,
                       const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                       const DSPDoubleSplitComplex *__D, vDSP_Stride __ID,
                       vDSP_Length __M, vDSP_Length __N, vDSP_Length __P)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:

        Pseudocode:     Memory:
        A[m][p]         A->realp[(m*P+p)*IA] + i * A->imagp[(m*P+p)*IA].
        B[p][n]         B->realp[(p*N+n)*IB] + i * B->imagp[(p*N+n)*IB].
        C[m][n]         C->realp[(m*N+n)*IC] + i * C->imagp[(m*N+n)*IC].
        D[m][n]         D->realp[(m*N+n)*ID] + i * D->imagp[(m*N+n)*ID].

    These compute:

        for (m = 0; m < M; ++m)
        for (n = 0; n < N; ++n)
            D[m][n] = C[m][n] - sum(A[m][p] * B[p][n], 0 <= p < P);
*/

/*  Split-complex matrix multiply.
 */
extern void vDSP_zmmul(const DSPSplitComplex *__A, vDSP_Stride __IA,
                       const DSPSplitComplex *__B, vDSP_Stride __IB,
                       const DSPSplitComplex *__C, vDSP_Stride __IC,
                       vDSP_Length __M, vDSP_Length __N, vDSP_Length __P)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_zmmulD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                        const DSPDoubleSplitComplex *__B, vDSP_Stride __IB,
                        const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                        vDSP_Length __M, vDSP_Length __N, vDSP_Length __P)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:

        Pseudocode:     Memory:
        A[m][p]         A->realp[(m*P+p)*IA] + i * A->imagp[(m*P+p)*IA].
        B[p][n]         B->realp[(p*N+n)*IB] + i * B->imagp[(p*N+n)*IB].
        C[m][n]         C->realp[(m*N+n)*IC] + i * C->imagp[(m*N+n)*IC].

    These compute:

        for (m = 0; m < M; ++m)
        for (n = 0; n < N; ++n)
            C[m][n] = sum(A[m][p] * B[p][n], 0 <= p < P);
*/

// Vector add.
extern void vDSP_vadd(const float *__A, vDSP_Stride __IA, const float *__B,
                      vDSP_Stride __IB, float *__C, vDSP_Stride __IC,
                      vDSP_Length __N) API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_vaddD(const double *__A, vDSP_Stride __IA, const double *__B,
                       vDSP_Stride __IB, double *__C, vDSP_Stride __IC,
                       vDSP_Length __N) API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_vaddi(const int *__A, vDSP_Stride __IA, const int *__B,
                       vDSP_Stride __IB, int *__C, vDSP_Stride __IC,
                       vDSP_Length __N) API_AVAILABLE(macos(10.9), ios(7.0));
extern void vDSP_zvadd(const DSPSplitComplex *__A, vDSP_Stride __IA,
                       const DSPSplitComplex *__B, vDSP_Stride __IB,
                       const DSPSplitComplex *__C, vDSP_Stride __IC,
                       vDSP_Length __N) API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_zvaddD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                        const DSPDoubleSplitComplex *__B, vDSP_Stride __IB,
                        const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                        vDSP_Length __N) API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_zrvadd(const DSPSplitComplex *__A, vDSP_Stride __IA,
                        const float *__B, vDSP_Stride __IB,
                        const DSPSplitComplex *__C, vDSP_Stride __IC,
                        vDSP_Length __N) API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_zrvaddD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                         const double *__B, vDSP_Stride __IB,
                         const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                         vDSP_Length __N) API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[n] + B[n];
*/

// Vector subtract.
extern void vDSP_vsub(const float *__B, // Caution:  A and B are swapped!
                      vDSP_Stride __IB,
                      const float *__A, // Caution:  A and B are swapped!
                      vDSP_Stride __IA, float *__C, vDSP_Stride __IC,
                      vDSP_Length __N) API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_vsubD(const double *__B, // Caution:  A and B are swapped!
                       vDSP_Stride __IB,
                       const double *__A, // Caution:  A and B are swapped!
                       vDSP_Stride __IA, double *__C, vDSP_Stride __IC,
                       vDSP_Length __N) API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_zvsub(const DSPSplitComplex *__A, vDSP_Stride __IA,
                       const DSPSplitComplex *__B, vDSP_Stride __IB,
                       const DSPSplitComplex *__C, vDSP_Stride __IC,
                       vDSP_Length __N) API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_zvsubD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                        const DSPDoubleSplitComplex *__B, vDSP_Stride __IB,
                        const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                        vDSP_Length __N) API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[n] - B[n];
*/

// Vector multiply.
extern void vDSP_vmul(const float *__A, vDSP_Stride __IA, const float *__B,
                      vDSP_Stride __IB, float *__C, vDSP_Stride __IC,
                      vDSP_Length __N) API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_vmulD(const double *__A, vDSP_Stride __IA, const double *__B,
                       vDSP_Stride __IB, double *__C, vDSP_Stride __IC,
                       vDSP_Length __N) API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_zrvmul(const DSPSplitComplex *__A, vDSP_Stride __IA,
                        const float *__B, vDSP_Stride __IB,
                        const DSPSplitComplex *__C, vDSP_Stride __IC,
                        vDSP_Length __N) API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_zrvmulD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                         const double *__B, vDSP_Stride __IB,
                         const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                         vDSP_Length __N) API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[n] * B[n];
*/

// Vector divide.
extern void vDSP_vdiv(const float *__B, // Caution:  A and B are swapped!
                      vDSP_Stride __IB,
                      const float *__A, // Caution:  A and B are swapped!
                      vDSP_Stride __IA, float *__C, vDSP_Stride __IC,
                      vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vdivD(const double *__B, // Caution:  A and B are swapped!
                       vDSP_Stride __IB,
                       const double *__A, // Caution:  A and B are swapped!
                       vDSP_Stride __IA, double *__C, vDSP_Stride __IC,
                       vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vdivi(const int *__B, // Caution:  A and B are swapped!
                       vDSP_Stride __IB,
                       const int *__A, // Caution:  A and B are swapped!
                       vDSP_Stride __IA, int *__C, vDSP_Stride __IC,
                       vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void
vDSP_zvdiv(const DSPSplitComplex *__B, // Caution:  A and B are swapped!
           vDSP_Stride __IB,
           const DSPSplitComplex *__A, // Caution:  A and B are swapped!
           vDSP_Stride __IA, const DSPSplitComplex *__C, vDSP_Stride __IC,
           vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void
vDSP_zvdivD(const DSPDoubleSplitComplex *__B, // Caution:  A and B are swapped!
            vDSP_Stride __IB,
            const DSPDoubleSplitComplex *__A, // Caution:  A and B are swapped!
            vDSP_Stride __IA, const DSPDoubleSplitComplex *__C,
            vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zrvdiv(const DSPSplitComplex *__A, vDSP_Stride __IA,
                        const float *__B, vDSP_Stride __IB,
                        const DSPSplitComplex *__C, vDSP_Stride __IC,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zrvdivD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                         const double *__B, vDSP_Stride __IB,
                         const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                         vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[n] / B[n];
*/

// Vector-scalar multiply.
extern void vDSP_vsmul(const float *__A, vDSP_Stride __IA, const float *__B,
                       float *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_vsmulD(const double *__A, vDSP_Stride __IA, const double *__B,
                        double *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[n] * B[0];
*/

// Vector square.
extern void vDSP_vsq(const float *__A, vDSP_Stride __IA, float *__C,
                     vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_vsqD(const double *__A, vDSP_Stride __IA, double *__C,
                      vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[n]**2;
*/

// Vector signed square.
extern void vDSP_vssq(const float *__A, vDSP_Stride __IA, float *__C,
                      vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_vssqD(const double *__A, vDSP_Stride __IA, double *__C,
                       vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[n] * |A[n]|;
*/

// Euclidean distance, squared.
extern void vDSP_distancesq(const float *__A, vDSP_Stride __IA,
                            const float *__B, vDSP_Stride __IB, float *__C,
                            vDSP_Length __N)
    API_AVAILABLE(macos(10.8), ios(5.0));
extern void vDSP_distancesqD(const double *__A, vDSP_Stride __IA,
                             const double *__B, vDSP_Stride __IB, double *__C,
                             vDSP_Length __N)
    API_AVAILABLE(macos(10.10), ios(8.0));
/*  Maps:  The default maps are used.

    These compute:

        C[0] = sum((A[n] - B[n]) ** 2, 0 <= n < N);
*/

// Dot product.
extern void vDSP_dotpr(const float *__A, vDSP_Stride __IA, const float *__B,
                       vDSP_Stride __IB, float *__C, vDSP_Length __N)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_dotprD(const double *__A, vDSP_Stride __IA, const double *__B,
                        vDSP_Stride __IB, double *__C, vDSP_Length __N)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_zdotpr(const DSPSplitComplex *__A, vDSP_Stride __IA,
                        const DSPSplitComplex *__B, vDSP_Stride __IB,
                        const DSPSplitComplex *__C, vDSP_Length __N)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_zdotprD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                         const DSPDoubleSplitComplex *__B, vDSP_Stride __IB,
                         const DSPDoubleSplitComplex *__C, vDSP_Length __N)
    API_AVAILABLE(macos(10.2), ios(4.0));
extern void vDSP_zrdotpr(const DSPSplitComplex *__A, vDSP_Stride __IA,
                         const float *__B, vDSP_Stride __IB,
                         const DSPSplitComplex *__C, vDSP_Length __N)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_zrdotprD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                          const double *__B, vDSP_Stride __IB,
                          const DSPDoubleSplitComplex *__C, vDSP_Length __N)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        C[0] = sum(A[n] * B[n], 0 <= n < N);
*/

// Vector add and multiply.
extern void vDSP_vam(const float *__A, vDSP_Stride __IA, const float *__B,
                     vDSP_Stride __IB, const float *__C, vDSP_Stride __IC,
                     float *__D, vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_vamD(const double *__A, vDSP_Stride __IA, const double *__B,
                      vDSP_Stride __IB, const double *__C, vDSP_Stride __IC,
                      double *__D, vDSP_Stride __IDD, vDSP_Length __N)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            D[n] = (A[n] + B[n]) * C[n];
*/

// Vector multiply and add.
extern void vDSP_vma(const float *__A, vDSP_Stride __IA, const float *__B,
                     vDSP_Stride __IB, const float *__C, vDSP_Stride __IC,
                     float *__D, vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vmaD(const double *__A, vDSP_Stride __IA, const double *__B,
                      vDSP_Stride __IB, const double *__C, vDSP_Stride __IC,
                      double *__D, vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zvma(const DSPSplitComplex *__A, vDSP_Stride __IA,
                      const DSPSplitComplex *__B, vDSP_Stride __IB,
                      const DSPSplitComplex *__C, vDSP_Stride __IC,
                      const DSPSplitComplex *__D, vDSP_Stride __ID,
                      vDSP_Length __N) API_AVAILABLE(macos(10.9), ios(7.0));
extern void vDSP_zvmaD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                       const DSPDoubleSplitComplex *__B, vDSP_Stride __IB,
                       const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                       const DSPDoubleSplitComplex *__D, vDSP_Stride __ID,
                       vDSP_Length __N) API_AVAILABLE(macos(10.10), ios(8.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            D[n] = A[n] * B[n] + C[n];
*/

// Complex multiplication with optional conjugation.
extern void vDSP_zvmul(const DSPSplitComplex *__A, vDSP_Stride __IA,
                       const DSPSplitComplex *__B, vDSP_Stride __IB,
                       const DSPSplitComplex *__C, vDSP_Stride __IC,
                       vDSP_Length __N, int __Conjugate)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_zvmulD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                        const DSPDoubleSplitComplex *__B, vDSP_Stride __IB,
                        const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                        vDSP_Length __N, int __Conjugate)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        If Conjugate is +1:

            for (n = 0; n < N; ++n)
                C[n] = A[n] * B[n];

        If Conjugate is -1:

            for (n = 0; n < N; ++n)
                C[n] = conj(A[n]) * B[n];
*/

// Complex-split inner (conjugate) dot product.
extern void vDSP_zidotpr(const DSPSplitComplex *__A, vDSP_Stride __IA,
                         const DSPSplitComplex *__B, vDSP_Stride __IB,
                         const DSPSplitComplex *__C, vDSP_Length __N)
    API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_zidotprD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                          const DSPDoubleSplitComplex *__B, vDSP_Stride __IB,
                          const DSPDoubleSplitComplex *__C, vDSP_Length __N)
    API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        C[0] = sum(conj(A[n]) * B[n], 0 <= n < N);
*/

// Complex-split conjugate multiply and add.
extern void vDSP_zvcma(const DSPSplitComplex *__A, vDSP_Stride __IA,
                       const DSPSplitComplex *__B, vDSP_Stride __IB,
                       const DSPSplitComplex *__C, vDSP_Stride __IC,
                       const DSPSplitComplex *__D, vDSP_Stride __ID,
                       vDSP_Length __N) API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_zvcmaD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                        const DSPDoubleSplitComplex *__B, vDSP_Stride __IB,
                        const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                        const DSPDoubleSplitComplex *__D, vDSP_Stride __ID,
                        vDSP_Length __N) API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            D[n] = conj(A[n]) * B[n] + C[n];
*/

// Subtract real from complex-split.
extern void vDSP_zrvsub(const DSPSplitComplex *__A, vDSP_Stride __IA,
                        const float *__B, vDSP_Stride __IB,
                        const DSPSplitComplex *__C, vDSP_Stride __IC,
                        vDSP_Length __N) API_AVAILABLE(macos(10.0), ios(4.0));
extern void vDSP_zrvsubD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                         const double *__B, vDSP_Stride __IB,
                         const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                         vDSP_Length __N) API_AVAILABLE(macos(10.2), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[n] - B[n];
*/

// Vector convert between double precision and single precision.
extern void vDSP_vdpsp(const double *__A, vDSP_Stride __IA, float *__C,
                       vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vspdp(const float *__A, vDSP_Stride __IA, double *__C,
                       vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[n];
*/

// Vector absolute value.
extern void vDSP_vabs(const float *__A, vDSP_Stride __IA, float *__C,
                      vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vabsD(const double *__A, vDSP_Stride __IA, double *__C,
                       vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vabsi(const int *__A, vDSP_Stride __IA, int *__C,
                       vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zvabs(const DSPSplitComplex *__A, vDSP_Stride __IA, float *__C,
                       vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zvabsD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                        double *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = |A[n]|;
*/

// Vector bit-wise equivalence, NOT (A XOR B).
extern void vDSP_veqvi(const int *__A, vDSP_Stride __IA, const int *__B,
                       vDSP_Stride __IB, int *__C, vDSP_Stride __IC,
                       vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = ~(A[n] ^ B[n]);
*/

// Vector fill.
extern void vDSP_vfill(const float *__A, float *__C, vDSP_Stride __IC,
                       vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfillD(const double *__A, double *__C, vDSP_Stride __IC,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfilli(const int *__A, int *__C, vDSP_Stride __IC,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zvfill(const DSPSplitComplex *__A, const DSPSplitComplex *__C,
                        vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zvfillD(const DSPDoubleSplitComplex *__A,
                         const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                         vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[0];
*/

// Vector-scalar add.
extern void vDSP_vsadd(const float *__A, vDSP_Stride __IA, const float *__B,
                       float *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vsaddD(const double *__A, vDSP_Stride __IA, const double *__B,
                        double *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vsaddi(const int *__A, vDSP_Stride __IA, const int *__B,
                        int *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[n] + B[0];
*/

// Vector-scalar divide.
extern void vDSP_vsdiv(const float *__A, vDSP_Stride __IA, const float *__B,
                       float *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vsdivD(const double *__A, vDSP_Stride __IA, const double *__B,
                        double *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vsdivi(const int *__A, vDSP_Stride __IA, const int *__B,
                        int *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[n] / B[0];
*/

// Complex-split accumulating autospectrum.
extern void vDSP_zaspec(const DSPSplitComplex *__A, float *__C, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zaspecD(const DSPDoubleSplitComplex *__A, double *__C,
                         vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:

        No strides are used; arrays map directly to memory.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] += |A[n]| ** 2;
*/

// Create Blackman window.
extern void vDSP_blkman_window(float *__C, vDSP_Length __N, int __Flag)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_blkman_windowD(double *__C, vDSP_Length __N, int __Flag)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:

        No strides are used; the array maps directly to memory.

    These compute:

        If Flag & vDSP_HALF_WINDOW:
            Length = (N+1)/2;
        Else
            Length = N;

        for (n = 0; n < Length; ++n)
        {
            angle = 2*pi*n/N;
            C[n] = .42 - .5 * cos(angle) + .08 * cos(2*angle);
        }
*/

// Coherence function.
extern void vDSP_zcoher(const float *__A, const float *__B,
                        const DSPSplitComplex *__C, float *__D, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zcoherD(const double *__A, const double *__B,
                         const DSPDoubleSplitComplex *__C, double *__D,
                         vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:

        No strides are used; arrays map directly to memory.

    These compute:

        for (n = 0; n < N; ++n)
            D[n] = |C[n]| ** 2 / (A[n] * B[n]);
*/

// Anti-aliasing down-sample with real filter.
extern void vDSP_desamp(const float *__A, // Input signal.
                        vDSP_Stride __DF, // Decimation Factor.
                        const float *__F, // Filter.
                        float *__C,       // Output.
                        vDSP_Length __N,  // Output length.
                        vDSP_Length __P)  // Filter length.
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_desampD(const double *__A, // Input signal.
                         vDSP_Stride __DF,  // Decimation Factor.
                         const double *__F, // Filter.
                         double *__C,       // Output.
                         vDSP_Length __N,   // Output length.
                         vDSP_Length __P)   // Filter length.
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zrdesamp(const DSPSplitComplex *__A, // Input signal.
                          vDSP_Stride __DF,           // Decimation Factor.
                          const float *__F,           // Filter.
                          const DSPSplitComplex *__C, // Output.
                          vDSP_Length __N,            // Output length.
                          vDSP_Length __P)            // Filter length.
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zrdesampD(const DSPDoubleSplitComplex *__A, // Input signal.
                           vDSP_Stride __DF,  // Decimation Factor.
                           const double *__F, // Filter.
                           const DSPDoubleSplitComplex *__C, // Output.
                           vDSP_Length __N,                  // Output length.
                           vDSP_Length __P)                  // Filter length.
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:

        No strides are used; arrays map directly to memory.  DF specifies
        the decimation factor.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = sum(A[n*DF+p] * F[p], 0 <= p < P);
*/

// Transfer function, B/A.
extern void vDSP_ztrans(const float *__A, const DSPSplitComplex *__B,
                        const DSPSplitComplex *__C, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_ztransD(const double *__A, const DSPDoubleSplitComplex *__B,
                         const DSPDoubleSplitComplex *__C, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:

        No strides are used; arrays map directly to memory.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = B[n] / A[n];
*/

// Accumulating cross-spectrum.
extern void vDSP_zcspec(const DSPSplitComplex *__A, const DSPSplitComplex *__B,
                        const DSPSplitComplex *__C, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zcspecD(const DSPDoubleSplitComplex *__A,
                         const DSPDoubleSplitComplex *__B,
                         const DSPDoubleSplitComplex *__C, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:

        No strides are used; arrays map directly to memory.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] += conj(A[n]) * B[n];
*/

// Vector conjugate and multiply.
extern void vDSP_zvcmul(const DSPSplitComplex *__A, vDSP_Stride __IA,
                        const DSPSplitComplex *__B, vDSP_Stride __IB,
                        const DSPSplitComplex *__C, vDSP_Stride __IC,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zvcmulD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                         const DSPDoubleSplitComplex *__B, vDSP_Stride __IB,
                         const DSPDoubleSplitComplex *__C, vDSP_Stride __iC,
                         vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = conj(A[n]) * B[n];
*/

// Vector conjugate.
extern void vDSP_zvconj(const DSPSplitComplex *__A, vDSP_Stride __IA,
                        const DSPSplitComplex *__C, vDSP_Stride __IC,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zvconjD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                         const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                         vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = conj(A[n]);
*/

// Vector multiply with scalar.
extern void vDSP_zvzsml(const DSPSplitComplex *__A, vDSP_Stride __IA,
                        const DSPSplitComplex *__B, const DSPSplitComplex *__C,
                        vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zvzsmlD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                         const DSPDoubleSplitComplex *__B,
                         const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                         vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[n] * B[0];
*/

// Vector magnitudes squared.
extern void vDSP_zvmags(const DSPSplitComplex *__A, vDSP_Stride __IA,
                        float *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zvmagsD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                         double *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = |A[n]| ** 2;
*/

// Vector magnitudes square and add.
extern void vDSP_zvmgsa(const DSPSplitComplex *__A, vDSP_Stride __IA,
                        const float *__B, vDSP_Stride __IB, float *__C,
                        vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zvmgsaD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                         const double *__B, vDSP_Stride __IB, double *__C,
                         vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = |A[n]| ** 2 + B[n];
*/

// Complex-split vector move.
extern void vDSP_zvmov(const DSPSplitComplex *__A, vDSP_Stride __IA,
                       const DSPSplitComplex *__C, vDSP_Stride __IC,
                       vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zvmovD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                        const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[n];
*/

// Vector negate.
extern void vDSP_zvneg(const DSPSplitComplex *__A, vDSP_Stride __IA,
                       const DSPSplitComplex *__C, vDSP_Stride __IC,
                       vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zvnegD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                        const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = -A[n];
*/

// Vector phasea.
extern void vDSP_zvphas(const DSPSplitComplex *__A, vDSP_Stride __IA,
                        float *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zvphasD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                         double *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = atan2(Im(A[n]), Re(A[n]));
*/

// Vector multiply by scalar and add.
extern void vDSP_zvsma(const DSPSplitComplex *__A, vDSP_Stride __IA,
                       const DSPSplitComplex *__B, const DSPSplitComplex *__C,
                       vDSP_Stride __IC, const DSPSplitComplex *__D,
                       vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_zvsmaD(const DSPDoubleSplitComplex *__A, vDSP_Stride __IA,
                        const DSPDoubleSplitComplex *__B,
                        const DSPDoubleSplitComplex *__C, vDSP_Stride __IC,
                        const DSPDoubleSplitComplex *__D, vDSP_Stride __ID,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            D[n] = A[n] * B[0] + C[n];
*/

// Difference equation, 2 poles, 2 zeros.
extern void vDSP_deq22(const float *__A, vDSP_Stride __IA, const float *__B,
                       float *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_deq22D(const double *__A, vDSP_Stride __IA, const double *__B,
                        double *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 2; n < N+2; ++n)   // Note outputs start with C[2].
            C[n] =
                + A[n-0]*B[0]
                + A[n-1]*B[1]
                + A[n-2]*B[2]
                - C[n-1]*B[3]
                - C[n-2]*B[4];
*/

// Create Hamming window.
extern void vDSP_hamm_window(float *__C, vDSP_Length __N, int __Flag)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_hamm_windowD(double *__C, vDSP_Length __N, int __Flag)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:

        No strides are used; the array maps directly to memory.

    These compute:

        If Flag & vDSP_HALF_WINDOW:
            Length = (N+1)/2;
        Else
            Length = N;

        for (n = 0; n < Length; ++n)
            C[n] = .54 - .46 * cos(2*pi*n/N);
*/

// Create Hanning window.
extern void vDSP_hann_window(float *__C, vDSP_Length __N, int __Flag)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_hann_windowD(double *__C, vDSP_Length __N, int __Flag)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:

        No strides are used; the array maps directly to memory.

    These compute:

        If Flag & vDSP_HALF_WINDOW:
            Length = (N+1)/2;
        Else
            Length = N;

        If Flag & vDSP_HANN_NORM:
            W = .816496580927726;
        Else
            W = .5;

        for (n = 0; n < Length; ++n)
            C[n] = W * (1 - cos(2*pi*n/N));
*/

// Maximum magnitude of vector.
extern void vDSP_maxmgv(const float *__A, vDSP_Stride __IA, float *__C,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_maxmgvD(const double *__A, vDSP_Stride __IA, double *__C,
                         vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    C[0] is set to the greatest value of |A[n]| for 0 <= n < N.
*/

// Maximum magnitude of vector.
extern void vDSP_maxmgvi(const float *__A, vDSP_Stride __IA, float *__C,
                         vDSP_Length *__I, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_maxmgviD(const double *__A, vDSP_Stride __IA, double *__C,
                          vDSP_Length *__I, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    C[0] is set to the greatest value of |A[n]| for 0 <= n < N.
    I[0] is set to the least i*IA such that |A[i]| has the value in C[0].
*/

// Maximum value of vector.
extern void vDSP_maxv(const float *__A, vDSP_Stride __IA, float *__C,
                      vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_maxvD(const double *__A, vDSP_Stride __I, double *__C,
                       vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    C[0] is set to the greatest value of A[n] for 0 <= n < N.
*/

// Maximum value of vector, with index.
extern void vDSP_maxvi(const float *__A, vDSP_Stride __IA, float *__C,
                       vDSP_Length *__I, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_maxviD(const double *__A, vDSP_Stride __IA, double *__C,
                        vDSP_Length *__I, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    C[0] is set to the greatest value of A[n] for 0 <= n < N.
    I[0] is set to the least i*IA such that A[i] has the value in C[0].
*/

// Mean magnitude of vector.
extern void vDSP_meamgv(const float *__A, vDSP_Stride __IA, float *__C,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_meamgvD(const double *__A, vDSP_Stride __IA, double *__C,
                         vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        C[0] = sum(|A[n]|, 0 <= n < N) / N;
*/

// Mean of vector.
extern void vDSP_meanv(const float *__A, vDSP_Stride __IA, float *__C,
                       vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_meanvD(const double *__A, vDSP_Stride __IA, double *__C,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        C[0] = sum(A[n], 0 <= n < N) / N;
*/

// Mean square of vector.
extern void vDSP_measqv(const float *__A, vDSP_Stride __IA, float *__C,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_measqvD(const double *__A, vDSP_Stride __I, double *__C,
                         vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        C[0] = sum(A[n]**2, 0 <= n < N) / N;
*/

// Minimum magnitude of vector.
extern void vDSP_minmgv(const float *__A, vDSP_Stride __IA, float *__C,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_minmgvD(const double *__A, vDSP_Stride __IA, double *__C,
                         vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    C[0] is set to the least value of |A[n]| for 0 <= n < N.
*/

// Minimum magnitude of vector, with index.
extern void vDSP_minmgvi(const float *__A, vDSP_Stride __IA, float *__C,
                         vDSP_Length *__I, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_minmgviD(const double *__A, vDSP_Stride __IA, double *__C,
                          vDSP_Length *__I, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    C[0] is set to the least value of |A[n]| for 0 <= n < N.
    I[0] is set to the least i*IA such that |A[i]| has the value in C[0].
*/

// Minimum value of vector.
extern void vDSP_minv(const float *__A, vDSP_Stride __IA, float *__C,
                      vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_minvD(const double *__A, vDSP_Stride __IA, double *__C,
                       vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    C[0] is set to the least value of A[n] for 0 <= n < N.
*/

// Minimum value of vector, with index.
extern void vDSP_minvi(const float *__A, vDSP_Stride __IA, float *__C,
                       vDSP_Length *__I, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_minviD(const double *__A, vDSP_Stride __IA, double *__C,
                        vDSP_Length *__I, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    C[0] is set to the least value of A[n] for 0 <= n < N.
    I[0] is set to the least i*IA such that A[i] has the value in C[0].
*/

// Matrix move.
extern void vDSP_mmov(const float *__A, float *__C, vDSP_Length __M,
                      vDSP_Length __N, vDSP_Length __TA, vDSP_Length __TC)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_mmovD(const double *__A, double *__C, vDSP_Length __M,
                       vDSP_Length __N, vDSP_Length __TA, vDSP_Length __TC)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:

        This routine does not have strides.

        A is regarded as a two-dimensional matrix with dimensions [N][TA].
        C is regarded as a two-dimensional matrix with dimensions [N][TC].

    These compute:

        for (n = 0; n < N; ++n)
        for (m = 0; m < M; ++m)
            C[n][m] = A[n][m];
*/

// Mean of signed squares of vector.
extern void vDSP_mvessq(const float *__A, vDSP_Stride __IA, float *__C,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_mvessqD(const double *__A, vDSP_Stride __IA, double *__C,
                         vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        C[0] = sum(A[n] * |A[n]|, 0 <= n < N) / N;
*/

// Find zero crossing.
extern void vDSP_nzcros(const float *__A, vDSP_Stride __IA, vDSP_Length __B,
                        vDSP_Length *__C, vDSP_Length *__D, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_nzcrosD(const double *__A, vDSP_Stride __IA, vDSP_Length __B,
                         vDSP_Length *__C, vDSP_Length *__D, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    Let S be the number of times the sign bit changes in the sequence A[0],
    A[1],... A[N-1].

    If B <= S:
        D[0] is set to B.
        C[0] is set to n*IA, where the B-th sign bit change occurs between
        elements A[n-1] and A[n].
    Else:
        D[0] is set to S.
        C[0] is set to 0.
*/

// Convert rectangular to polar.
extern void vDSP_polar(const float *__A, vDSP_Stride __IA, float *__C,
                       vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_polarD(const double *__A, vDSP_Stride __IA, double *__C,
                        vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  Strides are shown explicitly in pseudocode.

    These compute:

        for (n = 0; n < N; ++n)
        {
            x = A[n*IA+0];
            y = A[n*IA+1];
            C[n*IC+0] = sqrt(x**2 + y**2);
            C[n*IC+1] = atan2(y, x);
        }
*/

// Convert polar to rectangular.
extern void vDSP_rect(const float *__A, vDSP_Stride __IA, float *__C,
                      vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_rectD(const double *__A, vDSP_Stride __IA, double *__C,
                       vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  Strides are shown explicitly in pseudocode.

    These compute:

        for (n = 0; n < N; ++n)
        {
            r     = A[n*IA+0];
            theta = A[n*IA+1];
            C[n*IC+0] = r * cos(theta);
            C[n*IC+1] = r * sin(theta);
        }
*/

// Root-mean-square of vector.
extern void vDSP_rmsqv(const float *__A, vDSP_Stride __IA, float *__C,
                       vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_rmsqvD(const double *__A, vDSP_Stride __IA, double *__C,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        C[0] = sqrt(sum(A[n] ** 2, 0 <= n < N) / N);
*/

// Scalar-vector divide.
extern void vDSP_svdiv(const float *__A, const float *__B, vDSP_Stride __IB,
                       float *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_svdivD(const double *__A, const double *__B, vDSP_Stride __IB,
                        double *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[0] / B[n];

    When A[0] is not zero or NaN and B[n] is zero, C[n] is set to an
    infinity.
*/

// Sum of vector elements.
extern void vDSP_sve(const float *__A, vDSP_Stride __I, float *__C,
                     vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_sveD(const double *__A, vDSP_Stride __I, double *__C,
                      vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        C[0] = sum(A[n], 0 <= n < N);
*/

// Sum of vector elements magnitudes.
extern void vDSP_svemg(const float *__A, vDSP_Stride __IA, float *__C,
                       vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_svemgD(const double *__A, vDSP_Stride __IA, double *__C,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        C[0] = sum(|A[n]|, 0 <= n < N);
*/

// Sum of vector elements' squares.
extern void vDSP_svesq(const float *__A, vDSP_Stride __IA, float *__C,
                       vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_svesqD(const double *__A, vDSP_Stride __IA, double *__C,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        C[0] = sum(A[n] ** 2, 0 <= n < N);
*/

// Sum of vector elements and sum of vector elements' squares.
extern void vDSP_sve_svesq(const float *__A, vDSP_Stride __IA, float *__Sum,
                           float *__SumOfSquares, vDSP_Length __N)
    API_AVAILABLE(macos(10.8), ios(6.0));
extern void vDSP_sve_svesqD(const double *__A, vDSP_Stride __IA, double *__Sum,
                            double *__SumOfSquares, vDSP_Length __N)
    API_AVAILABLE(macos(10.8), ios(6.0));
/*  Maps:  The default maps are used.

    These compute:

        Sum[0]          = sum(A[n],      0 <= n < N);
        SumOfSquares[0] = sum(A[n] ** 2, 0 <= n < N);
*/

/*  Compute mean and standard deviation and then calculate new elements to have
    a zero mean and a unit standard deviation.

    For iOS 9.0 and later or OS X 10.11 and later, the production of new
    elements may be omitted by passing NULL for C.
*/
#if (defined __IPHONE_OS_VERSION_MIN_REQUIRED &&                               \
     __IPHONE_OS_VERSION_MIN_REQUIRED < 90000) ||                              \
    (defined __MAC_OS_X_VERSION_MIN_REQUIRED &&                                \
     __MAC_OS_X_VERSION_MIN_REQUIRED < 101100)
extern void vDSP_normalize(const float *__A, vDSP_Stride __IA, float *__C,
                           vDSP_Stride __IC, float *__Mean,
                           float *__StandardDeviation, vDSP_Length __N)
    API_AVAILABLE(macos(10.8), ios(6.0));
extern void vDSP_normalizeD(const double *__A, vDSP_Stride __IA, double *__C,
                            vDSP_Stride __IC, double *__Mean,
                            double *__StandardDeviation, vDSP_Length __N)
    API_AVAILABLE(macos(10.8), ios(6.0));
#else
extern void vDSP_normalize(const float *__A, vDSP_Stride __IA,
                           float *__nullable __C, vDSP_Stride __IC,
                           float *__Mean, float *__StandardDeviation,
                           vDSP_Length __N)
    API_AVAILABLE(macos(10.8), ios(6.0));
extern void vDSP_normalizeD(const double *__A, vDSP_Stride __IA,
                            double *__nullable __C, vDSP_Stride __IC,
                            double *__Mean, double *__StandardDeviation,
                            vDSP_Length __N)
    API_AVAILABLE(macos(10.8), ios(6.0));
#endif
/*  Maps:  The default maps are used.

    These compute:

        // Calculate mean and standard deviation.
        m = sum(A[n], 0 <= n < N) / N;
        d = sqrt(sum(A[n]**2, 0 <= n < N) / N - m**2);

        if (C)
        {
            // Normalize.
            for (n = 0; n < N; ++n)
                C[n] = (A[n] - m) / d;
        }
*/

// Sum of vector elements' signed squares.
extern void vDSP_svs(const float *__A, vDSP_Stride __IA, float *__C,
                     vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_svsD(const double *__A, vDSP_Stride __IA, double *__C,
                      vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        C[0] = sum(A[n] * |A[n]|, 0 <= n < N);
*/

// Vector add, add, and multiply.
extern void vDSP_vaam(const float *__A, vDSP_Stride __IA, const float *__B,
                      vDSP_Stride __IB, const float *__C, vDSP_Stride __IC,
                      const float *__D, vDSP_Stride __ID, float *__E,
                      vDSP_Stride __IE, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vaamD(const double *__A, vDSP_Stride __IA, const double *__B,
                       vDSP_Stride __IB, const double *__C, vDSP_Stride __IC,
                       const double *__D, vDSP_Stride __ID, double *__E,
                       vDSP_Stride __IE, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            E[n] = (A[n] + B[n]) * (C[n] + D[n]);
*/

// Vector add, subtract, and multiply.
extern void vDSP_vasbm(const float *__A, vDSP_Stride __IA, const float *__B,
                       vDSP_Stride __IB, const float *__C, vDSP_Stride __IC,
                       const float *__D, vDSP_Stride __ID, float *__E,
                       vDSP_Stride __IE, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vasbmD(const double *__A, vDSP_Stride __IA, const double *__B,
                        vDSP_Stride __IB, const double *__C, vDSP_Stride __IC,
                        const double *__D, vDSP_Stride __ID, double *__E,
                        vDSP_Stride __IE, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            E[n] = (A[n] + B[n]) * (C[n] - D[n]);
*/

// Vector add and scalar multiply.
extern void vDSP_vasm(const float *__A, vDSP_Stride __IA, const float *__B,
                      vDSP_Stride __IB, const float *__C, float *__D,
                      vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vasmD(const double *__A, vDSP_Stride __IA, const double *__B,
                       vDSP_Stride __IB, const double *__C, double *__D,
                       vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            D[n] = (A[n] + B[n]) * C[0];
*/

// Vector linear average.
extern void vDSP_vavlin(const float *__A, vDSP_Stride __IA, const float *__B,
                        float *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vavlinD(const double *__A, vDSP_Stride __IA, const double *__B,
                         double *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = (C[n]*B[0] + A[n]) / (B[0] + 1);
*/

// Vector clip.
extern void vDSP_vclip(const float *__A, vDSP_Stride __IA, const float *__B,
                       const float *__C, float *__D, vDSP_Stride __ID,
                       vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vclipD(const double *__A, vDSP_Stride __IA, const double *__B,
                        const double *__C, double *__D, vDSP_Stride __ID,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
        {
            D[n] = A[n];
            if (D[n] < B[0]) D[n] = B[0];
            if (C[0] < D[n]) D[n] = C[0];
        }
*/

// Vector clip and count.
extern void vDSP_vclipc(const float *__A, vDSP_Stride __IA, const float *__B,
                        const float *__C, float *__D, vDSP_Stride __ID,
                        vDSP_Length __N, vDSP_Length *__NLow,
                        vDSP_Length *__NHigh)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vclipcD(const double *__A, vDSP_Stride __IA, const double *__B,
                         const double *__C, double *__D, vDSP_Stride __ID,
                         vDSP_Length __N, vDSP_Length *__NLow,
                         vDSP_Length *__NHigh)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        NLow[0]  = 0;
        NHigh[0] = 0;
        for (n = 0; n < N; ++n)
        {
            D[n] = A[n];
            if (D[n] < B[0]) { D[n] = B[0]; ++NLow[0];  }
            if (C[0] < D[n]) { D[n] = C[0]; ++NHigh[0]; }
        }
*/

// Vector clear.
extern void vDSP_vclr(float *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vclrD(double *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = 0;
*/

// Vector compress.
extern void vDSP_vcmprs(const float *__A, vDSP_Stride __IA, const float *__B,
                        vDSP_Stride __IB, float *__C, vDSP_Stride __IC,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vcmprsD(const double *__A, vDSP_Stride __IA, const double *__B,
                         vDSP_Stride __IB, double *__C, vDSP_Stride __IC,
                         vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        p = 0;
        for (n = 0; n < N; ++n)
            if (B[n] != 0)
                C[p++] = A[n];
*/

// Vector convert to decibels, power, or amplitude.
extern void vDSP_vdbcon(const float *__A, vDSP_Stride __IA, const float *__B,
                        float *__C, vDSP_Stride __IC, vDSP_Length __N,
                        unsigned int __F) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vdbconD(const double *__A, vDSP_Stride __IA, const double *__B,
                         double *__C, vDSP_Stride __IC, vDSP_Length __N,
                         unsigned int __F) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        If Flag is 1:
            alpha = 20;
        If Flag is 0:
            alpha = 10;

        for (n = 0; n < N; ++n)
            C[n] = alpha * log10(A[n] / B[0]);
*/

// Vector distance.
extern void vDSP_vdist(const float *__A, vDSP_Stride __IA, const float *__B,
                       vDSP_Stride __IB, float *__C, vDSP_Stride __IC,
                       vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vdistD(const double *__A, vDSP_Stride __IA, const double *__B,
                        vDSP_Stride __IB, double *__C, vDSP_Stride __IC,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = sqrt(A[n]**2 + B[n]**2);
*/

// Vector envelope.
extern void vDSP_venvlp(const float *__A, vDSP_Stride __IA, const float *__B,
                        vDSP_Stride __IB, const float *__C, vDSP_Stride __IC,
                        float *__D, vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_venvlpD(const double *__A, vDSP_Stride __IA, const double *__B,
                         vDSP_Stride __IB, const double *__C, vDSP_Stride __IC,
                         double *__D, vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
        {
            if (C[n] < B[n] || A[n] < C[n]) D[n] = C[n];
            else D[n] = 0;
        }
*/

// Vector convert to integer, round toward zero.
extern void vDSP_vfix8(const float *__A, vDSP_Stride __IA, char *__C,
                       vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfix8D(const double *__A, vDSP_Stride __IA, char *__C,
                        vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfix16(const float *__A, vDSP_Stride __IA, short *__C,
                        vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfix16D(const double *__A, vDSP_Stride __IA, short *__C,
                         vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfix32(const float *__A, vDSP_Stride __IA, int *__C,
                        vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfix32D(const double *__A, vDSP_Stride __IA, int *__C,
                         vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfixu8(const float *__A, vDSP_Stride __IA, unsigned char *__C,
                        vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfixu8D(const double *__A, vDSP_Stride __IA,
                         unsigned char *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfixu16(const float *__A, vDSP_Stride __IA,
                         unsigned short *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfixu16D(const double *__A, vDSP_Stride __IA,
                          unsigned short *__C, vDSP_Stride __IC,
                          vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfixu32(const float *__A, vDSP_Stride __IA, unsigned int *__C,
                         vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfixu32D(const double *__A, vDSP_Stride __IA,
                          unsigned int *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = trunc(A[n]);
*/

/*  Vector convert single precision to 24-bit integer with pre-scaling.
    The scaled value is rounded toward zero.
*/
extern void vDSP_vsmfixu24(const float *__A, vDSP_Stride __IA, const float *__B,
                           vDSP_uint24 *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.9), ios(7.0));

/*  Vector convert single precision to 24-bit unsigned integer with pre-scaling.
    The scaled value is rounded toward zero.
*/
extern void vDSP_vsmfix24(const float *__A, vDSP_Stride __IA, const float *__B,
                          vDSP_int24 *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.9), ios(7.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = trunc(A[n] * B[0]);

    Note: Values outside the representable range are clamped to the largest
    or smallest representable values of the destination type.
*/

// Vector convert 24-bit integer to single-precision float.
extern void vDSP_vfltu24(const vDSP_uint24 *__A, vDSP_Stride __IA, float *__C,
                         vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.9), ios(7.0));
extern void vDSP_vflt24(const vDSP_int24 *__A, vDSP_Stride __IA, float *__C,
                        vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.9), ios(7.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[n];
*/

// Vector convert 24-bit integer to single-precision float and scale.
extern void vDSP_vfltsmu24(const vDSP_uint24 *__A, vDSP_Stride __IA,
                           const float *__B, float *__C, vDSP_Stride __IC,
                           vDSP_Length __N)
    API_AVAILABLE(macos(10.9), ios(7.0));
extern void vDSP_vfltsm24(const vDSP_int24 *__A, vDSP_Stride __IA,
                          const float *__B, float *__C, vDSP_Stride __IC,
                          vDSP_Length __N) API_AVAILABLE(macos(10.9), ios(7.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = B[0] * (float)A[n];
*/

// Vector convert to integer, round to nearest.
extern void vDSP_vfixr8(const float *__A, vDSP_Stride __IA, char *__C,
                        vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfixr8D(const double *__A, vDSP_Stride __IA, char *__C,
                         vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfixr16(const float *__A, vDSP_Stride __IA, short *__C,
                         vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfixr16D(const double *__A, vDSP_Stride __IA, short *__C,
                          vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfixr32(const float *__A, vDSP_Stride __IA, int *__C,
                         vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfixr32D(const double *__A, vDSP_Stride __IA, int *__C,
                          vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfixru8(const float *__A, vDSP_Stride __IA, unsigned char *__C,
                         vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfixru8D(const double *__A, vDSP_Stride __IA,
                          unsigned char *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfixru16(const float *__A, vDSP_Stride __IA,
                          unsigned short *__C, vDSP_Stride __IC,
                          vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfixru16D(const double *__A, vDSP_Stride __IA,
                           unsigned short *__C, vDSP_Stride __IC,
                           vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfixru32(const float *__A, vDSP_Stride __IA, unsigned int *__C,
                          vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfixru32D(const double *__A, vDSP_Stride __IA,
                           unsigned int *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = rint(A[n]);

    Note:  It is expected that the global rounding mode be the default,
    round-to-nearest.  It is unspecified whether ties round up or down.
*/

// Vector convert to floating-point from integer.
extern void vDSP_vflt8(const char *__A, vDSP_Stride __IA, float *__C,
                       vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vflt8D(const char *__A, vDSP_Stride __IA, double *__C,
                        vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vflt16(const short *__A, vDSP_Stride __IA, float *__C,
                        vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vflt16D(const short *__A, vDSP_Stride __IA, double *__C,
                         vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vflt32(const int *__A, vDSP_Stride __IA, float *__C,
                        vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vflt32D(const int *__A, vDSP_Stride __IA, double *__C,
                         vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfltu8(const unsigned char *__A, vDSP_Stride __IA, float *__C,
                        vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfltu8D(const unsigned char *__A, vDSP_Stride __IA,
                         double *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfltu16(const unsigned short *__A, vDSP_Stride __IA,
                         float *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfltu16D(const unsigned short *__A, vDSP_Stride __IA,
                          double *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfltu32(const unsigned int *__A, vDSP_Stride __IA, float *__C,
                         vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfltu32D(const unsigned int *__A, vDSP_Stride __IA,
                          double *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[n];
*/

// Vector fraction part (subtract integer toward zero).
extern void vDSP_vfrac(const float *__A, vDSP_Stride __IA, float *__C,
                       vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vfracD(const double *__A, vDSP_Stride __IA, double *__C,
                        vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[n] - trunc(A[n]);
*/

// Vector gather.
extern void vDSP_vgathr(const float *__A, const vDSP_Length *__B,
                        vDSP_Stride __IB, float *__C, vDSP_Stride __IC,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vgathrD(const double *__A, const vDSP_Length *__B,
                         vDSP_Stride __IB, double *__C, vDSP_Stride __IC,
                         vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.  Note that A has unit stride.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[B[n] - 1];
*/

// Vector gather, absolute pointers.
extern void vDSP_vgathra(const float *const __nonnull *__nonnull __A,
                         vDSP_Stride __IA, float *__C, vDSP_Stride __IC,
                         vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vgathraD(const double *const __nonnull *__nonnull __A,
                          vDSP_Stride __IA, double *__C, vDSP_Stride __IC,
                          vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = *A[n];
*/

// Vector generate tapered ramp.
extern void vDSP_vgen(const float *__A, const float *__B, float *__C,
                      vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vgenD(const double *__A, const double *__B, double *__C,
                       vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[0] + (B[0] - A[0]) * n/(N-1);
*/

// Vector generate by extrapolation and interpolation.
extern void vDSP_vgenp(const float *__A, vDSP_Stride __IA, const float *__B,
                       vDSP_Stride __IB, float *__C, vDSP_Stride __IC,
                       vDSP_Length __N,
                       vDSP_Length __M) // Length of A and of B.
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vgenpD(const double *__A, vDSP_Stride __IA, const double *__B,
                        vDSP_Stride __IB, double *__C, vDSP_Stride __IC,
                        vDSP_Length __N,
                        vDSP_Length __M) // Length of A and of B.
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            If n <= B[0],  then C[n] = A[0].
            If B[M-1] < n, then C[n] = A[M-1].
            Otherwise:
                Let m be such that B[m] < n <= B[m+1].
                C[n] = A[m] + (A[m+1]-A[m]) * (n-B[m]) / (B[m+1]-B[m]).

     The elements of B are expected to be in increasing order.
*/

// Vector inverted clip.
extern void vDSP_viclip(const float *__A, vDSP_Stride __IA, const float *__B,
                        const float *__C, float *__D, vDSP_Stride __ID,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_viclipD(const double *__A, vDSP_Stride __IA, const double *__B,
                         const double *__C, double *__D, vDSP_Stride __ID,
                         vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
        {
            if (A[n] <= B[0] || C[0] <= A[n])
                D[n] = A[n];
            else
                if (A[n] < 0)
                    D[n] = B[0];
                else
                    D[n] = C[0];
        }

    It is expected that B[0] <= 0 <= C[0].
*/

// Vector index, C[i] = A[truncate[B[i]].
extern void vDSP_vindex(const float *__A, const float *__B, vDSP_Stride __IB,
                        float *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vindexD(const double *__A, const double *__B, vDSP_Stride __IB,
                         double *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[trunc(B[n])];
*/

// Vector interpolation between vectors.
extern void vDSP_vintb(const float *__A, vDSP_Stride __IA, const float *__B,
                       vDSP_Stride __IB, const float *__C, float *__D,
                       vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vintbD(const double *__A, vDSP_Stride __IA, const double *__B,
                        vDSP_Stride __IB, const double *__C, double *__D,
                        vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            D[n] = A[n] + C[0] * (B[n] - A[n]);
*/

// Vector test limit.
extern void vDSP_vlim(const float *__A, vDSP_Stride __IA, const float *__B,
                      const float *__C, float *__D, vDSP_Stride __ID,
                      vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vlimD(const double *__A, vDSP_Stride __IA, const double *__B,
                       const double *__C, double *__D, vDSP_Stride __ID,
                       vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            if (B[0] <= A[n])
                D[n] = +C[0];
            else
                D[n] = -C[0];
*/

// Vector linear interpolation.
extern void vDSP_vlint(const float *__A, const float *__B, vDSP_Stride __IB,
                       float *__C, vDSP_Stride __IC, vDSP_Length __N,
                       vDSP_Length __M) // Nominal length of A, but not used.
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vlintD(const double *__A, const double *__B, vDSP_Stride __IB,
                        double *__C, vDSP_Stride __IC, vDSP_Length __N,
                        vDSP_Length __M) // Nominal length of A, but not used.
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
        {
            b = trunc(B[n]);
            a = B[n] - b;
            C[n] = A[b] + a * (A[b+1] - A[b]);
        }
*/

// Vector maxima.
extern void vDSP_vmax(const float *__A, vDSP_Stride __IA, const float *__B,
                      vDSP_Stride __IB, float *__C, vDSP_Stride __IC,
                      vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vmaxD(const double *__A, vDSP_Stride __IA, const double *__B,
                       vDSP_Stride __IB, double *__C, vDSP_Stride __IC,
                       vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = B[n] <= A[n] ? A[n] : B[n];
*/

// Vector maximum magnitude.
extern void vDSP_vmaxmg(const float *__A, vDSP_Stride __IA, const float *__B,
                        vDSP_Stride __IB, float *__C, vDSP_Stride __IC,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vmaxmgD(const double *__A, vDSP_Stride __IA, const double *__B,
                         vDSP_Stride __IB, double *__C, vDSP_Stride __IC,
                         vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = |B[n]| <= |A[n]| ? |A[n]| : |B[n]|;
*/

// Vector sliding window maxima.
extern void vDSP_vswmax(const float *__A, vDSP_Stride __IA, float *__C,
                        vDSP_Stride __IC, vDSP_Length __N,
                        vDSP_Length __WindowLength)
    API_AVAILABLE(macos(10.10), ios(8.0));
extern void vDSP_vswmaxD(const double *__A, vDSP_Stride __IA, double *__C,
                         vDSP_Stride __IC, vDSP_Length __N,
                         vDSP_Length __WindowLength)
    API_AVAILABLE(macos(10.10), ios(8.0));
/*  Maps:  The default maps are used.

    These compute the maximum value within a window to the input vector.
    A maximum is calculated for each window position:

        for (n = 0; n < N; ++n)
            C[n] = the greatest value of A[w] for n <= w < n+WindowLength.

    A must contain N+WindowLength-1 elements, and C must contain space for
    N+WindowLength-1 elements.  Although only N outputs are provided in C,
    the additional elements may be used for intermediate computation.

    A and C may not overlap.

    WindowLength must be positive (zero is not supported).
*/

// Vector minima.
extern void vDSP_vmin(const float *__A, vDSP_Stride __IA, const float *__B,
                      vDSP_Stride __IB, float *__C, vDSP_Stride __IC,
                      vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vminD(const double *__A, vDSP_Stride __IA, const double *__B,
                       vDSP_Stride __IB, double *__C, vDSP_Stride __IC,
                       vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[n] <= B[n] ? A[n] : B[n];
*/

// Vector minimum magnitude.
extern void vDSP_vminmg(const float *__A, vDSP_Stride __IA, const float *__B,
                        vDSP_Stride __IB, float *__C, vDSP_Stride __IC,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vminmgD(const double *__A, vDSP_Stride __IA, const double *__B,
                         vDSP_Stride __IB, double *__C, vDSP_Stride __IC,
                         vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = |A[n]| <= |B[n]| ? |A[n]| : |B[n]|;
*/

// Vector multiply, multiply, and add.
extern void vDSP_vmma(const float *__A, vDSP_Stride __IA, const float *__B,
                      vDSP_Stride __IB, const float *__C, vDSP_Stride __IC,
                      const float *__D, vDSP_Stride __ID, float *__E,
                      vDSP_Stride __IE, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vmmaD(const double *__A, vDSP_Stride __IA, const double *__B,
                       vDSP_Stride __IB, const double *__C, vDSP_Stride __IC,
                       const double *__D, vDSP_Stride __ID, double *__E,
                       vDSP_Stride __IE, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            E[n] = A[n]*B[n] + C[n]*D[n];
*/

// Vector multiply, multiply, and subtract.
extern void vDSP_vmmsb(const float *__A, vDSP_Stride __IA, const float *__B,
                       vDSP_Stride __IB, const float *__C, vDSP_Stride __IC,
                       const float *__D, vDSP_Stride __ID, float *__E,
                       vDSP_Stride __IE, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vmmsbD(const double *__A, vDSP_Stride __IA, const double *__B,
                        vDSP_Stride __IB, const double *__C, vDSP_Stride __IC,
                        const double *__D, vDSP_Stride __ID, double *__E,
                        vDSP_Stride __IE, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            E[n] = A[n]*B[n] - C[n]*D[n];
*/

// Vector multiply and scalar add.
extern void vDSP_vmsa(const float *__A, vDSP_Stride __IA, const float *__B,
                      vDSP_Stride __IB, const float *__C, float *__D,
                      vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vmsaD(const double *__A, vDSP_Stride __IA, const double *__B,
                       vDSP_Stride __IB, const double *__C, double *__D,
                       vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            D[n] = A[n]*B[n] + C[0];
*/

// Vector multiply and subtract.
extern void vDSP_vmsb(const float *__A, vDSP_Stride __IA, const float *__B,
                      vDSP_Stride __IB, const float *__C, vDSP_Stride __IC,
                      float *__D, vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vmsbD(const double *__A, vDSP_Stride __IA, const double *__B,
                       vDSP_Stride __IB, const double *__C, vDSP_Stride __IC,
                       double *__D, vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            D[n] = A[n]*B[n] - C[n];
*/

// Vector negative absolute value.
extern void vDSP_vnabs(const float *__A, vDSP_Stride __IA, float *__C,
                       vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vnabsD(const double *__A, vDSP_Stride __IA, double *__C,
                        vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = -|A[n]|;
*/

// Vector negate.
extern void vDSP_vneg(const float *__A, vDSP_Stride __IA, float *__C,
                      vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vnegD(const double *__A, vDSP_Stride __IA, double *__C,
                       vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = -A[n];
*/

// Vector polynomial.
extern void vDSP_vpoly(const float *__A, vDSP_Stride __IA, const float *__B,
                       vDSP_Stride __IB, float *__C, vDSP_Stride __IC,
                       vDSP_Length __N,
                       vDSP_Length __P) // P is the polynomial degree.
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vpolyD(const double *__A, vDSP_Stride __IA, const double *__B,
                        vDSP_Stride __IB, double *__C, vDSP_Stride __IC,
                        vDSP_Length __N,
                        vDSP_Length __P) // P is the polynomial degree.
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = sum(A[P-p] * B[n]**p, 0 <= p <= P);
*/

// Vector Pythagoras.
extern void vDSP_vpythg(const float *__A, vDSP_Stride __IA, const float *__B,
                        vDSP_Stride __IB, const float *__C, vDSP_Stride __IC,
                        const float *__D, vDSP_Stride __ID, float *__E,
                        vDSP_Stride __IE, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vpythgD(const double *__A, vDSP_Stride __IA, const double *__B,
                         vDSP_Stride __IB, const double *__C, vDSP_Stride __IC,
                         const double *__D, vDSP_Stride __ID, double *__E,
                         vDSP_Stride __IE, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            E[n] = sqrt((A[n]-C[n])**2 + (B[n]-D[n])**2);
*/

// Vector quadratic interpolation.
extern void vDSP_vqint(const float *__A, const float *__B, vDSP_Stride __IB,
                       float *__C, vDSP_Stride __IC, vDSP_Length __N,
                       vDSP_Length __M) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vqintD(const double *__A, const double *__B, vDSP_Stride __IB,
                        double *__C, vDSP_Stride __IC, vDSP_Length __N,
                        vDSP_Length __M) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
        {
            b = max(trunc(B[n]), 1);
            a = B[n] - b;
            C[n] = (A[b-1]*(a**2-a) + A[b]*(2-2*a**2) + A[b+1]*(a**2+a))
                / 2;
        }
*/

// Vector build ramp.
extern void vDSP_vramp(const float *__A, const float *__B, float *__C,
                       vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vrampD(const double *__A, const double *__B, double *__C,
                        vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[0] + n*B[0];
*/

// Vector running sum integration.
extern void vDSP_vrsum(const float *__A, vDSP_Stride __IA, const float *__S,
                       float *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vrsumD(const double *__A, vDSP_Stride __IA, const double *__S,
                        double *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = S[0] * sum(A[j], 0 < j <= n);

    Observe that C[0] is set to 0, and A[0] is not used.
*/

// Vector reverse order, in-place.
extern void vDSP_vrvrs(float *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vrvrsD(double *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        Let A contain a copy of C.
        for (n = 0; n < N; ++n)
            C[n] = A[N-1-n];
*/

// Vector subtract and multiply.
extern void vDSP_vsbm(const float *__A, vDSP_Stride __IA, const float *__B,
                      vDSP_Stride __IB, const float *__C, vDSP_Stride __IC,
                      float *__D, vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vsbmD(const double *__A, vDSP_Stride __IA, const double *__B,
                       vDSP_Stride __IB, const double *__C, vDSP_Stride __IC,
                       double *__D, vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            D[n] = (A[n] - B[n]) * C[n];
*/

// Vector subtract, subtract, and multiply.
extern void vDSP_vsbsbm(const float *__A, vDSP_Stride __IA, const float *__B,
                        vDSP_Stride __IB, const float *__C, vDSP_Stride __IC,
                        const float *__D, vDSP_Stride __ID, float *__E,
                        vDSP_Stride __IE, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vsbsbmD(const double *__A, vDSP_Stride __IA, const double *__B,
                         vDSP_Stride __IB, const double *__C, vDSP_Stride __IC,
                         const double *__D, vDSP_Stride __ID, double *__E,
                         vDSP_Stride __IE, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            E[n] = (A[n] - B[n]) * (C[n] - D[n]);
*/

// Vector subtract and scalar multiply.
extern void vDSP_vsbsm(const float *__A, vDSP_Stride __IA, const float *__B,
                       vDSP_Stride __IB, const float *__C, float *__D,
                       vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vsbsmD(const double *__A, vDSP_Stride __IA, const double *__B,
                        vDSP_Stride __IB, const double *__C, double *__D,
                        vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            D[n] = (A[n] - B[n]) * C[0];
*/

// Vector Simpson integration.
extern void vDSP_vsimps(const float *__A, vDSP_Stride __IA, const float *__B,
                        float *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vsimpsD(const double *__A, vDSP_Stride __IA, const double *__B,
                         double *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        C[0] = 0;
        C[1] = B[0] * (A[0] + A[1])/2;
        for (n = 2; n < N; ++n)
            C[n] = C[n-2] + B[0] * (A[n-2] + 4*A[n-1] + A[n])/3;
*/

// Vector-scalar multiply and vector add.
extern void vDSP_vsma(const float *__A, vDSP_Stride __IA, const float *__B,
                      const float *__C, vDSP_Stride __IC, float *__D,
                      vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vsmaD(const double *__A, vDSP_Stride __IA, const double *__B,
                       const double *__C, vDSP_Stride __IC, double *__D,
                       vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            D[n] = A[n]*B[0] + C[n];
*/

// Vector-scalar multiply and scalar add.
extern void vDSP_vsmsa(const float *__A, vDSP_Stride __IA, const float *__B,
                       const float *__C, float *__D, vDSP_Stride __ID,
                       vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vsmsaD(const double *__A, vDSP_Stride __IA, const double *__B,
                        const double *__C, double *__D, vDSP_Stride __ID,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            D[n] = A[n]*B[0] + C[0];
*/

// Vector scalar multiply and vector subtract.
extern void vDSP_vsmsb(const float *__A, vDSP_Stride __IA, const float *__B,
                       const float *__C, vDSP_Stride __IC, float *__D,
                       vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vsmsbD(const double *__A, vDSP_Stride __IA, const double *__B,
                        const double *__C, vDSP_Stride __IC, double *__D,
                        vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            D[n] = A[n]*B[0] - C[n];
*/

// Vector-scalar multiply, vector-scalar multiply and vector add.
extern void vDSP_vsmsma(const float *__A, vDSP_Stride __IA, const float *__B,
                        const float *__C, vDSP_Stride __IC, const float *__D,
                        float *__E, vDSP_Stride __IE, vDSP_Length __N)
    API_AVAILABLE(macos(10.9), ios(6.0));
extern void vDSP_vsmsmaD(const double *__A, vDSP_Stride __IA, const double *__B,
                         const double *__C, vDSP_Stride __IC, const double *__D,
                         double *__E, vDSP_Stride __IE, vDSP_Length __N)
    API_AVAILABLE(macos(10.10), ios(8.0));
/*  Maps:  The default maps are used.

    This computes:

        for (n = 0; n < N; ++n)
            E[n] = A[n]*B[0] + C[n]*D[0];
*/

// Vector sort, in-place.
extern void vDSP_vsort(float *__C, vDSP_Length __N, int __Order)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vsortD(double *__C, vDSP_Length __N, int __Order)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  If Order is +1, C is sorted in ascending order.
    If Order is -1, C is sorted in descending order.
*/

// Vector sort indices, in-place.
extern void vDSP_vsorti(const float *__C, vDSP_Length *__I,
                        vDSP_Length *__nullable __Temporary, vDSP_Length __N,
                        int __Order) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vsortiD(const double *__C, vDSP_Length *__I,
                         vDSP_Length *__nullable __Temporary, vDSP_Length __N,
                         int __Order) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  No strides are used; arrays map directly to memory.

    I contains indices into C.

    If Order is +1, I is sorted so that C[I[n]] increases, for 0 <= n < N.
    If Order is -1, I is sorted so that C[I[n]] decreases, for 0 <= n < N.

    Temporary is not used.  NULL should be passed for it.
*/

// Vector swap.
extern void vDSP_vswap(float *__A, vDSP_Stride __IA, float *__B,
                       vDSP_Stride __IB, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vswapD(double *__A, vDSP_Stride __IA, double *__B,
                        vDSP_Stride __IB, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            A[n] is swapped with B[n].
*/

// Vector sliding window sum.
extern void vDSP_vswsum(const float *__A, vDSP_Stride __IA, float *__C,
                        vDSP_Stride __IC, vDSP_Length __N,
                        vDSP_Length __P) // Length of window.
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vswsumD(const double *__A, vDSP_Stride __IA, double *__C,
                         vDSP_Stride __IC, vDSP_Length __N,
                         vDSP_Length __P) // Length of window.
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = sum(A[n+p], 0 <= p < P);

    Note that A must contain N+P-1 elements.
*/

// Vector table lookup and interpolation.
extern void vDSP_vtabi(const float *__A, vDSP_Stride __IA, const float *__S1,
                       const float *__S2, const float *__C, vDSP_Length __M,
                       float *__D, vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vtabiD(const double *__A, vDSP_Stride __IA, const double *__S1,
                        const double *__S2, const double *__C, vDSP_Length __M,
                        double *__D, vDSP_Stride __ID, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
        {
            p = S1[0] * A[n] + S2[0];
            if (p < 0)
                D[n] = C[0];
            else if (p < M-1)
            {
                q = trunc(p);
                r = p-q;
                D[n] = (1-r)*C[q] + r*C[q+1];
            }
            else
                D[n] = C[M-1];
        }
*/

// Vector threshold.
extern void vDSP_vthr(const float *__A, vDSP_Stride __IA, const float *__B,
                      float *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vthrD(const double *__A, vDSP_Stride __IA, const double *__B,
                       double *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            if (B[0] <= A[n])
                C[n] = A[n];
            else
                C[n] = B[0];
*/

// Vector threshold with zero fill.
extern void vDSP_vthres(const float *__A, vDSP_Stride __IA, const float *__B,
                        float *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vthresD(const double *__A, vDSP_Stride __IA, const double *__B,
                         double *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            if (B[0] <= A[n])
                C[n] = A[n];
            else
                C[n] = 0;
*/

// Vector threshold with signed constant.
extern void vDSP_vthrsc(const float *__A, vDSP_Stride __IA, const float *__B,
                        const float *__C, float *__D, vDSP_Stride __ID,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vthrscD(const double *__A, vDSP_Stride __IA, const double *__B,
                         const double *__C, double *__D, vDSP_Stride __ID,
                         vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            if (B[0] <= A[n])
                D[n] = +C[0];
            else
                D[n] = -C[0];
*/

// Vector tapered merge.
extern void vDSP_vtmerg(const float *__A, vDSP_Stride __IA, const float *__B,
                        vDSP_Stride __IB, float *__C, vDSP_Stride __IC,
                        vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vtmergD(const double *__A, vDSP_Stride __IA, const double *__B,
                         vDSP_Stride __IB, double *__C, vDSP_Stride __IC,
                         vDSP_Length __N) API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        for (n = 0; n < N; ++n)
            C[n] = A[n] + (B[n] - A[n]) * n/(N-1);
*/

// Vector trapezoidal integration.
extern void vDSP_vtrapz(const float *__A, vDSP_Stride __IA, const float *__B,
                        float *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_vtrapzD(const double *__A, vDSP_Stride __IA, const double *__B,
                         double *__C, vDSP_Stride __IC, vDSP_Length __N)
    API_AVAILABLE(macos(10.4), ios(4.0));
/*  Maps:  The default maps are used.

    These compute:

        C[0] = 0;
        for (n = 1; n < N; ++n)
            C[n] = C[n-1] + B[0] * (A[n-1] + A[n])/2;
*/

// Wiener Levinson.
extern void vDSP_wiener(vDSP_Length __L, const float *__A, const float *__C,
                        float *__F, float *__P, int __Flag, int *__Error)
    API_AVAILABLE(macos(10.4), ios(4.0));
extern void vDSP_wienerD(vDSP_Length __L, const double *__A, const double *__C,
                         double *__F, double *__P, int __Flag, int *__Error)
    API_AVAILABLE(macos(10.4), ios(4.0));

/*  vDSP_FFT16_copv and vDSP_FFT32_copv perform 16- and 32-element FFTs on
    interleaved complex unit-stride vector-block-aligned data.

    Parameters:

        float *Output

            Pointer to space for output data (interleaved complex).  This
            address must be vector-block aligned.

        const float *Input

            Pointer to input data (interleaved complex).  This address must be
            vector-block aligned.

        FFT_Direction Direction

            Transform direction, FFT_FORWARD or FFT_INVERSE.

    These routines calculate:

        For 0 <= k < N,

            H[k] = sum(1**(S * j*k/N) * h[j], 0 <= j < N),

    where:

        N is 16 or 32, as specified by the routine name,

        h[j] is Input[2*j+0] + i * Input[2*j+1] at routine entry,

        H[j] is Output[2*j+0] + i * Output[2*j+1] at routine exit,

        S is -1 if Direction is FFT_FORWARD and +1 if Direction is FFT_INVERSE,
        and

        1**x is e**(2*pi*i*x).

    Input and Output may be equal but may not otherwise overlap.
*/
void vDSP_FFT16_copv(float *__Output, const float *__Input,
                     FFTDirection __Direction)
    API_AVAILABLE(macos(10.6), ios(4.0));
void vDSP_FFT32_copv(float *__Output, const float *__Input,
                     FFTDirection __Direction)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_FFT16_zopv and vDSP_FFT32_zopv perform 16- and 32-element FFTs on
    separated complex unit-stride vector-block-aligned data.

    Parameters:

        float *Or, float *Oi

            Pointers to space for real and imaginary output data.  These
            addresses must be vector-block aligned.

        const float *Ir, *Ii

            Pointers to real and imaginary input data.  These addresses must be
            vector-block aligned.

        FFT_Direction Direction

            Transform direction, FFT_FORWARD or FFT_INVERSE.

    These routines calculate:

        For 0 <= k < N,

            H[k] = sum(1**(S * j*k/N) * h[j], 0 <= j < N),

    where:

        N is 16 or 32, as specified by the routine name,

        h[j] is Ir[j] + i * Ii[j] at routine entry,

        H[j] is Or[j] + i * Oi[j] at routine exit,

        S is -1 if Direction is FFT_FORWARD and +1 if Direction is FFT_INVERSE,
        and

        1**x is e**(2*pi*i*x).

    Or may equal Ir or Ii, and Oi may equal Ii or Ir, but the ararys may not
    otherwise overlap.
*/
void vDSP_FFT16_zopv(float *__Or, float *__Oi, const float *__Ir,
                     const float *__Ii, FFTDirection __Direction)
    API_AVAILABLE(macos(10.6), ios(4.0));
void vDSP_FFT32_zopv(float *__Or, float *__Oi, const float *__Ir,
                     const float *__Ii, FFTDirection __Direction)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vaddsub, vector single-precision add and subtract.

    Adds vector I0 to vector I1 and leaves the result in vector O0.
    Subtracts vector I0 from vector I1 and leaves the result in vector O1.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            float i1 = I1[i*I1S], i0 = I0[i*I0S];
            O0[i*O0S] = i1 + i0;
            O1[i*O1S] = i1 - i0;
        }

    Input:

        const float *I0, const float *I1, vDSP_Stride I0S, vDSP_Stride I1S.

            Starting addresses of both inputs and strides for the input vectors.

        float *O0, float *O1, vDSP_Stride O0S, vDSP_Stride O1S.

            Starting addresses of both outputs and strides for the output
   vectors.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O0 and O1.

    In-Place Operation:

        Either of O0 and/or O1 may equal I0 and/or I1, but O0 may not equal
        O1.  Otherwise, no overlap is permitted between any of the buffers.
*/
void vDSP_vaddsub(const float *__I0, vDSP_Stride __I0S, const float *__I1,
                  vDSP_Stride __I1S, float *__O0, vDSP_Stride __O0S,
                  float *__O1, vDSP_Stride __O1S, vDSP_Length __N)
    API_AVAILABLE(macos(10.10), ios(8.0));

/*  vDSP_vaddsubD, vector double-precision add and subtract.

    Adds vector I0 to vector I1 and leaves the result in vector O0.
    Subtracts vector I0 from vector I1 and leaves the result in vector O1.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            double i1 = I1[i*I1S], i0 = I0[i*I0S];
            O0[i*O0S] = i1 + i0;
            O1[i*O1S] = i1 - i0;
        }

    Input:

        const double *I0, const double *I1, vDSP_Stride I0S, vDSP_Stride I1S.

            Starting addresses of both inputs and strides for the input vectors.

        double *O0, double *O1, vDSP_Stride O0S, vDSP_Stride O1S.

            Starting addresses of both outputs and strides for the output
   vectors.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O0 and O1.

    In-Place Operation:

        Either of O0 and/or O1 may equal I0 and/or I1, but O0 may not equal
        O1.  Otherwise, no overlap is permitted between any of the buffers.
*/
void vDSP_vaddsubD(const double *__I0, vDSP_Stride __I0S, const double *__I1,
                   vDSP_Stride __I1S, double *__O0, vDSP_Stride __O0S,
                   double *__O1, vDSP_Stride __O1S, vDSP_Length __N)
    API_AVAILABLE(macos(10.10), ios(8.0));

/*  vDSP_vrampmul, vector single-precision vramp and multiply.

    This routine puts into O the product of I and a ramp function with initial
    value *Start and slope *Step.  *Start is updated to continue the ramp
    in a consecutive call.  To continue the ramp smoothly, the new value of
    *Step includes rounding errors accumulated during the routine rather than
    being calculated directly as *Start + N * *Step.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O[i*OS] = *Start * I[i*IS];
            *Start += *Step;
        }

    Input:

        const float *I, vDSP_Stride IS.

            Starting address and stride for the input vector.

        float *Start.

            Starting value for the ramp.

        const float *Step.

            Value of the step for the ramp.

        float *O, vDSP_Stride OS.

            Starting address and stride for the output vector.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmul(const float *__I, vDSP_Stride __IS, float *__Start,
                   const float *__Step, float *__O, vDSP_Stride __OS,
                   vDSP_Length __N) API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmulD, vector double-precision vramp and multiply.

    This routine puts into O the product of I and a ramp function with initial
    value *Start and slope *Step.  *Start is updated to continue the ramp
    in a consecutive call.  To continue the ramp smoothly, the new value of
    *Step includes rounding errors accumulated during the routine rather than
    being calculated directly as *Start + N * *Step.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O[i*OS] = *Start * I[i*IS];
            *Start += *Step;
        }

    Input:

        const double *I, vDSP_Stride IS.

            Starting address and stride for the input vector.

        double *Start.

            Starting value for the ramp.

        const double *Step.

            Value of the step for the ramp.

        double *O, vDSP_Stride OS.

            Starting address and stride for the output vector.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmulD(const double *__I, vDSP_Stride __IS, double *__Start,
                    const double *__Step, double *__O, vDSP_Stride __OS,
                    vDSP_Length __N) API_AVAILABLE(macos(10.10), ios(8.0));

/*  vDSP_vrampmuladd, vector single-precision vramp, multiply and add.

    This routine adds to O the product of I and a ramp function with initial
    value *Start and slope *Step.  *Start is updated to continue the ramp in a
    consecutive call.  To continue the ramp smoothly, the new value of *Step
    includes rounding errors accumulated during the routine rather than being
    calculated directly as *Start + N * *Step.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O[i*OS] += *Start * I[i*IS];
            *Start += *Step;
        }

    Input:

        const float *I, vDSP_Stride IS.

            Starting address and stride for the input vector.

        float *Start.

            Starting value for the ramp.

        const float *Step.

            Value of the step for the ramp.

        float *O, vDSP_Stride OS.

            Starting address and stride for the output vector.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are added to O.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmuladd(const float *__I, vDSP_Stride __IS, float *__Start,
                      const float *__Step, float *__O, vDSP_Stride __OS,
                      vDSP_Length __N) API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmuladdD, vector double-precision vramp, multiply and add.

    This routine adds to O the product of I and a ramp function with initial
    value *Start and slope *Step.  *Start is updated to continue the ramp in a
    consecutive call.  To continue the ramp smoothly, the new value of *Step
    includes rounding errors accumulated during the routine rather than being
    calculated directly as *Start + N * *Step.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O[i*OS] += *Start * I[i*IS];
            *Start += *Step;
        }

    Input:

        const double *I, vDSP_Stride IS.

            Starting address and stride for the input vector.

        double *Start.

            Starting value for the ramp.

        const double *Step.

            Value of the step for the ramp.

        double *O, vDSP_Stride OS.

            Starting address and stride for the output vector.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are added to O.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmuladdD(const double *__I, vDSP_Stride __IS, double *__Start,
                       const double *__Step, double *__O, vDSP_Stride __OS,
                       vDSP_Length __N) API_AVAILABLE(macos(10.10), ios(8.0));

/*  vDSP_vrampmul2, stereo vector single-precision vramp and multiply.

    This routine:

        Puts into O0 the product of I0 and a ramp function with initial value
        *Start and slope *Step.

        Puts into O1 the product of I1 and a ramp function with initial value
        *Start and slope *Step.

    *Start is updated to continue the ramp in a consecutive call.  To continue
    the ramp smoothly, the new value of *Step includes rounding errors
    accumulated during the routine rather than being calculated directly as
    *Start + N * *Step.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O0[i*OS] = *Start * I0[i*IS];
            O1[i*OS] = *Start * I1[i*IS];
            *Start += *Step;
        }

    Input:

        const float *I0, const float *I1, vDSP_Stride IS.

            Starting addresses of both inputs and stride for the input vectors.

        float *Start.

            Starting value for the ramp.

        const float *Step.

            Value of the step for the ramp.

        float *O0, float *O1, vDSP_Stride OS.

            Starting addresses of both outputs and stride for the output
   vectors.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O0 and O1.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmul2(const float *__I0, const float *__I1, vDSP_Stride __IS,
                    float *__Start, const float *__Step, float *__O0,
                    float *__O1, vDSP_Stride __OS, vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmul2D, stereo vector double-precision vramp and multiply.

    This routine:

        Puts into O0 the product of I0 and a ramp function with initial value
        *Start and slope *Step.

        Puts into O1 the product of I1 and a ramp function with initial value
        *Start and slope *Step.

    *Start is updated to continue the ramp in a consecutive call.  To continue
    the ramp smoothly, the new value of *Step includes rounding errors
    accumulated during the routine rather than being calculated directly as
    *Start + N * *Step.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O0[i*OS] = *Start * I0[i*IS];
            O1[i*OS] = *Start * I1[i*IS];
            *Start += *Step;
        }

    Input:

        const double *I0, const double *I1, vDSP_Stride IS.

            Starting addresses of both inputs and stride for the input vectors.

        double *Start.

            Starting value for the ramp.

        const double *Step.

            Value of the step for the ramp.

        double *O0, double *O1, vDSP_Stride OS.

            Starting addresses of both outputs and stride for the output
   vectors.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O0 and O1.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmul2D(const double *__I0, const double *__I1, vDSP_Stride __IS,
                     double *__Start, const double *__Step, double *__O0,
                     double *__O1, vDSP_Stride __OS, vDSP_Length __N)
    API_AVAILABLE(macos(10.10), ios(8.0));

/*  vDSP_vrampmuladd2, stereo vector single-precision vramp, multiply and add.

    This routine:

        Adds to O0 the product of I0 and a ramp function with initial value
        *Start and slope *Step.

        Adds to O1 the product of I1 and a ramp function with initial value
        *Start and slope *Step.

    *Start is updated to continue the ramp in a consecutive call.  To continue
    the ramp smoothly, the new value of *Step includes rounding errors
    accumulated during the routine rather than being calculated directly as
    *Start + N * *Step.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O0[i*OS] += *Start * I0[i*IS];
            O1[i*OS] += *Start * I1[i*IS];
            *Start += *Step;
        }

    Input:

        const float *I0, const float *I1, vDSP_Stride IS.

            Starting addresses of both inputs and stride for the input vectors.

        float *Start.

            Starting value for the ramp.

        const float *Step.

            Value of the step for the ramp.

        float *O0, float *O1, vDSP_Stride OS.

            Starting addresses of both outputs and stride for the output
   vectors.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O0 and O1.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmuladd2(const float *__I0, const float *__I1, vDSP_Stride __IS,
                       float *__Start, const float *__Step, float *__O0,
                       float *__O1, vDSP_Stride __OS, vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmuladd2D, stereo vector double-precision vramp, multiply and add.

    This routine:

        Adds to O0 the product of I0 and a ramp function with initial value
        *Start and slope *Step.

        Adds to O1 the product of I1 and a ramp function with initial value
        *Start and slope *Step.

    *Start is updated to continue the ramp in a consecutive call.  To continue
    the ramp smoothly, the new value of *Step includes rounding errors
    accumulated during the routine rather than being calculated directly as
    *Start + N * *Step.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O0[i*OS] += *Start * I0[i*IS];
            O1[i*OS] += *Start * I1[i*IS];
            *Start += *Step;
        }

    Input:

        const double *I0, const double *I1, vDSP_Stride IS.

            Starting addresses of both inputs and stride for the input vectors.

        double *Start.

            Starting value for the ramp.

        const double *Step.

            Value of the step for the ramp.

        double *O0, double *O1, vDSP_Stride OS.

            Starting addresses of both outputs and stride for the output
   vectors.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O0 and O1.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmuladd2D(const double *__I0, const double *__I1,
                        vDSP_Stride __IS, double *__Start, const double *__Step,
                        double *__O0, double *__O1, vDSP_Stride __OS,
                        vDSP_Length __N) API_AVAILABLE(macos(10.10), ios(8.0));

/*  vDSP_vrampmul_s1_15, vector integer 1.15 format vramp and multiply.

    This routine puts into O the product of I and a ramp function with initial
    value *Start and slope *Step.  *Start is updated to continue the ramp
    in a consecutive call.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O[i*OS] = *Start * I[i*IS];
            *Start += *Step;
        }

    The elements are fixed-point numbers, each with one sign bit and 15
    fraction bits.  Where the value of the short int is normally x, it is
    x/32768 for the purposes of this routine.

    Input:

        const short int *I, vDSP_Stride IS.

            Starting address and stride for the input vector.

        short int *Start.

            Starting value for the ramp.

        const short int *Step.

            Value of the step for the ramp.

        short int *O, vDSP_Stride OS.

            Starting address and stride for the output vector.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmul_s1_15(const short int *__I, vDSP_Stride __IS,
                         short int *__Start, const short int *__Step,
                         short int *__O, vDSP_Stride __OS, vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmuladd_s1_15, vector integer 1.15 format vramp, multiply and add.

    This routine adds to O the product of I and a ramp function with initial
    value *Start and slope *Step.  *Start is updated to continue the ramp in a
    consecutive call.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O[i*OS] += *Start * I[i*IS];
            *Start += *Step;
        }

    The elements are fixed-point numbers, each with one sign bit and 15
    fraction bits.  Where the value of the short int is normally x, it is
    x/32768 for the purposes of this routine.

    Input:
        const short int *I, vDSP_Stride IS.
            Starting address and stride for the input vector.
        short int *Start.
            Starting value for the ramp.
        const short int *Step.
            Value of the step for the ramp.
        short int *O, vDSP_Stride OS.

            Starting address and stride for the output vector.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are added to O.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmuladd_s1_15(const short int *__I, vDSP_Stride __IS,
                            short int *__Start, const short int *__Step,
                            short int *__O, vDSP_Stride __OS, vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmul2_s1_15, stereo vector integer 1.15 format vramp and multiply.

    This routine:

        Puts into O0 the product of I0 and a ramp function with initial value
        *Start and slope *Step.

        Puts into O1 the product of I1 and a ramp function with initial value
        *Start and slope *Step.

    *Start is updated to continue the ramp in a consecutive call.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O0[i*OS] = *Start * I0[i*IS];
            O1[i*OS] = *Start * I1[i*IS];
            *Start += *Step;
        }

    The elements are fixed-point numbers, each with one sign bit and 15
    fraction bits.  Where the value of the short int is normally x, it is
    x/32768 for the purposes of this routine.

    Input:

        const short int *I0, const short int *I1, vDSP_Stride IS.

            Starting addresses of both inputs and stride for the input vectors.

        short int *Start.

            Starting value for the ramp.

        const short int *Step.

            Value of the step for the ramp.

        short int *O0, short int *O1, vDSP_Stride OS.

            Starting addresses of both outputs and stride for the output
            vectors.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O0 and O1.

        On return, *Start contains initial *Start + N * *Step.

*/
void vDSP_vrampmul2_s1_15(const short int *__I0, const short int *__I1,
                          vDSP_Stride __IS, short int *__Start,
                          const short int *__Step, short int *__O0,
                          short int *__O1, vDSP_Stride __OS, vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmuladd2_s1_15, stereo vector integer 1.15 format vramp, multiply
    and add.

    This routine:

        Adds to O0 the product of I0 and a ramp function with initial value
        *Start and slope *Step.

        Adds to O1 the product of I1 and a ramp function with initial value
        *Start and slope *Step.

    *Start is updated to continue the ramp in a consecutive call.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O0[i*OS] += *Start * I0[i*IS];
            O1[i*OS] += *Start * I1[i*IS];
            *Start += *Step;
        }

    The elements are fixed-point numbers, each with one sign bit and 15
    fraction bits.  Where the value of the short int is normally x, it is
    x/32768 for the purposes of this routine.

    Input:

        const short int *I0, const short int *I1, vDSP_Stride IS.

            Starting addresses of both inputs and stride for the input vectors.

        short int *Start.

            Starting value for the ramp.

        const short int *Step.

            Value of the step for the ramp.

        short int *O0, short int *O1, vDSP_Stride OS.

            Starting addresses of both outputs and stride for the output
            vectors.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are added to O0 and O1.

        On return, *Start contains initial *Start + N * *Step.

*/
void vDSP_vrampmuladd2_s1_15(const short int *__I0, const short int *__I1,
                             vDSP_Stride __IS, short int *__Start,
                             const short int *__Step, short int *__O0,
                             short int *__O1, vDSP_Stride __OS, vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmul_s8_24, vector integer 8.24 format vramp and multiply.

    This routine puts into O the product of I and a ramp function with initial
    value *Start and slope *Step.  *Start is updated to continue the ramp
    in a consecutive call.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O[i*OS] = *Start * I[i*IS];
            *Start += *Step;
        }

    The elements are fixed-point numbers, each with eight integer bits
    (including sign) and 24 fraction bits.  Where the value of the int is
    normally x, it is x/16777216 for the purposes of this routine.

    Input:

        const int *I, vDSP_Stride IS.

            Starting address and stride for the input vector.

        int *Start.

            Starting value for the ramp.

        const int *Step.

            Value of the step for the ramp.

        int *O, vDSP_Stride OS.

            Starting address and stride for the output vector.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmul_s8_24(const int *__I, vDSP_Stride __IS, int *__Start,
                         const int *__Step, int *__O, vDSP_Stride __OS,
                         vDSP_Length __N) API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmuladd_s8_24, vector integer 8.24 format vramp, multiply and add.

    This routine adds to O the product of I and a ramp function with initial
    value *Start and slope *Step.  *Start is updated to continue the ramp in a
    consecutive call.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O[i*OS] += *Start * I[i*IS];
            *Start += *Step;
        }

    The elements are fixed-point numbers, each with eight integer bits
    (including sign) and 24 fraction bits.  Where the value of the int is
    normally x, it is x/16777216 for the purposes of this routine.

    Input:

        const int *I, vDSP_Stride IS.

            Starting address and stride for the input vector.

        int *Start.

            Starting value for the ramp.

        const int *Step.

            Value of the step for the ramp.

        int *O, vDSP_Stride OS.

            Starting address and stride for the output vector.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are added to O.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmuladd_s8_24(const int *__I, vDSP_Stride __IS, int *__Start,
                            const int *__Step, int *__O, vDSP_Stride __OS,
                            vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmul2_s8_24, stereo vector integer 8.24 format vramp and multiply.

    This routine:

        Puts into O0 the product of I0 and a ramp function with initial value
        *Start and slope *Step.

        Puts into O1 the product of I1 and a ramp function with initial value
        *Start and slope *Step.

    *Start is updated to continue the ramp in a consecutive call.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O0[i*OS] = *Start * I0[i*IS];
            O1[i*OS] = *Start * I1[i*IS];
            *Start += *Step;
        }

    The elements are fixed-point numbers, each with eight integer bits
    (including sign) and 24 fraction bits.  Where the value of the int is
    normally x, it is x/16777216 for the purposes of this routine.

    Input:

        const int *I0, const int *I1, vDSP_Stride IS.

            Starting addresses of both inputs and stride for the input vectors.

        int *Start.

            Starting value for the ramp.

        const int *Step.

            Value of the step for the ramp.

        int *O0, int *O1, vDSP_Stride OS.

            Starting addresses of both outputs and stride for the output
            vectors.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O0 and O1.

        On return, *Start contains initial *Start + N * *Step.

*/
void vDSP_vrampmul2_s8_24(const int *__I0, const int *__I1, vDSP_Stride __IS,
                          int *__Start, const int *__Step, int *__O0, int *__O1,
                          vDSP_Stride __OS, vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmuladd2_s8_24, stereo vector integer 8.24 format vramp, multiply
    and add.

    This routine:

        Adds to O0 the product of I0 and a ramp function with initial value
        *Start and slope *Step.

        Adds to O1 the product of I1 and a ramp function with initial value
        *Start and slope *Step.

    *Start is updated to continue the ramp in a consecutive call.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O0[i*OS] += *Start * I0[i*IS];
            O1[i*OS] += *Start * I1[i*IS];
            *Start += *Step;
        }

    The elements are fixed-point numbers, each with eight integer bits
    (including sign) and 24 fraction bits.  Where the value of the int is
    normally x, it is x/16777216 for the purposes of this routine.

    Input:
        const int *I0, const int *I1, vDSP_Stride IS.
            Starting addresses of both inputs and stride for the input vectors.

        int *Start.
            Starting value for the ramp.

        const int *Step.
            Value of the step for the ramp.

        int *O0, int *O1, vDSP_Stride OS.
            Starting addresses of both outputs and stride for the output
            vectors.

        vDSP_Length Length.
            Number of elements in each vector.

    Output:
        The results are written to O0 and O1.
        On return, *Start contains initial *Start + N * *Step.

*/
void vDSP_vrampmuladd2_s8_24(const int *__I0, const int *__I1, vDSP_Stride __IS,
                             int *__Start, const int *__Step, int *__O0,
                             int *__O1, vDSP_Stride __OS, vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));

#ifndef USE_NON_APPLE_STANDARD_DATATYPES
#define USE_NON_APPLE_STANDARD_DATATYPES 1
#endif /* !defined(USE_NON_APPLE_STANDARD_DATATYPES) */

#if USE_NON_APPLE_STANDARD_DATATYPES
enum {
  FFT_FORWARD = kFFTDirection_Forward,
  FFT_INVERSE = kFFTDirection_Inverse
};

enum {
  FFT_RADIX2 = kFFTRadix2,
  FFT_RADIX3 = kFFTRadix3,
  FFT_RADIX5 = kFFTRadix5
};

typedef DSPComplex COMPLEX;
typedef DSPSplitComplex COMPLEX_SPLIT;
typedef DSPDoubleComplex DOUBLE_COMPLEX;
typedef DSPDoubleSplitComplex DOUBLE_COMPLEX_SPLIT;
#endif /* USE_NON_APPLE_STANDARD_DATATYPES */

#pragma options align = reset

#if __has_feature(assume_nonnull)
_Pragma("clang assume_nonnull end")
#endif

#ifdef __cplusplus
}
#endif

#endif // __VDSP__
