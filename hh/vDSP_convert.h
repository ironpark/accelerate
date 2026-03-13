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
