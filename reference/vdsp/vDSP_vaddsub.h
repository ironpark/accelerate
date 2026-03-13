/*  vDSP_vaddsub, vector single-precision add and subtract.

    Adds vector I0 to vector I1 and leaves the result in vector O0.
    Subtracts vector I0 from vector I1 and leaves the result in vector O1.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            float i1 = I1[i*I1S], i0 = I0[i*I0S];
            O0[i*O0S] = i1 + i0;
            O1[i*O1S] = i1 - i0;
        }

    Input:

        const float *I0, const float *I1, vDSP_Stride I0S, vDSP_Stride I1S.

            Starting addresses of both inputs and strides for the input vectors.

        float *O0, float *O1, vDSP_Stride O0S, vDSP_Stride O1S.

            Starting addresses of both outputs and strides for the output
   vectors.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O0 and O1.

    In-Place Operation:

        Either of O0 and/or O1 may equal I0 and/or I1, but O0 may not equal
        O1.  Otherwise, no overlap is permitted between any of the buffers.
*/
void vDSP_vaddsub(const float *__I0, vDSP_Stride __I0S, const float *__I1,
                  vDSP_Stride __I1S, float *__O0, vDSP_Stride __O0S,
                  float *__O1, vDSP_Stride __O1S, vDSP_Length __N)
    API_AVAILABLE(macos(10.10), ios(8.0));

/*  vDSP_vaddsubD, vector double-precision add and subtract.

    Adds vector I0 to vector I1 and leaves the result in vector O0.
    Subtracts vector I0 from vector I1 and leaves the result in vector O1.

    This routine calculates:

        for (i = 0; i < N; ++i)
        {
            double i1 = I1[i*I1S], i0 = I0[i*I0S];
            O0[i*O0S] = i1 + i0;
            O1[i*O1S] = i1 - i0;
        }

    Input:

        const double *I0, const double *I1, vDSP_Stride I0S, vDSP_Stride I1S.

            Starting addresses of both inputs and strides for the input vectors.

        double *O0, double *O1, vDSP_Stride O0S, vDSP_Stride O1S.

            Starting addresses of both outputs and strides for the output
   vectors.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to O0 and O1.

    In-Place Operation:

        Either of O0 and/or O1 may equal I0 and/or I1, but O0 may not equal
        O1.  Otherwise, no overlap is permitted between any of the buffers.
*/
void vDSP_vaddsubD(const double *__I0, vDSP_Stride __I0S, const double *__I1,
                   vDSP_Stride __I1S, double *__O0, vDSP_Stride __O0S,
                   double *__O1, vDSP_Stride __O1S, vDSP_Length __N)
    API_AVAILABLE(macos(10.10), ios(8.0));
