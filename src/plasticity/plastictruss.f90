SUBROUTINE PLASTICTRUSS
! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
! .                                                                   .
! .   To set up storage and call the truss element subroutine
!.    LIU CHANGWU
! .                                                                   .
! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

  USE GLOBALS
  USE MEMALLOCATE

  IMPLICIT NONE
  INTEGER :: NUME, NUMMAT, MM, N(10)

  NUME = NPAR(2)
  NUMMAT = NPAR(3)
  NPAR(5) = 2

! Calculate the pointer to the arrays in the element group data
! N1: E(NUMMAT)
! N2: AREA(NUMMAT)
! N3: YIELD STRESS (NUMMAT)
! N4: PLASTIC MODULES K (NUMMAT)
! N5: HISTORY OF THE ELEMENT //ELASTIC OR PLASTIC// (NUME)
! N6: LM(6,NUME)
! N7: XYZ(6,NUME)
! N8: MTAP(NUME) 
  N(1)=0
  N(2)=N(1)+NUMMAT*ITWO
  N(3)=N(2)+NUMMAT*ITWO
  N(4)=N(3)+NUMMAT*ITWO
  N(5)=N(4)+NUMMAT*ITWO
  N(6)=N(5)+NUME
  N(7)=N(6)+6*NUME
  N(8)=N(7)+6*NUME*ITWO
  N(9)=N(8)+NUME
  N(10)=N(9)+NPAR(2)*NPAR(5)
  
  MIDEST=N(10)
  if (IND .EQ. 1) then
        ! Allocate storage for element group data
        call MemAlloc(11,"ELEGP",MIDEST,1)
  end if
  NFIRST = NP(11)   ! Pointer to the first entry in the element group data array in the unit of single precision (corresponding to A)
  N(:) = N(:) + NFIRST
  NLAST=N(10)

  CALL PLASTICRUSS (IA(NP(1)),DA(NP(2)),DA(NP(3)),DA(NP(4)),DA(NP(4)),IA(NP(5)),   &
        A(N(1)),A(N(2)),A(N(3)),A(N(4)),A(N(5)),A(N(6)),A(N(7)),A(N(8)),A(N(9)),A(N(10)))

  RETURN

END SUBROUTINE PLASTICTRUSS
    
SUBROUTINE PLASTICRUSS (ID,X,Y,Z,U,MHT,E,AREA,YIELDSTRESS,PLASTICK,HISTORY,LM,XYZ,MATP,NODE)
! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
! .                                                                   .
! .   TRUSS element subroutine                                        .
! .                                                                   .
! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

  USE GLOBALS
  USE MEMALLOCATE

  IMPLICIT NONE
  INTEGER :: ID(6,NUMNP),LM(6,NPAR(2)),MATP(NPAR(2)),MHT(NEQ),HISTORY(NPAR(2))
  REAL(8) :: X(NUMNP),Y(NUMNP),Z(NUMNP),E(NPAR(3)),AREA(NPAR(3)),  &
             XYZ(6,NPAR(2)),U(NEQ),YIELDSTRESS(NPAR(3)),PLASTICK(NPAR(3))
  REAL(8) :: S(6,6),ST(6),D(3)! StressCollection(6,NPAR(2)), GaussianCollection(3,NPAR(2))

  INTEGER :: NPAR1, NUME, NUMMAT, ND, I, J, L, N, Node(NPAR(2),NPAR(5))
  INTEGER :: MTYPE, IPRINT
  REAL(8) :: XL2, XL, SQRT, XX, YY, STR, P

  NPAR1  = NPAR(1)
  NUME   = NPAR(2)
  NUMMAT = NPAR(3) 

  ND=6

! Read and generate element information
  IF (IND .EQ. 1) THEN

     WRITE (IOUT,"(' E L E M E N T   D E F I N I T I O N',//,  &
                   ' ELEMENT TYPE ',13(' .'),'( NPAR(1) ) . . =',I5,/,   &
                   '     EQ.1, TRUSS ELEMENTS',/,      &
                   '     EQ.2, ELEMENTS CURRENTLY',/,  &
                   '     EQ.3, NOT AVAILABLE',//,      &
                   ' NUMBER OF ELEMENTS.',10(' .'),'( NPAR(2) ) . . =',I5,/)") NPAR1,NUME

     IF (NUMMAT.EQ.0) NUMMAT=1

     WRITE (IOUT,"(' M A T E R I A L   D E F I N I T I O N',//,  &
                   ' NUMBER OF DIFFERENT SETS OF MATERIAL',/,  &
                   ' AND CROSS-SECTIONAL  CONSTANTS ',         &
                   4 (' .'),'( NPAR(3) ) . . =',I5,/)") NUMMAT

     WRITE (IOUT,"('  SET       YOUNG''S     CROSS-SECTIONAL',/,  &
                   ' NUMBER     MODULUS',10X,'AREA',/,  &
                   15 X,'E',14X,'A')")

     DO I=1,NUMMAT
        READ (IIN,'(I5,2F10.0)') N,E(N),AREA(N)  ! Read material information
        WRITE (IOUT,"(I5,4X,E12.5,2X,E14.6)") N,E(N),AREA(N)
     END DO

     WRITE (IOUT,"(//,' E L E M E N T   I N F O R M A T I O N',//,  &
                      ' ELEMENT     NODE     NODE       MATERIAL',/,   &
                      ' NUMBER-N      I        J       SET NUMBER')")

     N=0
     DO WHILE (N .NE. NUME)
        READ (IIN,'(5I5)') N,Node(N,1:2),MTYPE  ! Read in element information

