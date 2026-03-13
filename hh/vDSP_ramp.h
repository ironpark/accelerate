/*  vDSP_vrampmul, vector single-precision vramp and multiply.

    This routine puts into O the product of I and a ramp function with initial
    value *Start and slope *Step.  *Start is updated to continue the ramp
    in a consecutive call.  To continue the ramp smoothly, the new value of
    *Step includes rounding errors accumulated during the routine rather than
    being calculated directly as *Start + N * *Step.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O[i*OS] = *Start * I[i*IS];
            *Start += *Step;
        }

    Input:

        const float *I, vDSP_Stride IS.

            Starting address and stride for the input vector.

        float *Start.

            Starting value for the ramp.

        const float *Step.

            Value of the step for the ramp.

        float *O, vDSP_Stride OS.

            Starting address and stride for the output vector.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmul(const float *__I, vDSP_Stride __IS, float *__Start,
                   const float *__Step, float *__O, vDSP_Stride __OS,
                   vDSP_Length __N) API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmulD, vector double-precision vramp and multiply.

    This routine puts into O the product of I and a ramp function with initial
    value *Start and slope *Step.  *Start is updated to continue the ramp
    in a consecutive call.  To continue the ramp smoothly, the new value of
    *Step includes rounding errors accumulated during the routine rather than
    being calculated directly as *Start + N * *Step.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O[i*OS] = *Start * I[i*IS];
            *Start += *Step;
        }

    Input:

        const double *I, vDSP_Stride IS.

            Starting address and stride for the input vector.

        double *Start.

            Starting value for the ramp.

        const double *Step.

            Value of the step for the ramp.

        double *O, vDSP_Stride OS.

            Starting address and stride for the output vector.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmulD(const double *__I, vDSP_Stride __IS, double *__Start,
                    const double *__Step, double *__O, vDSP_Stride __OS,
                    vDSP_Length __N) API_AVAILABLE(macos(10.10), ios(8.0));

/*  vDSP_vrampmuladd, vector single-precision vramp, multiply and add.

    This routine adds to O the product of I and a ramp function with initial
    value *Start and slope *Step.  *Start is updated to continue the ramp in a
    consecutive call.  To continue the ramp smoothly, the new value of *Step
    includes rounding errors accumulated during the routine rather than being
    calculated directly as *Start + N * *Step.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O[i*OS] += *Start * I[i*IS];
            *Start += *Step;
        }

    Input:

        const float *I, vDSP_Stride IS.

            Starting address and stride for the input vector.

        float *Start.

            Starting value for the ramp.

        const float *Step.

            Value of the step for the ramp.

        float *O, vDSP_Stride OS.

            Starting address and stride for the output vector.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are added to O.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmuladd(const float *__I, vDSP_Stride __IS, float *__Start,
                      const float *__Step, float *__O, vDSP_Stride __OS,
                      vDSP_Length __N) API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmuladdD, vector double-precision vramp, multiply and add.

    This routine adds to O the product of I and a ramp function with initial
    value *Start and slope *Step.  *Start is updated to continue the ramp in a
    consecutive call.  To continue the ramp smoothly, the new value of *Step
    includes rounding errors accumulated during the routine rather than being
    calculated directly as *Start + N * *Step.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O[i*OS] += *Start * I[i*IS];
            *Start += *Step;
        }

    Input:

        const double *I, vDSP_Stride IS.

            Starting address and stride for the input vector.

        double *Start.

            Starting value for the ramp.

        const double *Step.

            Value of the step for the ramp.

        double *O, vDSP_Stride OS.

            Starting address and stride for the output vector.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are added to O.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmuladdD(const double *__I, vDSP_Stride __IS, double *__Start,
                       const double *__Step, double *__O, vDSP_Stride __OS,
                       vDSP_Length __N) API_AVAILABLE(macos(10.10), ios(8.0));

/*  vDSP_vrampmul2, stereo vector single-precision vramp and multiply.

    This routine:

        Puts into O0 the product of I0 and a ramp function with initial value
        *Start and slope *Step.

        Puts into O1 the product of I1 and a ramp function with initial value
        *Start and slope *Step.

    *Start is updated to continue the ramp in a consecutive call.  To continue
    the ramp smoothly, the new value of *Step includes rounding errors
    accumulated during the routine rather than being calculated directly as
    *Start + N * *Step.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O0[i*OS] = *Start * I0[i*IS];
            O1[i*OS] = *Start * I1[i*IS];
            *Start += *Step;
        }

    Input:

        const float *I0, const float *I1, vDSP_Stride IS.

            Starting addresses of both inputs and stride for the input vectors.

        float *Start.

            Starting value for the ramp.

        const float *Step.

            Value of the step for the ramp.

        float *O0, float *O1, vDSP_Stride OS.

            Starting addresses of both outputs and stride for the output
   vectors.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O0 and O1.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmul2(const float *__I0, const float *__I1, vDSP_Stride __IS,
                    float *__Start, const float *__Step, float *__O0,
                    float *__O1, vDSP_Stride __OS, vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmul2D, stereo vector double-precision vramp and multiply.

    This routine:

        Puts into O0 the product of I0 and a ramp function with initial value
        *Start and slope *Step.

        Puts into O1 the product of I1 and a ramp function with initial value
        *Start and slope *Step.

    *Start is updated to continue the ramp in a consecutive call.  To continue
    the ramp smoothly, the new value of *Step includes rounding errors
    accumulated during the routine rather than being calculated directly as
    *Start + N * *Step.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O0[i*OS] = *Start * I0[i*IS];
            O1[i*OS] = *Start * I1[i*IS];
            *Start += *Step;
        }

    Input:

        const double *I0, const double *I1, vDSP_Stride IS.

            Starting addresses of both inputs and stride for the input vectors.

        double *Start.

            Starting value for the ramp.

        const double *Step.

            Value of the step for the ramp.

        double *O0, double *O1, vDSP_Stride OS.

            Starting addresses of both outputs and stride for the output
   vectors.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O0 and O1.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmul2D(const double *__I0, const double *__I1, vDSP_Stride __IS,
                     double *__Start, const double *__Step, double *__O0,
                     double *__O1, vDSP_Stride __OS, vDSP_Length __N)
    API_AVAILABLE(macos(10.10), ios(8.0));

/*  vDSP_vrampmuladd2, stereo vector single-precision vramp, multiply and add.

    This routine:

        Adds to O0 the product of I0 and a ramp function with initial value
        *Start and slope *Step.

        Adds to O1 the product of I1 and a ramp function with initial value
        *Start and slope *Step.

    *Start is updated to continue the ramp in a consecutive call.  To continue
    the ramp smoothly, the new value of *Step includes rounding errors
    accumulated during the routine rather than being calculated directly as
    *Start + N * *Step.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O0[i*OS] += *Start * I0[i*IS];
            O1[i*OS] += *Start * I1[i*IS];
            *Start += *Step;
        }

    Input:

        const float *I0, const float *I1, vDSP_Stride IS.

            Starting addresses of both inputs and stride for the input vectors.

        float *Start.

            Starting value for the ramp.

        const float *Step.

            Value of the step for the ramp.

        float *O0, float *O1, vDSP_Stride OS.

            Starting addresses of both outputs and stride for the output
   vectors.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O0 and O1.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmuladd2(const float *__I0, const float *__I1, vDSP_Stride __IS,
                       float *__Start, const float *__Step, float *__O0,
                       float *__O1, vDSP_Stride __OS, vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmuladd2D, stereo vector double-precision vramp, multiply and add.

    This routine:

        Adds to O0 the product of I0 and a ramp function with initial value
        *Start and slope *Step.

        Adds to O1 the product of I1 and a ramp function with initial value
        *Start and slope *Step.

    *Start is updated to continue the ramp in a consecutive call.  To continue
    the ramp smoothly, the new value of *Step includes rounding errors
    accumulated during the routine rather than being calculated directly as
    *Start + N * *Step.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O0[i*OS] += *Start * I0[i*IS];
            O1[i*OS] += *Start * I1[i*IS];
            *Start += *Step;
        }

    Input:

        const double *I0, const double *I1, vDSP_Stride IS.

            Starting addresses of both inputs and stride for the input vectors.

        double *Start.

            Starting value for the ramp.

        const double *Step.

            Value of the step for the ramp.

        double *O0, double *O1, vDSP_Stride OS.

            Starting addresses of both outputs and stride for the output
   vectors.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O0 and O1.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmuladd2D(const double *__I0, const double *__I1,
                        vDSP_Stride __IS, double *__Start, const double *__Step,
                        double *__O0, double *__O1, vDSP_Stride __OS,
                        vDSP_Length __N) API_AVAILABLE(macos(10.10), ios(8.0));

/*  vDSP_vrampmul_s1_15, vector integer 1.15 format vramp and multiply.

    This routine puts into O the product of I and a ramp function with initial
    value *Start and slope *Step.  *Start is updated to continue the ramp
    in a consecutive call.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O[i*OS] = *Start * I[i*IS];
            *Start += *Step;
        }

    The elements are fixed-point numbers, each with one sign bit and 15
    fraction bits.  Where the value of the short int is normally x, it is
    x/32768 for the purposes of this routine.

    Input:

        const short int *I, vDSP_Stride IS.

            Starting address and stride for the input vector.

        short int *Start.

            Starting value for the ramp.

        const short int *Step.

            Value of the step for the ramp.

        short int *O, vDSP_Stride OS.

            Starting address and stride for the output vector.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmul_s1_15(const short int *__I, vDSP_Stride __IS,
                         short int *__Start, const short int *__Step,
                         short int *__O, vDSP_Stride __OS, vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmuladd_s1_15, vector integer 1.15 format vramp, multiply and add.

    This routine adds to O the product of I and a ramp function with initial
    value *Start and slope *Step.  *Start is updated to continue the ramp in a
    consecutive call.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O[i*OS] += *Start * I[i*IS];
            *Start += *Step;
        }

    The elements are fixed-point numbers, each with one sign bit and 15
    fraction bits.  Where the value of the short int is normally x, it is
    x/32768 for the purposes of this routine.

    Input:
        const short int *I, vDSP_Stride IS.
            Starting address and stride for the input vector.
        short int *Start.
            Starting value for the ramp.
        const short int *Step.
            Value of the step for the ramp.
        short int *O, vDSP_Stride OS.

            Starting address and stride for the output vector.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are added to O.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmuladd_s1_15(const short int *__I, vDSP_Stride __IS,
                            short int *__Start, const short int *__Step,
                            short int *__O, vDSP_Stride __OS, vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmul2_s1_15, stereo vector integer 1.15 format vramp and multiply.

    This routine:

        Puts into O0 the product of I0 and a ramp function with initial value
        *Start and slope *Step.

        Puts into O1 the product of I1 and a ramp function with initial value
        *Start and slope *Step.

    *Start is updated to continue the ramp in a consecutive call.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O0[i*OS] = *Start * I0[i*IS];
            O1[i*OS] = *Start * I1[i*IS];
            *Start += *Step;
        }

    The elements are fixed-point numbers, each with one sign bit and 15
    fraction bits.  Where the value of the short int is normally x, it is
    x/32768 for the purposes of this routine.

    Input:

        const short int *I0, const short int *I1, vDSP_Stride IS.

            Starting addresses of both inputs and stride for the input vectors.

        short int *Start.

            Starting value for the ramp.

        const short int *Step.

            Value of the step for the ramp.

        short int *O0, short int *O1, vDSP_Stride OS.

            Starting addresses of both outputs and stride for the output
            vectors.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O0 and O1.

        On return, *Start contains initial *Start + N * *Step.

*/
void vDSP_vrampmul2_s1_15(const short int *__I0, const short int *__I1,
                          vDSP_Stride __IS, short int *__Start,
                          const short int *__Step, short int *__O0,
                          short int *__O1, vDSP_Stride __OS, vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmuladd2_s1_15, stereo vector integer 1.15 format vramp, multiply
    and add.

    This routine:

        Adds to O0 the product of I0 and a ramp function with initial value
        *Start and slope *Step.

        Adds to O1 the product of I1 and a ramp function with initial value
        *Start and slope *Step.

    *Start is updated to continue the ramp in a consecutive call.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O0[i*OS] += *Start * I0[i*IS];
            O1[i*OS] += *Start * I1[i*IS];
            *Start += *Step;
        }

    The elements are fixed-point numbers, each with one sign bit and 15
    fraction bits.  Where the value of the short int is normally x, it is
    x/32768 for the purposes of this routine.

    Input:

        const short int *I0, const short int *I1, vDSP_Stride IS.

            Starting addresses of both inputs and stride for the input vectors.

        short int *Start.

            Starting value for the ramp.

        const short int *Step.

            Value of the step for the ramp.

        short int *O0, short int *O1, vDSP_Stride OS.

            Starting addresses of both outputs and stride for the output
            vectors.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are added to O0 and O1.

        On return, *Start contains initial *Start + N * *Step.

