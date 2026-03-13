/*  How to use the Discrete Fourier Transform (DFT) and Discrete Cosine
    Transform (DCT) interfaces.

    There are three steps to performing a DFT or DCT:

        Call a setup routine (e.g., vDSP_DFT_zop_CreateSetup) to get a setup
        object.

            This is a preparation step to be done when a program is starting or
            is starting some new phase (e.g., when a communication channel is
            opened).  It should never be done during real-time processing.  The
            setup routine is slow and is called only once to prepare data that
            can be used many times.

        Call an execution routine (e.g., vDSP_DFT_Execute or vDSP_DCT_Execute)
        to perform a DFT or DCT, and pass it the setup object.

            The execution routine is fast (for selected cases) and is generally
            called many times.

        Call a destroy routine (e.g., vDSP_DFT_DestroySetup) to release the
        memory held by the setup object.

            This is done when a program is ending or is ending some phase.
            After calling a destroy routine, the setup data is no longer valid
            and should not be used.

    Discussion:

        The current sequences of setup, execution, destroy routines are:

            For single-precision (float):

                vDSP_DFT_zop_CreateSetup,
                vDSP_DFT_Execute,
                vDSP_DFT_DestroySetup.

                vDSP_DFT_zrop_CreateSetup,
                vDSP_DFT_Execute,
                vDSP_DFT_DestroySetup.

                vDSP_DCT_CreateSetup,
                vDSP_DCT_Execute,
                vDSP_DFT_DestroySetup.

                vDSP_DFT_CreateSetup,
                vDSP_DFT_zop,
                vDSP_DFT_DestroySetup.

            For double-precision (double):

                vDSP_DFT_zop_CreateSetupD,
                vDSP_DFT_ExecuteD,
                vDSP_DFT_DestroySetupD.

                vDSP_DFT_zrop_CreateSetupD,
                vDSP_DFT_ExecuteD,
                vDSP_DFT_DestroySetupD.

        Sharing DFT and DCT setups:

            Any setup returned by a DFT or DCT setup routine may be passed as
            input to any DFT or DCT setup routine for the same precision (float
            or double), in the parameter named Previous.  (This allows the
            setups to share data, avoiding unnecessary duplication of some
            setup data.)  Setup routines may be executed in any order.  Passing
            any setup of a group of setups sharing data will result in a new
            setup sharing data with all of the group.

            When calling an execution routine, each setup can be used only with
            its intended execution routine.  Thus the setup returned by
            vDSP_DFT_CreateSetup can only be used with vDSP_DFT_zop and not
            with vDSP_DFT_Execute.

            vDSP_DFT_DestroySetup is used to destroy any single-precision DFT
            or DCT setup.  vDSP_DFT_DestroySetupD is used to destroy any
            double-precision DFT or DCT setup.

        History:

            vDSP_DFT_CreateSetup and vDSP_DFT_zop are the original vDSP DFT
            routines.  vDSP_DFT_zop_CreateSetup, vDSP_DFT_zrop_CreateSetup, and
            vDSP_DFT_Execute are newer, more specialized DFT routines.  These
            newer routines do not have stride parameters (stride is one) and
            incorporate the direction parameter into the setup.  This reduces
            the number of arguments passed to the execution routine, which
            receives only the setup and four address parameters.  Additionally,
            the complex-to-complex DFT (zop) and real-to-complex DFT (zrop) use
            the same execution routine (the setup indicates which function to
            perform).

            We recommend you use vDSP_DFT_zop_CreateSetup,
            vDPS_DFT_zrop_CreateSetup, and vDSP_DFT_Execute, and that you not
            use vDSP_DFT_CreateSetup and vDSP_DFT_zop.

    Multithreading:

        The Accelerate FFT and DFT setup structures can optionally share
        underlying memory through the Previous parameter in the appropriate
        create setup function. To avoid undefined behaviour, don’t call a setup
        or destroy function on a setup structure while another setup structure
        that shares its memory is executing.

        The FFT and DFT setup structures only require read-only access to the
        underlying memory, therefore you can safely run multiple execution
        routines concurrently on structures that share memory.

        If you need to call setup and/or destroy routines while other DFT or
        DCT routines might be executing, you can either use Grand Central
        Dispatch or locks (costs time) to avoid simultaneous execution or you
        can create separate setup objects for them (costs memory).
*/

