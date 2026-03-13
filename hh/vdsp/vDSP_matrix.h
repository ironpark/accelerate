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