*/
void vDSP_vrampmuladd2_s1_15(const short int *__I0, const short int *__I1,
                             vDSP_Stride __IS, short int *__Start,
                             const short int *__Step, short int *__O0,
                             short int *__O1, vDSP_Stride __OS, vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmul_s8_24, vector integer 8.24 format vramp and multiply.

    This routine puts into O the product of I and a ramp function with initial
    value *Start and slope *Step.  *Start is updated to continue the ramp
    in a consecutive call.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O[i*OS] = *Start * I[i*IS];
            *Start += *Step;
        }

    The elements are fixed-point numbers, each with eight integer bits
    (including sign) and 24 fraction bits.  Where the value of the int is
    normally x, it is x/16777216 for the purposes of this routine.

    Input:

        const int *I, vDSP_Stride IS.

            Starting address and stride for the input vector.

        int *Start.

            Starting value for the ramp.

        const int *Step.

            Value of the step for the ramp.

        int *O, vDSP_Stride OS.

            Starting address and stride for the output vector.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmul_s8_24(const int *__I, vDSP_Stride __IS, int *__Start,
                         const int *__Step, int *__O, vDSP_Stride __OS,
                         vDSP_Length __N) API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmuladd_s8_24, vector integer 8.24 format vramp, multiply and add.

    This routine adds to O the product of I and a ramp function with initial
    value *Start and slope *Step.  *Start is updated to continue the ramp in a
    consecutive call.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O[i*OS] += *Start * I[i*IS];
            *Start += *Step;
        }

    The elements are fixed-point numbers, each with eight integer bits
    (including sign) and 24 fraction bits.  Where the value of the int is
    normally x, it is x/16777216 for the purposes of this routine.

    Input:

        const int *I, vDSP_Stride IS.

            Starting address and stride for the input vector.

        int *Start.

            Starting value for the ramp.

        const int *Step.

            Value of the step for the ramp.

        int *O, vDSP_Stride OS.

            Starting address and stride for the output vector.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are added to O.

        On return, *Start contains initial *Start + N * *Step.