/*  A vDSP_DFT_Setup object is a pointer to a structure whose definition is
    unpubilshed.
*/
typedef struct vDSP_DFT_SetupStruct *vDSP_DFT_Setup;
typedef struct vDSP_DFT_SetupStructD *vDSP_DFT_SetupD;

// DFT direction may be specified as vDSP_DFT_FORWARD or vDSP_DFT_INVERSE.
typedef vDSP_ENUM(int, vDSP_DFT_Direction){vDSP_DFT_FORWARD = +1,
                                           vDSP_DFT_INVERSE = -1};

typedef struct vDSP_DFT_Interleaved_SetupStruct *vDSP_DFT_Interleaved_Setup;
typedef struct vDSP_DFT_Interleaved_SetupStructD *vDSP_DFT_Interleaved_SetupD;

// Interleaved DFT used as vDSP_DFT_Interleaved_ComplextoComplex or
// vDSP_DFT_Interleaved_Real2Complex.
typedef vDSP_ENUM(bool, vDSP_DFT_RealtoComplex){
    vDSP_DFT_Interleaved_ComplextoComplex = false,
    vDSP_DFT_Interleaved_RealtoComplex = true};

/*  vDSP_DFT_CreateSetup is a DFT setup routine.  It creates a setup object
    for use with the vDSP_DFT_zop execution routine.  We recommend you use
    vDSP_DFT_zop_CreateSetup instead of this routine.

    Parameters:

        vDSP_DFT_Setup Previous

            Previous is either zero or a previous DFT or DCT setup.  If a
            previous setup is passed, the new setup will share data with the
            previous setup, if feasible (and with any other setups the previous
            setup shares with).  If zero is passed, the routine will allocate
            and initialize new memory.

        vDSP_Length Length

            Length is the number of complex elements to be transformed.

    Return value:

        Zero is returned if memory is unavailable.

    The returned setup object may be used only with vDSP_DFT_zop for the length
    given during setup.  Unlike previous vDSP FFT routines, the setup may not
    be used to execute transforms with shorter lengths.

    Do not call this routine while any DFT routine sharing setup data might be
    executing.
*/
__nullable vDSP_DFT_Setup
vDSP_DFT_CreateSetup(__nullable vDSP_DFT_Setup __Previous, vDSP_Length __Length)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_DFT_zop_CreateSetup is a DFT setup routine.  It creates a setup object
    for use with the vDSP_DFT_Execute execution routine, to perform a
    complex-to-complex DFT.

    Parameters:

        vDSP_DFT_Setup Previous

            Previous is either zero or a previous DFT or DCT setup.  If a
            previous setup is passed, the new setup will share data with the
            previous setup, if feasible (and with any other setups the previous
            setup shares with).  If zero is passed, the routine will allocate
            and initialize new memory.

        vDSP_Length Length

            Length is the number of complex elements to be transformed.

        vDSP_DFT_Direction Direction

            Transform direction, vDSP_DFT_FORWARD or vDSP_DFT_INVERSE.

    Return value:

        Zero is returned if memory is unavailable or if there is no
        implementation for the requested case.  Currently, the implemented
        cases are:

            Length = 2**n.

            Length = f * 2**n, where f is 3, 5, or 15 and 3 <= n.

        Additionally, it is recommended that the array addresses (passed to
        vDSP_DFT_Execute) be 16-byte aligned.  For other cases, performance may
        be slightly or greatly worse, depending on transform length and
        processor model.

    Function:

        When vDSP_DFT_Execute is called with a setup returned from this
        routine, it calculates:

            For 0 <= k < N,

                H[k] = sum(1**(S * j*k/N) * h[j], 0 <= j < N),

        where:

            N is the length given in the setup;

            h is the array of complex numbers specified by Ir and Ii when
            vDSP_DFT_Execute is called:

                for 0 <= j < N,
                    h[j] = Ir[j] + i * Ii[j];

            H is the array of complex numbers specified by Or and Oi when
            vDSP_DFT_Execute returns:

                for 0 <= k < N,
                    H[k] = Or[k] + i * Oi[k];

            S is -1 if Direction is vDSP_DFT_FORWARD and +1 if Direction is
            vDSP_DFT_INVERSE; and

            1**x is e**(2*pi*i*x).

    Performance:

        Performance is good when the array addresses (passed to
        vDSP_DFT_Execute) are 16-byte aligned.  Other alignments are supported,
        but performance may be significantly worse in some cases, depending on
        the processor model or the transform length (because different
        algorithms are used for different forms of transform length).

    In-Place Operation:

        Or may equal Ir and Oi may equal Ii (in the call to vDSP_DFT_Execute).
        Otherwise, no overlap of Or, Oi, Ir, and Ii is supported.

    The returned setup object may be used only with vDSP_DFT_Execute for the
    length given during setup.  Unlike previous vDSP FFT routines, the setup
    may not be used to execute transforms with shorter lengths.

    Do not call this routine while any DFT or DCT routine sharing setup data
    might be executing.
