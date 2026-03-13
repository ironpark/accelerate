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


// Split header includes
#include "vDSP_fft.h"
#include "vDSP_biquad.h"
#include "vDSP_dft.h"
#include "vDSP_conv.h"
#include "vDSP_matrix.h"
#include "vDSP_dotp.h"
#include "vDSP_vecop.h"
#include "vDSP_reduction.h"
#include "vDSP_clip.h"
#include "vDSP_convert.h"
#include "vDSP_util.h"
#include "vDSP_fixed_fft.h"
#include "vDSP_vaddsub.h"
#include "vDSP_ramp.h"

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