*/
void vDSP_vrampmuladd_s8_24(const int *__I, vDSP_Stride __IS, int *__Start,
                            const int *__Step, int *__O, vDSP_Stride __OS,
                            vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmul2_s8_24, stereo vector integer 8.24 format vramp and multiply.

    This routine:

        Puts into O0 the product of I0 and a ramp function with initial value
        *Start and slope *Step.

        Puts into O1 the product of I1 and a ramp function with initial value
        *Start and slope *Step.

    *Start is updated to continue the ramp in a consecutive call.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O0[i*OS] = *Start * I0[i*IS];
            O1[i*OS] = *Start * I1[i*IS];
            *Start += *Step;
        }

    The elements are fixed-point numbers, each with eight integer bits
    (including sign) and 24 fraction bits.  Where the value of the int is
    normally x, it is x/16777216 for the purposes of this routine.

    Input:

        const int *I0, const int *I1, vDSP_Stride IS.

            Starting addresses of both inputs and stride for the input vectors.

        int *Start.

            Starting value for the ramp.

        const int *Step.

            Value of the step for the ramp.

        int *O0, int *O1, vDSP_Stride OS.

            Starting addresses of both outputs and stride for the output
            vectors.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O0 and O1.

        On return, *Start contains initial *Start + N * *Step.