*/
__nullable vDSP_DFT_Setup vDSP_DFT_zop_CreateSetup(
    __nullable vDSP_DFT_Setup __Previous, vDSP_Length __Length,
    vDSP_DFT_Direction __Direction) API_AVAILABLE(macos(10.7), ios(4.0));
__nullable vDSP_DFT_SetupD vDSP_DFT_zop_CreateSetupD(
    __nullable vDSP_DFT_SetupD __Previous, vDSP_Length __Length,
    vDSP_DFT_Direction __Direction) API_AVAILABLE(macos(10.9), ios(7.0));

/*  vDSP_DFT_zrop_CreateSetup and vDSP_DFT_zrop_CreateSetupD are DFT setup
    routines.  Each creates a setup object for use with the corresponding
    execution routine, vDSP_DFT_Execute or vDSP_DFT_ExecuteD, to perform a
    real-to-complex DFT or a complex-to-real DFT.  Documentation below is
    written for vDSP_DFT_zrop_CreateSetup.  vDSP_DFT_CreateSetupD behaves the
    same way, with corresponding changes of the types, objects, and routines to
    the double-precision versions.

    Parameters:

        vDSP_DFT_Setup Previous

            Previous is either zero or a previous DFT or DCT setup.  If a
            previous setup is passed, the new setup will share data with the
            previous setup, if feasible (and with any other setups the previous
            setup shares with).  If zero is passed, the routine will allocate
            and initialize new memory.

        vDSP_Length Length

            Length is the number of real elements to be transformed (in a a
            forward, real-to-complex transform) or produced (in a reverse,
            complex-to-real transform).  Length must be even.

        vDSP_DFT_Direction Direction

            Transform direction, vDSP_DFT_FORWARD or vDSP_DFT_INVERSE.

    Return value:

        Zero is returned if memory is unavailable or if there is no
        implementation for the requested case.  Currently, the implemented
        cases are:

            Length = 2**n.

            Length = f * 2**n, where f is 3, 5, or 15 and 4 <= n.

        Additionally, it is recommended that the array addresses (passed to
        vDSP_DFT_Execute) be 16-byte aligned.  For other cases, performance may
        be slightly or greatly worse, depending on transform length and
        processor model.

    Function:

        When vDSP_DFT_Execute is called with a setup returned from this
        routine, it calculates:

            For 0 <= k < N,

                H[k] = C * sum(1**(S * j*k/N) * h[j], 0 <= j < N),

        where:

            N is the Length given in the setup;

            h is the array of numbers specified by Ir and Ii when
            vDSP_DFT_Execute is called (see "Data Layout" below);

            H is the array of numbers specified by Or and Oi when
            vDSP_DFT_Execute returns (see "Data Layout" below);

            C is 2 if Direction is vDSP_DFT_FORWARD and 1 if Direction is
            vDSP_DFT_INVERSE;

            S is -1 if Direction is vDSP_DFT_FORWARD and +1 if Direction is
            vDSP_DFT_INVERSE; and

            1**x is e**(2*pi*i*x).

        Data Layout:

            If Direction is vDSP_DFT_FORWARD, then:

                h is an array of real numbers, with its even-index elements
                stored in Ir and its odd-index elements stored in Ii:

                    For 0 <= j < N/2,
                        h[2*j+0] = Ir[j], and
                        h[2*j+1] = Ii[j].

                H is an array of complex numbers, stored in Or and Oi:

                    H[0  ] = Or[0].  (H[0  ] is pure real.)
                    H[N/2] = Oi[0].  (H[N/2] is pure real.)
                    For 1 < k < N/2,
                        H[k] = Or[k] + i * Oi[k].

                For N/2 < k < N, H[k] is not explicitly stored in memory but is
                known because it necessarily equals the conjugate of H[N-k],
                which is stored as described above.

            If Direction is vDSP_DFT_INVERSE, then the layouts of the input and
            output arrays are swapped.  Ir and Ii describe an input array with
            complex elements laid out as described above for Or and Oi.  When
            vDSP_DFT_Execute returns, Or and Oi contain a pure real array, with
            its even-index elements stored in Or and its odd-index elements in
            Oi.

    Performance:

        Performance is good when the array addresses (passed to
        vDSP_DFT_Execute) are 16-byte aligned.  Other alignments are supported,
        but performance may be significantly worse in some cases, depending on
        the processor model or the transform length (because different
        algorithms are used for different forms of transform length).

    In-Place Operation:

        Or may equal Ir and Oi may equal Ii (in the call to vDSP_DFT_Execute).
        Otherwise, no overlap of Or, Oi, Ir, and Ii is supported.

    The returned setup object may be used only with vDSP_DFT_Execute for the
    length given during setup.  Unlike previous vDSP FFT routines, the setup
    may not be used to execute transforms with shorter lengths.

    Do not call this routine while any DFT routine sharing setup data might be
    executing.
*/
__nullable vDSP_DFT_Setup vDSP_DFT_zrop_CreateSetup(
    __nullable vDSP_DFT_Setup __Previous, vDSP_Length __Length,
    vDSP_DFT_Direction __Direction) API_AVAILABLE(macos(10.7), ios(4.0));