!       Save element information
        XYZ(1:NPAR(5)*3-1:3,N)=X(Node(N,:))  ! Coordinates of the element's nodes
        XYZ(2:NPAR(5)*3  :3,N)=Y(Node(N,:))
        XYZ(3:NPAR(5)*3+1:3,N)=Z(Node(N,:))
        MATP(N)=MTYPE  ! Material type

        DO L=1,6
           LM(L,N)=0
        END DO

        DO L=1,3
           LM(L,N)=ID(L,Node(N,1))     ! Connectivity matrix
           LM(L+3,N)=ID(L,Node(N,2))
        END DO

!       Update column heights and bandwidth
        if (.NOT. PARDISODOOR) CALL COLHT (MHT,ND,LM(1,N))   

        WRITE (IOUT,"(I5,6X,I5,4X,I5,7X,I5)") N,Node(N,1:2),MTYPE
!        write (VTKNodeTmp) NPAR(5), Node(N,:)-1

     END DO

     RETURN

! Assemble stucture stiffness matrix
  ELSE IF (IND .EQ. 2) THEN

     DO N=1,NUME
        MTYPE=MATP(N)

        XL2=0.
        DO L=1,3
           D(L)=XYZ(L,N) - XYZ(L+3,N)
           XL2=XL2 + D(L)*D(L)
        END DO
        XL=SQRT(XL2)   ! Length of element N

        XX=E(MTYPE)*AREA(MTYPE)*XL   !  E*A*l

        DO L=1,3
           ST(L)=D(L)/XL2
           ST(L+3)=-ST(L)
        END DO

        DO J=1,ND
           YY=ST(J)*XX
           DO I=1,J
              S(I,J)=ST(I)*YY
           END DO
        END DO

!        if(pardisodoor) then
!            call pardiso_addban(DA(NP(3)),IA(NP(2)),IA(NP(5)),S,LM(1,N),ND)
!        else
            CALL ADDBAN (DA(NP(3)),IA(NP(2)),S,LM(1,N),ND)
!        end if

     END DO

     RETURN

! Stress calculations
  ELSE IF (IND .EQ. 3) THEN

     IPRINT=0
     DO N=1,NUME
        IPRINT=IPRINT + 1
        IF (IPRINT.GT.50) IPRINT=1
        IF (IPRINT.EQ.1) WRITE (IOUT,"(//,' S T R E S S  C A L C U L A T I O N S  F O R  ',  &
                                           'E L E M E N T  G R O U P',I4,//,   &
                                           '  ELEMENT',13X,'FORCE',12X,'STRESS',/,'  NUMBER')") NG
        MTYPE=MATP(N)

        XL2=0.
        DO L=1,3
           D(L) = XYZ(L,N) - XYZ(L+3,N)
           XL2=XL2 + D(L)*D(L)
        END DO

        DO L=1,3
           ST(L)=(D(L)/XL2)*E(MTYPE)
           ST(L+3)=-ST(L)
        END DO

        STR=0.0
        DO L=1,3
           I=LM(L,N)
           IF (I.GT.0) STR=STR + ST(L)*U(I)

           J=LM(L+3,N)
           IF (J.GT.0) STR=STR + ST(L+3)*U(J)
        END DO

        P=STR*AREA(MTYPE)

        WRITE (IOUT,"(1X,I5,11X,E13.6,4X,E13.6)") N,P,STR
!        GaussianCollection(:,N) = 0.5*(XYZ(4:6,N)+XYZ(1:3,N))
!        StressCollection(1,N) = STR
     END DO
!>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>WORKING PROGRESS
!     StressCollection(2,:) = 0D0
!     call PostProcessor(NPAR(1), 1, XYZ, &
!                       Node, 1, GaussianCollection, StressCollection, U)
!>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>AT POINT 513 & 1370 WHERE TRUSSES MERGE, DO NOT USE LEAST SQUARE!
!>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>WOULD BE BETTER IF USE DIM==1.
  ELSE 
     STOP "*** ERROR *** Invalid IND value."
  END IF

END SUBROUTINE PLASTICRUSS