*/
void vDSP_vrampmul2_s8_24(const int *__I0, const int *__I1, vDSP_Stride __IS,
                          int *__Start, const int *__Step, int *__O0, int *__O1,
                          vDSP_Stride __OS, vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_vrampmuladd2_s8_24, stereo vector integer 8.24 format vramp, multiply
    and add.

    This routine:

        Adds to O0 the product of I0 and a ramp function with initial value
        *Start and slope *Step.

        Adds to O1 the product of I1 and a ramp function with initial value
        *Start and slope *Step.

    *Start is updated to continue the ramp in a consecutive call.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            O0[i*OS] += *Start * I0[i*IS];
            O1[i*OS] += *Start * I1[i*IS];
            *Start += *Step;
        }

    The elements are fixed-point numbers, each with eight integer bits
    (including sign) and 24 fraction bits.  Where the value of the int is
    normally x, it is x/16777216 for the purposes of this routine.

    Input:
        const int *I0, const int *I1, vDSP_Stride IS.
            Starting addresses of both inputs and stride for the input vectors.

        int *Start.
            Starting value for the ramp.

        const int *Step.
            Value of the step for the ramp.

        int *O0, int *O1, vDSP_Stride OS.
            Starting addresses of both outputs and stride for the output
            vectors.

        vDSP_Length Length.
            Number of elements in each vector.

    Output:
        The results are written to O0 and O1.
        On return, *Start contains initial *Start + N * *Step.

*/
void vDSP_vrampmuladd2_s8_24(const int *__I0, const int *__I1, vDSP_Stride __IS,
                             int *__Start, const int *__Step, int *__O0,
                             int *__O1, vDSP_Stride __OS, vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));