__nullable vDSP_DFT_SetupD vDSP_DFT_zrop_CreateSetupD(
    __nullable vDSP_DFT_SetupD __Previous, vDSP_Length __Length,
    vDSP_DFT_Direction __Direction) API_AVAILABLE(macos(10.9), ios(7.0));

/*  vDSP_DFT_DestroySetup and vDSP_DFT_DestroySetupD are DFT destroy routines.
    They release the memory used by a setup object.  Documentation below is
    written for vDSP_DFT_DestroySetup.  vDSP_DFT_DestroySetupD behaves the same
    way, with corresponding changes of the types, objects, and routines to the
    double-precision versions.

    Parameters:

        vDSP_DFT_Setup Setup

            Setup is the setup object to be released.  The object may have
            been previously allocated with any DFT or DCT setup routine, such
            as vDSP_DFT_zop_CreateSetup, vDSP_DFT_zrop_CreateSetup, or
            vDSP_DCT_CreateSetup.

            Setup may be a null pointer, in which case the call has no effect.

    Destroying a setup with shared data is safe; it will release only memory
    not needed by other undestroyed setups.  Memory (and the data it contains)
    is freed only when all setup objects using it have been destroyed.

    Do not call this routine while any DFT or DCT routine sharing setup data
    might be executing.
*/
void vDSP_DFT_DestroySetup(__nullable vDSP_DFT_Setup __Setup)
    API_AVAILABLE(macos(10.6), ios(4.0));
void vDSP_DFT_DestroySetupD(__nullable vDSP_DFT_SetupD __Setup)
    API_AVAILABLE(macos(10.9), ios(7.0));

