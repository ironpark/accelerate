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
