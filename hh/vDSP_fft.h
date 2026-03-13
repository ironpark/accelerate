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