/*  vDSP_DFT_zop is a DFT execution routine.  It performs a DFT, with the aid
    of previously created setup data.

    Parameters:

        vDSP_DFT_Setup Setup

            A setup object returned by a previous call to
            vDSP_DFT_zop_CreateSetup.

        const float *Ir
        const float *Ii

            Pointers to real and imaginary components of input data.

        vDSP_Stride Is

            The number of physical elements from one logical input element to
            the next.

        float *Or
        float *Oi

            Pointers to space for real and imaginary components of output
            data.

            The input and output arrays may not overlap except as specified
            in "In-Place Operation", below.

        vDSP_Stride Os

            The number of physical elements from one logical output element to
            the next.

        vDSP_DFT_Direction Direction

            Transform direction, vDSP_DFT_FORWARD or vDSP_DFT_INVERSE.

    Observe there is no separate length parameter.  The length is passed via
    the setup object.

    Performance:

        Performance is good for these cases:

            All addresses are 16-byte aligned, all strides are one, and the
            length is f * 2**n, where f is 3, 5, or 15 and 3 <= n.

        Performance is extremely slow for all other cases.

    In-Place Operation:

        For cases where the length is f * 2**n, where f is 3, 5, or 15 and 3 <=
        n, Or may equal Ir and Oi may equal Ii.  Otherwise, no overlap of Or,
        Oi, Ir, and Ii is supported.

    This routine calculates:

        For 0 <= k < N,

            H[k] = sum(1**(S * j*k/N) * h[j], 0 <= j < N),

    where:

        N is the length given in the setup,

        h is the array of complex numbers specified by Ir, Ii, and Is at
        routine entry:

            h[j] = Ir[j*Is] + i * Ii[j*Is],
            for 0 <= j < N,

        H is the array of complex numbers stored as specified by Or, Oi, and Os
        at routine exit:

            H[k] = Or[k*Os] + i * Oi[k*Os],
            for 0 <= k < N,

        S is -1 if Direction is vDSP_DFT_FORWARD and +1 if Direction is
        vDSP_DFT_INVERSE, and

        1**x is e**(2*pi*i*x).

    Do not call this routine while any DFT setup or destroy routine sharing
    setup data might be executing.
*/
void vDSP_DFT_zop(const struct vDSP_DFT_SetupStruct *__Setup, const float *__Ir,
                  const float *__Ii, vDSP_Stride __Is, float *__Or, float *__Oi,
                  vDSP_Stride __Os, vDSP_DFT_Direction __Direction)
    API_AVAILABLE(macos(10.6), ios(4.0));

/*  vDSP_DFT_Execute and vDSP_DFT_ExecuteD are DFT execution routines.  They
    perform a DFT, with the aid of previously created setup data.
    Documentation below is written for vDSP_DFT_Execute.  vDSP_DFT_ExecuteD
    behaves the same way, with corresponding changes of the types, objects, and
    routines to the double-precision versions.

    Parameters:

        vDSP_DFT_Setup Setup

            A setup object returned by a previous call to
            vDSP_DFT_zop_CreateSetup or vDSP_DFT_zrop_CreateSetup.

        const float *Ir
        const float *Ii

            Pointers to input data.

        float *Or
        float *Oi

            Pointers to output data.

            The input and output arrays may not overlap except as specified
            in "In-Place Operation", below.

    Performance and In-Place Operation:

        See notes for the setup routine for the operation being executed.

    Function:

        The function performed by this routine is determined by the setup
        passed to it.  The documentation for the routine used to create the
        setup describes the function.

        Note that different numbers of elements are required when this routine
        is called, depending on the setup used:

            When the setup is from vDSP_zop_CreateSetup, each array (Ir, Ii,
            Or, and Oi) must have Length elements.

            When the setup is from vDSP_zrop_CreateSetup, each array (Ir, Ii,
            Or, and Oi) must have Length/2 elements.

    Do not call this routine while any DFT setup or destroy routine sharing
    setup data might be executing.
*/
void vDSP_DFT_Execute(const struct vDSP_DFT_SetupStruct *__Setup,
                      const float *__Ir, const float *__Ii, float *__Or,
                      float *__Oi) API_AVAILABLE(macos(10.7), ios(4.0));
void vDSP_DFT_ExecuteD(const struct vDSP_DFT_SetupStructD *__Setup,
                       const double *__Ir, const double *__Ii, double *__Or,
                       double *__Oi) API_AVAILABLE(macos(10.9), ios(7.0));

