! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
! .                                                                       .
! .                            S T A P 9 0                                .
! .                                                                       .
! .     AN IN-CORE SOLUTION STATIC ANALYSIS PROGRAM IN FORTRAN 90         .
! .     Adapted from STAP (KJ Bath, FORTRAN IV) for teaching purpose      .
! .                                                                       .
! .     Xiong Zhang, (2013)                                               .
! .     Computational Dynamics Group, School of Aerospace                 .
! .     Tsinghua Univerity                                                .
! .                                                                       .
! . . . . . . . . . . . . . .  . . .  . . . . . . . . . . . . . . . . . . .

SUBROUTINE INPUT (ID,X,Y,Z,NUMNP,NEQ)
! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
! .                                                                       .
! .   To read, generate, and print nodal point input data                 .
! .   To calculate equation numbers and store them in id arrray           .
! .                                                                       .
! .      N = Element number                                               .
! .      ID = Boundary condition codes (0=free,1=deleted)                 .
! .      X,Y,Z = Coordinates                                              .
! .      KN = Generation code                                             .
! .           i.e. increment on nodal point number                        .
! .                                                                       .
! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

  USE GLOBALS, ONLY : IIN, IOUT, DIM, bandwidthopt, pardisodoor
  ! For bandwith optimization and pardiso
  USE NODE_CLASS
  USE LIST_CLASS
  IMPLICIT NONE
  INTEGER :: NUMNP,NEQ,ID(DIM,NUMNP)
  REAL(8) :: X(NUMNP),Y(NUMNP),Z(NUMNP)
  INTEGER :: I, N !, J
  
  ! Read nodal point data

  N = 0
  DO WHILE (N.NE.NUMNP)
     READ (IIN,"(I10,6I10,3F10.0,I5)") N,(ID(I,N),I=1,6),X(N),Y(N),Z(N)
  END DO

! Write complete nodal data

  WRITE (IOUT,"(//,' N O D A L   P O I N T   D A T A',/)")

  WRITE (IOUT,"('  NODE',10X,'BOUNDARY',25X,'NODAL POINT',/,  &
                ' NUMBER     CONDITION  CODES',21X,'COORDINATES', /,15X, &
                'X    Y    Z   RX   RY   RZ',15X,'X',12X,'Y',12X,'Z')")

  DO N=1,NUMNP
     WRITE (IOUT,"(I10,6X,6I10,1X,3F13.3)") N,(ID(I,N),I=1,6),X(N),Y(N),Z(N)
  END DO

! Number unknowns
  NEQ=0
  DO N=1,NUMNP
     DO I=1,6
        IF (ID(I,N) .EQ. 0) THEN
           NEQ=NEQ + 1
           ID(I,N)=NEQ
        ELSE
           ID(I,N)=0
        END IF
     END DO
  END DO

! Write equation numbers
  WRITE (IOUT,"(//,' EQUATION NUMBERS',//,'   NODE',9X,  &
                   'DEGREES OF FREEDOM',/,'  NUMBER',/,  &
                   '     N',13X,'X    Y    Z   RX   RY   RZ',/,(1X,I10,9X,6I10))") (N,(ID(I,N),I=1,6),N=1,NUMNP)

! Add bandwidth optimization and pardiso
! *******Adding those two function need extra input
IF( BANDWIDTHOPT) THEN
    CALL bdopt(ID)
END IF

  RETURN
END SUBROUTINE INPUT


SUBROUTINE LOADS (R,NOD,IDIRN,FLOAD,ID,NLOAD,NEQ)
! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
! .                                                                   .
! .   To read nodal load data                                         .
! .   To calculate the load vector r for each load case and           .
! .   write onto unit ILOAD                                           .
! .                                                                   .
! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
  USE GLOBALS, ONLY : IIN, IOUT, ILOAD, MODEX, DIM, NUMNP

  IMPLICIT NONE
  INTEGER :: NLOAD,NEQ,ID(DIM,*),NOD(NLOAD),IDIRN(NLOAD)
  REAL(8) :: R(NEQ),FLOAD(NLOAD)
  INTEGER :: I,L,LI,LN,II

  WRITE (IOUT,"(/,'    NODE       DIRECTION      LOAD',/, '   NUMBER',19X,'MAGNITUDE')")

  READ (IIN,"(I10,I10,F10.0)") (NOD(I),IDIRN(I),FLOAD(I),I=1,NLOAD)

  WRITE (IOUT,"(' ',I10,9X,I10,7X,E12.5)") (NOD(I),IDIRN(I),FLOAD(I),I=1,NLOAD)

  IF (MODEX.EQ.0) RETURN

  !DO I=1,NEQ
     R(:)=0.
  !END DO

  DO L=1,NLOAD
     LN=NOD(L)
     LI=IDIRN(L)
     II=ID(LI,LN)
     IF (II > 0) R(II)=R(II) + FLOAD(L)
  END DO

  WRITE (ILOAD) R

  RETURN
  
END SUBROUTINE LOADS


SUBROUTINE LOADV (R,NEQ)
! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
! .                                                                   .
! .   To obtain the load vector                                       .
! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
!
  USE GLOBALS, ONLY : ILOAD

  IMPLICIT NONE
  INTEGER :: NEQ
  REAL(8) :: R(NEQ)

  READ (ILOAD) R
  
  RETURN
END SUBROUTINE LOADV
