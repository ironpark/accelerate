/*  vDSP_dotpr2, vector single-precision stereo dot product.

    Function:

        This routine calculates the dot product of A0 with B and the dot
        product of A1 with B.  This is functionally equivalent to calculating
        two dot products but might execute faster.

        In pseudocode, the operation is:

            sum0 = 0;
            sum1 = 0;
            for (i = 0; i < Length; ++i)
            {
                sum0 += A0[i*A0Stride] * B[i*BStride];
                sum1 += A1[i*A1Stride] * B[i*BStride];
            }
            *C0 = sum0;
            *C1 = sum1;

    Input:

        const float *A0, vDSP_Stride A0Stride.

            Starting address and stride for input vector A0.

        const float *A1, vDSP_Stride A1Stride.

            Starting address and stride for input vector A1.

        const float *B,  vDSP_Stride BStride.

            Starting address and stride for input vector B.

        float *C0.

            Address for dot product of A0 and B.

        float *C1.

            Address for dot product of A1 and B.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to *C0 and *C1.
*/
void vDSP_dotpr2(const float *__A0, vDSP_Stride __IA0, const float *__A1,
                 vDSP_Stride __IA1, const float *__B, vDSP_Stride __IB,
                 float *__C0, float *__C1, vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_dotpr2D, vector double-precision stereo dot product.

    Function:

        This routine calculates the dot product of A0 with B and the dot
        product of A1 with B.  This is functionally equivalent to calculating
        two dot products but might execute faster.

        In pseudocode, the operation is:

            sum0 = 0;
            sum1 = 0;
            for (i = 0; i < Length; ++i)
            {
                sum0 += A0[i*A0Stride] * B[i*BStride];
                sum1 += A1[i*A1Stride] * B[i*BStride];
            }
            *C0 = sum0;
            *C1 = sum1;

    Input:

        const double *A0, vDSP_Stride A0Stride.

            Starting address and stride for input vector A0.

        const double *A1, vDSP_Stride A1Stride.

            Starting address and stride for input vector A1.

        const double *B,  vDSP_Stride BStride.

            Starting address and stride for input vector B.

        double *C0.

            Address for dot product of A0 and B.

        double *C1.

            Address for dot product of A1 and B.

        vDSP_Length Length.

            Number of elements in each vector.

    Output:

        The results are written to *C0 and *C1.
*/
void vDSP_dotpr2D(const double *__A0, vDSP_Stride __IA0, const double *__A1,
                  vDSP_Stride __IA1, const double *__B, vDSP_Stride __IB,
                  double *__C0, double *__C1, vDSP_Length __N)
    API_AVAILABLE(macos(10.10), ios(8.0));

/*  vDSP_dotpr_s1_15, vector integer 1.15 format dot product.

    Function:

        This routine calculates the dot product of A with B.

        In pseudocode, the operation is:

            sum = 0;
            for (i = 0; i < N; ++i)
            {
                sum0 += A[i*AStride] * B[i*BStride];
            }
            *C = sum;

    The elements are fixed-point numbers, each with one sign bit and 15
    fraction bits.  Where the value of the short int is normally x, it is
    x/32768 for the purposes of this routine.

    Input:

        const short int *A, vDSP_Stride AStride.

            Starting address and stride for input vector A.

        const short int *B,  vDSP_Stride BStride.

            Starting address and stride for input vector B.

        short int *C.

            Address for dot product of A and B.

        vDSP_Length N.

            Number of elements in each vector.

    Output:

        The result is written to *C.
*/
void vDSP_dotpr_s1_15(const short int *__A, vDSP_Stride __IA,
                      const short int *__B, vDSP_Stride __IB, short int *__C,
                      vDSP_Length __N) API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_dotpr2_s1_15, vector integer 1.15 format stereo dot product.

    Function:

        This routine calculates the dot product of A0 with B and the dot
        product of A1 with B.  This is functionally equivalent to calculating
        two dot products but might execute faster.

        In pseudocode, the operation is:

            sum0 = 0;
            sum1 = 0;
            for (i = 0; i < N; ++i)
            {
                sum0 += A0[i*A0Stride] * B[i*BStride];
                sum1 += A1[i*A1Stride] * B[i*BStride];
            }
            *C0 = sum0;
            *C1 = sum1;

    The elements are fixed-point numbers, each with one sign bit and 15
    fraction bits.  Where the value of the short int is normally x, it is
    x/32768 for the purposes of this routine.

    Input:

        const short int *A0, vDSP_Stride A0Stride.

            Starting address and stride for input vector A0.

        const short int *A1, vDSP_Stride A1Stride.

            Starting address and stride for input vector A1.

        const short int *B,  vDSP_Stride BStride.

            Starting address and stride for input vector B.

        short int *C0.

            Address for dot product of A0 and B.

        short int *C1.

            Address for dot product of A1 and B.

        vDSP_Length N.

            Number of elements in each vector.

    Output:

        The results are written to *C0 and *C1.
*/
void vDSP_dotpr2_s1_15(const short int *__A0, vDSP_Stride __IA0,
                       const short int *__A1, vDSP_Stride __IA1,
                       const short int *__B, vDSP_Stride __IB, short int *__C0,
                       short int *__C1, vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_dotpr_s8_24, vector integer 8.24 format dot product.

    Function:

        This routine calculates the dot product of A with B.

        In pseudocode, the operation is:

            sum = 0;
            for (i = 0; i < N; ++i)
            {
                sum0 += A[i*AStride] * B[i*BStride];
            }
            *C = sum;

    The elements are fixed-point numbers, each with eight integer bits
    (including sign) and 24 fraction bits.  Where the value of the int is
    normally x, it is x/16777216 for the purposes of this routine.

    Input:

        const int *A, vDSP_Stride AStride.

            Starting address and stride for input vector A.

        const int *B,  vDSP_Stride BStride.

            Starting address and stride for input vector B.

        int *C.

            Address for dot product of A and B.

        vDSP_Length N.

            Number of elements in each vector.

    Output:

        The result is written to *C.
*/
void vDSP_dotpr_s8_24(const int *__A, vDSP_Stride __IA, const int *__B,
                      vDSP_Stride __IB, int *__C, vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_dotpr2_s8_24, vector integer 8.24 format stereo dot product.

    Function:

        This routine calculates the dot product of A0 with B and the dot
        product of A1 with B.  This is functionally equivalent to calculating
        two dot products but might execute faster.

        In pseudocode, the operation is:

            sum0 = 0;
            sum1 = 0;
            for (i = 0; i < N; ++i)
            {
                sum0 += A0[i*A0Stride] * B[i*BStride];
                sum1 += A1[i*A1Stride] * B[i*BStride];
            }
            *C0 = sum0;
            *C1 = sum1;

    The elements are fixed-point numbers, each with eight integer bits
    (including sign) and 24 fraction bits.  Where the value of the int is
    normally x, it is x/16777216 for the purposes of this routine.

    Input:

        const int *A0, vDSP_Stride A0Stride.

            Starting address and stride for input vector A0.

        const int *A1, vDSP_Stride A1Stride.

            Starting address and stride for input vector A1.

        const int *B,  vDSP_Stride BStride.

            Starting address and stride for input vector B.

        int *C0.

            Address for dot product of A0 and B.

        int *C1.

            Address for dot product of A1 and B.

        vDSP_Length N.

            Number of elements in each vector.

    Output:

        The results are written to *C0 and *C1.
*/
void vDSP_dotpr2_s8_24(const int *__A0, vDSP_Stride __IA0, const int *__A1,
                       vDSP_Stride __IA1, const int *__B, vDSP_Stride __IB,
                       int *__C0, int *__C1, vDSP_Length __N)
    API_AVAILABLE(macos(10.6), ios(4.0));