/*  vDSP_DCT_CreateSetup is a DCT setup routine.  It creates a setup object
    for use with the vDSP_DCT_Execute routine.  See additional information
    above, at "How to use the Discrete Fourier Transform (DFT) and Discrete
    Cosine Transform (DCT) interfaces."

    Parameters:

        vDSP_DFT_Setup Previous

            Previous is either zero or a previous DFT or DCT setup.  If a
            previous setup is passed, the new setup will share data with the
            previous setup, if feasible (and with any other setups the
            previous setup shares with).  If zero is passed, the routine
            will allocate and initialize new memory.

        vDSP_Length Length

            Length is the number of real elements to be transformed.

        vDSP_DCT_Type Type

            Type specifies which DCT variant to perform.  At present, the
            supported DCT types are II and III (which are mutual inverses, up
            to scaling) and IV (which is its own inverse).  These are specified
            with symbol names vDSP_DCT_II, vDSP_DCT_III, and vDSP_DCT_IV.

    Return value:

        Zero is returned if memory is unavailable or if there is no
        implementation for the requested case.  Currently, the implemented
        cases are:

            Length = f * 2**n, where f is 1, 3, 5, or 15 and 4 <= n.

    Function:

        When vDSP_DCT_Execute is called with a setup returned from this
        routine, it calculates:

            If Type is vDSP_DCT_II:

                For 0 <= k < N,

                    Or[k] = sum(Ir[j] * cos(k * (j+1/2) * pi / N, 0 <= j < N).

            If Type is vDSP_DCT_III

                For 0 <= k < N,

                    Or[k] = Ir[0]/2
                        + sum(Ir[j] * cos((k+1/2) * j * pi / N), 1 <= j < N).

            If Type is vDSP_DCT_IV:

                For 0 <= k < N,

                    Or[k] = sum(Ir[j] * cos((k+1/2) * (j+1/2) * pi / N, 0 <= j <
   N).

            Where:

                N is the length given in the setup,

                h is the array of real numbers passed to vDSP_DCT_Execute in
                Input, and

                H is the array of real numbers stored by vDSP_DCT_Execute in
                the array passed to it in Output.

     Performance:

        Performance is good when the array addresses (passed to
        vDSP_DFT_Execute) are 16-byte aligned.  Other alignments are supported,
        but performance may be significantly worse in some cases, depending on
        the processor model or the transform length (because different
        algorithms are used for different forms of transform length).

    In-Place Operation:

        Output may equal Input (in the call the vDSP_DCT_Execute).  Otherwise,
        no overlap is permitted between the two buffers.

    The returned setup object may be used only with vDSP_DCT_Execute for the
    length given during setup.

    Do not call this routine while any DFT or DCT routine sharing setup data
    might be executing.
*/
typedef vDSP_ENUM(int, vDSP_DCT_Type){vDSP_DCT_II = 2, vDSP_DCT_III = 3,
                                      vDSP_DCT_IV = 4};

__nullable vDSP_DFT_Setup
vDSP_DCT_CreateSetup(__nullable vDSP_DFT_Setup __Previous, vDSP_Length __Length,
                     vDSP_DCT_Type __Type) API_AVAILABLE(macos(10.9), ios(6.0));

/*  vDSP_DCT_Execute is a DCT execution routine.  It performs a DCT, with the
    aid of previously created setup data.  See additional information above, at
    "How to use the Discrete Fourier Transform (DFT) and Discrete Cosine
    Transform (DCT) interfaces."

    Parameters:

        vDSP_DFT_Setup Setup

            A setup object returned by a previous call to vDSP_DCT_CreateSetup.

        const float *Input

            Pointer to the input buffer.

        float *Output

            Pointer to the output buffer.

        Observe there are no separate length or type parameters.  They are
        specified at the time that the Setup is created.

        Because the DCT is real-to-real, the parameters for vDSP_DCT_Execute
        are different from those used for a DFT.
*/
void vDSP_DCT_Execute(const struct vDSP_DFT_SetupStruct *__Setup,
                      const float *__Input, float *__Output)
    API_AVAILABLE(macos(10.9), ios(6.0));

