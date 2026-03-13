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
