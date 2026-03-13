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

