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
