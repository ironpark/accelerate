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
