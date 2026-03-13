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