/*  vDSP_DFT_Interleaved_CreateSetup is a DFT setup routine.  It creates a setup
   object for use with the vDSP_DFT_Interleaved_Execute execution routine, to
   perform a complex-to-complex DFT for interleaved data format.

    Parameters:

        vDSP_DFT_Interleaved_Setup Previous

            Previous is either zero or a previous DFT or DCT setup.  If a
            previous setup is passed, the new setup will share data with the
            previous setup, if feasible (and with any other setups the previous
            setup shares with).  If zero is passed, the routine will allocate
            and initialize new memory.

        vDSP_Length Length

            Length is the number of complex elements to be transformed.

        vDSP_DFT_Direction Direction

            Transform direction, vDSP_DFT_FORWARD or vDSP_DFT_INVERSE.

        vDSP_DFT_RealtoComplex RealtoComplex specifies transform used as
   vDSP_DFT_Interleaved_ComplextoComplex or vDSP_DFT_Interleaved_RealtoComplex.

            bool flag indicates whether the Setup is used for ComplextoComplex
   or RealtoComplex transform

    Note:

        For real-to-complex DFT, Length should be half of the length of the real
   signal.

    Return value:

        Zero is returned if memory is unavailable or if there is no
        implementation for the requested case.  Currently, the implemented
        cases are:

            Length = f * 2**n, where f is 2, 3, 5, 3*3, 3*5, or 5*5 and n >= 2.

        Additionally, it is recommended that the array addresses (passed to
        vDSP_DFT_Interleaved_Execute) be 16-byte aligned.  For other cases,
   performance may be slightly or greatly worse, depending on transform length
   and processor model.

    Function:

        When vDSP_DFT_Interleaved_Execute is called with a setup returned from
   this routine, it calculates:

            For 0 <= k < N,

                H[k] = sum(1**(S * j*k/N) * h[j], 0 <= j < N),

        where:

            N is the length given in the setup;

            h is the array of complex numbers specified by a complex array Iri
   when vDSP_DFT_Interleaved_Execute is called:

                for 0 <= j < N,
                    h[j] = Iri[2*j] + i * Iri[2*j+1];

            H is the array of complex numbers specified by a complex array Ori
   when vDSP_DFT_Interleaved_Execute returns:

                for 0 <= k < N,
                    H[k] = Ori[2*k] + i * Ori[2*k+1];

            S is -1 if Direction is vDSP_DFT_FORWARD and +1 if Direction is
            vDSP_DFT_INVERSE; and

            1**x is e**(2*pi*i*x).

    Performance:

        Performance is good when the array addresses (passed to
        vDSP_DFT_Interleaved_Execute) are 16-byte aligned.  Other alignments are
   supported, but performance may be significantly worse in some cases,
   depending on the processor model or the transform length (because different
        algorithms are used for different forms of transform length).

    In-Place Operation:

        Ori may equal Iri (in the call to vDSP_DFT_Interleaved_Execute).
        Otherwise, no overlap of Ori and Iri is supported.

    The returned setup object may be used only with vDSP_DFT_Interleaved_Execute
   for the length given during setup.  Unlike previous vDSP FFT routines, the
   setup may not be used to execute transforms with shorter lengths.

    Do not call this routine while any DFT or DCT routine sharing setup data
    might be executing.
*/

/*! @abstract DFT setup routine for interleaved complex data, single-precision
 *
 *  @discussion
 *  This routine creates the required butterfly weight factors needed in the
 * computation of the interleaved complex number DFT of a specified length. It
 * returns with the pointer to the DFT setup, if the length is supported, or
 * NULL otherwise.
 *
 *  @param Previous (input) Previous is either zero or a previous
 * DFT_Interleaved setup
 *
 *  @param Length (input) the number of complex elements to be transformed.
 *
 *  @param Direction (input) Transform direction, vDSP_DFT_FORWARD or
 * vDSP_DFT_INVERSE.
 *
 *  @param RealtoComplex (input) flag for real to complex transform, true or
 * false.
 *
 *  @return a pointer to the requested DFT setup on success, or 0 if the Length
 * is not supported, or having other issues, such as memory allocation.
 *
 */
__nullable vDSP_DFT_Interleaved_Setup vDSP_DFT_Interleaved_CreateSetup(
    __nullable vDSP_DFT_Interleaved_Setup Previous, vDSP_Length Length,
    vDSP_DFT_Direction Direction, vDSP_DFT_RealtoComplex RealtoComplex)
    API_AVAILABLE(macos(12.0), ios(15.0), watchos(8.0), tvos(15.0));

/*! @abstract DFT setup routine for interleaved complex data, double-precision
 *
 *  @discussion
 *  This routine creates the required butterfly weight factors needed in the
 * computation of the interleaved complex number DFT of a specified length. It
 * returns with the pointer to the DFT setup, if the length is supported, or
 * NULL otherwise.
 *
 *  @param Previous (input) Previous is either zero or a previous
 * DFT_Interleaved setup
 *
 *  @param Length (input) the number of complex elements to be transformed.
 *
 *  @param Direction (input) Transform direction, vDSP_DFT_FORWARD or
 * vDSP_DFT_INVERSE.
 *
 *  @param RealtoComplex (input) flag for real to complex transform, true or
 * false.
 *
 *  @return a pointer to the requested DFT setup on success, or 0 if the Length
 * is not supported, or having other issues, such as memory allocation.
 *
 */
