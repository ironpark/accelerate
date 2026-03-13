/*  vDSP_FFT16_copv and vDSP_FFT32_copv perform 16- and 32-element FFTs on
    interleaved complex unit-stride vector-block-aligned data.

    Parameters:

        float *Output

            Pointer to space for output data (interleaved complex).  This
            address must be vector-block aligned.

        const float *Input

            Pointer to input data (interleaved complex).  This address must be
            vector-block aligned.

        FFT_Direction Direction

            Transform direction, FFT_FORWARD or FFT_INVERSE.

    These routines calculate:

        For 0 <= k < N,

            H[k] = sum(1**(S * j*k/N) * h[j], 0 <= j < N),

    where:

        N is 16 or 32, as specified by the routine name,

        h[j] is Input[2*j+0] + i * Input[2*j+1] at routine entry,

        H[j] is Output[2*j+0] + i * Output[2*j+1] at routine exit,

        S is -1 if Direction is FFT_FORWARD and +1 if Direction is FFT_INVERSE,
        and

        1**x is e**(2*pi*i*x).

    Input and Output may be equal but may not otherwise overlap.
*/
void vDSP_FFT16_copv(float *__Output, const float *__Input,
                     FFTDirection __Direction)
    API_AVAILABLE(macos(10.6), ios(4.0));
void vDSP_FFT32_copv(float *__Output, const float *__Input,
                     FFTDirection __Direction)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_FFT16_zopv and vDSP_FFT32_zopv perform 16- and 32-element FFTs on
    separated complex unit-stride vector-block-aligned data.

    Parameters:

        float *Or, float *Oi

            Pointers to space for real and imaginary output data.  These
            addresses must be vector-block aligned.

        const float *Ir, *Ii

            Pointers to real and imaginary input data.  These addresses must be
            vector-block aligned.

        FFT_Direction Direction

            Transform direction, FFT_FORWARD or FFT_INVERSE.

    These routines calculate:

        For 0 <= k < N,

            H[k] = sum(1**(S * j*k/N) * h[j], 0 <= j < N),

    where:

        N is 16 or 32, as specified by the routine name,

        h[j] is Ir[j] + i * Ii[j] at routine entry,

        H[j] is Or[j] + i * Oi[j] at routine exit,

        S is -1 if Direction is FFT_FORWARD and +1 if Direction is FFT_INVERSE,
        and

        1**x is e**(2*pi*i*x).

    Or may equal Ir or Ii, and Oi may equal Ii or Ir, but the ararys may not
    otherwise overlap.
*/
void vDSP_FFT16_zopv(float *__Or, float *__Oi, const float *__Ir,
                     const float *__Ii, FFTDirection __Direction)
    API_AVAILABLE(macos(10.6), ios(4.0));
void vDSP_FFT32_zopv(float *__Or, float *__Oi, const float *__Ir,
                     const float *__Ii, FFTDirection __Direction)
    API_AVAILABLE(macos(10.6), ios(4.0));