__nullable vDSP_DFT_Interleaved_SetupD vDSP_DFT_Interleaved_CreateSetupD(
    __nullable vDSP_DFT_Interleaved_SetupD Previous, vDSP_Length Length,
    vDSP_DFT_Direction Direction, vDSP_DFT_RealtoComplex RealtoComplex)
    API_AVAILABLE(macos(12.0), ios(15.0), watchos(8.0), tvos(15.0));

/*  vDSP_DFT_Execute_Interleaved and vDSP_DFT_Interleaved_ExecuteD are DFT
   execution routines (interleaved data format). They perform a DFT, with the
   aid of previously created setup data. Documentation below is written for
   vDSP_DFT_Interleaved_Execute. vDSP_DFT_Interleaved_ExecuteD behaves the same
   way, with corresponding changes of the types, objects, and routines to the
   double-precision versions.

    Parameters:

        vDSP_DFT_Interleaved_Setup Setup

            A setup object returned by a previous call to
   vDSP_DFT_Interleaved_CreateSetup

        const DSPComplex *Iri

            Pointer to input data.

        DSPComplex *Ori

            Pointer to output data.

            The input and output arrays may not overlap except as specified
            in "In-Place Operation", below.

    Performance and In-Place Operation:

        See notes for the setup routine for the operation being executed.

    Function:

        The function performed by this routine is determined by the setup
        passed to it.  The documentation for the routine used to create the
        setup describes the function.

        Note that different numbers of elements are required when this routine
        is called, depending on the setup used:

            When the setup is from vDSP_DFT_Interleaved_CreateSetup, each array
   (Iri and Ori) must have Length elements.

    Do not call this routine while any DFT setup or destroy routine sharing
    setup data might be executing.
*/

/*! @abstract DFT execution routine for real data, single-precision
 *
 *  @discussion
 *  This routine perform a DFT for real numbers, with the aid of previously
 * created setup data.
 *
 *  @param Setup (input) A setup object returned by a previous call to
 * vDSP_DFT_Interleaved_CreateSetup
 *
 *  @param Iri (input) Pointer to input data.
 *
 *  @param Ori (input) Pointer to output data.
 *
 */
void vDSP_DFT_Interleaved_Execute(const vDSP_DFT_Interleaved_Setup Setup,
                                  const DSPComplex *Iri, DSPComplex *Ori)
    API_AVAILABLE(macos(12.0), ios(15.0), watchos(8.0), tvos(15.0));

/*! @abstract DFT execution routine for interleaved complex data,
 * double-precision
 *
 *  @discussion
 *  This routine perform a DFT for interleaved complex numbers, with the aid of
 * previously created setup data.
 *
 *  @param Setup (input) A setup object returned by a previous call to
 * vDSP_DFT_Interleaved_CreateSetupD
 *
 *  @param Iri (input) Pointer to input data.
 *
 *  @param Ori (input) Pointer to output data.
 *
 */
void vDSP_DFT_Interleaved_ExecuteD(const vDSP_DFT_Interleaved_SetupD Setup,
                                   const DSPDoubleComplex *Iri,
                                   DSPDoubleComplex *Ori)
    API_AVAILABLE(macos(12.0), ios(15.0), watchos(8.0), tvos(15.0));

/*! @abstract DFT destroy routine, single-precision
 *
 *  @discussion
 *  This routine releases the memory used by a setup object.
 *
 *  @param Setup (input) A setup object vDSP_DFT_Interleaved_Setup,
 *    created by either vDSP_DFT_Interleaved_CreateSetup
 *
 */
void vDSP_DFT_Interleaved_DestroySetup(
    __nullable vDSP_DFT_Interleaved_Setup Setup)
    API_AVAILABLE(macos(12.0), ios(15.0), watchos(8.0), tvos(15.0));

/*! @abstract DFT destroy routine, double-precision
 *
 *  @discussion
 *  This routine releases the memory used by a setup object.
 *
 *  @param Setup (input) A setup object vDSP_DFT_Interleaved_SetupD,
 *    created by either vDSP_DFT_Interleaved_CreateSetupD
 *
 */
void vDSP_DFT_Interleaved_DestroySetupD(
    __nullable vDSP_DFT_Interleaved_SetupD Setup)
    API_AVAILABLE(macos(12.0), ios(15.0), watchos(8.0), tvos(15.0));
