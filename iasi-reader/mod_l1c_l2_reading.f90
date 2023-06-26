!
! IASI L1c and L2 reader module

module mod_l1c_l2_reading

   use mod_calendar

   implicit none

!!$   ! kind sizes for Integer variables 
!!$   integer, parameter :: JPI1 = selected_int_kind(2)
!!$   integer, parameter :: JPI2 = selected_int_kind(4)
!!$   integer, parameter :: JPI4 = selected_int_kind(9)
!!$   integer, parameter :: JPI8 = selected_int_kind(12)
!!$   ! kind sizes for real variables 
!!$   integer, parameter :: JPR1 = selected_real_kind(2,1)
!!$   integer, parameter :: JPR2 = selected_real_kind(4,2)
!!$   integer, parameter :: JPR4 = selected_real_kind(6,37)
!!$   integer, parameter :: JPR8 = selected_real_kind(13,300)

   integer(kind=4), parameter :: AMCO    =    100
   integer(kind=4), parameter :: AMLI    =    100
   integer(kind=4), parameter :: CCD     =      2
   integer(kind=4), parameter :: IMCO    =     64
   integer(kind=4), parameter :: IMLI    =     64
   integer(kind=4), parameter :: MAXBA   =   3600
   integer(kind=4), parameter :: NVP     = 221000
   integer(kind=4), parameter :: NIFVP   = 55000
   integer(kind=4), parameter :: NBK     =      6
   integer(kind=4), parameter :: NCL     =      7
   integer(kind=4), parameter :: NIM     =     28
   integer(kind=4), parameter :: PN      =      4
   integer(kind=4), parameter :: SB      =      3
   integer(kind=4), parameter :: SGI     =     25
   integer(kind=4), parameter :: SNOT    =     30
   integer(kind=4), parameter :: SNOTp4  =     34
   integer(kind=4), parameter :: SS      =   8700
   integer(kind=4), parameter :: VP      =      1
   integer(kind=4), parameter :: NLT     =    101
   integer(kind=4), parameter :: NLQ     =    101
   integer(kind=4), parameter :: NLO     =    101
   integer(kind=4), parameter :: NEW     =     12
   integer(kind=4), parameter :: NL_CO   =     19
   integer(kind=4), parameter :: NL_HNO3 =     19
   integer(kind=4), parameter :: NL_O3   =     40
   integer(kind=4), parameter :: NL_SO2  =      5
   integer(kind=4), parameter :: NE      =   2048
   integer(kind=4), parameter :: NP      =    103
   integer(kind=4), parameter :: NSVERIF =   4320
   integer(kind=4), parameter :: HUIT    =      8
   integer(kind=4), parameter :: DIX     =     10
   
   integer(kind=4), parameter :: MAX_RECORDS = 50000 ! Max records per file
   integer(kind=4), parameter :: nbrIasi     = 8461
   
   real(kind=8), parameter  :: CST_H    = 6.6260755D-34         ! Planck constant (J.s)
   real(kind=8), parameter  :: CST_C    = 2.99792458D+8         ! Light speed constant (m/s)
   real(kind=8), parameter  :: CST_K    = 1.380658D-23          ! Boltzmann constant (J/K)
   real(kind=8), parameter  :: CST_2HC2 = CST_H*CST_C*CST_C*2D0 ! c1: 2.h.c**2 (W.m^2/sr)
   real(kind=8), parameter  :: CST_HCK  = CST_H*CST_C/CST_K     ! c2: h.c/k (m.K)
   real(kind=8), parameter  :: RADEARTH = 6372.8                ! Earth radius (km)
   real(kind=8), parameter  :: G0       = 9.80665               ! Gravity constant (m/s2)
   real(kind=8), parameter  :: T0       = 273.15                ! Water freezing point (K)
   real(kind=8), parameter  :: Pi       = 3.14159265358979323846

   real(kind=8), parameter :: GDAY_IASI_EPOCHTIME = 2451544.5D0

   ! Derived types
   type VINTEGER4
      integer(kind=1) :: sf
      integer(kind=4) :: value
   end type

   type BITS8
      byte :: PART8
   end type BITS8

   type BITS16
      byte :: PART116
      byte :: PART216
   end type BITS16

   type BITS32
      byte :: PART132
      byte :: PART232
      byte :: PART332
      byte :: PART432
   end type BITS32

   type SHORT_CDS_TIME
      integer(kind=2) :: day
      integer(kind=4) :: msec
   end type SHORT_CDS_TIME

   type RECORD_HEADER
      integer(kind=1) :: RECORD_CLASS
      integer(kind=1) :: INSTRUMENT_GROUP
      integer(kind=1) :: RECORD_SUBCLASS
      integer(kind=1) :: RECORD_SUBCLASS_VERSION
      integer(kind=4) :: RECORD_SIZE
      type(SHORT_CDS_TIME) :: RECORD_START_TIME
      type(SHORT_CDS_TIME) :: RECORD_END_TIME
   end type RECORD_HEADER

   type RECORD_ID
      integer(kind=1) :: cl      ! Class
      integer(kind=1) :: scl     ! Subclass
      integer(kind=8) :: pos     ! Position
   end type

   type RECORD_GIADR_SCALE_FACTORS
      integer(kind=2) :: IDefScaleSondNbScale
      integer(kind=2) :: IDefScaleSondNsFirst(10)
      integer(kind=2) :: IDefScaleSondNsLast(10)
      integer(kind=2) :: IDefScaleSondScaleFactor(10)
      integer(kind=2) :: IDefScaleIISScaleFactor
   end type
   
   type RECORD_GIADR_QUALITY
      integer(kind=4)     :: IDefPsfSondNbLin(PN)
      integer(kind=4)     :: IDefPsfSondNbCol(PN)
      real(kind=4)        :: IDefPsfSondOverSampFactor
      real(kind=4)        :: IDefPsfSondY(100,PN)
      real(kind=4)        :: IDefPsfSondZ(100,PN)
      real(kind=4)        :: IDefPsfSondWgt(100,100,PN)
      integer(kind=4)     :: IDefllSSrfNsfirst
      integer(kind=4)     :: IDefllSSrfNslast
      real(kind=4)        :: IDefllSSrf(100)
      real(kind=4)        :: IDefllSSrfDWn
      real(kind=4)        :: IDefIISNeDT(IMCO, IMLI)
      logical             :: IDefDptIISDeadPix(IMCO, IMLI)
   end type RECORD_GIADR_QUALITY
   
   type RECORD_GIADR_ENGINEERING
      type(RECORD_HEADER)                :: grh
      type(SHORT_CDS_TIME)               :: cds_date ! days since 2001-01-01
      integer(kind=4) ,dimension(3)      :: GEPSUtcLeapSecond
      integer(kind=4)                    :: GEPSCcuObtCorrel
      integer(kind=4) ,dimension(3)      :: GEPSUtcCorrel
      real(kind=8)                       :: GEPSAStepCorrel
      real(kind=8)                       :: GEPSBStepCorrel
   end type RECORD_GIADR_ENGINEERING

   
   type RECORD_VIADR_ENGINEERING
      integer(kind=4)                        :: line
      type(RECORD_HEADER)                    :: grh
      integer(kind=1)  ,dimension(555)       :: MExsSmin
      integer(kind=1)  ,dimension(555)       :: MExsSmax
      integer(kind=1)  ,dimension(IMCO,IMLI) :: MDptIISBadHealthPix
      integer(kind=1)  ,dimension(IMCO,IMLI) :: MDptIISinHomPix
   end type RECORD_VIADR_ENGINEERING

   type DATA_PX
      integer(kind=4)  ,dimension(PN,SNOT)  :: Day    ! Word 4
      integer(kind=4)  ,dimension(PN,SNOT)  :: ms     ! Word 5-6
      integer(kind=4)  ,dimension(PN,SNOT)  :: NS_Rpd ! Word 11
      integer(kind=4)  ,dimension(PN,SNOT)  :: SN     ! Word 12 B0-B7
      integer(kind=4)  ,dimension(PN,SNOT)  :: SP     ! Word 12 B8-B15
      integer(kind=4)  ,dimension(PN,SNOT)  :: CD     ! Word 13 B0
      integer(kind=4)  ,dimension(PN,SNOT)  :: CSQ    ! Word 13 B1
      integer(kind=4)  ,dimension(PN,SNOT)  :: SQ1    ! Word 13 B2
      integer(kind=4)  ,dimension(PN,SNOT)  :: SQ2    ! Word 13 B3
      integer(kind=4)  ,dimension(PN,SNOT)  :: IEQ    ! Word 13 B4
      integer(kind=4)  ,dimension(PN,SNOT)  :: SN_NV  ! Word 13 B8
      integer(kind=4)  ,dimension(PN,SNOT)  :: CD_NV  ! Word 13 B9
      integer(kind=4)  ,dimension(PN,SNOT)  :: CSQ_NV ! Word 13 B10
      integer(kind=4)  ,dimension(PN,SNOT)  :: SP_NV  ! Word 13 B11
      integer(kind=4)  ,dimension(PN,SNOT)  :: SQ1_NV ! Word 13 B12
      integer(kind=4)  ,dimension(PN,SNOT)  :: SQ2_NV ! Word 13 B13
      integer(kind=4)  ,dimension(PN,SNOT)  :: NS_NV  ! Word 13 B14
      integer(kind=4)  ,dimension(PN,SNOT)  :: IEQ_NV ! Word 13 B15
      integer(kind=4)  ,dimension(PN,SNOT)  :: Chain    ! Word 14 B3
      integer(kind=4)  ,dimension(PN,SNOT)  :: MAS_HAU1 ! Word 14 B8
      integer(kind=4)  ,dimension(PN,SNOT)  :: MAS_HAU2 ! Word 14 B9
      integer(kind=4)  ,dimension(PN,SNOT)  :: MAS_HAU3 ! Word 14 B10
      integer(kind=4)  ,dimension(PN,SNOT)  :: MAS_HAU4 ! Word 14 B11
      integer(kind=4)  ,dimension(PN,SNOT)  :: LAZER    ! Word 14 B15
      integer(kind=4)  ,dimension(PN,SNOT)  :: RC       ! Word 15 B0
      integer(kind=4)  ,dimension(PN,SNOT)  :: LNR      ! Word 15 B1
      integer(kind=4)  ,dimension(PN,SNOT)  :: ASE      ! Word 15 B2
      integer(kind=4)  ,dimension(PN,SNOT)  :: LBR      ! Word 15 B3
      integer(kind=4)  ,dimension(PN,SNOT)  :: PIX1     ! Word 15 B4-B6
      integer(kind=4)  ,dimension(PN,SNOT)  :: PIX2     ! Word 15 B7-B9
      integer(kind=4)  ,dimension(PN,SNOT)  :: PIX3     ! Word 15 B10-B12
      integer(kind=4)  ,dimension(PN,SNOT)  :: PIX4     ! Word 15 B13_B15
      integer(kind=4)  ,dimension(PN,SNOT)  :: PTSIMSW  ! Word 16
      integer(kind=4)  ,dimension(PN,SNOT)  :: PTSILSW  ! Word 17
      integer(kind=4)  ,dimension(PN,SNOT)  :: LN       ! Word 18
      integer(kind=4)  ,dimension(PN,SNOT)  :: INS_STA  ! Word 19 B8
      integer(kind=4)  ,dimension(PN,SNOT)  :: INS_MOD  ! Word 19 B9-B15
      integer(kind=4)  ,dimension(PN,SNOT)  :: SQIS     ! Word 20
      integer(kind=4)  ,dimension(PN,SNOT)  :: PIXEL    ! Word 21
      integer(kind=4)  ,dimension(PN,SNOT)  :: BdcoNbReceivedWords  ! Word 22
      real(kind=4)     ,dimension(SB,PN,SNOT)    :: BNlcAnaMV ! Word 23-28
      integer(kind=4)  ,dimension(PN,SNOT)       :: BZpdNzpd  ! Word 29
      real(kind=4)     ,dimension(PN,SNOT)       :: BzpdNzpdQualIndexEW ! Word 30-31
      real(kind=4)     ,dimension(10,SB,PN,SNOT) :: BArcImagMean    ! Word 32-87
      real(kind=4)     ,dimension(10,SB,PN,SNOT) :: BArcImagRMS     ! Word 88-143
      real(kind=4)     ,dimension(SB,PN,SNOT)    :: BArcImagMeanRMS ! Word 144-149
      integer(kind=4)  ,dimension(PN,SNOT)       :: Flag_DVL                ! Word 150 B0
      integer(kind=4)  ,dimension(PN,SNOT)       :: Flag_VLN                ! Word 150 B1
      integer(kind=4)  ,dimension(PN,SNOT+7)       :: BBofFlagSpectNonQual    ! Word 150 B2
      integer(kind=4)  ,dimension(SB,PN,SNOT)    :: BDcoFlagMasErrorPath    ! Word 150 B3-B5
      integer(kind=4)  ,dimension(SB,PN,SNOT)    :: BDcoFlagMasOverflow     ! Word 150 B6-B8
      integer(kind=4)  ,dimension(SB,PN,SNOT)    :: BDcoFlagMasEcret        ! Word 150 B9-B11
      integer(kind=4)  ,dimension(PN,SNOT)       :: BdcoFlagMasErrorNbWords ! Word 150 B12
      integer(kind=4)  ,dimension(SB,PN,SNOT)    :: BSpkFlagSpik            ! Word 151 B0-B2
      integer(kind=4)   ,dimension(PN,SNOT)      :: BzpdFlagNzpdNonQualEW   ! Word 151 B3
      integer(kind=4)  ,dimension(SB,PN,SNOT)    :: BIsiFlagErrorFft        ! Word 151 B4-B6
      integer(kind=4)  ,dimension(SB,PN,SNOT)    :: BArcFlagCalSpectNonQual ! Word 151 B7-B9
      integer(kind=4)  ,dimension(PN,SNOT)       :: BCodFlagFlood           ! Word 151 B10
      integer(kind=4)  ,dimension(SB,PN,SNOT)    :: BDcoFlagErrorInterf     ! Word 151 B11-B13
   end type DATA_PX

   type DATA_IP
      integer(kind=4)   ,dimension(PN,SNOT)  :: SQII         ! word 20
      integer(kind=4)   ,dimension(PN,SNOT)  :: IIS_SIZE     ! word 21 B0-B7
      integer(kind=4)   ,dimension(PN,SNOT)  :: IIS_ADC_OVFL ! word 21 B8
      integer(kind=4)   ,dimension(PN,SNOT)  :: IIS_NS       ! word 21 B9
      integer(kind=4)   ,dimension(PN,SNOT)  :: IIS_COUNT    ! word 22
   end type DATA_IP

   type DATA_AREA
      ! PN (1 2 3 4) Word 71 131 191 251
      ! SN (32 33 35 36) 71 86 101 116
      integer(kind=4)   ,dimension(PN,4)     :: NS_Rpd ! Word 71
      integer(kind=4)   ,dimension(PN,4)     :: SN     ! Word 72 B0-B7
      integer(kind=4)   ,dimension(PN,4)     :: SP     ! Word 72 B8-B15
      integer(kind=4)   ,dimension(PN,4)     :: CD     ! Word 73 B0
      integer(kind=4)   ,dimension(PN,4)     :: CSQ    ! Word 73 B1
      integer(kind=4)   ,dimension(PN,4)     :: SQ1    ! Word 73 B2
      integer(kind=4)   ,dimension(PN,4)     :: SQ2    ! Word 73 B3
      integer(kind=4)   ,dimension(PN,4)     :: IEQ    ! Word 73 B4
      integer(kind=4)   ,dimension(PN,4)     :: SN_NV  ! Word 73 B8
      integer(kind=4)   ,dimension(PN,4)     :: CD_NV  ! Word 73 B9
      integer(kind=4)   ,dimension(PN,4)     :: CSQ_NV ! Word 73 B10
      integer(kind=4)   ,dimension(PN,4)     :: SP_NV  ! Word 73 B11
      integer(kind=4)   ,dimension(PN,4)     :: SQ1_NV ! Word 73 B12
      integer(kind=4)   ,dimension(PN,4)     :: SQ2_NV ! Word 73 B13
      integer(kind=4)   ,dimension(PN,4)     :: NS_NV  ! Word 73 B14
      integer(kind=4)   ,dimension(PN,4)     :: IEQ_NV ! Word 73 B15
      integer(kind=4)   ,dimension(PN,4)     :: BdcoNbReceivedWords ! Word 74
      real(kind=4)      ,dimension(SB,PN,4)  :: BNlcAnaMV           ! Word 75-80
      integer(kind=4)   ,dimension(PN,4)     :: BZpdNzpd            ! Word 81
      real(kind=4)      ,dimension(PN,4)     :: BzpdNzpdQualIndex   ! Word 82-83
   end type DATA_AREA

   type STATUS_AREA
      ! PN (1 2 3 4) Word 311 331 351 371
      ! SN (32 33 35 36) Word 311 315 319 323
      integer(kind=4)    ,dimension(PN,4)    :: LNR_DVL ! Word 311 BO
      integer(kind=4)    ,dimension(PN,4)    :: LNR_VLN ! Word 311 B1
      integer(kind=4)    ,dimension(PN,4)    :: BBofFlagSpectNonQual    ! Word 311 B2
      integer(kind=4)    ,dimension(SB,PN,4) :: BDcoFlagMasErrorPath    ! Word 311 B3-B5
      integer(kind=4)    ,dimension(SB,PN,4) :: BDcoFlagMasOverflow     ! Word 311 B6-B8
      integer(kind=4)    ,dimension(SB,PN,4) :: BDcoFlagMasEcret        ! Word 311 B9-B11
      integer(kind=4)    ,dimension(PN,4)    :: BDcoFlagMasErrorNbWords ! Word 311 B12
      integer(kind=4)    ,dimension(SB,PN,4) :: BDcoFlagErrorInterf     ! Word 311 B13-B15
      integer(kind=4)    ,dimension(SB,PN,4) :: BNlcFlagIntegrity       ! Word 312 B0-B2
      integer(kind=4)    ,dimension(SB,PN,4) :: BSpkFlagSpik            ! Word 312 B3-B5
      integer(kind=4)    ,dimension(PN,4)    :: BZpdFlagNzpdNonQual     ! Word 312 B6
      integer(kind=4)    ,dimension(PN,4)    :: BIrsFlagSrdNonIntegrity ! Word 312 B7
      integer(kind=4)    ,dimension(SB,PN,4) :: BIsiFlagErrorFft        ! Word 312 B8-B10
   end type STATUS_AREA

   type EXTRA_STATUS_AREA
      ! PN (1 2 3 4) Word 327 347 367 387
      integer(kind=4)    ,dimension(2,PN)    :: BBofFlagSrdInit      ! Word 327 B0 B1
      integer(kind=4)    ,dimension(2,PN)    :: BBofFlagSrdNonUpdate ! Word 327 B2 B3
      integer(kind=4)    ,dimension(2,SB,PN) :: BBofFlagCoefCalInit  ! Word 327 B4-B6
                                                                     ! Word 328 B0-B2
      integer(kind=4)    ,dimension(2,SB,PN) :: BBofFlagCoefCalNonUpdate ! Word 328 B3-B8
      integer(kind=4)    ,dimension(2,SB,PN) :: BRciFlagNonIntegritySlope ! Word 328 B9-B14
      integer(kind=4)    ,dimension(2,SB,PN) :: BRciFlagNonIntegrityOffset ! Word 329 B0-B5
   end type EXTRA_STATUS_AREA

   type DATA_AP
      integer(kind=4)                        :: Chain    ! Word 11 B3
      integer(kind=4)                        :: MAS_HAU1 ! Word 11 B8
      integer(kind=4)                        :: MAS_HAU2 ! Word 11 B9
      integer(kind=4)                        :: MAS_HAU3 ! Word 11 B10
      integer(kind=4)                        :: MAS_HAU4 ! Word 11 B11
      integer(kind=4)                        :: LAZER    ! Word 11 B15
      integer(kind=4)                        :: RC       ! Word 12 B0
      integer(kind=4)                        :: LNR      ! Word 12 B1
      integer(kind=4)                        :: ASE      ! Word 12 B2
      integer(kind=4)                        :: LBR      ! Word 12 B3
      integer(kind=4)                        :: PIX1     ! Word 12 B4-B6
      integer(kind=4)                        :: PIX2     ! Word 12 B7-B9
      integer(kind=4)                        :: PIX3     ! Word 12 B10-B12
      integer(kind=4)                        :: PIX4     ! Word 12 B13_B15
      integer(kind=4)                        :: PTSIMSW  ! Word 13
      integer(kind=4)                        :: PTSILSW  ! Word 14
      real(kind=4)                           :: BBT      ! Word 15-16
      integer(kind=4)                        :: INS_MODE ! Word 17
      integer(kind=4)                        :: LN       ! Word 18
      integer(kind=4)                        :: SQIS     ! Word 19
      integer(kind=4)                        :: SQII     ! Word 20
      integer(kind=4)                        :: RTS      ! Word 21
      integer(kind=4)                        :: RTL      ! Word 22
      integer(kind=4)                        :: IFPT     ! Word 23
      integer(kind=4)                        :: FPT      ! Word 24
      integer(kind=4)                        :: HAUT     ! Word 25
      integer(kind=4)                        :: OPBT     ! Word 26
      integer(kind=4)                        :: CBST     ! Word 27
      integer(kind=4)                        :: OTM_NV   ! Word 28
      integer(kind=4)                        :: SPTSI    ! Word 29-30
      integer(kind=4)                        :: DPC1     ! Word 33 B0
      integer(kind=4)                        :: DPC2     ! Word 33 B1
      integer(kind=4)                        :: DPC3     ! Word 33 B2
      integer(kind=4)                        :: DPC4     ! Word 33 B3
      integer(kind=4)                        :: DPC5     ! Word 33 B4
      integer(kind=4)                        :: FMU_N    ! Word 33 B5
      integer(kind=4)                        :: FMU_R    ! Word 33 B6
      integer(kind=4)                        :: LNR_IS   ! Word 33 B7
      integer(kind=4)                        :: PX1A_B   ! Word 33 B8
      integer(kind=4)                        :: PX2A_B   ! Word 33 B9
      integer(kind=4)                        :: PX3A_B   ! Word 33 B10
      integer(kind=4)                        :: PX4A_B   ! Word 33 B11
      integer(kind=4)                        :: DMC_SW   ! Word 33 B13
      integer(kind=4)                        :: EEPROM_RAM ! Word 33 B14
      integer(kind=4)                        :: DMC_RAM  ! Word 33 B15
      integer(kind=4)                        :: P1_MODE  ! Word 34 B0-B2
      integer(kind=4)                        :: P2_MODE  ! Word 34 B3-B5
      integer(kind=4)                        :: P3_MODE  ! Word 34 B6-B8
      integer(kind=4)                        :: P4_MODE  ! Word 34 B9-B11
      integer(kind=4)                        :: OP_MODE  ! Word 34 B12-B15
      integer(kind=4)                        :: PN_V     ! Word 35 B0-B3
      integer(kind=4)                        :: SB_V     ! Word 35 B4-B7
      integer(kind=4)                        :: SN_V     ! Word 35 B8-B15
      integer(kind=4)                        :: NO_OD_INFO  ! Word 36-37
      integer(kind=4)                        :: NO_IIS_INFO ! Word 38-39
      integer(kind=4)                        :: NO_MAS_INFO ! Word 40-41
      integer(kind=4)                        :: ELT1_CD     ! Word 42 B0
      integer(kind=4)                        :: ELT1_ERROR  ! Word 42 B1-B9
      integer(kind=4)                        :: ELT1_SN     ! Word 42 B10-B15
      integer(kind=4)                        :: ELT1_LN     ! Word 43
      integer(kind=4)                        :: ELT1_PN     ! Word 44 B0-B2
      integer(kind=4)                        :: ELT1_SB     ! Word 44 B3-B4
      integer(kind=4)                        :: ELT1_sever  ! Word 44 B5-B7
      integer(kind=4)                        :: ELT2_CD     ! Word 45 as 42 B0
      integer(kind=4)                        :: ELT2_ERROR  ! Word 45 as 42 B1-B9
      integer(kind=4)                        :: ELT2_SN     ! Word 45 as 42 B10-B15
      integer(kind=4)                        :: ELT2_LN     ! Word 46 as 43
      integer(kind=4)                        :: ELT2_PN     ! Word 47 as 44
      integer(kind=4)                        :: ELT2_SB     ! Word 47 as 44 B3-B4
      integer(kind=4)                        :: ELT2_sever  ! Word 47 as 44 B5-B7
      integer(kind=4)                        :: ELT3_CD     ! Word 48 as 42 B0
      integer(kind=4)                        :: ELT3_ERROR  ! Word 48 as 42 B1-B9
      integer(kind=4)                        :: ELT3_SN     ! Word 48 as 42 B10-B15
      integer(kind=4)                        :: ELT3_LN     ! Word 49 as 43
      integer(kind=4)                        :: ELT3_PN     ! Word 50 as 44 B0-B2
      integer(kind=4)                        :: ELT3_SB     ! Word 50 as 44 B3-B4 B1-B9
      integer(kind=4)                        :: ELT3_sever  ! Word 50 as 44 B5-B7 B10-B15
      integer(kind=4)                        :: ELT4_CD     ! Word 51 as 42 B0
      integer(kind=4)                        :: ELT4_ERROR  ! Word 51 as 42 B1-B9
      integer(kind=4)                        :: ELT4_SN     ! Word 51 as 42 B10-B15
      integer(kind=4)                        :: ELT4_LN     ! Word 52 as 43
      integer(kind=4)                        :: ELT4_PN     ! Word 53 as 44 B0-B2
      integer(kind=4)                        :: ELT4_SB     ! Word 53 as 44 B3-B4 B1-B9
      integer(kind=4)                        :: ELT4_sever  ! Word 53 as 44 B5-B7 B10-B15
      type(DATA_AREA)                        :: AP_DATA
      type(STATUS_AREA)                      :: AP_STATUS
      type(EXTRA_STATUS_AREA)                :: AP_EXTRA_STATUS
   end type DATA_AP

   type AI_VP
      integer(kind=4)                        :: SN     ! Word 12 B0-B7
      integer(kind=4)                        :: SP     ! Word 12 B8-B15
      integer(kind=4)                        :: CD     ! Word 13 B0
      integer(kind=4)                        :: PN_V ! word 20 B0-B3
      integer(kind=4)                        :: SB_V ! word 20 B4-B7
      integer(kind=4)                        :: SN_V ! word 20 B8-B15
      integer(kind=4)                        :: VP_Id                   ! word 21 B0-B7
      integer(kind=4)                        :: BZpdFlagNzpdNonQual     ! word 21 B8
      integer(kind=4)                        :: BdcoFlagMasErrorNbWords ! word 21 B9
      integer(kind=4)                        :: BZpdNzpd                ! word 22
      real(kind=4)                           :: BzpdNzpdQualIndexXX     ! word 23-24
      integer(kind=4)                        :: BdcoNbReceivedWords     ! word 25
      integer(kind=4)                        :: IZsbNsfirstSrd          ! word 26
      integer(kind=4)                        :: IZsbNslastSrd           ! word 27
      integer(kind=4)                        :: IUsbNsfirst             ! word 28
      integer(kind=4)                        :: IUsbNslast              ! word 29
      integer(kind=4)                        :: IOsbNsFirstMb1b2        ! word 30
      integer(kind=4)                        :: IOsbNsLastMb1b2         ! word 31
      integer(kind=4)                        :: IOsbNsFirstMb2b3        ! word 32
      integer(kind=4)                        :: IOsbNsLastMb2b3         ! word 33
   end type AI_VP

   type DATA_VP
      integer(kind=2)  ,dimension(:),allocatable     :: IF_MAS          ! VPA-VPB 
      complex(kind=4)  ,dimension(:),allocatable     :: BFrsSrdCS       ! VPC
      complex(kind=4)  ,dimension(:),allocatable     :: BFrsSrdBB
      complex(kind=4)  ,dimension(:),allocatable     :: BFrcOffset
      complex(kind=4)  ,dimension(:),allocatable     :: BFrcSlope
      complex(kind=4)  ,dimension(:),allocatable     :: BCrcOffset      ! VPD
      complex(kind=4)  ,dimension(:),allocatable     :: BCrcSlope
      real(kind=4)     ,dimension(:),allocatable     :: BArcSpectb1     ! VPE
      real(kind=4)     ,dimension(:),allocatable     :: BArcSpectb21
      real(kind=4)     ,dimension(:),allocatable     :: BArcSpectb23
      real(kind=4)     ,dimension(:),allocatable     :: BArcSpectb3
   end type DATA_VP

   type RECORD_MDR_ENGINEERING
      integer(kind=4)                        :: line
      integer(kind=4), dimension(8,SNOT)     :: vdate    ! idem year month etc..
      type(RECORD_HEADER)                    :: grh
      real(kind=8)                           :: BIMSBBT
      real(kind=8)                           :: GFtbFilteredBBT
      integer(kind=4)  ,dimension(8)         :: GEPSIdConf_Line
      integer(kind=4)                        :: GEPSIasiMode
      integer(kind=4)  ,dimension(NBK,SNOT)  :: GCcsConfAvhrrChannel
      integer(kind=4)                        :: GEPSGranulNumber
      type(SHORT_CDS_TIME) ,dimension(SNOT)  :: GEPSDatIasi
      integer(kind=4)                        :: GEPSOPSProcessingMode
      integer(kind=4)      ,dimension(SNOT)  :: GEPS_SP
      integer(kind=4)      ,dimension(SNOT)  :: GEPS_CCD
      real(kind=8)         ,dimension(2)     :: GGeoSubSatellitePosition
      integer(kind=1)                        :: GEPSOPSFlagNan
      type(SHORT_CDS_TIME)                   :: GEPSEndEclipseTime
      real(kind=8)                           :: GSmeTScan
      integer(kind=1)                        :: GSmeFlagDateNOK
      real(kind=8)                           :: GFtbBBTRes
      integer(kind=1)                        :: GFtbFlagBBTNonQual
      integer(kind=4)                        :: GEPS_LN
      integer(kind=1)    ,dimension(PN,SNOT) :: GDocFlagUnderOverFlow
      integer(kind=4)    ,dimension(PN,SNOT) :: GDocNbUnderFlow
      integer(kind=4)    ,dimension(PN,SNOT) :: GDocNbOverFlow
      integer(kind=4)  ,dimension(3,PN,SNOT) :: GDocPosUnderFlow
      integer(kind=4)  ,dimension(3,PN,SNOT) :: GDocPosOverFlow
      integer(kind=2)  ,dimension(NSVERIF)   :: BCodSpecVerlf
      real(kind=8)     ,dimension(2,SNOT)    :: GlacOffsetIISAvhrr
      real(kind=8)     ,dimension(SNOT)      :: GlacCorrelQual
      real(kind=8)     ,dimension(SNOT)      :: GlacPosMaxQual
      integer(kind=1)  ,dimension(SNOT)      :: GlacFlagCoregNonValid
      integer(kind=1)  ,dimension(SNOT)      :: GlacFlagCoregNonQual
      real(kind=8)     ,dimension(SNOT)      :: GIacVarImagIIS
      real(kind=8)     ,dimension(SNOT)      :: GIacAvgImagIIS
      integer(kind=1)  ,dimension(PN,SNOT)   :: GEUMAvhrr1BCldFrac
      integer(kind=1)  ,dimension(PN,SNOT)   :: GEUMAvhrr1BLandFrac
      integer(kind=1)  ,dimension(PN,SNOT)   :: GEUMAvhrr1BQual
      real(kind=8)   ,dimension(2,PN,SNOT)   :: GCcsOffsetSondAvhrr
      real(kind=8)   ,dimension(2,PN,SNOT)   :: GCcsOffsetSondIIS
      real(kind=8)   ,dimension(SNOT)        :: GQisCcsQualIndex
      integer(kind=1)                        :: GCcsFlagDateNOK
      real(kind=4)   ,dimension(4,PN,SNOT)   :: GCcsAvhrrPseudoChn
      integer(kind=4),dimension(PN,SNOT)     :: GCcsRadAnalNbClass
      integer(kind=4),dimension(SNOT)        :: GCcsFlagPostProcessing
      real(kind=8)   ,dimension(SNOT)        :: GCcsNonClassifRate
      real(kind=8)   ,dimension(SNOT)        :: GCcsVarianceRate
      integer(kind=1),dimension(PN,SNOT)     :: GSsdConverFlag
      real(kind=8)   ,dimension(PN,SNOT)     :: GSsdWnShift
      real(kind=8)   ,dimension(PN,SNOT)     :: GSsdWnShiftQual
      integer(kind=1),dimension(PN,SNOT)     :: GSsdFlagSpectralShiftNonQual
      real(kind=8)   ,dimension(PN,CCD)      :: GSssWnShiftMean
      real(kind=8)   ,dimension(PN,CCD)      :: GSssWnShiftMeanQual
      integer(kind=1),dimension(PN,CCD)      :: GSssFlagNonSelPix
      integer(kind=1)                        :: GSssFlagDateNOK
      real(kind=8)   ,dimension(CCD)         :: GlaxAxeY
      real(kind=8)   ,dimension(CCD)         :: GlaxAxeZ
      integer(kind=1),dimension(CCD)         :: GFaxFlagAxeNonQual
      real(kind=8)   ,dimension(CCD)         :: GFaxAxeRes
      real(kind=8)   ,dimension(CCD)         :: GFaxAxeY
      real(kind=8)   ,dimension(CCD)         :: GFaxAxeZ
      integer(kind=1),dimension(CCD)         :: GIsfFlagPdsNonValid
      integer(kind=2),dimension(IMCO,IMLI)   :: GIccRadCalOffsetImag
      integer(kind=4),dimension(IMCO,IMLI)   :: GlccRadCalSlopeImag ! sf=14
      integer(kind=1)                        :: GlccFlagInit
      integer(kind=1),dimension(SB,PN,SNOT)  :: GQisFlagQual
      integer(kind=2),dimension(PN,SNOT)     :: GQisFlagQualDetailed
      real(kind=8)   ,dimension(PN,SNOT)     :: GQisQualIndex
      real(kind=8)   ,dimension(SNOT)        :: GQisQualIndexIIS
      real(kind=8)   ,dimension(PN,SNOT)     :: GQisQualIndexLoc
      real(kind=8)   ,dimension(PN,SNOT)     :: GQisQualIndexRad
      real(kind=8)   ,dimension(PN,SNOT)     :: GQisQualIndexSpect
      integer(kind=2),dimension(PN,SNOT+4)   :: MHipNZpdInterPixel
      integer(kind=2),dimension(PN,SNOT+4)   :: MHipFlagInterPixNzpdNonQual
      real(kind=4)   ,dimension(NIM,PN,SNOT) :: MMcxNoiseCalRad
      real(kind=4)   ,dimension(NIM,PN,SNOT) :: MMcxBiasCalRad
      integer(kind=1),dimension(PN,SNOT)     :: MMcxFlagNoiseCalRad
      integer(kind=1),dimension(PN,SNOT)     :: MMcxFlagBlasCalRad
      real(kind=8)   ,dimension(SB,PN,SNOT)  :: MMcxCoeffCalRad
      real(kind=8)                           :: MDptVarImagMax
      real(kind=8)                           :: MDptVarImagMean
      real(kind=8)                           :: MDptPixQual
      integer(kind=1)                        :: GHecFlagDateNOK
      type(DATA_PX)                          :: ENG_PX
      type(DATA_IP)                          :: ENG_IP
      integer(kind=2),dimension(PN,SNOT+4,2) :: EqualizationCounter
      integer(kind=1),dimension(PN,SNOT)     :: GOPSFlaPixMiss
      integer(kind=1)                        :: GOPSFlaDataGap
      integer(kind=1),dimension(SNOT)        :: GOPSFltIsrfemOff
      type(SHORT_CDS_TIME)                   :: GOPSDatIsrfemOff
      integer(kind=1),dimension(SNOT)        :: GOPSFItBandMiss
      type(SHORT_CDS_TIME)                   :: GOPSDatBandMiss
      integer(kind=1)                        :: GOPSFltBBTMiss
      type(SHORT_CDS_TIME)                   :: GOPSDatBBTMiss
      integer(kind=1),dimension(SNOT)        :: GOPSFltImgEWMiss
      type(SHORT_CDS_TIME)                   :: GOPSDatImgEWMiss
      integer(kind=1)                        :: GOPSFltImgBBMiss
      type(SHORT_CDS_TIME)                   :: GOPSDatImgBBMiss
      integer(kind=1)                        :: GOPSFltImgCSMiss
      type(SHORT_CDS_TIME)                   :: GOPSDatImgCSMiss
      integer(kind=1),dimension(4)           :: GOPSFlaIISCalibMiss
      integer(kind=1),dimension(SNOT)        :: GOPSFltRadAvhrrMiss
      type(SHORT_CDS_TIME)                   :: GOPSDatRadAvhrrMiss
      integer(kind=1),dimension(5)           :: GOPSFlagPacketVPMiss
      integer(kind=1)                        :: GOPSFlagPacketAPMiss
      integer(kind=1),dimension(PN,SNOT)     :: GOPSFlagPacketPXMiss
      integer(kind=1),dimension(SNOT+4)      :: GOPSFlagPacketIPMiss
      integer(kind=1),dimension(SNOT)        :: GOPSFlaGeoAvhrrMiss
   end type RECORD_MDR_ENGINEERING

   
   type RECORD_MDR_VERIFICATION
      type(RECORD_HEADER)          :: grh
      integer(kind=4)              :: line
      integer(kind=4)              :: SIZE_OF_VERIFICATION_DATA ! = NVP
      type(DATA_AP)                :: aux
      type(AI_VP)    ,dimension(5) :: vpa
      type(DATA_VP)                :: vpd
   end type RECORD_MDR_VERIFICATION

   type L1_ENG_VER_GRANULE
      integer(kind=4)                                           :: nb_lines
      integer(kind=4)                                           :: nb_eng
      integer(kind=4)                                           :: nb_ver
      integer(kind=4)                                           :: nb_viadr
      type(RECORD_MDR_ENGINEERING)  , dimension(:),allocatable  :: mdr_l1eng
      type(RECORD_VIADR_ENGINEERING), dimension(:),allocatable  :: viadr_l1eng
      type(RECORD_GIADR_ENGINEERING)                            :: giadr_l1eng
      type(RECORD_MDR_VERIFICATION) , dimension(:),allocatable  :: mdr_l1ver
   end type L1_ENG_VER_GRANULE

   type RECORD_GEADR
      character(len=120) :: fname
   end type RECORD_GEADR

   type RECORD_SPHR
      type(RECORD_HEADER)  :: grh
      character(len=49)    :: SRC_DATA_QUAL
      character(len=38)    :: EARTH_VIEWS_PER_SCANLINE
      character(len=36)    :: NAV_SAMPLE_RATE
   end type RECORD_SPHR

   type DATA_CALQUAL
      integer*1             :: NEDT_VALUE         ! sf=2
      type(BITS8)           :: CALIBRATION_QUALITY
   end type DATA_CALQUAL

   type RECORD_GIADR_RADIANCE
      type(RECORD_HEADER)  :: grh
      type(BITS16)         :: RAMP_CAL_COEFFICIENT
      integer(kind=2)      :: YEAR_RECENT_CALIBRATION
      integer(kind=2)      :: DAY_RECENT_CALIBRATION
      integer(kind=2)      :: PRIMARY_CALIBRATION_ALGORITHM_ID
      type(BITS16)         :: PRIMARY_CAL_ALGO_OPTION
      integer(kind=2)      :: SECONDARY_CALIBRATION_ALGORITHM_ID
      type(BITS16)         :: SECONDARY_CAL_ALGO_OPTION
      integer(kind=2)      :: IR_TEMPERATURE1_COEFFICIENT1
      integer(kind=2)      :: IR_TEMPERATURE1_COEFFICIENT2
      integer(kind=2)      :: IR_TEMPERATURE1_COEFFICIENT3
      integer(kind=2)      :: IR_TEMPERATURE1_COEFFICIENT4
      integer(kind=2)      :: IR_TEMPERATURE1_COEFFICIENT5
      integer(kind=2)      :: IR_TEMPERATURE1_COEFFICIENT6
      integer(kind=2)      :: IR_TEMPERATURE2_COEFFICIENT1
      integer(kind=2)      :: IR_TEMPERATURE2_COEFFICIENT2
      integer(kind=2)      :: IR_TEMPERATURE2_COEFFICIENT3
      integer(kind=2)      :: IR_TEMPERATURE2_COEFFICIENT4
      integer(kind=2)      :: IR_TEMPERATURE2_COEFFICIENT5
      integer(kind=2)      :: IR_TEMPERATURE2_COEFFICIENT6
      integer(kind=2)      :: IR_TEMPERATURE3_COEFFICIENT1
      integer(kind=2)      :: IR_TEMPERATURE3_COEFFICIENT2
      integer(kind=2)      :: IR_TEMPERATURE3_COEFFICIENT3
      integer(kind=2)      :: IR_TEMPERATURE3_COEFFICIENT4
      integer(kind=2)      :: IR_TEMPERATURE3_COEFFICIENT5
      integer(kind=2)      :: IR_TEMPERATURE3_COEFFICIENT6
      integer(kind=2)      :: IR_TEMPERATURE4_COEFFICIENT1
      integer(kind=2)      :: IR_TEMPERATURE4_COEFFICIENT2
      integer(kind=2)      :: IR_TEMPERATURE4_COEFFICIENT3
      integer(kind=2)      :: IR_TEMPERATURE4_COEFFICIENT4
      integer(kind=2)      :: IR_TEMPERATURE4_COEFFICIENT5
      integer(kind=2)      :: IR_TEMPERATURE4_COEFFICIENT6
      integer(kind=2)      :: CH1_SOLAR_FILTERED_IRRADIANCE  ! sf 1
      integer(kind=2)      :: CH1_EQUIVALENT_FILTER_WIDTH    ! sf 3
      integer(kind=2)      :: CH2_SOLAR_FILTERED_IRRADIANCE  ! sf 1
      integer(kind=2)      :: CH2_EQUIVALENT_FILTER_WIDTH    ! sf 3
      integer(kind=2)      :: CH3A_SOLAR_FILTERED_IRRADIANCE ! sf 1
      integer(kind=2)      :: CH3A_EQUIVALENT_FILTER_WIDTH   ! sf 3
      integer(kind=4)      :: CH3B_CENTRAL_WAVENUMBER        ! sf 2
      integer(kind=4)      :: CH3B_CONSTANT1                 ! sf 5
      integer(kind=4)      :: CH3B_CONSTANT2_SLOPE           ! sf 6
      integer(kind=4)      :: CH4_CENTRAL_WAVENUMBER         ! sf 3
      integer(kind=4)      :: CH4_CONSTANT1                  ! sf 5
      integer(kind=4)      :: CH4_CONSTANT2_SLOPE            ! sf 6
      integer(kind=4)      :: CH5_CENTRAL_WAVENUMBER         ! sf 3
      integer(kind=4)      :: CH5_CONSTANT1                  ! sf 5
      integer(kind=4)      :: CH5_CONSTANT2_SLOPE            ! sf 6
   end type RECORD_GIADR_RADIANCE

   type RECORD_GIADR_ANALOG
      type(RECORD_HEADER)  :: grh
      integer(kind=2)      :: PATCH_TEMPERATURE_COEFFICIENT1
      integer(kind=2)      :: PATCH_TEMPERATURE_COEFFICIENT2
      integer(kind=2)      :: PATCH_TEMPERATURE_COEFFICIENT3
      integer(kind=2)      :: PATCH_TEMPERATURE_COEFFICIENT4
      integer(kind=2)      :: PATCH_TEMPERATURE_COEFFICIENT5
      integer(kind=2)      :: PATCH_TEMPERATURE_EXTENDED_COEFFICIENT1
      integer(kind=2)      :: PATCH_TEMPERATURE_EXTENDED_COEFFICIENT2
      integer(kind=2)      :: PATCH_TEMPERATURE_EXTENDED_COEFFICIENT3
      integer(kind=2)      :: PATCH_TEMPERATURE_EXTENDED_COEFFICIENT4
      integer(kind=2)      :: PATCH_TEMPERATURE_EXTENDED_COEFFICIENT5
      integer(kind=2)      :: PATCH_POWER_COEFFICIENT1
      integer(kind=2)      :: PATCH_POWER_COEFFICIENT2
      integer(kind=2)      :: PATCH_POWER_COEFFICIENT3
      integer(kind=2)      :: PATCH_POWER_COEFFICIENT4
      integer(kind=2)      :: PATCH_POWER_COEFFICIENT5
      integer(kind=2)      :: RADIATOR_TEMPERATURE_COEFFICIENT1
      integer(kind=2)      :: RADIATOR_TEMPERATURE_COEFFICIENT2
      integer(kind=2)      :: RADIATOR_TEMPERATURE_COEFFICIENT3
      integer(kind=2)      :: RADIATOR_TEMPERATURE_COEFFICIENT4
      integer(kind=2)      :: RADIATOR_TEMPERATURE_COEFFICIENT5
      integer(kind=2)      :: BLACKBODY_TEMPERATURE1_COEFFICIENT1
      integer(kind=2)      :: BLACKBODY_TEMPERATURE1_COEFFICIENT2
      integer(kind=2)      :: BLACKBODY_TEMPERATURE1_COEFFICIENT3
      integer(kind=2)      :: BLACKBODY_TEMPERATURE1_COEFFICIENT4
      integer(kind=2)      :: BLACKBODY_TEMPERATURE1_COEFFICIENT5
      integer(kind=2)      :: BLACKBODY_TEMPERATURE2_COEFFICIENT1
      integer(kind=2)      :: BLACKBODY_TEMPERATURE2_COEFFICIENT2
      integer(kind=2)      :: BLACKBODY_TEMPERATURE2_COEFFICIENT3
      integer(kind=2)      :: BLACKBODY_TEMPERATURE2_COEFFICIENT4
      integer(kind=2)      :: BLACKBODY_TEMPERATURE2_COEFFICIENT5
      integer(kind=2)      :: BLACKBODY_TEMPERATURE3_COEFFICIENT1
      integer(kind=2)      :: BLACKBODY_TEMPERATURE3_COEFFICIENT2
      integer(kind=2)      :: BLACKBODY_TEMPERATURE3_COEFFICIENT3
      integer(kind=2)      :: BLACKBODY_TEMPERATURE3_COEFFICIENT4
      integer(kind=2)      :: BLACKBODY_TEMPERATURE3_COEFFICIENT5
      integer(kind=2)      :: BLACKBODY_TEMPERATURE4_COEFFICIENT1
      integer(kind=2)      :: BLACKBODY_TEMPERATURE4_COEFFICIENT2
      integer(kind=2)      :: BLACKBODY_TEMPERATURE4_COEFFICIENT3
      integer(kind=2)      :: BLACKBODY_TEMPERATURE4_COEFFICIENT4
      integer(kind=2)      :: BLACKBODY_TEMPERATURE4_COEFFICIENT5
      integer(kind=2)      :: ELECTRONIC_CURRENT_COEFFICIENT1
      integer(kind=2)      :: ELECTRONIC_CURRENT_COEFFICIENT2
      integer(kind=2)      :: ELECTRONIC_CURRENT_COEFFICIENT3
      integer(kind=2)      :: ELECTRONIC_CURRENT_COEFFICIENT4
      integer(kind=2)      :: ELECTRONIC_CURRENT_COEFFICIENT5
      integer(kind=2)      :: MOTOR_CURRENT_COEFFICIENT1
      integer(kind=2)      :: MOTOR_CURRENT_COEFFICIENT2
      integer(kind=2)      :: MOTOR_CURRENT_COEFFICIENT3
      integer(kind=2)      :: MOTOR_CURRENT_COEFFICIENT4
      integer(kind=2)      :: MOTOR_CURRENT_COEFFICIENT5
      integer(kind=2)      :: EARTH_SHIELD_POSITION_COEFFICIENT1
      integer(kind=2)      :: EARTH_SHIELD_POSITION_COEFFICIENT2
      integer(kind=2)      :: EARTH_SHIELD_POSITION_COEFFICIENT3
      integer(kind=2)      :: EARTH_SHIELD_POSITION_COEFFICIENT4
      integer(kind=2)      :: EARTH_SHIELD_POSITION_COEFFICIENT5
      integer(kind=2)      :: ELECTRONIC_TEMPERATURE_COEFFICIENT1
      integer(kind=2)      :: ELECTRONIC_TEMPERATURE_COEFFICIENT2
      integer(kind=2)      :: ELECTRONIC_TEMPERATURE_COEFFICIENT3
      integer(kind=2)      :: ELECTRONIC_TEMPERATURE_COEFFICIENT4
      integer(kind=2)      :: ELECTRONIC_TEMPERATURE_COEFFICIENT5
      integer(kind=2)      :: COOLER_HOUSING_TEMPERATURE_COEFFICIENT1
      integer(kind=2)      :: COOLER_HOUSING_TEMPERATURE_COEFFICIENT2
      integer(kind=2)      :: COOLER_HOUSING_TEMPERATURE_COEFFICIENT3
      integer(kind=2)      :: COOLER_HOUSING_TEMPERATURE_COEFFICIENT4
      integer(kind=2)      :: COOLER_HOUSING_TEMPERATURE_COEFFICIENT5
      integer(kind=2)      :: BASEPLATE_TEMPERATURE_COEFFICIENT1
      integer(kind=2)      :: BASEPLATE_TEMPERATURE_COEFFICIENT2
      integer(kind=2)      :: BASEPLATE_TEMPERATURE_COEFFICIENT3
      integer(kind=2)      :: BASEPLATE_TEMPERATURE_COEFFICIENT4
      integer(kind=2)      :: BASEPLATE_TEMPERATURE_COEFFICIENT5
      integer(kind=2)      :: MOTOR_HOUSING_TEMPERATURE_COEFFICIENT1
      integer(kind=2)      :: MOTOR_HOUSING_TEMPERATURE_COEFFICIENT2
      integer(kind=2)      :: MOTOR_HOUSING_TEMPERATURE_COEFFICIENT3
      integer(kind=2)      :: MOTOR_HOUSING_TEMPERATURE_COEFFICIENT4
      integer(kind=2)      :: MOTOR_HOUSING_TEMPERATURE_COEFFICIENT5
      integer(kind=2)      :: AD_CONVERTER_TEMPERATURE_COEFFICIENT1
      integer(kind=2)      :: AD_CONVERTER_TEMPERATURE_COEFFICIENT2
      integer(kind=2)      :: AD_CONVERTER_TEMPERATURE_COEFFICIENT3
      integer(kind=2)      :: AD_CONVERTER_TEMPERATURE_COEFFICIENT4
      integer(kind=2)      :: AD_CONVERTER_TEMPERATURE_COEFFICIENT5
      integer(kind=2)      :: DETECTOR4_BIAS_VOLTAGE_COEFFICIENT1
      integer(kind=2)      :: DETECTOR4_BIAS_VOLTAGE_COEFFICIENT2
      integer(kind=2)      :: DETECTOR4_BIAS_VOLTAGE_COEFFICIENT3
      integer(kind=2)      :: DETECTOR4_BIAS_VOLTAGE_COEFFICIENT4
      integer(kind=2)      :: DETECTOR4_BIAS_VOLTAGE_COEFFICIENT5
      integer(kind=2)      :: DETECTOR5_BIAS_VOLTAGE_COEFFICIENT1
      integer(kind=2)      :: DETECTOR5_BIAS_VOLTAGE_COEFFICIENT2
      integer(kind=2)      :: DETECTOR5_BIAS_VOLTAGE_COEFFICIENT3
      integer(kind=2)      :: DETECTOR5_BIAS_VOLTAGE_COEFFICIENT4
      integer(kind=2)      :: DETECTOR5_BIAS_VOLTAGE_COEFFICIENT5
      integer(kind=2)      :: CH3B_BLACKBODY_VIEW_COEFFICIENT1
      integer(kind=2)      :: CH3B_BLACKBODY_VIEW_COEFFICIENT2
      integer(kind=2)      :: CH3B_BLACKBODY_VIEW_COEFFICIENT3
      integer(kind=2)      :: CH3B_BLACKBODY_VIEW_COEFFICIENT4
      integer(kind=2)      :: CH3B_BLACKBODY_VIEW_COEFFICIENT5
      integer(kind=2)      :: CH4_BLACKBODY_VIEW_COEFFICIENT1
      integer(kind=2)      :: CH4_BLACKBODY_VIEW_COEFFICIENT2
      integer(kind=2)      :: CH4_BLACKBODY_VIEW_COEFFICIENT3
      integer(kind=2)      :: CH4_BLACKBODY_VIEW_COEFFICIENT4
      integer(kind=2)      :: CH4_BLACKBODY_VIEW_COEFFICIENT5
      integer(kind=2)      :: CH5_BLACKBODY_VIEW_COEFFICIENT1
      integer(kind=2)      :: CH5_BLACKBODY_VIEW_COEFFICIENT2
      integer(kind=2)      :: CH5_BLACKBODY_VIEW_COEFFICIENT3
      integer(kind=2)      :: CH5_BLACKBODY_VIEW_COEFFICIENT4
      integer(kind=2)      :: CH5_BLACKBODY_VIEW_COEFFICIENT5
      integer(kind=2)      :: REFERENCE_VOLTAGE_COEFFICIENT1
      integer(kind=2)      :: REFERENCE_VOLTAGE_COEFFICIENT2
      integer(kind=2)      :: REFERENCE_VOLTAGE_COEFFICIENT3
      integer(kind=2)      :: REFERENCE_VOLTAGE_COEFFICIENT4
      integer(kind=2)      :: REFERENCE_VOLTAGE_COEFFICIENT5
  end type RECORD_GIADR_ANALOG

  type RECORD_MDR_AVHRR_1B_FULL
      integer(kind=4)                    :: line ! granule line number
      type(SHORT_CDS_TIME)               :: cds_date ! days since 2001-01-01
      integer(kind=4), dimension(8)      :: vdate    ! idem year month etc..
      integer(kind=2), dimension(4,NE)   :: Cloud_Flag_Vect
      type(RECORD_HEADER)  :: grh
      logical              :: DEGRADED_INST_MDR
      logical              :: DEGRADED_PROC_MDR
      integer(kind=2)      :: EARTH_VIEWS_PER_SCANLINE
      real(kind=4)         :: SCENE_RADIANCES(NE,5)         ! sf=2 (1 2 4 5)
                                                            ! sf=4 (3a 3b)
      integer(kind=4)      :: TIME_ATTITUDE
      integer(kind=2)      :: EULER_ANGLE(3)                ! sf=3
      type(BITS32)         :: NAVIGATION_STATUS
      integer(kind=4)      :: SPACECRAFT_ALTITUDE           ! sf=1
!!$      real(kind=4)         :: ANGULAR_RELATIONS_FIRST(4)    ! sf=2
!!$      real(kind=4)         :: ANGULAR_RELATIONS_LAST(4)     ! sf=2
!!$      real(kind=4)         :: EARTH_LOCATION_FIRST(2)       ! sf=4
!!$      real(kind=4)         :: EARTH_LOCATION_LAST(2)        ! sf=4
      integer(kind=2)      :: NUM_NAVIGATION_POINTS
      real(kind=4)         :: ANGULAR_RELATIONS(4, NP+2)    ! sf=2
      real(kind=4)         :: EARTH_LOCATIONS(2, NP+2)      ! sf=4
      real(kind=4)         :: ANGULAR_RELATIONS_NE(4, NE)   ! sf=2
      real(kind=4)         :: EARTH_LOCATIONS_NE(2, NE)     ! sf=4
      integer(kind=4)      :: QUALITY_INDICATOR
      integer(kind=4)      :: SCAN_LINE_QUALITY
      type(DATA_CALQUAL)   :: DATA_CALIBRATION(3)
      integer(kind=2)      :: COUNT_ERROR_FRAME
      integer(kind=4)      :: CH123A_CURVE_SLOPE1(3)        ! sf=7
      integer(kind=4)      :: CH123A_CURVE_INTERCEPT1(3)    ! sf=6
      integer(kind=4)      :: CH123A_CURVE_SLOPE2(3)        ! sf=7
      integer(kind=4)      :: CH123A_CURVE_INTERCEPT2(3)    ! sf=6
      integer(kind=4)      :: CH123A_CURVE_INTERCEPTION(3)
      integer(kind=4)      :: CH123A_TEST_CURVE_SLOPE1(3)          ! sf=7
      integer(kind=4)      :: CH123A_TEST_CURVE_INTERCEPT1(3)      ! sf=6
      integer(kind=4)      :: CH123A_TEST_CURVE_SLOPE2(3)          ! sf=7
      integer(kind=4)      :: CH123A_TEST_CURVE_INTERCEPT2(3)      ! sf=6
      integer(kind=4)      :: CH123A_TEST_CURVE_INTERCEPTION(3)
      integer(kind=4)      :: CH123A_PRELAUNCH_CURVE_SLOPE1(3)     ! sf=7
      integer(kind=4)      :: CH123A_PRELAUNCH_CURVE_INTERCEPT1(3) ! sf=6
      integer(kind=4)      :: CH123A_PRELAUNCH_CURVE_SLOPE2(3)     ! sf=7
      integer(kind=4)      :: CH123A_PRELAUNCH_CURVE_INTERCEPT2(3) ! sf=6
      integer(kind=4)      :: CH123A_PRELAUNCH_CURVE_INTERCEPTION(3)
      integer(kind=4)      :: CH3B45_SECOND_TERM(3)         ! sf=9
      integer(kind=4)      :: CH3B45_FIRST_TERM(3)          ! sf=6
      integer(kind=4)      :: CH3B45_ZEROTH_TERM(3)         ! sf=6
      integer(kind=4)      :: CH3B45_TEST_SECOND_TERM(3)    ! sf=9
      integer(kind=4)      :: CH3B45_TEST_FIRST_TERM(3)     ! sf=6
      integer(kind=4)      :: CH3B45_TEST_ZEROTH_TERM(3)    ! sf=6
      integer(kind=2)      :: CLOUD_INFORMATION(NE)
      integer(kind=2)      :: FRAME_SYNCHRONISATION(6)
      type(BITS16)         :: FRAME_INDICATOR(2)
      type(BITS16)         :: TIME_CODE(4)
      integer(kind=2)      :: RAMP_CALIB(5)
      integer(kind=2)      :: INTERNAL_TARGET_TEMPERATURE_COUNT(3)
      type(BITS16)         :: INSTRUMENT_INVALID_WORD_FLAG
      type(BITS16)         :: DIGITAL_B_DATA
      type(BITS32)         :: INSTRUMENT_INVALID_ANALOG_WORD_FLAG
      integer(kind=2)      :: PATCH_TEMPERATURE
      integer(kind=2)      :: PATCH_EXTENDED_TEMPERATURE
      integer(kind=2)      :: PATCH_POWER
      integer(kind=2)      :: RADIATOR_TEMPERATURE
      integer(kind=2)      :: BLACKBODY_TEMPERATURE1
      integer(kind=2)      :: BLACKBODY_TEMPERATURE2
      integer(kind=2)      :: BLACKBODY_TEMPERATURE3
      integer(kind=2)      :: BLACKBODY_TEMPERATURE4
      integer(kind=2)      :: ELECTRONIC_CURRENT
      integer(kind=2)      :: MOTOR_CURRENT
      integer(kind=2)      :: EARTH_SHIELD_POSITION
      integer(kind=2)      :: ELECTRONIC_TEMPERATURE
      integer(kind=2)      :: COOLER_HOUSING_TEMPERATURE
      integer(kind=2)      :: BASEPLATE_TEMPERATURE
      integer(kind=2)      :: MOTOR_HOUSING_TEMPERATURE
      integer(kind=2)      :: AD_CONVERTER_TEMPERATURE
      integer(kind=2)      :: DETECTOR4_VOLTAGE
      integer(kind=2)      :: DETECTOR5_VOLTAGE
      integer(kind=2)      :: CH3_BLACKBODY_VIEW
      integer(kind=2)      :: CH4_BLACKBODY_VIEW
      integer(kind=2)      :: CH5_BLACKBODY_VIEW
      integer(kind=2)      :: REFERENCE_VOLTAGE
   end type RECORD_MDR_AVHRR_1B_FULL

   type AVHRR_GRANULE
      integer(kind=4)                                   :: nb_lines
      type(RECORD_MDR_AVHRR_1B_FULL), dimension(:),allocatable  :: mdr_avhrr
      type(RECORD_GIADR_RADIANCE)                       :: giadr_radiance
      type(RECORD_GIADR_ANALOG)                         :: giadr_analog
   end type AVHRR_GRANULE

   type AVHRR_RAD_ANAL
      integer(kind=4)  :: channelid(NBK)
      integer(kind=4)  :: nbclass(PN,SNOT)
      real(kind=4)     :: wgt(NCL,PN,SNOT)
      real(kind=4)     :: Y(NCL,PN,SNOT)
      real(kind=4)     :: Z(NCL,PN,SNOT)
      real(kind=4)     :: mean(NBK,NCL,PN,SNOT)
      real(kind=4)     :: std(NBK,NCL,PN,SNOT)
      integer(kind=1)  :: imageclassified(AMCO,AMLI,SNOT)
      integer(kind=2)  :: imageclassifiednblin(SNOT)
      integer(kind=2)  :: imageclassifiednbcol(SNOT)
      integer(kind=1)  :: ccsmode
      integer(kind=1)  :: classtype(NCL,SNOT)
   end type AVHRR_RAD_ANAL

   type RECORD_MDR_L1C
      integer(kind=4)                             :: line           ! granule line number
      integer(kind=4)                             :: GEPSIasiMode   ! instrument mode
      integer(kind=4), dimension(SNOT)            :: GEPS_SP        ! scan position
      integer(kind=1), dimension(SNOT)            :: GEPS_CCD       ! Corner cube direction
      real(kind=4), dimension(PN,SNOT)            :: lon, lat       ! longitude, latitude
      type(SHORT_CDS_TIME), dimension(SNOT)       :: cds_date       ! days since 2001-01-01
      integer(kind=4), dimension(8,SNOT)          :: vdate          ! idem year month etc..
      integer(kind=1), dimension(SB,PN,SNOT)      :: flg            ! quality flag per band
      real(kind=4), dimension(PN,SNOT)            :: iaa, iza       ! instrument azimuth and zenith angles
      real(kind=4), dimension(PN,SNOT)            :: saa, sza       ! solar azimuth and zenith angles
      integer(kind=1), dimension(PN,SNOT)         :: clc, lfr, sif  ! cloud cover, land fraction, AVHRR 1B qual
      real(kind=4)                                :: dWn            ! spectral step
      integer(kind=4)                             :: NsFirst        ! first sample
      integer(kind=4)                             :: NsLast         ! last sample
      real(kind=4), dimension(nbrIasi,PN,SNOT)    :: rad            ! radiance
      type(AVHRR_RAD_ANAL)                        :: radanal        ! AVHRR radiance analysis
      real(kind=4), dimension(SGI,SNOT)           :: IISlon, IISlat ! IIS subgrid localization
!~    contains
!~       module procedure read => read_iasi_mdr_l1c
   end type RECORD_MDR_L1C

   type L1C_GRANULE
      integer(kind=4)                                :: nb_lines
      type(RECORD_MDR_L1C), dimension(:),allocatable :: mdr_l1c      
   end type L1C_GRANULE

   type RECORD_MDR_L2
      integer(kind=4)                         :: line ! granule line number
      type(SHORT_CDS_TIME), dimension(2)      :: cds_date       ! days since 2001-01-01
      integer(kind=4), dimension(8,SNOT)      :: vdate          ! idem year month etc..
      integer(kind=2)                         :: DEGRADED_INST_MDR              !! sf=n offset=20
      integer(kind=2)                         :: DEGRADED_PROC_MDR              !! sf=n offset=21
      real(kind=4)    ,dimension(NLT,PN,SNOT) :: FG_ATMOSPHERIC_TEMPERATURE     !! sf=2 offset=22
      real(kind=4)    ,dimension(NLQ,PN,SNOT) :: FG_ATMOSPHERIC_WATER_VAPOUR    !! sf=7 offset=24262
      real(kind=4)    ,dimension(NLO,PN,SNOT) :: FG_ATMOSPHERIC_OZONE           !! sf=8 offset=72742
      real(kind=4)    ,dimension(PN,SNOT)     :: FG_SURFACE_TEMPERATURE         !! sf=2 offset=96982
      integer(kind=4) ,dimension(PN,SNOT)     :: FG_QI_ATMOSPHERIC_TEMPERATURE  !! sf=1 offset=97222
      integer(kind=4) ,dimension(PN,SNOT)     :: FG_QI_ATMOSPHERIC_WATER_VAPOUR !! sf=1 offset=97342
      integer(kind=4) ,dimension(PN,SNOT)     :: FG_QI_ATMOSPHERIC_OZONE        !! sf=1 offset=97462
      integer(kind=4) ,dimension(PN,SNOT)     :: FG_QI_SURFACE_TEMPERATURE      !! sf=1 offset=97582
      real(kind=4)    ,dimension(NLT,PN,SNOT) :: ATMOSPHERIC_TEMPERATURE        !! sf=2 offset=97702
      real(kind=4)    ,dimension(NLQ,PN,SNOT) :: ATMOSPHERIC_WATER_VAPOUR       !! sf=7 offset=121942
      real(kind=4)    ,dimension(NLO,PN,SNOT) :: ATMOSPHERIC_OZONE              !! sf=8 offset=170422
      real(kind=4)    ,dimension(PN,SNOT) :: SURFACE_TEMPERATURE                !! sf=2 offset=194662
      real(kind=4)    ,dimension(PN,SNOT) :: INTEGRATED_WATER_VAPOUR            !! sf=2 offset=194902
      real(kind=4)    ,dimension(PN,SNOT) :: INTEGRATED_OZONE                   !! sf=6 offset=195142
      real(kind=4)    ,dimension(PN,SNOT) :: INTEGRATED_N2O                     !! sf=6 offset=195382
      real(kind=4)    ,dimension(PN,SNOT) :: INTEGRATED_CO                      !! sf=7 offset=195622
      real(kind=4)    ,dimension(PN,SNOT) :: INTEGRATED_CH4                     !! sf=6 offset=195862
      real(kind=4)    ,dimension(PN,SNOT) :: INTEGRATED_CO2                     !! sf=3 offset=196102
      real(kind=4)    ,dimension(NEW)     :: SURFACE_EMISSIVITY                 !! sf=4 offset=196342
      integer(kind=4) ,dimension(PN,SNOT)   :: NUMBER_CLOUD_FORMATIONS          !! sf=0 offset=199222
      integer(kind=4) ,dimension(3,PN,SNOT) :: FRACTIONAL_CLOUD_COVER           !! sf=2 offset=199342
      real(kind=4)    ,dimension(3,PN,SNOT) :: CLOUD_TOP_TEMPERATURE            !! sf=2 offset=200062
      real(kind=4)    ,dimension(3,PN,SNOT) :: CLOUD_TOP_PRESSURE               !! sf=0 offset=200782
      integer(kind=4) ,dimension(3,PN,SNOT) :: CLOUD_PHASE                      !! sf=0 offset=202222
      real(kind=4)    ,dimension(PN,SNOT)   :: SURFACE_PRESSURE                 !! sf=0 offset=202582
      integer(kind=4)                       :: INSTRUMENT_MODE                  !! sf=0 offset=203062
      real(kind=4)                          :: SPACECRAFT_ALTITUDE              !! sf=1 offset=203063
      real(kind=4)    ,dimension(4,PN,SNOT):: ANGULAR_RELATION                  !! sf=2 offset=203067
      real(kind=4)    ,dimension(2,PN,SNOT):: EARTH_LOCATION                    !! sf=4 offset=204027
      integer(kind=1) ,dimension(PN,SNOT) :: FLG_AMSUBAD                        !! sf=n offset=204987
      integer(kind=1) ,dimension(PN,SNOT) :: FLG_AVHRRBAD                       !! sf=n offset=205107
      integer(kind=1) ,dimension(PN,SNOT) :: FLG_CLDFRM                         !! sf=n offset=205227
      integer(kind=1) ,dimension(PN,SNOT) :: FLG_CLDNES                         !! sf=n offset=205347
      integer(kind=2) ,dimension(PN,SNOT) :: FLG_CLDTST                         !! sf=n offset=205467
      integer(kind=1) ,dimension(PN,SNOT) :: FLG_DAYNIT                         !! sf=n offset=205707
      integer(kind=1) ,dimension(PN,SNOT) :: FLG_DUSTCLD                        !! sf=1 offset=205827
      integer(kind=2) ,dimension(PN,SNOT) :: FLG_FGCHECK                        !! sf=n offset=205947
      integer(kind=1) ,dimension(PN,SNOT) :: FLG_IASIBAD                        !! sf=n offset=206187
      integer(kind=1) ,dimension(PN,SNOT) :: FLG_INITIA                         !! sf=n offset=206307
      integer(kind=1) ,dimension(PN,SNOT) :: FLG_ITCONV                         !! sf=n offset=206427
      integer(kind=1) ,dimension(PN,SNOT) :: FLG_LANSEA                         !! sf=n offset=206547
      integer(kind=1) ,dimension(PN,SNOT) :: FLG_MHSBAD                         !! sf=n offset=206667
      integer(kind=1) ,dimension(PN,SNOT) :: FLG_NUMIT                          !! sf=0 offset=206787
      integer(kind=1) ,dimension(PN,SNOT) :: FLG_NWPBAD                         !! sf=n offset=206907
      integer(kind=1) ,dimension(PN,SNOT) :: FLG_PHYSCHECK                      !! sf=n offset=207027
      integer(kind=2) ,dimension(PN,SNOT) :: FLG_RETCHECK                       !! sf=n offset=207147
      integer(kind=1) ,dimension(PN,SNOT) :: FLG_SATMAN                         !! sf=n offset=207387
      integer(kind=1) ,dimension(PN,SNOT) :: FLG_SUNGLNT                        !! sf=n offset=207507
      integer(kind=1) ,dimension(PN,SNOT) :: FLG_THICIR                         !! sf=n offset=207627
    end type RECORD_MDR_L2

   type RECORD_GIADR_L2
      integer(kind=1)                    :: NUM_PRESSURE_LEVELS_TEMP          !! sf=0 offset=20
      real(kind=4) ,dimension(NLT)       :: PRESSURE_LEVELS_TEMP              !! sf=2 offset=21
      integer(kind=1)                    :: NUM_PRESSURE_LEVELS_HUMIDITY      !! sf=0 offset=425
      real(kind=4) ,dimension(NLQ)       :: PRESSURE_LEVELS_HUMIDITY          !! sf=2 offset=426
      integer(kind=1)                    :: NUM_PRESSURE_LEVELS_OZONE         !! sf=0 offset=830
      real(kind=4) ,dimension(NLO)       :: PRESSURE_LEVELS_OZONE             !! sf=2 offset=831
      integer(kind=1)                    :: NUM_SURFACE_EMISSIVITY_WAVELENGTH !! sf=0 offset=1235
      real(kind=4) ,dimension(NEW)       :: SURFACE_EMISSIVITY_WAVELENGTH     !! sf=4 offset=1236
      integer(kind=1)                    :: NUM_TEMPERATURE_PCS               !! sf=0 offset=1284
      integer(kind=1)                    :: NUM_WATER_VAPOUR_PCS              !! sf=0 offset=1285
      integer(kind=1)                    :: NUM_OZONE_PCS                     !! sf=0 offset=1286
      integer(kind=1)                    :: FORLI_NUM_LAYERS_CO               !! sf=0 offset=1287
      real(kind=4)    ,dimension(NL_CO)  :: FORLI_LAYERS_HEIGHTS_CO           !! sf=0 offset=1288
      integer(kind=1)                    :: FORLI_NUM_LAYERS_HNO3             !! sf=0 offset=1326
      real(kind=4)    ,dimension(NL_HNO3):: FORLI_LAYERS_HEIGHTS_HNO3         !! sf=0 offset=1327
      integer(kind=1)                    :: FORLI_NUM_LAYERS_O3               !! sf=0 offset=1365
      real(kind=4)    ,dimension(NL_O3)  :: FORLI_LAYERS_HEIGHTS_O3           !! sf=0 offset=1366
      integer(kind=1)                    :: BRESCIA_NUM_ALTITUDES_SO2         !! sf=0 offset=1446
      real(kind=4)    ,dimension(NL_SO2) :: BRESCIA_ALTITUDES_SO2             !! sf=0 offset=1447
   end type RECORD_GIADR_L2

   type L2_GRANULE
      integer(kind=4)                                :: nb_lines
      type(RECORD_MDR_L2), dimension(:),allocatable  :: mdr_l2
      type(RECORD_GIADR_L2)                          :: giadr_l2
   end type L2_GRANULE
  
   ! Module interfaces
   interface vint42r4
      module procedure vint42r4_0d, vint42r4_1d
   end interface
   private :: vint42r4_0d, vint42r4_1d

contains

   subroutine read_l1eng_file(fname, granule)
      implicit none
      ! Variables
      character(len=500)       , intent(in)               :: fname
      type(L1_ENG_VER_GRANULE) , intent(inout)            :: granule
      ! Internal variables
      integer(kind=4)                                     :: uin 
      type(RECORD_ID)                                     :: recs(MAX_RECORDS)
      type(RECORD_ID)                                     :: recv(MAX_RECORDS)
      integer(kind=4)                                     :: k, j
      
      
      ! Get list of records and scale factors
      call read_l1eng_file_recs( fname, granule%nb_eng, granule%nb_viadr, &
                                 recs, recv, granule%giadr_l1eng )
      write(*,*) 'l1eng nb-mdr nb-viadr ', granule%nb_eng, granule%nb_viadr
      ! Open file
      uin = getFileUnit()
      open(unit=uin, file=fname, access='stream', status='old',&
           action='read', convert='big_endian')
      
      ! Read mdr lines
      allocate(granule%mdr_l1eng(granule%nb_eng))
      do k = 1, granule%nb_eng
         call read_mdr_l1eng( uin, recs(k)%pos,    &
                              granule%mdr_l1eng(k) )
         granule%mdr_l1eng(k)%line = k
         !
         ! Date conversion
         do j = 1, SNOT
            granule%mdr_l1eng(k)%vdate(:,j) =                    &
                   time_sct2date(granule%mdr_l1eng(k)%GEPSDatIasi(j))
         end do
      end do
      
      ! Read viadr lines
      allocate(granule%viadr_l1eng(granule%nb_viadr))
      do k = 1, granule%nb_viadr
         call read_viadr_l1eng( uin, recv(k)%pos,      &
                                granule%viadr_l1eng(k) )
         granule%viadr_l1eng(k)%line = k
      end do
      
      ! Close file
      close(uin)
      return
   end subroutine read_l1eng_file

   subroutine read_l1eng_file_recs( fname, nrecs, nrecv, recs, recv,&
                                    giadr_l1eng )
      implicit none
      ! Arguments
      character(len=500), intent(in)                  :: fname
      integer(kind=4)   , intent(out)                 :: nrecs
      integer(kind=4)   , intent(out)                 :: nrecv
      type(RECORD_ID)   , intent(out)                 :: recs(MAX_RECORDS)
      type(RECORD_ID)   , intent(out)                 :: recv(MAX_RECORDS)
      type(RECORD_GIADR_ENGINEERING), intent(out)     :: giadr_l1eng
      ! internal variables
      integer(kind=4)                                 :: uin
      integer(kind=8)                                 :: fsize, fpos
      type(RECORD_HEADER)                             :: grh

100 format("line: ",I4,", pos: ", I10,", class:",I3, ", subclass:",I3, ", version:",I3, ", size: ",I10)

      inquire(file=fname, size=fsize)
      uin = getFileUnit()
      ! Open file
      open(unit=uin, file=fname, access='stream', status='old',&
           action='read', convert='big_endian', err=999)
      fpos = 1
      nrecs = 0
      nrecv = 0
      do while(fpos < fsize)
         ! read generic record header
         call read_grh(uin, fpos, grh)
         call print_grh(grh)
         
         ! if record is a giadr_engineering
         if (grh%RECORD_CLASS==5 .and. grh%RECORD_SUBCLASS==2) then 
            call read_giadr_l1eng(uin, fpos, giadr_l1eng)
         endif
         
         ! if record is a viadr_engineering, fill record list
         if (grh%RECORD_CLASS==7 .and. grh%RECORD_SUBCLASS==0) then 
            nrecv = nrecv + 1
            recv(nrecv)%cl  = grh%RECORD_CLASS
            recv(nrecv)%scl = grh%RECORD_SUBCLASS
            recv(nrecv)%pos = fpos
         endif

         ! if record is a mdr-l1eng, fill record list
         if (grh%RECORD_CLASS==8 .and. grh%RECORD_SUBCLASS==3) then
            nrecs = nrecs + 1
            recs(nrecs)%cl  = grh%RECORD_CLASS
            recs(nrecs)%scl = grh%RECORD_SUBCLASS
            recs(nrecs)%pos = fpos
         endif
         
         !write(*,100) nrecs, fpos, grh%RECORD_CLASS, grh%RECORD_SUBCLASS, &
         !             grh%RECORD_SUBCLASS_VERSION, grh%RECORD_SIZE

         ! Update position in file stream
         fpos = fpos + grh%RECORD_SIZE
      enddo
      close(uin)
      return
  999 write(0,*) 'file open error',uin, trim(fname)
   end subroutine read_l1eng_file_recs

   subroutine read_mdr_l1eng(uin, line_pos, l1eng)
      implicit none
      ! Arguments
      integer(kind=4), intent(in)                    :: uin
      integer(kind=8), intent(in)                    :: line_pos
      type(RECORD_MDR_ENGINEERING), intent(out)      :: l1eng
      ! internal variables
      integer(kind=4)                                :: i, j, k, l, m, n, LL
      integer(kind=4)                                :: offset
      integer(kind=4)                                :: offset_PX
      integer(kind=4)                                :: vali4
      integer(kind=4)     , dimension(16)            :: bit
      integer(kind=2)                                :: vali2
      integer(kind=2)                                :: vali2_a
      integer(kind=2)                                :: vali2_b
      integer(kind=2)     , dimension(PN*SNOT)       :: vali2PNSNOT
      integer(kind=2)     , dimension(PN*SNOT)       :: vali2PNSNOT_a
      integer(kind=2)     , dimension(PN*SNOT)       :: vali2PNSNOT_b
      integer(kind=2)     , dimension(148)           :: vali2148
      integer(kind=1)                                :: vali1
      byte                                           :: vali1_a
      byte                                           :: vali1_b
      integer(kind=4)     , dimension(SNOT)          :: vali4SNOT
      real(kind=4)                                   :: valr4
      real(kind=4)        , dimension(SB*PN*SNOT)    :: valr4SBPNSNOT
      real(kind=4)        , dimension(PN*SNOT)       :: valr4PNSNOT
      integer(kind=2)     , dimension(HUIT*PN*SNOT)  :: vali2HUITPNSNOT_a
      integer(kind=2)     , dimension(DIX*PN*SNOT)   :: vali2DIXPNSNOT_a
      integer(kind=2)     , dimension(HUIT*PN*SNOT)  :: vali2HUITPNSNOT_b
      integer(kind=2)     , dimension(DIX*PN*SNOT)   :: vali2DIXPNSNOT_b
      real(kind=4)        , dimension(SB)            :: valr4SB
      real(kind=4)        , dimension(8)             :: valr48
      real(kind=4)        , dimension(10)            :: valr410
      real(kind=8)                                   :: valr8
      real(kind=8)        , dimension(2)             :: valr82
      real(kind=8)        , dimension(2*PN)          :: valr82PN
      real(kind=8)        , dimension(SNOT)          :: valr8SNOT
      real(kind=8)        , dimension(2*SNOT)        :: valr82SNOT
      real(kind=8)        , dimension(2*PN*SNOT)     :: valr82PNSNOT
      real(kind=8)        , dimension(PN*SNOT)       :: valr8PNSNOT
      integer(kind=4)     , dimension(PN*SNOT)       :: vali4PNSNOT
      integer(kind=1)     , dimension(SNOT)          :: vali1SNOT
      integer(kind=1)     , dimension(PN*SNOT)       :: vali1PNSNOT
      integer(kind=1)     , dimension(SB*PN*SNOT)    :: vali1SBPNSNOT
      integer(kind=1)     , dimension(PN*CCD)        :: vali1PNCCD
      type(SHORT_CDS_TIME), dimension(SNOT)          :: date_iasi

      ! BIMSBBT
      offset = line_pos + 20
      read(uin, pos=offset) valr8
      l1eng%BIMSBBT = valr8
      ! GFtbFilteredBBT
      offset = line_pos + 28
      read(uin, pos=offset) valr8
      l1eng%GFtbFilteredBBT = valr8
      ! GEPSIasiMode
      offset = line_pos + 70
      vali2_a = 0
      read(uin, pos=offset) vali2_b
      call commute32bits2i4( vali2_a, vali2_b, valr4 )
      l1eng%GEPSIasiMode = int(valr4)
!!$      write(*,*) 'l1eng%GEPSIasiMode ', l1eng%GEPSIasiMode
      ! GEPSDatIasi
      offset = line_pos + 796
      read(uin, pos=offset) l1eng%GEPSDatIasi
      ! GEPS_SP
      offset = line_pos + 980
      read(uin, pos=offset) vali4SNOT
      l1eng%GEPS_SP = vali4SNOT
      ! GEPS_CCD
      offset = line_pos + 1100
      read(uin, pos=offset) vali1SNOT
      l1eng%GEPS_CCD(1:SNOT) = vali1SNOT(1:SNOT)
      ! GGeoSubSatellitePosition
      offset = line_pos + 1130
      read(uin, pos=offset) valr82
      l1eng%GGeoSubSatellitePosition(1:2) = valr82(1:2)
      ! GEPSEndEclipseTime
      offset = line_pos + 1147
      read(uin, pos=offset) date_iasi(1)
      l1eng%GEPSEndEclipseTime = date_iasi(1)
      ! GSmeTScan
      offset = line_pos + 1153
      read(uin, pos=offset) valr8
      l1eng%GSmeTScan = valr8
      ! GSmeFlagDateNOK
      offset = line_pos + 1161
      read(uin, pos=offset) vali1
      l1eng%GSmeFlagDateNOK = vali1
      ! GFtbBBTRes
      offset = line_pos + 1162
      read(uin, pos=offset) valr8
      l1eng%GFtbBBTRes = valr8
      ! GFtbFlagBBTNonQual
      offset = line_pos + 1170
      read(uin, pos=offset) vali1
      l1eng%GFtbFlagBBTNonQual = vali1
      ! GEPS_LN
      offset = line_pos + 1171
      read(uin, pos=offset) vali4
      l1eng%GEPS_LN = vali4
      ! GDocFlagUnderOverFlow
      offset = line_pos + 1175
      read(uin, pos=offset) vali1PNSNOT
      l1eng%GDocFlagUnderOverFlow(1:PN,1:SNOT) = &
                          reshape(vali1PNSNOT(1:PN*SNOT),(/PN,SNOT/))
      ! GDocNbUnderFlow
      offset = line_pos + 1295
      read(uin, pos=offset) vali4PNSNOT
      l1eng%GDocNbUnderFlow(1:PN,1:SNOT) = &
                          reshape(vali4PNSNOT(1:PN*SNOT),(/PN,SNOT/))
      ! GDocNbOverFlow
      offset = line_pos + 1775
      read(uin, pos=offset) vali4PNSNOT
      l1eng%GDocNbOverFlow(1:PN,1:SNOT) = &
                          reshape(vali4PNSNOT(1:PN*SNOT),(/PN,SNOT/))
      ! GlacOffsetIISAvhrr
      offset = line_pos + 13775
      read(uin, pos=offset) valr82SNOT
      l1eng%GlacOffsetIISAvhrr = reshape(valr82SNOT(1:2*SNOT),(/2,SNOT/))
      ! GlacCorrelQual
      offset = line_pos + 14255
      read(uin, pos=offset) valr8SNOT
      l1eng%GlacCorrelQual(1:SNOT) = valr8SNOT(1:SNOT)
      ! GlacPosMaxQual
      offset = line_pos + 14495
      read(uin, pos=offset) valr8SNOT
      l1eng%GlacPosMaxQual(1:SNOT) = valr8SNOT(1:SNOT)
      ! GlacFlagCoregNonValid
      offset = line_pos + 14735
      read(uin, pos=offset) vali1SNOT
      l1eng%GlacFlagCoregNonValid(1:SNOT) = vali1SNOT(1:SNOT)
      ! GlacFlagCoregNonQual
      offset = line_pos + 14765
      read(uin, pos=offset) vali1SNOT
      l1eng%GlacFlagCoregNonQual(1:SNOT) = vali1SNOT(1:SNOT)
      ! GIacVarImagIIS
      offset = line_pos + 14795
      read(uin, pos=offset) valr8SNOT
      l1eng%GIacVarImagIIS(1:SNOT) = valr8SNOT(1:SNOT)
      ! GIacAvgImagIIS
      offset = line_pos + 15035
      read(uin, pos=offset) valr8SNOT
      l1eng%GIacAvgImagIIS(1:SNOT) = valr8SNOT(1:SNOT)
      ! GEUMAvhrr1BCldFrac
      offset = line_pos + 15275
      read(uin, pos=offset) vali1PNSNOT
      l1eng%GEUMAvhrr1BCldFrac(1:PN,1:SNOT) = &
                          reshape(vali1PNSNOT(1:PN*SNOT),(/PN,SNOT/))
      ! GEUMAvhrr1BLandFrac
      offset = line_pos + 15395
      read(uin, pos=offset) vali1PNSNOT
      l1eng%GEUMAvhrr1BLandFrac(1:PN,1:SNOT) = &
                          reshape(vali1PNSNOT(1:PN*SNOT),(/PN,SNOT/))
      ! GEUMAvhrr1BQual
      offset = line_pos + 15515
      read(uin, pos=offset) vali1PNSNOT
      l1eng%GEUMAvhrr1BQual(1:PN,1:SNOT) = &
                          reshape(vali1PNSNOT(1:PN*SNOT),(/PN,SNOT/))
      ! GCcsOffsetSondAvhrr
      offset = line_pos + 15635
      read(uin, pos=offset) valr82PNSNOT
      l1eng%GCcsOffsetSondAvhrr(1:2,1:PN,1:SNOT) = &
                     reshape(valr82PNSNOT(1:2*PN*SNOT),(/2,PN,SNOT/))
      ! GCcsOffsetSondIIS
      offset = line_pos + 17555
      read(uin, pos=offset) valr82PNSNOT
      l1eng%GCcsOffsetSondIIS(1:2,1:PN,1:SNOT) = &
                      reshape(valr82PNSNOT(1:2*PN*SNOT),(/2,PN,SNOT/))
      ! GSsdWnShift
      offset = line_pos + 22836
      read(uin, pos=offset) valr8PNSNOT
      l1eng%GSsdWnShift(1:PN,1:SNOT) = &
                       reshape(valr8PNSNOT(1:PN*SNOT),(/PN,SNOT/))
      ! GSsdWnShiftQual
      offset = line_pos + 23796
      read(uin, pos=offset) valr8PNSNOT
      l1eng%GSsdWnShiftQual(1:PN,1:SNOT) = &
                       reshape(valr8PNSNOT(1:PN*SNOT),(/PN,SNOT/))
      ! GSssWnShiftMean
      offset = line_pos + 24876
      read(uin, pos=offset) valr82PN
      l1eng%GSssWnShiftMean(1:PN,1:2) = &
                       reshape(valr82PN(1:PN*2),(/PN,2/))
      ! GSssWnShiftMeanQual
      offset = line_pos + 24940
      read(uin, pos=offset) valr82PN
      l1eng%GSssWnShiftMeanQual(1:PN,1:2) = &
                       reshape(valr82PN(1:PN*2),(/PN,2/))
      ! GSssFlagNonSelPix
      offset = line_pos + 25004
      read(uin, pos=offset) vali1PNCCD
      l1eng%GSssFlagNonSelPix(1:PN,1:2) = &
                       reshape(vali1PNCCD(1:PN*CCD),(/PN,CCD/))
      ! GlaxAxeY
      offset = line_pos + 25013
      read(uin, pos=offset) valr82
      l1eng%GlaxAxeY(1:2) = valr82(1:2) * Pi / 180.0
      ! GlaxAxeZ
      offset = line_pos + 25029
      read(uin, pos=offset) valr82
      l1eng%GlaxAxeZ(1:2) = valr82(1:2) * Pi / 180.0
      ! GFaxAxeY
      offset = line_pos + 25079
      read(uin, pos=offset) valr82
      l1eng%GFaxAxeY(1:2) = valr82(1:2) * Pi / 180.0
      ! GFaxAxeZ
      offset = line_pos + 25095
      read(uin, pos=offset) valr82
      l1eng%GFaxAxeZ(1:2) = valr82(1:2) * Pi / 180.0
      ! GQisFlagQual
      offset = line_pos + 49708
      read(uin, pos=offset) vali1SBPNSNOT
      l1eng%GQisFlagQual(1:SB,1:PN,1:SNOT) = &
                          reshape(vali1SBPNSNOT(1:SB*PN*SNOT),(/SB,PN,SNOT/))
      ! Data_PX size SN*PN*148*2 octets
      offset_PX = line_pos + 84957
!!$      k = 1
!!$      do i = 1, 148
!!$         offset = offset_PX + (2*120*(k-1))
!!$         read(uin, pos=offset) vali2PNSNOT
!!$         write(*,*) i+3,(vali2PNSNOT(l),l=1,120)
!!$         k = k + 1
!!$      end do
      ! Day Word 4-3
      k = 4-3
      offset = offset_PX + (2*PN*SNOT*(k-1))
      read(uin, pos=offset) vali2PNSNOT
      l1eng%ENG_PX%Day(1:PN,1:SNOT) = &
                       reshape(vali2PNSNOT(1:PN*SNOT),(/PN,SNOT/))
      ! msec Word 5-3 6-3
      k = 5-3
      offset = offset_PX + (2*PN*SNOT*(k-1))
      read(uin, pos=offset) vali2PNSNOT
      l1eng%ENG_PX%ms(1:PN,1:SNOT) = &
                       reshape(vali2PNSNOT(1:PN*SNOT),(/PN,SNOT/)) * 2**16
      k = 6-3
      offset = offset_PX + (2*PN*SNOT*(k-1))
      read(uin, pos=offset) vali2PNSNOT
      l1eng%ENG_PX%ms(1:PN,1:SNOT) = l1eng%ENG_PX%ms(1:PN,1:SNOT) &
                     + reshape(vali2PNSNOT(1:PN*SNOT),(/PN,SNOT/))
      ! NS_Rpd Word 11-3
      k = 11-3
      offset = offset_PX + (2*PN*SNOT*(k-1))
      read(uin, pos=offset) vali2PNSNOT
      do j = 1, SNOT
         do i = 1, PN
            if( vali2PNSNOT((j-1)*PN+i) < 0 ) then
               vali4 = vali2PNSNOT((j-1)*PN+i) + 2**16
            else
               vali4 = vali2PNSNOT((j-1)*PN+i)
            end if
            l1eng%ENG_PX%NS_Rpd(i,j) = vali4
         end do
      end do
      ! SN SP Word 12-3
      k = 12-3
      offset = offset_PX + (2*PN*SNOT*(k-1))
      read(uin, pos=offset) vali2PNSNOT
      do j = 1, SNOT
         do i = 1, PN
            call split16_8(vali2PNSNOT((j-1)*PN+i),vali1_a,vali1_b)
            l1eng%ENG_PX%SN(i,j) = vali1_a
            l1eng%ENG_PX%SP(i,j) = vali1_b
         end do
      end do
      ! Word 13-3
      k = 13-3
      offset = offset_PX + (2*PN*SNOT*(k-1))
      read(uin, pos=offset) vali2PNSNOT
      do j = 1, SNOT
         do i = 1, PN
            call commute16bits2bit(vali2PNSNOT((j-1)*PN+i),bit)
            l1eng%ENG_PX%CD(i,j)  = bit(16)
            l1eng%ENG_PX%CSQ(i,j) = bit(15)
            l1eng%ENG_PX%SQ1(i,j) = bit(14)
            l1eng%ENG_PX%SQ2(i,j) = bit(13)
            l1eng%ENG_PX%IEQ(i,j) = bit(12)
            l1eng%ENG_PX%SN_NV(i,j)  = bit(8)
            l1eng%ENG_PX%CD_NV(i,j)  = bit(7)
            l1eng%ENG_PX%CSQ_NV(i,j) = bit(6)
            l1eng%ENG_PX%SP_NV(i,j)  = bit(5)
            l1eng%ENG_PX%SQ1_NV(i,j) = bit(4)
            l1eng%ENG_PX%SQ2_NV(i,j) = bit(3)
            l1eng%ENG_PX%NS_NV(i,j)  = bit(2)
            l1eng%ENG_PX%IEQ_NV(i,j) = bit(1)
         end do
      end do
      ! PTSI Word 16-3 17-3
      k = 16-3
      offset = offset_PX + (2*PN*SNOT*(k-1))
      read(uin, pos=offset) vali2PNSNOT
      l1eng%ENG_PX%PTSIMSW(1:PN,1:SNOT) = &
                       reshape(vali2PNSNOT(1:PN*SNOT),(/PN,SNOT/))
      k = 17-3
      offset = offset_PX + (2*PN*SNOT*(k-1))
      read(uin, pos=offset) vali2PNSNOT
      l1eng%ENG_PX%PTSILSW(1:PN,1:SNOT) = &
                       reshape(vali2PNSNOT(1:PN*SNOT),(/PN,SNOT/))
      ! LN Word 18-3
      k = 18-3
      offset = offset_PX + (2*PN*SNOT*(k-1))
      read(uin, pos=offset) vali2PNSNOT
      l1eng%ENG_PX%LN(1:PN,1:SNOT) = &
                       reshape(vali2PNSNOT(1:PN*SNOT),(/PN,SNOT/))
      ! InstrumentMode Word 19
      k = 19-3
      offset = offset_PX + (2*PN*SNOT*(k-1))
      read(uin, pos=offset) vali2PNSNOT
      l1eng%ENG_PX%INS_MOD(1:PN,1:SNOT) = &
                       reshape(vali2PNSNOT(1:PN*SNOT),(/PN,SNOT/))
      ! PN Word 21-3
      k = 21-3
      offset = offset_PX + (2*PN*SNOT*(k-1))
      read(uin, pos=offset) vali2PNSNOT
      l1eng%ENG_PX%PIXEL(1:PN,1:SNOT) = &
                       reshape(vali2PNSNOT(1:PN*SNOT),(/PN,SNOT/))
      ! BdcoNbReceivedWords Word 22-3
      k = 22-3
      offset = offset_PX + (2*PN*SNOT*(k-1))
      read(uin, pos=offset) vali2PNSNOT
      do j = 1, SNOT
         do i = 1, PN
            if( vali2PNSNOT((j-1)*PN+i) < 0 ) then
               vali4 = vali2PNSNOT((j-1)*PN+i) + 2**16
            else
               vali4 = vali2PNSNOT((j-1)*PN+i)
            end if
            l1eng%ENG_PX%BdcoNbReceivedWords(i,j) = vali4
         end do
      end do
      ! BNlcAnaMV Word 23-3 28-3
      do l = 1, SB
         k = 23-3+2*(l-1)
         offset = offset_PX + (2*PN*SNOT*(k-1))
         read(uin, pos=offset) vali2PNSNOT_a
         k = 24-3+2*(l-1)
         offset = offset_PX + (2*PN*SNOT*(k-1))
         read(uin, pos=offset) vali2PNSNOT_b
         do j = 1, SNOT
            do i = 1, PN
               call commute32bits2r4( vali2PNSNOT_a((j-1)*PN+i), &
                                      vali2PNSNOT_b((j-1)*PN+i), valr4 )
               l1eng%ENG_PX%BNlcAnaMV(l,i,j) = valr4
            end do
         end do
      end do
      ! BZpdNzpd Word 29-3
      k = 29-3
      offset = offset_PX + (2*PN*SNOT*(k-1))
      read(uin, pos=offset) vali2PNSNOT
      l1eng%ENG_PX%BZpdNzpd(1:PN,1:SNOT) = &
                       reshape(vali2PNSNOT(1:PN*SNOT),(/PN,SNOT/))
      ! BzpdNzpdQualIndexEW Word 30-3 31-3
      k = 30-3
      offset = offset_PX + (2*PN*SNOT*(k-1))
      read(uin, pos=offset) vali2PNSNOT_a
      k = 31-3
      offset = offset_PX + (2*PN*SNOT*(k-1))
      read(uin, pos=offset) vali2PNSNOT_b
      do j = 1, SNOT
         do i = 1, PN
            call commute32bits2r4( vali2PNSNOT_a((j-1)*PN+i), &
                                   vali2PNSNOT_b((j-1)*PN+i), valr4 )
            l1eng%ENG_PX%BzpdNzpdQualIndexEW(i,j) = valr4
         end do
      end do
      ! BArcImagMean Word 32-3 48-3 68-3
      n = 0
      do m = 1, SB
         if( m == 1 ) then
            LL = HUIT
         else
            LL = DIX
         end if
         do l = 1, LL
            n = n + 1
            k = 32-3+2*(n-1)
            offset = offset_PX + (2*PN*SNOT*(k-1))
            read(uin, pos=offset) vali2PNSNOT_a
            k = 33-3+2*(n-1)
            offset = offset_PX + (2*PN*SNOT*(k-1))
            read(uin, pos=offset) vali2PNSNOT_b
            do j = 1, SNOT
               do i = 1, PN
                  call commute32bits2r4( vali2PNSNOT_a((j-1)*PN+i), &
                                         vali2PNSNOT_b((j-1)*PN+i), valr4 )
                  l1eng%ENG_PX%BArcImagMean(l,m,i,j) = valr4
               end do
            end do
         end do
      end do
     ! BArcImagRMS Word 88-3 104-3 124-3
      n = 0
      do m = 1, SB
         if( m == 1 ) then
            LL = HUIT
         else
            LL = DIX
         end if
         do l = 1, LL
            n = n + 1
            k = 88-3+2*(n-1)
            offset = offset_PX + (2*PN*SNOT*(k-1))
            read(uin, pos=offset) vali2PNSNOT_a
            k = 89-3+2*(n-1)
            offset = offset_PX + (2*PN*SNOT*(k-1))
            read(uin, pos=offset) vali2PNSNOT_b
            do j = 1, SNOT
               do i = 1, PN
                  call commute32bits2r4( vali2PNSNOT_a((j-1)*PN+i), &
                                         vali2PNSNOT_b((j-1)*PN+i), valr4 )
                  l1eng%ENG_PX%BArcImagRMS(l,m,i,j) = valr4
               end do
            end do
         end do
      end do
      ! BArcImagMeanRMS Word 144-3 146-3 148-3
      do l = 1, SB
         k = 144-3+2*(l-1) 
         offset = offset_PX + (2*PN*SNOT*(k-1))
         read(uin, pos=offset) vali2PNSNOT_a
         k = 145-3+2*(l-1) 
         offset = offset_PX + (2*PN*SNOT*(k-1))
         read(uin, pos=offset) vali2PNSNOT_b
         do j = 1, SNOT
            do i = 1, PN
               call commute32bits2r4( vali2PNSNOT_a((j-1)*PN+i), &
                                      vali2PNSNOT_b((j-1)*PN+i), valr4 )
               l1eng%ENG_PX%BArcImagMeanRMS(l,i,j) = valr4
            end do
         end do
      end do
      ! Flag Word 150-3
      k = 150-3
      offset = offset_PX + (2*PN*SNOT*(k-1))
      read(uin, pos=offset) vali2PNSNOT
      do j = 1, SNOT
         do i = 1, PN
            call commute16bits2bit(vali2PNSNOT((j-1)*PN+i),bit)
            l1eng%ENG_PX%BBofFlagSpectNonQual(i,j)  = int(bit(14),2)
            l1eng%ENG_PX%BDcoFlagMasErrorPath(1:SB,i,j) = bit(13:11:-1)
            l1eng%ENG_PX%BDcoFlagMasOverFlow(1:SB,i,j) = bit(10:8:-1)
            l1eng%ENG_PX%BDcoFlagMasEcret(1:SB,i,j)  = bit(7:5:-1)
            l1eng%ENG_PX%BdcoFlagMasErrorNbWords(i,j) = bit(4)
         end do
      end do
      ! Flag Word 151-3
      k = 151-3
      offset = offset_PX + (2*PN*SNOT*(k-1))
      read(uin, pos=offset) vali2PNSNOT
      do j = 1, SNOT
         do i = 1, PN
            call commute16bits2bit(vali2PNSNOT((j-1)*PN+i),bit)
            l1eng%ENG_PX%BSpkFlagSpik(1:SB,i,j)  = bit(16:14:-1)
            l1eng%ENG_PX%BzpdFlagNzpdNonQualEW(i,j) = bit(13)
            l1eng%ENG_PX%BIsiFlagErrorFft(1:SB,i,j) = bit(12:10:-1)
            l1eng%ENG_PX%BArcFlagCalSpectNonQual(1:SB,i,j) = bit(9:7:-1)
            l1eng%ENG_PX%BCodFlagFlood(i,j)  = bit(6)
            l1eng%ENG_PX%BDcoFlagErrorInterf(1:SB,i,j) = bit(5:3:-1)
         end do
      end do
      return
   end subroutine read_mdr_l1eng

   subroutine read_l1ver_file(fname, granule)
      implicit none
      ! Variables
      character(len=500)       , intent(in)               :: fname
      type(L1_ENG_VER_GRANULE) , intent(inout)            :: granule
      ! Internal variables
      integer(kind=4)                                     :: uin 
      type(RECORD_ID)                                     :: recs(MAX_RECORDS)
      integer(kind=4)                                     :: k
      
      
      ! Get list of records and scale factors
      call read_l1ver_file_recs( fname, granule%nb_ver, recs )
      write(*,*) 'L1ver nb-mdr ', granule%nb_ver
      ! Open file
      uin = getFileUnit()
      open(unit=uin, file=fname, access='stream', status='old',&
           action='read', convert='big_endian')
      
      ! Read mdr lines
      allocate(granule%mdr_l1ver(granule%nb_ver))
      do k = 1, granule%nb_ver
         call read_mdr_l1ver( uin, recs(k)%pos,    &
                              granule%mdr_l1ver(k) )
         granule%mdr_l1ver(k)%line = k
      end do
      
      ! Close file
      close(uin)
      return
   end subroutine read_l1ver_file

   subroutine read_l1ver_file_recs( fname, nrecs, recs )
      implicit none
      ! Arguments
      character(len=500), intent(in)                  :: fname
      integer(kind=4)   , intent(out)                 :: nrecs
      type(RECORD_ID)   , intent(out)                 :: recs(MAX_RECORDS)
      ! internal variables
      integer(kind=4)                                 :: uin
      integer(kind=8)                                 :: fsize, fpos
      type(RECORD_HEADER)                             :: grh

100 format("line: ",I4,", pos: ", I10,", class:",I3, ", subclass:",I3, ", version:",I3, ", size: ",I10)

      inquire(file=fname, size=fsize)
      uin = getFileUnit()
      ! Open file
      open(unit=uin, file=fname, access='stream', status='old',&
           action='read', convert='big_endian', err=999)
      fpos = 1
      nrecs = 0
      do while(fpos < fsize)
         ! read generic record header
         call read_grh(uin, fpos, grh)
         call print_grh(grh)
         
         ! if record is a mdr-l1ver, fill record list
         if (grh%RECORD_CLASS==8 .and. grh%RECORD_SUBCLASS==4) then
            nrecs = nrecs + 1
            recs(nrecs)%cl  = grh%RECORD_CLASS
            recs(nrecs)%scl = grh%RECORD_SUBCLASS
            recs(nrecs)%pos = fpos
         endif
         
         !write(*,100) nrecs, fpos, grh%RECORD_CLASS, grh%RECORD_SUBCLASS, &
         !             grh%RECORD_SUBCLASS_VERSION, grh%RECORD_SIZE

         ! Update position in file stream
         fpos = fpos + grh%RECORD_SIZE
      enddo
      close(uin)
      return
  999 write(0,*) 'file open error',uin, trim(fname)
   end subroutine read_l1ver_file_recs

   subroutine read_mdr_l1ver(uin, line_pos, l1ver)
      implicit none
      ! Arguments
      integer(kind=4), intent(in)                    :: uin
      integer(kind=8), intent(in)                    :: line_pos
      type(RECORD_MDR_VERIFICATION), intent(out)     :: l1ver
      ! internal variables
      integer(kind=4)                                :: i, j, k, l, m, n, LL
      integer(kind=8)                                :: offset
      integer(kind=4)                                :: offset_AP_AIF
      integer(kind=4)                                :: offset_AP_ADF
      integer(kind=4)                                :: offset_VPA_A
      integer(kind=4)                                :: offset_VPB_A
      integer(kind=4)                                :: offset_VPC_A
      integer(kind=4)                                :: offset_VPD_A
      integer(kind=4)                                :: offset_VPE_A
      integer(kind=4)                                :: offset_VPA_D
      integer(kind=4)                                :: offset_VPB_D
      integer(kind=4)                                :: offset_VPC_D
      integer(kind=4)                                :: offset_VPD_D
      integer(kind=4)                                :: offset_VPE_D
      integer(kind=4)                                :: Word_a
      integer(kind=4)                                :: Word_b
      integer(kind=4)     , dimension(16)            :: bit
      integer(kind=4)                                :: vali4
      integer(kind=2)                                :: vali2
      integer(kind=2)                                :: vali2_a
      integer(kind=2)                                :: vali2_b
      byte                                           :: vali1_a
      byte                                           :: vali1_b
      real(kind=4)                                   :: valr4
      real(kind=4)                                   :: valr4_a
      real(kind=4)                                   :: valr4_b
      ! grh
      offset = line_pos + 0
      call read_grh(uin, offset, l1ver%grh)
      !
      ! SIZE_OF_VERIFICATION_DATA
      offset = line_pos + 20
      read(uin, pos=offset) vali4
      l1ver%SIZE_OF_VERIFICATION_DATA = vali4
      !
      ! AUXILLARY ANCILLARY INFO FIELD (70 Words)
      offset_AP_AIF = line_pos + 24
      call read_auxillary_aif( uin, offset_AP_AIF, l1ver%aux )
      !
      ! AUXILLARY APPLICATION DATA FIELD (320 +1 Words)
      offset_AP_ADF = offset_AP_AIF + 2*70
      call read_auxillary_adf( uin, offset_AP_ADF, l1ver%aux )
      !
      ! VPA ANCILLARY INFO FIELD (VPA VPB VPC VPD VPE)
      offset_VPA_A = offset_AP_AIF + 2*391
      call read_aivp( uin, offset_VPA_A, l1ver%vpa(1) )
      !
      ! VPA Application Data
      offset_VPA_D = offset_VPA_A + 2*40
      allocate( l1ver%vpd%IF_MAS(l1ver%vpa(1)%BdcoNbReceivedWords) )
      Word_a = ( l1ver%vpa(1)%BdcoNbReceivedWords &
                + mod( l1ver%vpa(1)%BdcoNbReceivedWords , 2 ) ) / 2
      do i = 1, Word_a
         k = (i-1)*2
         offset = offset_VPA_D + k
         read(uin, pos=offset) vali2
         l1ver%vpd%IF_MAS(i) = vali2
      end do
      !
      ! VPB ANCILLARY INFO FIELD
      offset_VPB_A = offset_VPA_D + 2*Word_a + 2
      call read_aivp( uin, offset_VPB_A, l1ver%vpa(2) )
      !
      ! VPB Application Data
      offset_VPB_D = offset_VPB_A + 2*40
      Word_b = ( l1ver%vpa(1)%BdcoNbReceivedWords &
                - mod( l1ver%vpa(1)%BdcoNbReceivedWords , 2 ) ) / 2
      do i = 1, Word_b
         k = (i-1)*2
         j = i + Word_a
         offset = offset_VPB_D + k
         read(uin, pos=offset) vali2
         l1ver%vpd%IF_MAS(j) = vali2
      end do
      !
      ! VPC ANCILLARY INFO FIELD
      offset_VPC_A = offset_VPB_D + 2*Word_b + 2
      call read_aivp( uin, offset_VPC_A, l1ver%vpa(3) )
      !
      ! VPC Application Data
      allocate( l1ver%vpd%BFrsSrdCS(l1ver%vpa(1)%IZsbNslastSrd&
                                   -l1ver%vpa(1)%IZsbNsfirstSrd+1) )
      allocate( l1ver%vpd%BFrsSrdBB(l1ver%vpa(1)%IZsbNslastSrd&
                                   -l1ver%vpa(1)%IZsbNsfirstSrd+1) )
      allocate( l1ver%vpd%BFrcOffset(l1ver%vpa(1)%IUsbNslast&
                                    -l1ver%vpa(1)%IUsbNsfirst+1) )
      allocate( l1ver%vpd%BFrcSlope(l1ver%vpa(1)%IUsbNslast&
                                   -l1ver%vpa(1)%IUsbNsfirst+1) )
      offset_VPC_D = offset_VPC_A + 2*40
      k = -1
      do i = 1, l1ver%vpa(1)%IZsbNslastSrd-l1ver%vpa(1)%IZsbNsfirstSrd+1
         k = k + 1
         offset = offset_VPC_D + 2*k
         read(uin, pos=offset) vali2_a
         k = k + 1
         offset = offset_VPC_D + 2*k 
         read(uin, pos=offset) vali2_b
         call commute32bits2r4( vali2_a, vali2_b, valr4_a )
         k = k + 1
         offset = offset_VPC_D + 2*k
         read(uin, pos=offset) vali2_a
         k = k + 1
         offset = offset_VPC_D + 2*k
         read(uin, pos=offset) vali2_b
         call commute32bits2r4( vali2_a, vali2_b, valr4_b )
         l1ver%vpd%BFrsSrdCS(i) = dcmplx( valr4_a, valr4_b )
      end do
      offset_VPC_D = offset_VPC_D &
            + 8*(l1ver%vpa(1)%IZsbNslastSrd-l1ver%vpa(1)%IZsbNsfirstSrd+1)
      k = -1
      do i = 1, l1ver%vpa(1)%IZsbNslastSrd-l1ver%vpa(1)%IZsbNsfirstSrd+1
         k = k + 1
         offset = offset_VPC_D + 2*k
         read(uin, pos=offset) vali2_a
         k = k + 1
         offset = offset_VPC_D + 2*k
         read(uin, pos=offset) vali2_b
         call commute32bits2r4( vali2_a, vali2_b, valr4_a )
         k = k + 1
         offset = offset_VPC_D + 2*k
         read(uin, pos=offset) vali2_a
         k = k + 1
         offset = offset_VPC_D + 2*k
         read(uin, pos=offset) vali2_b
         call commute32bits2r4( vali2_a, vali2_b, valr4_b )
         l1ver%vpd%BFrsSrdBB(i) = dcmplx( valr4_a, valr4_b )
      end do
      offset_VPC_D = offset_VPC_D &
            + 8*(l1ver%vpa(1)%IZsbNslastSrd-l1ver%vpa(1)%IZsbNsfirstSrd+1)
      k = -1
      do i = 1, l1ver%vpa(1)%IUsbNslast-l1ver%vpa(1)%IUsbNsfirst+1
         k = k + 1
         offset = offset_VPC_D + 2*k
         read(uin, pos=offset) vali2_a
         k = k + 1
         offset = offset_VPC_D + 2*k
         read(uin, pos=offset) vali2_b
         call commute32bits2r4( vali2_a, vali2_b, valr4_a )
         k = k + 1
         offset = offset_VPC_D + 2*k
         read(uin, pos=offset) vali2_a
         k = k + 1
         offset = offset_VPC_D + 2*k
         read(uin, pos=offset) vali2_b
         call commute32bits2r4( vali2_a, vali2_b, valr4_b )
         l1ver%vpd%BFrcOffset(i) = dcmplx( valr4_a, valr4_b )
      end do
      offset_VPC_D = offset_VPC_D &
            + 8*(l1ver%vpa(1)%IUsbNslast-l1ver%vpa(1)%IUsbNsfirst+1)
      k = -1
      do i = 1, l1ver%vpa(1)%IUsbNslast-l1ver%vpa(1)%IUsbNsfirst+1
         k = k + 1
         offset = offset_VPC_D + 2*k
         read(uin, pos=offset) vali2_a
         k = k + 1
         offset = offset_VPC_D + 2*k
         read(uin, pos=offset) vali2_b
         call commute32bits2r4( vali2_a, vali2_b, valr4_a )
         k = k + 1
         offset = offset_VPC_D + 2*k
         read(uin, pos=offset) vali2_a
         k = k + 1
         offset = offset_VPC_D + 2*k
         read(uin, pos=offset) vali2_b
         call commute32bits2r4( vali2_a, vali2_b, valr4_b )
         l1ver%vpd%BFrcSlope(i) = dcmplx( valr4_a, valr4_b )
      end do
      offset_VPC_D = offset_VPC_D &
            + 8*(l1ver%vpa(1)%IUsbNslast-l1ver%vpa(1)%IUsbNsfirst+1)
      !
      ! VPD ANCILLARY INFO FIELD
      offset_VPD_A = offset_VPC_D + 2
      call read_aivp( uin, offset_VPD_A, l1ver%vpa(4) )
      allocate( l1ver%vpd%BCrcOffset(l1ver%vpa(1)%IUsbNslast&
                                    -l1ver%vpa(1)%IUsbNsfirst+1) )
      allocate( l1ver%vpd%BCrcSlope(l1ver%vpa(1)%IUsbNslast&
                                   -l1ver%vpa(1)%IUsbNsfirst+1) )
      ! VPD Application Data
      offset_VPD_D = offset_VPD_A + 2*40
      k = -1
      do i = 1, l1ver%vpa(1)%IUsbNslast-l1ver%vpa(1)%IUsbNsfirst+1
         k = k + 1
         offset = offset_VPD_D + 2*k
         read(uin, pos=offset) vali2_a
         k = k + 1
         offset = offset_VPD_D + 2*k
         read(uin, pos=offset) vali2_b
         call commute32bits2r4( vali2_a, vali2_b, valr4_a )
         k = k + 1
         offset = offset_VPD_D + 2*k
         read(uin, pos=offset) vali2_a
         k = k + 1
         offset = offset_VPD_D + 2*k
         read(uin, pos=offset) vali2_b
         call commute32bits2r4( vali2_a, vali2_b, valr4_b )
         l1ver%vpd%BCrcOffset(i) = dcmplx( valr4_a, valr4_b )
      end do
      offset_VPD_D = offset_VPD_D &
            + 8*(l1ver%vpa(1)%IUsbNslast-l1ver%vpa(1)%IUsbNsfirst+1)
      k = -1
      do i = 1, l1ver%vpa(1)%IUsbNslast-l1ver%vpa(1)%IUsbNsfirst+1
         k = k + 1
         offset = offset_VPD_D + 2*k
         read(uin, pos=offset) vali2_a
         k = k + 1
         offset = offset_VPD_D + 2*k
         read(uin, pos=offset) vali2_b
         call commute32bits2r4( vali2_a, vali2_b, valr4_a )
         k = k + 1
         offset = offset_VPD_D + 2*k
         read(uin, pos=offset) vali2_a
         k = k + 1
         offset = offset_VPD_D + 2*k
         read(uin, pos=offset) vali2_b
         call commute32bits2r4( vali2_a, vali2_b, valr4_b )
         l1ver%vpd%BCrcSlope(i) = dcmplx( valr4_a, valr4_b )
      end do
      offset_VPD_D = offset_VPD_D &
            + 8*(l1ver%vpa(1)%IUsbNslast-l1ver%vpa(1)%IUsbNsfirst+1)
      !
      ! VPE ANCILLARY INFO FIELD
      offset_VPE_A = offset_VPD_D + 2
      call read_aivp( uin, offset_VPE_A, l1ver%vpa(5) )
      ! VPE Application Data
      allocate( l1ver%vpd%BArcSpectb1(l1ver%vpa(1)%IOsbNsLastMb1b2&
                                     -l1ver%vpa(1)%IOsbNsfirstMb1b2+1) )
      allocate( l1ver%vpd%BArcSpectb21(l1ver%vpa(1)%IOsbNsLastMb1b2&
                                      -l1ver%vpa(1)%IOsbNsfirstMb1b2+1) )
      allocate( l1ver%vpd%BArcSpectb23(l1ver%vpa(1)%IOsbNsLastMb2b3&
                                     -l1ver%vpa(1)%IOsbNsfirstMb2b3+1) )
      allocate( l1ver%vpd%BArcSpectb3(l1ver%vpa(1)%IOsbNsLastMb2b3&
                                     -l1ver%vpa(1)%IOsbNsfirstMb2b3+1) )
      offset_VPE_D = offset_VPE_A + 2*40
      k = -1
      do i = 1, l1ver%vpa(1)%IOsbNsLastMb1b2-l1ver%vpa(1)%IOsbNsfirstMb1b2+1
         k = k + 1
         offset = offset_VPE_D + 2*k
         read(uin, pos=offset) vali2_a
         k = k + 1
         offset = offset_VPE_D + 2*k
         read(uin, pos=offset) vali2_b
         call commute32bits2r4( vali2_a, vali2_b, valr4 )
         l1ver%vpd%BArcSpectb1(i) = valr4
      end do
      offset_VPE_D = offset_VPE_D &
            + 4*(l1ver%vpa(1)%IOsbNsLastMb1b2-l1ver%vpa(1)%IOsbNsfirstMb1b2+1)
      k = -1
      do i = 1, l1ver%vpa(1)%IOsbNsLastMb1b2-l1ver%vpa(1)%IOsbNsfirstMb1b2+1
         k = k + 1
         offset = offset_VPE_D + 2*k
         read(uin, pos=offset) vali2_a
         k = k + 1
         offset = offset_VPE_D + 2*k
         read(uin, pos=offset) vali2_b
         call commute32bits2r4( vali2_a, vali2_b, valr4 )
         l1ver%vpd%BArcSpectb21(i) = valr4
      end do
      offset_VPE_D = offset_VPE_D &
            + 4*(l1ver%vpa(1)%IOsbNsLastMb1b2-l1ver%vpa(1)%IOsbNsfirstMb1b2+1)
      k = -1
      do i = 1, l1ver%vpa(1)%IOsbNsLastMb2b3-l1ver%vpa(1)%IOsbNsfirstMb2b3+1
         k = k + 1
         offset = offset_VPE_D + 2*k
         read(uin, pos=offset) vali2_a
         k = k + 1
         offset = offset_VPE_D + 2*k
         read(uin, pos=offset) vali2_b
         call commute32bits2r4( vali2_a, vali2_b, valr4 )
         l1ver%vpd%BArcSpectb23(i) = valr4
      end do
      offset_VPE_D = offset_VPE_D &
            + 4*(l1ver%vpa(1)%IOsbNsLastMb2b3-l1ver%vpa(1)%IOsbNsfirstMb2b3+1)
      k = -1
      do i = 1, l1ver%vpa(1)%IOsbNsLastMb2b3-l1ver%vpa(1)%IOsbNsfirstMb2b3+1
         k = k + 1
         offset = offset_VPE_D + 2*k
         read(uin, pos=offset) vali2_a
         k = k + 1
         offset = offset_VPE_D + 2*k
         read(uin, pos=offset) vali2_b
         call commute32bits2r4( vali2_a, vali2_b, valr4 )
         l1ver%vpd%BArcSpectb3(i) = valr4
      end do
      return
   end subroutine read_mdr_l1ver

   subroutine read_auxillary_aif( uin, offset_AP_AIF, aux )
     implicit none
     integer(kind=4)    ,intent(in)             :: uin
     integer(kind=4)    ,intent(in)             :: offset_AP_AIF
     type(DATA_AP)      ,intent(inout)          :: aux
     integer(kind=4)                            :: offset
     integer(kind=4)                            :: k
     integer(kind=4)     ,dimension(16)         :: bit
     integer(kind=4)                            :: vali4
     integer(kind=2)                            :: vali2
     integer(kind=2)                            :: vali2_a
     integer(kind=2)                            :: vali2_b
     integer(kind=1)                            :: vali4_a
     integer(kind=1)                            :: vali1_b
     real(kind=4)                               :: valr4
     !
     ! Word 11
     k = 11
     offset = offset_AP_AIF + 2*(k-1)
     read(uin, pos=offset) vali2
     call commute16bits2bit(vali2,bit)
     aux%Chain = bit(13)
     aux%MAS_HAU1 = bit(8)
     aux%MAS_HAU2 = bit(7)
     aux%MAS_HAU3 = bit(6)
     aux%MAS_HAU4 = bit(5)
     aux%LAZER = bit(1)
     ! Word 12
     k = 12
     offset = offset_AP_AIF + 2*(k-1)
     read(uin, pos=offset) vali2
     call commute16bits2bit(vali2,bit)
     aux%RC = bit(16)
     aux%LNR = bit(15)
     aux%ASE = bit(14)
     aux%LBR = bit(13)
     aux%PIX1 = bit(12)*2**0 + bit(11)*2**1 + bit(10)*2**2
     aux%PIX2 = bit( 9)*2**0 + bit( 8)*2**1 + bit( 7)*2**2
     aux%PIX3 = bit( 6)*2**0 + bit( 5)*2**1 + bit( 4)*2**2
     aux%PIX4 = bit( 3)*2**0 + bit( 2)*2**1 + bit( 1)*2**2
     ! Word 13 14
     k = 13
     offset = offset_AP_AIF + 2*(k-1)
     read(uin, pos=offset) vali2
     aux%PTSIMSW = vali2
     k = 14
     offset = offset_AP_AIF + 2*(k-1)
     read(uin, pos=offset) vali2
     aux%PTSILSW = vali2
     ! Word 15 16
     k = 15
     offset = offset_AP_AIF + 2*(k-1)
     read(uin, pos=offset) vali2_a
     k = 16
     offset = offset_AP_AIF + 2*(k-1)
     read(uin, pos=offset) vali2_b
     call commute32bits2i4( vali2_a, vali2_b, valr4 )
     aux%BBT = valr4 / 1000.
     ! Word 17
     k = 17
     offset = offset_AP_AIF + 2*(k-1)
     read(uin, pos=offset) vali2
     aux%INS_MODE = vali2
     ! Word 18
     k = 18
     offset = offset_AP_AIF + 2*(k-1)
     read(uin, pos=offset) vali2
     aux%LN = vali2
     ! Word 19
     k = 19
     offset = offset_AP_AIF + 2*(k-1)
     read(uin, pos=offset) vali2
     aux%SQIS = vali2
     ! Word 20
     k = 20
     offset = offset_AP_AIF + 2*(k-1)
     read(uin, pos=offset) vali2
     aux%SQII = vali2
     ! Word 21
     k = 21
     offset = offset_AP_AIF + 2*(k-1)
     read(uin, pos=offset) vali2
     aux%RTS = vali2
     ! Word 22
     k = 22
     offset = offset_AP_AIF + 2*(k-1)
     read(uin, pos=offset) vali2
     aux%RTL = vali2
     ! Word 23
     k = 23
     offset = offset_AP_AIF + 2*(k-1)
     read(uin, pos=offset) vali2
     aux%IFPT = vali2
     ! Word 24
     k = 24
     offset = offset_AP_AIF + 2*(k-1)
     read(uin, pos=offset) vali2
     aux%FPT = vali2
     ! Word 25
     k = 25
     offset = offset_AP_AIF + 2*(k-1)
     read(uin, pos=offset) vali2
     aux%HAUT = vali2
     ! Word 26
     k = 26
     offset = offset_AP_AIF + 2*(k-1)
     read(uin, pos=offset) vali2
     aux%OPBT = vali2
     ! Word 27
     k = 27
     offset = offset_AP_AIF + 2*(k-1)
     read(uin, pos=offset) vali2
     aux%CBST = vali2
     ! Word 28
     k = 28
     offset = offset_AP_AIF + 2*(k-1)
     read(uin, pos=offset) vali2
     aux%OTM_NV = vali2
     ! Word 29
     k = 29
     offset = offset_AP_AIF + 2*(k-1)
     ! Word 30
     k = 30
     offset = offset_AP_AIF + 2*(k-1)
     ! Word 31 32 SPARE
     k = 32
     offset = offset_AP_AIF + 2*(k-1)
     ! DPS STATUS
     ! Word 33
     k = 33
     offset = offset_AP_AIF + 2*(k-1)
     return
   end subroutine read_auxillary_aif


   subroutine read_auxillary_adf( uin, offset_AP_ADF, aux )
     implicit none
     integer(kind=4)    ,intent(in)             :: uin
     integer(kind=4)    ,intent(in)             :: offset_AP_ADF
     type(DATA_AP)      ,intent(inout)          :: aux
     integer(kind=4)                            :: offset
     integer(kind=4)                            :: k, i, j, l
     integer(kind=4)     ,dimension(16)         :: bit
     integer(kind=4)                            :: vali4
     integer(kind=2)                            :: vali2
     integer(kind=2)                            :: vali2_a
     integer(kind=2)                            :: vali2_b
     integer(kind=1)                            :: vali1_a
     integer(kind=1)                            :: vali1_b
     real(kind=4)                               :: valr4
     !
     ! DATA AREA PN1 Words 71 130
     offset = offset_AP_ADF - 2
     do i = 1, PN
        do j = 1, 4
           ! Word 71 131 191 251
           offset = offset + 2
           read(uin, pos=offset) vali2
            if( vali2 < 0 ) then
               vali4 = vali2 + 2**16
            else
               vali4 = vali2
            end if
           aux%AP_DATA%NS_Rpd(i,j) = vali4
           ! Word 72
           offset = offset + 2
           read(uin, pos=offset) vali2
           call split16_8(vali2,vali1_a,vali1_b)
           aux%AP_DATA%SN(i,j) = vali1_a
           aux%AP_DATA%SP(i,j) = vali1_b
           ! Word 73
           offset = offset + 2
           read(uin, pos=offset) vali2
           call commute16bits2bit(vali2,bit)
           aux%AP_DATA%CD(i,j) = bit(16)
           aux%AP_DATA%CSQ(i,j) = bit(15)
           aux%AP_DATA%SQ1(i,j) = bit(14)
           aux%AP_DATA%SQ2(i,j) = bit(13)
           aux%AP_DATA%IEQ(i,j) = bit(12)
           aux%AP_DATA%SN_NV(i,j) = bit(8)
           aux%AP_DATA%CD_NV(i,j) = bit(7)
           aux%AP_DATA%CSQ_NV(i,j) = bit(6)
           aux%AP_DATA%SP_NV(i,j) = bit(5)
           aux%AP_DATA%SQ1_NV(i,j) = bit(4)
           aux%AP_DATA%SQ2_NV(i,j) = bit(3)
           aux%AP_DATA%NS_NV(i,j) = bit(2)
           aux%AP_DATA%IEQ_NV(i,j) = bit(1)
           ! Word 74
           offset = offset + 2
           read(uin, pos=offset) vali2
           if( vali2 < 0 ) then
              vali4 = vali2 + 2**16
           else
              vali4 = vali2
           end if
           aux%AP_DATA%BdcoNbReceivedWords(i,j) = vali4
           do l = 1, SB
              ! Words 75 76 77 78 79 80
              offset = offset + 2
              read(uin, pos=offset) vali2_a
              offset = offset + 2
              read(uin, pos=offset) vali2_b
              call commute32bits2r4( vali2_a, vali2_b, valr4 )
              aux%AP_DATA%BNlcAnaMV(l,i,j) = valr4
           end do
           ! Word 81
           offset = offset + 2
           read(uin, pos=offset) vali2
           aux%AP_DATA%BZpdNZpd(i,j) = vali2
           ! Word 82 83
           offset = offset + 2
           read(uin, pos=offset) vali2_a
           k = k + 1
           offset = offset + 2
           read(uin, pos=offset) vali2_b
           call commute32bits2r4( vali2_a, vali2_b, valr4 )
           aux%AP_DATA%BzpdNzpdQualIndex(i,j) = valr4
           ! Word 84 85 (SPARE)
           offset = offset + 4
        end do
     end do
     !
     ! STATUS AREA PN1 Words 311 330
     do i = 1, PN
        do j = 1, 4
           ! Word 311 331 351 371
           offset = offset + 2
           read(uin, pos=offset) vali2
           call commute16bits2bit(vali2,bit)
           aux%AP_STATUS%LNR_DVL(i,j) = bit(16)
           aux%AP_STATUS%LNR_VLN(i,j) = bit(15)
           aux%AP_STATUS%BBofFlagSpectNonQual(i,j) = bit(14)
           aux%AP_STATUS%BDcoFlagMasErrorPath(1,i,j) = bit(13)
           aux%AP_STATUS%BDcoFlagMasErrorPath(2,i,j) = bit(12)
           aux%AP_STATUS%BDcoFlagMasErrorPath(3,i,j) = bit(11)
           aux%AP_STATUS%BDcoFlagMasOverflow(1,i,j) = bit(10)
           aux%AP_STATUS%BDcoFlagMasOverflow(2,i,j) = bit(9)
           aux%AP_STATUS%BDcoFlagMasOverflow(3,i,j) = bit(8)
           aux%AP_STATUS%BDcoFlagMasEcret(1,i,j) = bit(7)
           aux%AP_STATUS%BDcoFlagMasEcret(2,i,j) = bit(6)
           aux%AP_STATUS%BDcoFlagMasEcret(3,i,j) = bit(5)
           aux%AP_STATUS%BDcoFlagMasErrorNbWords(i,j) = bit(4)
           aux%AP_STATUS%BDcoFlagErrorInterf(1,i,j) = bit(3)
           aux%AP_STATUS%BDcoFlagErrorInterf(2,i,j) = bit(2)
           aux%AP_STATUS%BDcoFlagErrorInterf(3,i,j) = bit(1)
           ! Word 312 332 352 372
           offset = offset + 2
           read(uin, pos=offset) vali2
           call commute16bits2bit(vali2,bit)
           aux%AP_STATUS%BNlcFlagIntegrity(1,i,j) = bit(16)
           aux%AP_STATUS%BNlcFlagIntegrity(2,i,j) = bit(15)
           aux%AP_STATUS%BNlcFlagIntegrity(3,i,j) = bit(14)
           aux%AP_STATUS%BSpkFlagSpik(1,i,j) = bit(13)
           aux%AP_STATUS%BSpkFlagSpik(2,i,j) = bit(12)
           aux%AP_STATUS%BSpkFlagSpik(3,i,j) = bit(11)
           aux%AP_STATUS%BZpdFlagNzpdNonQual(i,j) = bit(10)
           aux%AP_STATUS%BIrsFlagSrdNonIntegrity(i,j) = bit(9)
           aux%AP_STATUS%BIsiFlagErrorFft(1,i,j) = bit(8)
           aux%AP_STATUS%BIsiFlagErrorFft(2,i,j) = bit(7)
           aux%AP_STATUS%BIsiFlagErrorFft(3,i,j) = bit(6)
           ! Word 313-4 333-4 353-4 373-4 SPARE
           offset = offset + 4
        end do
        ! EXTRA STATUS AREA PN1 Words 327 330
        ! Word 327 347 367 387
        offset = offset + 2
        read(uin, pos=offset) vali2
        call commute16bits2bit(vali2,bit)
        aux%AP_EXTRA_STATUS%BBofFlagSrdInit(1,i) = bit(16)
        aux%AP_EXTRA_STATUS%BBofFlagSrdInit(2,i) = bit(15)
        aux%AP_EXTRA_STATUS%BBofFlagSrdNonUpdate(1,i) = bit(14)
        aux%AP_EXTRA_STATUS%BBofFlagSrdNonUpdate(2,i) = bit(13)
        aux%AP_EXTRA_STATUS%BBofFlagCoefCalInit(1,1,i) = bit(12)
        aux%AP_EXTRA_STATUS%BBofFlagCoefCalInit(1,2,i) = bit(11)
        aux%AP_EXTRA_STATUS%BBofFlagCoefCalInit(1,3,i) = bit(10)
        ! Word 328 348 368 388
        offset = offset + 2
        read(uin, pos=offset) vali2
        call commute16bits2bit(vali2,bit)
        aux%AP_EXTRA_STATUS%BBofFlagCoefCalInit(2,1,i) = bit(16)
        aux%AP_EXTRA_STATUS%BBofFlagCoefCalInit(2,2,i) = bit(15)
        aux%AP_EXTRA_STATUS%BBofFlagCoefCalInit(2,3,i) = bit(14)
        aux%AP_EXTRA_STATUS%BBofFlagCoefCalNonUpdate(1,1,i) = bit(13)
        aux%AP_EXTRA_STATUS%BBofFlagCoefCalNonUpdate(1,2,i) = bit(12)
        aux%AP_EXTRA_STATUS%BBofFlagCoefCalNonUpdate(1,3,i) = bit(11)
        aux%AP_EXTRA_STATUS%BBofFlagCoefCalNonUpdate(2,1,i) = bit(10)
        aux%AP_EXTRA_STATUS%BBofFlagCoefCalNonUpdate(2,2,i) = bit(9)
        aux%AP_EXTRA_STATUS%BBofFlagCoefCalNonUpdate(2,3,i) = bit(8)
        aux%AP_EXTRA_STATUS%BRciFlagNonIntegritySlope(1,1,i) = bit(7)
        aux%AP_EXTRA_STATUS%BRciFlagNonIntegritySlope(1,2,i) = bit(6)
        aux%AP_EXTRA_STATUS%BRciFlagNonIntegritySlope(1,3,i) = bit(5)
        aux%AP_EXTRA_STATUS%BRciFlagNonIntegritySlope(2,1,i) = bit(4)
        aux%AP_EXTRA_STATUS%BRciFlagNonIntegritySlope(2,2,i) = bit(3)
        aux%AP_EXTRA_STATUS%BRciFlagNonIntegritySlope(2,3,i) = bit(2)
        ! Word 329 349 369 389
        offset = offset + 2
        read(uin, pos=offset) vali2
        call commute16bits2bit(vali2,bit)
        aux%AP_EXTRA_STATUS%BRciFlagNonIntegrityOffset(1,1,i) = bit(16)
        aux%AP_EXTRA_STATUS%BRciFlagNonIntegrityOffset(1,2,i) = bit(15)
        aux%AP_EXTRA_STATUS%BRciFlagNonIntegrityOffset(1,3,i) = bit(14)
        aux%AP_EXTRA_STATUS%BRciFlagNonIntegrityOffset(2,1,i) = bit(13)
        aux%AP_EXTRA_STATUS%BRciFlagNonIntegrityOffset(2,2,i) = bit(12)
        aux%AP_EXTRA_STATUS%BRciFlagNonIntegrityOffset(2,3,i) = bit(11)
        ! Word 330 350 370 390 SPARE
        offset = offset + 2
     end do
     return
   end subroutine read_auxillary_adf

   subroutine read_aivp( uin, offset_VP_A, vpa )
     implicit none
     integer(kind=4)    ,intent(in)             :: uin
     integer(kind=4)    ,intent(in)             :: offset_VP_A
     type(AI_VP)        ,intent(inout)          :: vpa
     integer(kind=4)                            :: offset
     integer(kind=4)                            :: k
     integer(kind=2)                            :: vali2_a
     integer(kind=2)                            :: vali2_b
     integer(kind=4)                            :: vali4
     integer(kind=2)                            :: vali2
     integer(kind=1)                            :: vali1_a
     integer(kind=1)                            :: vali1_b
     integer(kind=4)    ,dimension(16)          :: bit
     real(kind=4)                               :: valr4
     ! SN SP Word 12
     k = 12
     offset = offset_VP_A + (2*(k-1))
     read(uin, pos=offset) vali2
     call split16_8(vali2,vali1_a,vali1_b)
     vpa%SN = vali1_a
     vpa%SP = vali1_b
     ! Word 13
     k = 13
     offset = offset_VP_A + (2*(k-1))
     read(uin, pos=offset) vali2
     call commute16bits2bit(vali2,bit)
     vpa%CD = bit(16)
     ! Word 20
     k = 20
     offset = offset_VP_A + (2*(k-1))
     read(uin, pos=offset) vali2
     call commute16bits2bit(vali2,bit)
     call split16_8(vali2,vali1_a,vali1_b)
     vpa%PN_V = bit(13) + bit(14)*2**1 + bit(15)*2**2 + bit(16)*2**3
     vpa%SB_V = bit(9) + bit(10)*2**1 + bit(11)*2**2 + bit(12)*2**3
     vpa%SN_V = vali1_b
     ! Word 21
     k = 21
     offset = offset_VP_A + (2*(k-1))
     read(uin, pos=offset) vali2
     call split16_8(vali2,vali1_a,vali1_b)
     vpa%VP_Id = vali1_a
     call commute16bits2bit(vali2,bit)
     vpa%BZpdFlagNzpdNonQual = bit(8)
     vpa%BdcoFlagMasErrorNbWords = bit(7)
     ! Word 22
     k = 22
     offset = offset_VP_A + (2*(k-1))
     read(uin, pos=offset) vali2
     vpa%BZpdNzpd = vali2
     ! Word 23 24
     k = 23
     offset = offset_VP_A + (2*(k-1))
     read(uin, pos=offset) vali2_a
     k = 24
     offset = offset_VP_A + (2*(k-1))
     read(uin, pos=offset) vali2_b
     call commute32bits2r4( vali2_a, vali2_b, valr4 )
     vpa%BzpdNzpdQualIndexXX = valr4
     ! Word 25
     k = 25
     offset = offset_VP_A + (2*(k-1))
     read(uin, pos=offset) vali2
     if( vali2 < 0 ) then
        vali4 = vali2 + 2**16
     else
        vali4 = vali2
     end if
     vpa%BdcoNbReceivedWords = vali4
     ! Word 26
     k = 26
     offset = offset_VP_A + (2*(k-1))
     read(uin, pos=offset) vali2
     vpa%IZsbNsfirstSrd = vali2
     ! Word 27
     k = 27
     offset = offset_VP_A + (2*(k-1))
     read(uin, pos=offset) vali2
     vpa%IZsbNslastSrd = vali2
     ! Word 28
     k = 28
     offset = offset_VP_A + (2*(k-1))
     read(uin, pos=offset) vali2
     vpa%IUsbNsfirst = vali2
     ! Word 29
     k = 29
     offset = offset_VP_A + (2*(k-1))
     read(uin, pos=offset) vali2
     vpa%IUsbNslast = vali2
     ! Word 30
     k = 30
     offset = offset_VP_A + (2*(k-1))
     read(uin, pos=offset) vali2
     vpa%IOsbNsFirstMb1b2 = vali2
     ! Word 31
     k = 31
     offset = offset_VP_A + (2*(k-1))
     read(uin, pos=offset) vali2
     vpa%IOsbNsLastMb1b2 = vali2
     ! Word 32
     k = 32
     offset = offset_VP_A + (2*(k-1))
     read(uin, pos=offset) vali2
     vpa%IOsbNsFirstMb2b3 = vali2
     ! Word 33
     k = 33
     offset = offset_VP_A + (2*(k-1))
     read(uin, pos=offset) vali2
     vpa%IOsbNsLastMb2b3 = vali2
     ! Word 34 40 Spare
     return
   end subroutine read_aivp

   subroutine read_viadr_l1eng(uin, line_pos, l1eng)
      implicit none
      ! Arguments
      integer(kind=4), intent(in)                    :: uin
      integer(kind=8), intent(in)                    :: line_pos
      type(RECORD_VIADR_ENGINEERING), intent(out)    :: l1eng
      ! internal variables

      return
   end subroutine read_viadr_l1eng

   subroutine read_giadr_l1eng(uin, line_pos, l1eng)
      implicit none
      ! Arguments
      integer(kind=4), intent(in)                    :: uin
      integer(kind=8), intent(in)                    :: line_pos
      type(RECORD_GIADR_ENGINEERING), intent(out)    :: l1eng
      ! internal variables
     

      return
   end subroutine read_giadr_l1eng


   subroutine read_iasi_l1c_radanal( fname, MetOp_Id, channel, granule )
  
      character(len=500)  , intent(in)     :: fname
      character(len=3)    , intent(in)     :: MetOp_Id
      integer(kind=4)     , intent(in)     :: channel
      type(L1C_GRANULE)   , intent(out)    :: granule
      ! local variables
      integer(kind=4)                      :: il
      integer(kind=4)                      :: NL
  
      call read_iasi_l1c_file(fname, granule)
      !
      NL = granule%nb_lines ! # of lines
      do il = 1,NL
          call l1c_extract_radanal( MetOp_Id, channel, granule%mdr_l1c(il) )
      end do
  
   end subroutine read_iasi_l1c_radanal

   subroutine l1c_extract_radanal( MetOp_Id, channel, mdr_l1c )
      implicit none
      
      character(len=3)           , intent(in)     :: MetOp_Id
      integer(4)                 , intent(in)     :: channel
      type(RECORD_MDR_L1C)       , intent(inout)  :: mdr_l1c
      !
      ! local
      integer(4), dimension(1)     :: Pos
      real(4)   , dimension(NCL-1) :: Tab
      integer(4), dimension(NCL-1) :: Index
      integer(4)                   :: nc, n, c, i, j
      real(4)   , parameter        :: M01_WN_AVHRR_4 = 931.3130195
      real(4)   , parameter        :: M01_WN_AVHRR_5 = 837.8669661
      real(4)   , parameter        :: M02_WN_AVHRR_4 = 926.1029007
      real(4)   , parameter        :: M02_WN_AVHRR_5 = 837.0495664
      !
      real(4)   , parameter        :: M01_A0_AVHRR_4 = 0.1204674797
      real(4)   , parameter        :: M01_A1_AVHRR_4 = 0.9990877383
      real(4)   , parameter        :: M01_A0_AVHRR_5 = 0.0323283539
      real(4)   , parameter        :: M01_A1_AVHRR_5 = 0.9994701608
      real(4)   , parameter        :: M02_A0_AVHRR_4 = 0.3691230795
      real(4)   , parameter        :: M02_A1_AVHRR_4 = 0.9987261946
      real(4)   , parameter        :: M02_A0_AVHRR_5 = 0.2163976927
      real(4)   , parameter        :: M02_A1_AVHRR_5 = 0.9991777009
      real(4)   , parameter        :: T_Ref = 280
      real(4)                      :: wn, rad, Tb
      real(4)                      :: WN_AVHRR_CH4, A0_AVHRR_CH4, A1_AVHRR_CH4
      real(4)                      :: WN_AVHRR_CH5, A0_AVHRR_CH5, A1_AVHRR_CH5
      
      if( MetOp_Id == 'M01' ) then
         WN_AVHRR_CH4 = M01_WN_AVHRR_4
         WN_AVHRR_CH5 = M01_WN_AVHRR_5
         A0_AVHRR_CH4 = M01_A0_AVHRR_4
         A1_AVHRR_CH4 = M01_A1_AVHRR_4
         A0_AVHRR_CH5 = M01_A0_AVHRR_5
         A1_AVHRR_CH5 = M01_A1_AVHRR_5
      else if( MetOp_Id == 'M02' ) then
         WN_AVHRR_CH4 = M02_WN_AVHRR_4
         WN_AVHRR_CH5 = M02_WN_AVHRR_5
         A0_AVHRR_CH4 = M02_A0_AVHRR_4
         A1_AVHRR_CH4 = M02_A1_AVHRR_4
         A0_AVHRR_CH5 = M02_A0_AVHRR_5
         A1_AVHRR_CH5 = M02_A1_AVHRR_5
      else if( MetOp_Id == 'M03' ) then
         write(*,*) 'Sorry too early', MetOp_Id
         stop
      else
         write(*,*) 'Wrong MetOp_Id', MetOp_Id
         stop
      end if
      
      do j = 1, SNOT
         !
         ! Date conversion
         mdr_l1c%vdate(:,j) = time_sct2date(mdr_l1c%cds_date(j))
          
         do i = 1, PN
            !
            ! Class compression
            if( mdr_l1c%radanal%mean(channel,NCL,i,j) /= 0.00 ) then
                mdr_l1c%radanal%nbclass(i,j) = &
                               mdr_l1c%radanal%nbclass(i,j) - 1
               nc = mdr_l1c%radanal%nbclass(i,j)
            else
               nc = min( mdr_l1c%radanal%nbclass(i,j), NCL-1 )
            end if

            Tab(1:NCL-1) = mdr_l1c%radanal%mean(channel,1:NCL-1,i,j)
            do n = 1, NCL-1
               Pos = maxloc(Tab)
               Index(n) = Pos(1)
               mdr_l1c%radanal%mean(channel,n,i,j) = Tab(Index(n))
               Tab(Pos(1)) = 0.0
            end do
            mdr_l1c%radanal%mean(channel,nc+1:NCL-1,i,j) = 0.0
            Tab(1:NCL-1) = mdr_l1c%radanal%std(channel,1:NCL-1,i,j)
            mdr_l1c%radanal%std(channel,1:nc,i,j) = Tab(Index(1:nc))
            mdr_l1c%radanal%std(channel,nc+1:NCL-1,i,j) = 0.0
            Tab(1:NCL-1) = mdr_l1c%radanal%wgt(1:NCL-1,i,j)
            mdr_l1c%radanal%wgt(1:nc,i,j) = Tab(Index(1:nc))
            mdr_l1c%radanal%wgt(nc+1:NCL-1,i,j) = 0.0
            Tab(1:NCL-1) = mdr_l1c%radanal%Y(1:NCL-1,i,j)
            mdr_l1c%radanal%Y(1:nc,i,j) = Tab(Index(1:nc))
            mdr_l1c%radanal%Y(nc+1:NCL-1,i,j) = 0.0
            Tab(1:NCL-1) = mdr_l1c%radanal%Z(1:NCL-1,i,j)
            mdr_l1c%radanal%Z(1:nc,i,j) = Tab(Index(1:nc))
            mdr_l1c%radanal%Z(nc+1:NCL-1,i,j) = 0.0
            if( mdr_l1c%radanal%ccsmode == 0 ) then
               Tab(1:NCL-1) = mdr_l1c%radanal%mean(channel+1,1:NCL-1,i,j)
               do n = 1, NCL-1
                  Pos = maxloc(Tab)
                  Index(n) = Pos(1)
                  mdr_l1c%radanal%mean(channel+1,n,i,j) = Tab(Index(n))
                  Tab(Pos(1)) = 0.0
               end do
               mdr_l1c%radanal%mean(channel+1,nc+1:NCL-1,i,j) = 0.0
               Tab(1:NCL-1) = mdr_l1c%radanal%std(channel+1,1:NCL-1,i,j)
               mdr_l1c%radanal%std(channel+1,1:nc,i,j) = Tab(Index(1:nc))
               mdr_l1c%radanal%std(channel+1,nc+1:NCL-1,i,j) = 0.0
            else
               Tab(1:NCL-1) = mdr_l1c%radanal%mean(channel+1,1:NCL-1,i,j)
               mdr_l1c%radanal%mean(channel+1,1:nc,i,j) = Tab(Index(1:nc))
               mdr_l1c%radanal%mean(channel+1,nc+1:NCL-1,i,j) = 0.0
               Tab(1:NCL-1) = mdr_l1c%radanal%std(channel+1,1:NCL-1,i,j)
               mdr_l1c%radanal%std(channel+1,1:nc,i,j) = Tab(Index(1:nc))
               mdr_l1c%radanal%std(channel+1,nc+1:NCL-1,i,j) = 0.0
            end if
            !
            ! Radiance conversion to TB and NEDT
            do c = 1, nc
               if( mdr_l1c%radanal%ccsmode == 0 ) then
                  wn = WN_AVHRR_CH4
                  rad = mdr_l1c%radanal%mean(channel,c,i,j)
                  Tb = ( rad2brt(wn, rad) - A0_AVHRR_CH4) / A1_AVHRR_CH4
!!$                  write(*,*) j,i,c,wn,rad,Tb
                  mdr_l1c%radanal%mean(channel,c,i,j) = Tb
                  mdr_l1c%radanal%std(channel,c,i,j) = rad/drad2dbrt(Tb, wn)
                  wn = WN_AVHRR_CH5
                  rad = mdr_l1c%radanal%mean(channel+1,c,i,j)
                  Tb = ( rad2brt(wn, rad) - A0_AVHRR_CH5) / A1_AVHRR_CH5
                  mdr_l1c%radanal%mean(channel+1,c,i,j) = Tb
                  mdr_l1c%radanal%std(channel+1,c,i,j) = rad/drad2dbrt(Tb, wn)
               end if
            end do
            do c = NCL, NCL
               if( mdr_l1c%radanal%ccsmode == 0 .and. &
                   mdr_l1c%radanal%mean(channel,NCL,i,j) /= 0.00 ) then
                  wn = WN_AVHRR_CH4
                  rad = mdr_l1c%radanal%mean(channel,c,i,j)
                  Tb = ( rad2brt(wn, rad) - A0_AVHRR_CH4) / A1_AVHRR_CH4
                  mdr_l1c%radanal%mean(channel,c,i,j) = Tb
                  mdr_l1c%radanal%std(channel,c,i,j) = rad/drad2dbrt(Tb, wn)
                  wn = WN_AVHRR_CH5
                  rad = mdr_l1c%radanal%mean(channel+1,c,i,j)
                  Tb = ( rad2brt(wn, rad) - A0_AVHRR_CH5) / A1_AVHRR_CH5
                  mdr_l1c%radanal%mean(channel+1,c,i,j) = Tb
                  mdr_l1c%radanal%std(channel+1,c,i,j) = rad/drad2dbrt(Tb, wn)
               end if
            end do
            !
            ! Filter bad localisation
            if( mdr_l1c%lat(i,j) < -100.0 .or. &
                mdr_l1c%lat(i,j) > +100.0) then
               mdr_l1c%lat(i,j) = -999.99
               mdr_l1c%lon(i,j) = -999.99
               mdr_l1c%iaa(i,j) = -999.99
               mdr_l1c%iza(i,j) = -999.99
               mdr_l1c%saa(i,j) = -999.99
               mdr_l1c%sza(i,j) = -999.99
               mdr_l1c%flg(:,i,j) = 1
            end if
         end do
      end do
      return
   end subroutine l1c_extract_radanal

   subroutine read_iasi_l1c_file(fname, granule)
      implicit none
      ! Variables
      character(len=500)    , intent(in)               :: fname
      type(L1C_GRANULE)     , intent(inout)            :: granule
      ! Internal variables
      integer(kind=4)                                  :: uin 
      integer(kind=8)                                  :: fpos
      type(RECORD_GIADR_SCALE_FACTORS)                 :: giadr_sf
      type(RECORD_GIADR_QUALITY)                       :: giadr_quality
      type(RECORD_ID)                                  :: recs(MAX_RECORDS)
      integer(kind=4)                                  :: k, j
      
      
      ! Get list of records and scale factors
      call read_iasi_l1c_file_recs( fname, granule%nb_lines, recs,&
                                    giadr_sf, giadr_quality)
      
      ! Open file
      uin = getFileUnit()
      open(unit=uin, file=fname, access='stream', status='old',&
           action='read', convert='big_endian')
      
      ! Read lines
      print *,'Number of lines:',granule%nb_lines
      ! granule%nb_lines=min(100,granule%nb_lines)
      ! print *,'New number of lines:',granule%nb_lines
      allocate(granule%mdr_l1c(granule%nb_lines))
      do k = 1, granule%nb_lines
         call read_iasi_mdr_l1c( uin, recs(k)%pos, giadr_sf,&
                                 granule%mdr_l1c(k) )
         granule%mdr_l1c(k)%line = k
         !
         ! Date conversion
         do j = 1, SNOT
            granule%mdr_l1c(k)%vdate(:,j) =                 &
                   time_sct2date(granule%mdr_l1c(k)%cds_date(j))
         end do
      end do
      
      ! Close file
      close(uin)
      return
   end subroutine read_iasi_l1c_file

   subroutine read_iasi_l1c_file_recs(fname, nrec, recs, giadr_sf, giadr_quality)
      implicit none
      ! Arguments
      character(len=*), intent(in)                  :: fname
      integer(kind=4)   , intent(out)                 :: nrec
      type(RECORD_ID)   , intent(out)                 :: recs(MAX_RECORDS)
      type(RECORD_GIADR_SCALE_FACTORS), intent(out)   :: giadr_sf
      type(RECORD_GIADR_QUALITY), intent(out)         :: giadr_quality
      ! internal variables
      integer(kind=8)                                 :: fsize, fpos
      integer(kind=4)                                 :: uin
      type(RECORD_HEADER)                             :: grh
      integer(kind=4)                                 :: i, j

100 format("line: ",I4,", pos: ", I10,", class:",I3, ", subclass:",I3, ", version:",I3, ", size: ",I10)

      inquire(file=fname, size=fsize)
      write(0,*)"fsize: ", fsize
      uin = getFileUnit()
      ! Open file
      open(unit=uin, file=fname, access='stream', status='old',&
           action='read', convert='big_endian', err=999)
      fpos = 1
      nrec = 0
      do while(fpos < fsize)
         ! read generic record header
         call read_grh(uin, fpos, grh)
         call print_grh(grh)
         ! if record is a giadr_quality
         if (grh%RECORD_CLASS==5 .and. grh%RECORD_SUBCLASS==0) then 
            call read_giadr_quality(uin, fpos, giadr_quality)
            call print_giadr_quality(giadr_quality)
         endif
         
         ! if record is a giadr_scale_factors, read radiance scale factors
         if (grh%RECORD_CLASS==5 .and. grh%RECORD_SUBCLASS==1 .and. &
               grh%RECORD_SUBCLASS_VERSION==2) then 
            call read_giadr_scale_factors(uin, fpos, giadr_sf)
         endif
         
         ! if record is a mdr-l1c, fill record list
         if (grh%RECORD_CLASS==8 .and. grh%RECORD_SUBCLASS==2) then
            nrec = nrec + 1
            recs(nrec)%cl  = grh%RECORD_CLASS
            recs(nrec)%scl = grh%RECORD_SUBCLASS
            recs(nrec)%pos = fpos
         endif
         
         !write(*,100) nrec, fpos, grh%RECORD_CLASS, grh%RECORD_SUBCLASS, &
         !   grh%RECORD_SUBCLASS_VERSION, grh%RECORD_SIZE

         ! Update position in file stream
         fpos = fpos + grh%RECORD_SIZE
      enddo
      close(uin)
      return
  999 write(0,*) 'file open error',uin, trim(fname)
   end subroutine read_iasi_l1c_file_recs

   subroutine read_iasi_mdr_l1c(uin, line_pos, giadr_sf, l1c)
      implicit none
      ! Arguments
      integer(kind=4), intent(in)                  :: uin
      integer(kind=8), intent(in)                  :: line_pos
      type(RECORD_GIADR_SCALE_FACTORS), intent(in) :: giadr_sf
      type(RECORD_MDR_L1C), intent(out)            :: l1c
      ! internal variables
     
      call l1c_getIasiMode(uin, line_pos, l1c%GEPSIasiMode)
      call l1c_getSP(uin, line_pos, l1c%GEPS_SP)
      call l1c_getCCD(uin, line_pos, l1c%GEPS_CCD)
      call l1c_getLongLat(uin, line_pos, l1c%lon, l1c%lat)
      call l1c_getDatIASI(uin, line_pos, l1c%cds_date)
      call l1c_getFlagQual_3(uin, line_pos, l1c%flg)
      call l1c_getMetopAngles(uin, line_pos, l1c%iza, l1c%iaa)
      call l1c_getSunAngles(uin, line_pos, l1c%sza, l1c%saa)
      call l1c_getEUMAvhrr(uin, line_pos, l1c%clc, l1c%lfr, l1c%sif)
      call l1c_getRadiances(uin, line_pos, giadr_sf, l1c%rad, &
                                 l1c%dWn, l1c%NsFirst, l1c%NsLast )
      call l1c_getRadAnal(uin, line_pos, l1c%radanal)
      call l1c_getIISLoc(uin, line_pos, l1c%IISlon, l1c%IISlat)

      return
   end subroutine read_iasi_mdr_l1c

   ! subroutine read_iasi_l2_file( fname, granule )
   !    implicit none
   !    ! Variables
   !    character(len=500)    , intent(in)                 :: fname
   !    type(L2_GRANULE)      , intent(out)                :: granule
   !    ! Internal variables
   !    integer(kind=4)                                    :: uin 
   !    type(RECORD_ID)                                    :: recs(MAX_RECORDS)
   !    integer(kind=4)                                    :: k
   !    integer(kind=4)                                    :: j
      
   !    ! Get list of records and giadr
   !    call read_iasi_l2_file_recs( fname, granule%nb_lines,&
   !                                 recs, granule%giadr_l2 )
      
   !    ! Open file
   !    uin = getFileUnit()
   !    open(unit=uin, file=fname, access='stream', status='old',&
   !          action='read', convert='big_endian')
      
   !    ! Read lines
   !    allocate(granule%mdr_l2(granule%nb_lines))
   !    do k = 1, granule%nb_lines
   !       call read_iasi_l2_mdr(uin, recs(k)%pos, granule%mdr_l2(k))
   !       granule%mdr_l2(k)%line = k
   !       do j = 1, SNOT
   !          granule%mdr_l2(k)%vdate(:,j) = &
   !                   time_sct2date(granule%mdr_l2(k)%cds_date(j))
   !       end do
   !    end do
      
   !    ! Close file
   !    close(uin)
   ! end subroutine read_iasi_l2_file

   subroutine read_iasi_l2_file_recs(fname, nrec, recs, giadr_l2)
      implicit none
      ! Arguments
      character(len=500)     , intent(in)               :: fname
      integer(kind=4)        , intent(out)              :: nrec
      type(RECORD_ID)        , intent(out)              :: recs(MAX_RECORDS)
      type(RECORD_GIADR_L2)  , intent(out)              :: giadr_l2
      ! internal variables
      integer(kind=4)                                   :: uin
      integer(kind=8)                                   :: fsize, fpos
      type(RECORD_HEADER)                               :: grh
      integer(kind=4)                                   :: i, j

100 format("line: ",I4,", pos: ", I10,", class:",I3, ", subclass:",I3, ", version:",I3, ", size: ",I10)

      inquire(file=fname, size=fsize)
      uin = getFileUnit()
      ! Open file
      open(unit=uin, file=fname, access='stream', status='old',&
           action='read', convert='big_endian')
      fpos = 1
      nrec = 0
      do while(fpos<fsize)
         ! read general record
         call read_grh(uin, fpos, grh)
         call print_grh(grh)
         ! if record is a giadr_l2
         if (grh%RECORD_CLASS==5 .and. grh%RECORD_SUBCLASS==1) then 
            call read_giadr_l2(uin, fpos, giadr_l2)
         end if
         
         ! if record is a mdr-l2, fill record list
         if (grh%RECORD_CLASS==8 .and. grh%RECORD_SUBCLASS==1) then
            nrec = nrec + 1
            recs(nrec)%cl  = grh%RECORD_CLASS
            recs(nrec)%scl = grh%RECORD_SUBCLASS
            recs(nrec)%pos = fpos
         end if
         
         !write(*,100) nrec, fpos, grh%RECORD_CLASS, grh%RECORD_SUBCLASS, &
         !             grh%RECORD_SUBCLASS_VERSION, grh%RECORD_SIZE

         ! Update position in file stream
         fpos = fpos + grh%RECORD_SIZE
      end do
      close(uin)
      
      return
   end subroutine read_iasi_l2_file_recs
  

   subroutine read_avhrr_l1b_file( fname, granule )
      implicit none
      ! Variables
      character(len=500)    , intent(in)                 :: fname
      type(AVHRR_GRANULE)   , intent(inout)              :: granule
      ! Internal variables
      integer(kind=4)                                    :: uin 
      type(RECORD_ID)                                    :: recs(MAX_RECORDS)
      integer(kind=4)                                    :: k
      integer(kind=4)                                    :: j
      
      ! Get list of records and giadr
      call read_avhrr_l1b_file_recs( fname, granule%nb_lines,     &
                                     recs, granule%giadr_radiance,&
                                     granule%giadr_analog         )
      
      ! Open file
      uin = getFileUnit()
      open(unit=uin, file=fname, access='stream', status='old',&
            action='read', convert='big_endian', err=999)
      
      ! Read lines
      allocate(granule%mdr_avhrr(granule%nb_lines))
      do k = 1, granule%nb_lines
         call read_avhrr_l1b_mdr(uin, recs(k)%pos, granule%mdr_avhrr(k))
         granule%mdr_avhrr(k)%line = k
         granule%mdr_avhrr(k)%cds_date%day =                      &
                     granule%mdr_avhrr(k)%grh%RECORD_START_TIME%day
         granule%mdr_avhrr(k)%cds_date%msec =                      &
                     granule%mdr_avhrr(k)%grh%RECORD_START_TIME%msec
         granule%mdr_avhrr(k)%vdate(:) =                        &
                     time_sct2date(granule%mdr_avhrr(k)%cds_date)
         call avhrr_cloud_information( granule%mdr_avhrr(k)%CLOUD_INFORMATION,&
                                       granule%mdr_avhrr(k)%QUALITY_INDICATOR,&
                                       granule%mdr_avhrr(k)%SCAN_LINE_QUALITY,&
                                       granule%mdr_avhrr(k)%Cloud_Flag_Vect   )
      end do
      
      ! Close file
      close(uin)
      return
  999 write(*,*) 'Openning file error'
   end subroutine read_avhrr_l1b_file

   subroutine read_avhrr_l1b_file_recs( fname, nrec, recs,&
                                        giadr_radiance,   &
                                        giadr_analog      )
      implicit none
      ! Arguments
      character(len=500)         ,intent(in)               :: fname
      integer(kind=4)            ,intent(out)              :: nrec
      type(RECORD_ID)            ,intent(out)              :: recs(MAX_RECORDS)
      type(RECORD_GIADR_RADIANCE),intent(out)              :: giadr_radiance
      type(RECORD_GIADR_ANALOG)  ,intent(out)              :: giadr_analog
      ! internal variables
      integer(kind=4)                                   :: uin
      integer(kind=8)                                   :: fsize, fpos
      type(RECORD_HEADER)                               :: grh
      integer(kind=4)                                   :: i, j

100 format("line: ",I10,", pos: ", I15,", class:",I3, ", subclass:",I3, ", version:",I3, ", size: ",I10)

      inquire(file=fname, size=fsize)
      uin = getFileUnit()
      ! Open file
      open(unit=uin, file=fname, access='stream', status='old',&
           action='read', convert='big_endian', err=999)
      fpos = 1
      nrec = 0
      do while(fpos<fsize)
         ! read generic record header
         call read_grh(uin, fpos, grh)
         call print_grh(grh)
         ! if record is a giadr-radiance
         if (grh%RECORD_CLASS==5 .and. grh%RECORD_SUBCLASS==1) then 
            call read_giadr_radiance(uin, fpos, giadr_radiance)
         end if
         ! if record is a giadr-analog
         if (grh%RECORD_CLASS==5 .and. grh%RECORD_SUBCLASS==2) then 
            call read_giadr_analog(uin, fpos, giadr_analog)
         end if
         
         ! if record is a mdr-avhrr-l1b, fill record list
         if (grh%RECORD_CLASS==8 .and. grh%RECORD_SUBCLASS==2) then
            nrec = nrec + 1
            recs(nrec)%cl  = grh%RECORD_CLASS
            recs(nrec)%scl = grh%RECORD_SUBCLASS
            recs(nrec)%pos = fpos
         end if
         
         !write(*,100) nrec, fpos, grh%RECORD_CLASS, grh%RECORD_SUBCLASS, &
         !             grh%RECORD_SUBCLASS_VERSION, grh%RECORD_SIZE

         ! Update position in file stream
         fpos = fpos + grh%RECORD_SIZE
      end do
      close(uin)
      
      return
  999 write(*,*) 'openning file error'
   end subroutine read_avhrr_l1b_file_recs
 
   subroutine read_avhrr_l1b_mdr(uin, line_pos, mdr)
      implicit none
      ! Arguments
      integer(kind=4), intent(in)                  :: uin
      integer(kind=8), intent(in)                  :: line_pos
      type(RECORD_MDR_AVHRR_1B_FULL), intent(out)  :: mdr
      ! internal variables
      type(RECORD_HEADER)                          :: grh
      integer(kind=8)                              :: offset
      integer(kind=4)                              :: i, j
      integer(kind=2)                              :: val2
      integer(kind=2), dimension(NE*5)             :: values
      integer(kind=2), dimension(NE,5)             :: values2
      integer(kind=4), dimension(2)                :: val4x2
      integer(kind=4), dimension(2*NP)             :: val4x2xNP
      integer(kind=2), dimension(4*NP)             :: val2x4xNP
      integer(kind=2), dimension(4)                :: val2x4
      integer(kind=2), dimension(NE)               :: val2xNE
      integer(kind=4)                              :: val4
      real(kind=4)   , dimension(NP+2)             :: ylr
      real(kind=4)   , dimension(NE)               :: yhr
      ! mdr grh
      call read_grh(uin, line_pos, mdr%grh)
      ! earth views per scanline NE
      offset = line_pos + 22
      read(unit=uin, pos=offset) val2
      mdr%EARTH_VIEWS_PER_SCANLINE = val2
!      if( mdr%EARTH_VIEWS_PER_SCANLINE /= NE ) then
!         write(*,*) 'line_pos offset', line_pos, offset
!         write(*,*) 'wrong number of views per scan line must be ', NE, val2
!         stop
!      end if
      ! scene_radiances
      offset = line_pos + 24
      read(unit=uin, pos=offset) values
      values2 = reshape(values(1:NE*5),(/NE,5/))
      do j = 1, 2
         do i = 1, NE
            mdr%SCENE_RADIANCES(i,j) = values2(i,j)*1.e-2
         end do
      end do
      j = 3
      do i = 1, NE
         mdr%SCENE_RADIANCES(i,j) = values2(i,j)*1.e-4
      end do
      do j = 4, 5
         do i = 1, NE
            mdr%SCENE_RADIANCES(i,j) = values2(i,j)*1.e-2
         end do
      end do
      ! angular relations first
      offset = line_pos + 20522
      read(unit=uin, pos=offset) val2x4
      mdr%ANGULAR_RELATIONS(1:4,1) = val2x4*1.e-2
      ! angular relations last
      offset = line_pos + 20530
      read(unit=uin, pos=offset) val2x4
      mdr%ANGULAR_RELATIONS(1:4,NP+2) = val2x4*1.e-2
      ! earth location first
      offset = line_pos + 20538
      read(unit=uin, pos=offset) val4x2
      mdr%EARTH_LOCATIONS(1:2,1) = val4x2*1.e-4
      ! earth location last
      offset = line_pos + 20546
      read(unit=uin, pos=offset) val4x2
      mdr%EARTH_LOCATIONS(1:2,NP+2) = val4x2*1.e-4
      ! num navigation points NP
      offset = line_pos + 20554
      read(unit=uin, pos=offset) val2
      mdr%NUM_NAVIGATION_POINTS = val2
      if( mdr%NUM_NAVIGATION_POINTS /= NP ) then
         write(*,*) 'line_pos offset', line_pos, offset
         write(*,*) 'wrong number of navigation points must be ', NP, val2
         stop
      end if
      ! angular relations
      offset = line_pos + 20556
      read(unit=uin, pos=offset) val2x4xNP
      mdr%ANGULAR_RELATIONS(1:4,2:NP+1) = &
                     reshape(val2x4xNP(1:4*NP)*1.e-2,(/4,NP/))
      ! angular relations interpolation
      ylr(1:NP+2) = mdr%ANGULAR_RELATIONS(1,1:NP+2)
      call location_angular_interp( ylr, yhr )
      mdr%ANGULAR_RELATIONS_NE(1,1:NE) = yhr(1:NE)
      ylr(1:NP+2) = mdr%ANGULAR_RELATIONS(2,1:NP+2)
      call location_angular_interp( ylr, yhr )
      mdr%ANGULAR_RELATIONS_NE(2,1:NE) = yhr(1:NE)
      ylr(1:NP+2) = mdr%ANGULAR_RELATIONS(3,1:NP+2)
      call location_angular_interp( ylr, yhr )
      mdr%ANGULAR_RELATIONS_NE(3,1:NE) = yhr(1:NE)
      ylr(1:NP+2) = mdr%ANGULAR_RELATIONS(4,1:NP+2)
      call location_angular_interp( ylr, yhr )
      mdr%ANGULAR_RELATIONS_NE(4,1:NE) = yhr(1:NE)
      ! earth location
      offset = line_pos + 21380
      read(unit=uin, pos=offset) val4x2xNP
      mdr%EARTH_LOCATIONS(1:2,2:NP+1) = &
                     reshape(val4x2xNP(1:2*NP)*1.e-4,(/2,NP/))
     ! earth location interpolation
      ylr(1:NP+2) = mdr%EARTH_LOCATIONS(1,1:NP+2)
      call location_angular_interp( ylr, yhr )
      mdr%EARTH_LOCATIONS_NE(1,1:NE) = yhr(1:NE)
      ylr(1:NP+2) = mdr%EARTH_LOCATIONS(2,1:NP+2)
      call location_angular_interp( ylr, yhr )
      mdr%EARTH_LOCATIONS_NE(2,1:NE) = yhr(1:NE)
      ! quality indicator
      offset = line_pos + 22204
      read(unit=uin, pos=offset) val4
      mdr%QUALITY_INDICATOR = val4
      ! scan line quality
      offset = line_pos + 22208
      read(unit=uin, pos=offset) val4
      mdr%SCAN_LINE_QUALITY = val4
      ! cloud information
      offset = line_pos + 22472
      read(unit=uin, pos=offset) val2xNE
      mdr%CLOUD_INFORMATION = val2xNE
      return
   end subroutine read_avhrr_l1b_mdr

   subroutine read_giadr_radiance(uin, fpos, giadr_radiance)
      implicit none
      integer(kind=4)                                      :: uin, offset
      integer(kind=8)                                      :: fpos
      type(RECORD_GIADR_RADIANCE),intent(out)              :: giadr_radiance
      integer(kind=2)                                      :: val2
      integer(kind=4)                                      :: val4
      ! CH1_SOLAR_FILTERED_IRRADIANCE
      offset = fpos + 82
      read(unit=uin, pos=offset) val2
      giadr_radiance%CH1_SOLAR_FILTERED_IRRADIANCE = val2 * 1.e-1
      ! CH1_EQUIVALENT_FILTER_WIDTH
      offset = fpos + 84
      read(unit=uin, pos=offset) val2
      giadr_radiance%CH1_EQUIVALENT_FILTER_WIDTH = val2 * 1.e-3
      ! CH2_SOLAR_FILTERED_IRRADIANCE
      offset = fpos + 86
      read(unit=uin, pos=offset) val2
      giadr_radiance%CH2_SOLAR_FILTERED_IRRADIANCE = val2 * 1.e-1
      ! CH2_EQUIVALENT_FILTER_WIDTH
      offset = fpos + 88
      read(unit=uin, pos=offset) val2
      giadr_radiance%CH2_EQUIVALENT_FILTER_WIDTH = val2 * 1.e-3
      ! CH3A_SOLAR_FILTERED_IRRADIANCE
      offset = fpos + 90
      read(unit=uin, pos=offset) val2
      giadr_radiance%CH3A_SOLAR_FILTERED_IRRADIANCE = val2 * 1.e-1
      ! CH3A_EQUIVALENT_FILTER_WIDTH
      offset = fpos + 92
      read(unit=uin, pos=offset) val2
      giadr_radiance%CH3A_EQUIVALENT_FILTER_WIDTH = val2 * 1.e-3
      ! CH3B_CENTRAL_WAVENUMBER
      offset = fpos + 94
      read(unit=uin, pos=offset) val4
      giadr_radiance%CH3B_CENTRAL_WAVENUMBER = val4 * 1.e-2
      ! CH3B_CONSTANT1
      offset = fpos + 98
      read(unit=uin, pos=offset) val4
      giadr_radiance%CH3B_CONSTANT1 = val4 * 1.e-5
      ! CH3B_CONSTANT2_SLOPE
      offset = fpos + 102
      read(unit=uin, pos=offset) val4
      giadr_radiance%CH3B_CONSTANT2_SLOPE = val4 * 1.e-6
      ! CH4_CENTRAL_WAVENUMBER
      offset = fpos + 106
      read(unit=uin, pos=offset) val4
      giadr_radiance%CH4_CENTRAL_WAVENUMBER = val4 * 1.e-3
      ! CH4_CONSTANT1
      offset = fpos + 110
      read(unit=uin, pos=offset) val4
      giadr_radiance%CH4_CONSTANT1 = val4 * 1.e-5
      ! CH4_CONSTANT2_SLOPE
      offset = fpos + 114
      read(unit=uin, pos=offset) val4
      giadr_radiance%CH4_CONSTANT2_SLOPE = val4 * 1.e-6
      ! CH5_CENTRAL_WAVENUMBER
      offset = fpos + 118
      read(unit=uin, pos=offset) val4
      giadr_radiance%CH5_CENTRAL_WAVENUMBER = val4 * 1.e-3
      ! CH5_CONSTANT1
      offset = fpos + 122
      read(unit=uin, pos=offset) val4
      giadr_radiance%CH5_CONSTANT1 = val4 * 1.e-5
      ! CH5_CONSTANT2_SLOPE
      offset = fpos + 126
      read(unit=uin, pos=offset) val4
      giadr_radiance%CH5_CONSTANT2_SLOPE = val4 * 1.e-6
      return
   end subroutine read_giadr_radiance

   subroutine read_giadr_analog(uin, fpos, giadr_analog)
      implicit none
      integer(kind=4)                                      :: uin
      integer(kind=8)                                      :: fpos
      type(RECORD_GIADR_ANALOG)  ,intent(out)              :: giadr_analog
      return
   end subroutine read_giadr_analog

   subroutine read_grh(uin, fpos, grh)
      implicit none
      integer(kind=4)                 , intent(in)  :: uin
      integer(kind=8)                 , intent(in)  :: fpos
      type(RECORD_HEADER)  , intent(out) :: grh
      read(unit=uin, pos=fpos) grh%RECORD_CLASS, grh%INSTRUMENT_GROUP, &
           grh%RECORD_SUBCLASS, grh%RECORD_SUBCLASS_VERSION,           &
           grh%RECORD_SIZE, grh%RECORD_START_TIME%day,                 &  
           grh%RECORD_START_TIME%msec, grh%RECORD_END_TIME%day,        &
           grh%RECORD_END_TIME%msec
   end subroutine read_grh

   subroutine print_grh(grh)
      implicit none
      type(RECORD_HEADER), intent(in) :: grh
      write(19,'(A,T32,I10)') "RECORD_CLASS", grh%RECORD_CLASS
      write(19,'(A,T32,I10)') "INSTRUMENT_GROUP", grh%INSTRUMENT_GROUP
      write(19,'(A,T32,I10)') "RECORD_SUBCLASS", grh%RECORD_SUBCLASS
      write(19,'(A,T32,I10)') "RECORD_SUBCLASS_VERSION", grh%RECORD_SUBCLASS_VERSION
      write(19,'(A,T32,I10)') "RECORD_SIZE", grh%RECORD_SIZE
      write(19,'(A,T32,I10)') "RECORD_START_TIME%day ", grh%RECORD_START_TIME%day
      write(19,'(A,T32,I10)') "RECORD_START_TIME%msec", grh%RECORD_START_TIME%msec
      write(19,'(A,T32,I10)') "RECORD_END_TIME%day ", grh%RECORD_END_TIME%day
      write(19,'(A,T32,I10)') "RECORD_END_TIME%msec", grh%RECORD_END_TIME%msec
   end subroutine print_grh


   subroutine read_iasi_l2_mdr(uin, fpos, mdr_l2)
      implicit none
      ! Arguments
      integer(kind=4)      , intent(in)       :: uin
      integer(kind=8)      , intent(in)       :: fpos
      type(RECORD_MDR_L2), intent(out)        :: mdr_l2
      ! internal variables
      type(RECORD_HEADER)                     :: grh
      integer(kind=1)                         :: lvalue
      integer(kind=1)                         :: i1value
      integer(kind=4)                         :: i4value
      integer(kind=2) ,dimension(NLT,PN,SNOT) :: vi2valueNLTPNSNOT
      integer(kind=4) ,dimension(NLQ,PN,SNOT) :: vi4valueNLQPNSNOT
      integer(kind=2) ,dimension(NLO,PN,SNOT) :: vi2valueNLOPNSNOT
      integer(kind=4) ,dimension(PN,SNOT)     :: vi4valuePNSNOT
      integer(kind=2) ,dimension(PN,SNOT)     :: vi2valuePNSNOT
      integer(kind=1) ,dimension(PN,SNOT)     :: vi1valuePNSNOT
      integer(kind=2) ,dimension(NEW)         :: vi2valueNEW
      integer(kind=4) ,dimension(3,PN,SNOT)   :: vi4value3PNSNOT
      integer(kind=2) ,dimension(3,PN,SNOT)   :: vi2value3PNSNOT
      integer(kind=1) ,dimension(3,PN,SNOT)   :: vi1value3PNSNOT
      integer(kind=4) ,dimension(2,PN,SNOT)   :: vi4value2PNSNOT
      integer(kind=2) ,dimension(4,PN,SNOT)   :: vi2value4PNSNOT
      ! read generic record header
      call read_grh(uin, fpos, grh)
      mdr_l2%cds_date(1) = grh%RECORD_START_TIME
      mdr_l2%cds_date(2) = grh%RECORD_END_TIME
      ! DEGRADED FLAGS
      read(unit=uin, pos=fpos+20) lvalue
      mdr_l2%DEGRADED_INST_MDR = lvalue == 1
      read(unit=uin, pos=fpos+21) lvalue
      mdr_l2%DEGRADED_PROC_MDR = lvalue == 1
      ! FG_ATMOSPHERIC_TEMPERATURE
      read(unit=uin, pos=fpos+22) vi2valueNLTPNSNOT
      mdr_l2%FG_ATMOSPHERIC_TEMPERATURE = reshape(vi2valueNLTPNSNOT * 1e-2,(/NLT,PN,SNOT/))
      ! FG_ATMOSPHERIC_WATER_VAPOUR
      read(unit=uin, pos=fpos+24262) vi4valueNLQPNSNOT
      mdr_l2%FG_ATMOSPHERIC_WATER_VAPOUR = reshape(vi4valueNLQPNSNOT * 1e-7,(/NLQ,PN,SNOT/))
      ! FG_ATMOSPHERIC_OZONE
      read(unit=uin, pos=fpos+72742) vi2valueNLOPNSNOT
      mdr_l2%FG_ATMOSPHERIC_OZONE = reshape(vi2valueNLOPNSNOT * 1e-8,(/NLO,PN,SNOT/))
      ! FG_SURFACE_TEMPERATURE
      read(unit=uin, pos=fpos+96982) vi2valuePNSNOT
      mdr_l2%FG_SURFACE_TEMPERATURE = reshape(vi2valuePNSNOT * 1e-2,(/PN,SNOT/))
      ! FG_QI_ATMOSPHERIC_TEMPERATURE
      read(unit=uin, pos=fpos+97222) vi1valuePNSNOT
      mdr_l2%FG_QI_ATMOSPHERIC_TEMPERATURE = reshape(vi1valuePNSNOT * 1e-1,(/PN,SNOT/))
      ! FG_QI_ATMOSPHERIC_WATER_VAPOUR
      read(unit=uin, pos=fpos+97342) vi1valuePNSNOT
      mdr_l2%FG_QI_ATMOSPHERIC_WATER_VAPOUR = reshape(vi1valuePNSNOT * 1e-1,(/PN,SNOT/))
      ! FG_QI_ATMOSPHERIC_OZONE
      read(unit=uin, pos=fpos+97462) vi1valuePNSNOT
      mdr_l2%FG_QI_ATMOSPHERIC_OZONE = reshape(vi1valuePNSNOT * 1e-1,(/PN,SNOT/))
      ! FG_QI_SURFACE_TEMPERATURE
      read(unit=uin, pos=fpos+97582) vi1valuePNSNOT
      mdr_l2%FG_QI_SURFACE_TEMPERATURE = reshape(vi1valuePNSNOT * 1e-1,(/PN,SNOT/))
      ! ATMOSPHERIC_TEMPERATURE
      read(unit=uin, pos=fpos+97702) vi2valueNLTPNSNOT
      mdr_l2%ATMOSPHERIC_TEMPERATURE = reshape(vi2valueNLTPNSNOT * 1e-2,(/NLT,PN,SNOT/))
      ! ATMOSPHERIC_WATER_VAPOUR
      read(unit=uin, pos=fpos+121942) vi4valueNLQPNSNOT
      mdr_l2%ATMOSPHERIC_WATER_VAPOUR = reshape(vi4valueNLQPNSNOT * 1e-7,(/NLQ,PN,SNOT/))
      ! ATMOSPHERIC_OZONE
      read(unit=uin, pos=fpos+170422) vi2valueNLOPNSNOT
      mdr_l2%ATMOSPHERIC_OZONE = reshape(vi2valueNLOPNSNOT * 1e-8,(/NLO,PN,SNOT/))
      ! SURFACE_TEMPERATURE
      read(unit=uin, pos=fpos+194662) vi2valuePNSNOT
      mdr_l2%SURFACE_TEMPERATURE = reshape(vi2valuePNSNOT * 1e-2,(/PN,SNOT/))
      ! INTEGRATED_WATER_VAPOUR
      read(unit=uin, pos=fpos+194902) vi2valuePNSNOT
      mdr_l2%INTEGRATED_WATER_VAPOUR = reshape(vi2valuePNSNOT * 1e-2,(/PN,SNOT/))
      ! INTEGRATED_OZONE
      read(unit=uin, pos=fpos+195142) vi2valuePNSNOT
      mdr_l2%INTEGRATED_OZONE = reshape(vi2valuePNSNOT * 1e-6,(/PN,SNOT/))
      ! INTEGRATED_N2O
      read(unit=uin, pos=fpos+195382) vi2valuePNSNOT
      mdr_l2%INTEGRATED_N2O = reshape(vi2valuePNSNOT * 1e-6,(/PN,SNOT/))
      ! INTEGRATED_CO
      read(unit=uin, pos=fpos+195622) vi2valuePNSNOT
      mdr_l2%INTEGRATED_CO = reshape(vi2valuePNSNOT * 1e-7,(/PN,SNOT/))
      ! INTEGRATED_CH4
      read(unit=uin, pos=fpos+195862) vi2valuePNSNOT
      mdr_l2%INTEGRATED_CH4 = reshape(vi2valuePNSNOT * 1e-6,(/PN,SNOT/))
      ! INTEGRATED_CO2
      read(unit=uin, pos=fpos+196102) vi2valuePNSNOT
      mdr_l2%INTEGRATED_CO2 = reshape(vi2valuePNSNOT * 1e-3,(/PN,SNOT/))
      ! SURFACE_EMISSIVITY
      read(unit=uin, pos=fpos+196342) vi2valueNEW
      mdr_l2%SURFACE_EMISSIVITY = vi2valueNEW * 1e-4
      ! NUMBER_CLOUD_FORMATIONS
      read(unit=uin, pos=fpos+199342) vi1valuePNSNOT
      mdr_l2%NUMBER_CLOUD_FORMATIONS = reshape(vi1valuePNSNOT,(/PN,SNOT/))
      ! FRACTIONAL_CLOUD_COVER
      read(unit=uin, pos=fpos+199342) vi2value3PNSNOT
      mdr_l2%FRACTIONAL_CLOUD_COVER = reshape(vi2value3PNSNOT * 1e-2,(/3,PN,SNOT/))
      ! CLOUD_TOP_TEMPERATURE
      read(unit=uin, pos=fpos+200062) vi2value3PNSNOT
      mdr_l2%CLOUD_TOP_TEMPERATURE = reshape(vi2value3PNSNOT * 1e-2,(/3,PN,SNOT/))
      ! CLOUD_TOP_PRESSURE
      read(unit=uin, pos=fpos+200782) vi4value3PNSNOT
      mdr_l2%CLOUD_TOP_PRESSURE = reshape(vi4value3PNSNOT,(/3,PN,SNOT/))
      ! CLOUD_PHASE
      read(unit=uin, pos=fpos+202222) vi1value3PNSNOT
      mdr_l2%CLOUD_PHASE = reshape(vi1value3PNSNOT,(/3,PN,SNOT/))
      ! SURFACE_PRESSURE
      read(unit=uin, pos=fpos+202582) vi4valuePNSNOT
      mdr_l2%SURFACE_PRESSURE = reshape(vi4valuePNSNOT,(/PN,SNOT/))
      ! INSTRUMENT_MODE
      read(unit=uin, pos=fpos+203062) i1value
      mdr_l2%INSTRUMENT_MODE = i1value
      ! SPACECRAFT_ALTITUDE
      read(unit=uin, pos=fpos+203063) i4value
      mdr_l2%SPACECRAFT_ALTITUDE = i4value * 1e-1
      ! ANGULAR_RELATION
      read(unit=uin, pos=fpos+203067) vi2value4PNSNOT
      mdr_l2%ANGULAR_RELATION = reshape(vi2value4PNSNOT * 1e-2 ,(/4,PN,SNOT/))
      ! EARTH_LOCATION
      read(unit=uin, pos=fpos+204027) vi4value2PNSNOT
      mdr_l2%EARTH_LOCATION = reshape(vi4value2PNSNOT * 1e-4 ,(/2,PN,SNOT/))
      ! FLG_AMSUBAD
      read(unit=uin, pos=fpos+204987) vi1valuePNSNOT
      mdr_l2%FLG_AMSUBAD = reshape(vi1valuePNSNOT,(/PN,SNOT/))
      ! FLG_AVHRRBAD
      read(unit=uin, pos=fpos+205107) vi1valuePNSNOT
       mdr_l2%FLG_AVHRRBAD = reshape(vi1valuePNSNOT,(/PN,SNOT/))
     ! FLG_CLDFRM
      read(unit=uin, pos=fpos+205227) vi1valuePNSNOT
      mdr_l2%FLG_CLDFRM = reshape(vi1valuePNSNOT,(/PN,SNOT/))
      ! FLG_CLDNES
      read(unit=uin, pos=fpos+205347) vi1valuePNSNOT
      mdr_l2%FLG_CLDNES = reshape(vi1valuePNSNOT,(/PN,SNOT/))
      ! FLG_CLDTST
      read(unit=uin, pos=fpos+205467) vi2valuePNSNOT
      mdr_l2%FLG_CLDTST = reshape(vi2valuePNSNOT,(/PN,SNOT/))
      ! FLG_DAYNIT
      read(unit=uin, pos=fpos+205707) vi1valuePNSNOT
      mdr_l2%FLG_DAYNIT = reshape(vi1valuePNSNOT,(/PN,SNOT/))
      ! FLG_DUSTCLD
      read(unit=uin, pos=fpos+205827) vi1valuePNSNOT
      mdr_l2%FLG_DUSTCLD = reshape(vi1valuePNSNOT * 1e-1 ,(/PN,SNOT/))
      ! FLG_FGCHECK
      read(unit=uin, pos=fpos+205947) vi2valuePNSNOT
      mdr_l2%FLG_FGCHECK = reshape(vi2valuePNSNOT,(/PN,SNOT/))
      ! FLG_IASIBAD
      read(unit=uin, pos=fpos+206187) vi1valuePNSNOT
      mdr_l2%FLG_IASIBAD = reshape(vi1valuePNSNOT,(/PN,SNOT/))
      ! FLG_INITIA
      read(unit=uin, pos=fpos+206307) vi1valuePNSNOT
      mdr_l2%FLG_INITIA = reshape(vi1valuePNSNOT,(/PN,SNOT/))
      ! FLG_ITCONV
      read(unit=uin, pos=fpos+206427) vi1valuePNSNOT
      mdr_l2%FLG_ITCONV = reshape(vi1valuePNSNOT,(/PN,SNOT/))
      ! FLG_LANSEA
      read(unit=uin, pos=fpos+206547) vi1valuePNSNOT
      mdr_l2%FLG_LANSEA = reshape(vi1valuePNSNOT,(/PN,SNOT/))
      ! FLG_MHSBAD
      read(unit=uin, pos=fpos+206667) vi1valuePNSNOT
      mdr_l2%FLG_MHSBAD = reshape(vi1valuePNSNOT,(/PN,SNOT/))
      ! FLG_NUMIT
      read(unit=uin, pos=fpos+206787) vi1valuePNSNOT
      mdr_l2%FLG_NUMIT = reshape(vi1valuePNSNOT,(/PN,SNOT/))
      ! FLG_NWPBAD
      read(unit=uin, pos=fpos+206907) vi1valuePNSNOT
      mdr_l2%FLG_NWPBAD = reshape(vi1valuePNSNOT,(/PN,SNOT/))
      ! FLG_PHYSCHECK
      read(unit=uin, pos=fpos+207027) vi1valuePNSNOT
      mdr_l2%FLG_PHYSCHECK = reshape(vi1valuePNSNOT,(/PN,SNOT/))
      ! FLG_RETCHECK
      read(unit=uin, pos=fpos+207147) vi2valuePNSNOT
      mdr_l2%FLG_RETCHECK = reshape(vi2valuePNSNOT,(/PN,SNOT/))
      ! FLG_SATMAN
      read(unit=uin, pos=fpos+207387) vi1valuePNSNOT
      mdr_l2%FLG_SATMAN = reshape(vi1valuePNSNOT,(/PN,SNOT/))
      ! FLG_SUNGLNT
      read(unit=uin, pos=fpos+207507) vi1valuePNSNOT
      mdr_l2%FLG_SUNGLNT = reshape(vi1valuePNSNOT,(/PN,SNOT/))
      ! FLG_THICIR
      read(unit=uin, pos=fpos+207627) vi1valuePNSNOT
      mdr_l2%FLG_THICIR = reshape(vi1valuePNSNOT,(/PN,SNOT/))


      return
   end subroutine read_iasi_l2_mdr

   subroutine read_giadr_scale_factors(uin, fpos, giadr_sf)
      implicit none
      integer(kind=4)                 , intent(in)  :: uin
      integer(kind=8)                 , intent(in)  :: fpos
      type(RECORD_GIADR_SCALE_FACTORS), intent(out) :: giadr_sf
      read(unit=uin, pos=fpos+20) giadr_sf 
      return
   end subroutine read_giadr_scale_factors

   subroutine read_giadr_quality(uin, fpos, giadr_quality)
      implicit none
      integer(kind=4)             , intent(in)  :: uin
      integer(kind=8)             , intent(in)  :: fpos
      type(RECORD_GIADR_QUALITY)  , intent(out) :: giadr_quality
      integer(kind=4)                           :: i, j, k
      integer(kind=4)                           :: i4value
      type(VINTEGER4)                           :: vi4value
      integer(kind=4)    ,dimension(PN)         :: i4value4
      integer(kind=4)    ,dimension(100,PN)     :: i4values
      type(VINTEGER4)    ,dimension(100,100,PN) :: vi4values
      type(VINTEGER4)    ,dimension(100)        :: vi4value100
      type(VINTEGER4)    ,dimension(IMCO,IMLI)  :: vi4value6464
      integer(kind=1)    ,dimension(IMCO,IMLI)  :: lvalue6464
      !
      ! PSF dimensions
      read(unit=uin, pos=fpos+20) i4value4
      do i = 1, PN
        giadr_quality%IDefPsfSondNbLin(i) = i4value4(i)
      end do
      read(unit=uin, pos=fpos+36) i4value4
      do i = 1, PN
        giadr_quality%IDefPsfSondNbCol(i) = i4value4(i)
      end do
      ! PSF over samp factor
      read(unit=uin, pos=fpos+52) vi4value
      giadr_quality%IDefPsfSondOverSampFactor = vint42r4_0d(vi4value)
      ! PSF coordinates
      read(unit=uin, pos=fpos+57) i4values
      do j = 1, PN
        do i = 1, giadr_quality%IDefPsfSondNbLin(PN)
          giadr_quality%IDefPsfSondY(i,j) = i4values(i,j) * 1e-6
        end do
      end do
      read(unit=uin, pos=fpos+1657) i4values
      do j = 1, PN
        do i = 1, giadr_quality%IDefPsfSondNbCol(PN)
          giadr_quality%IDefPsfSondZ(i,j) = i4values(i,j) * 1e-6
        end do
      end do
      ! PSF weights
      read(unit=uin, pos=fpos+3257) vi4values
      do j = 1, PN
        do i = 1, giadr_quality%IDefPsfSondNbLin(PN)
          do k = 1, giadr_quality%IDefPsfSondNbCol(PN)
            giadr_quality%IDefPsfSondWgt(k,i,j) = vint42r4_0d(vi4values(k,i,j))
          end do
        end do
      end do
      ! IIS SRF dimensions
      read(unit=uin, pos=fpos+203257) i4value
      giadr_quality%IDefllSSrfNsfirst = i4value
      read(unit=uin, pos=fpos+203261) i4value
      giadr_quality%IDefllSSrfNslast = i4value
      ! IIS SRF weigths
      read(unit=uin, pos=fpos+203265) vi4value100
      do i = 1, 100
        giadr_quality%IDefllSSrf(i) = vint42r4_0d(vi4value100(i))
      end do
      ! IIS SRF spectral step
      read(unit=uin, pos=fpos+203765) vi4value
      giadr_quality%IDefllSSrfDWn = vint42r4_0d(vi4value)
      ! IIS Noise
      read(unit=uin, pos=fpos+203770) vi4value6464
      do j = 1, IMLI
        do i = 1, IMCO
          giadr_quality%IDefIISNeDT(i,j) = vint42r4_0d(vi4value6464(i,j))
        end do
      end do
      ! IIS Dead Pixels Map
      read(unit=uin, pos=fpos+224250) lvalue6464
      do j = 1, IMLI
        do i = 1, IMCO
          giadr_quality%IDefDptIISDeadPix(i,j) = lvalue6464(i,j)==1
        end do
      end do
      !print*, sizeof(i1)
      !print*, sizeof(lvalue6464(1,1))
      !print*, sizeof(giadr_quality%IDefDptIISDeadPix(1,1))
      return
   end subroutine read_giadr_quality

   subroutine print_giadr_quality(giadr_quality)
      implicit none
      type(RECORD_GIADR_QUALITY), intent(in)    :: giadr_quality
      integer(kind=4)                           :: i, j, k
      integer(kind=4)    ,dimension(IMCO)       :: col
      !
      write(21,*) 'IDefPsfSondOverSampFactor ', giadr_quality%IDefPsfSondOverSampFactor
      write(21,*) 'IDefPsfSondNbLin ', giadr_quality%IDefPsfSondNbLin(1:PN) 
      write(21,*) 'IDefPsfSondNbCol ', giadr_quality%IDefPsfSondNbCol(1:PN) 
      do i = 1, PN
        write(21,*) 'IDefPsfSondY      ', i, giadr_quality%IDefPsfSondY(1:&
                                             giadr_quality%IDefPsfSondNbCol(i),i)
        write(21,*) 'IDefPsfSondZ      ', i, giadr_quality%IDefPsfSondZ(1:&
                                             giadr_quality%IDefPsfSondNbLin(i),i)
      end do
      write(22,*) 'IDefllSSrfNsfirst ', giadr_quality%IDefllSSrfNsfirst 
      write(22,*) 'IDefllSSrfNslast  ', giadr_quality%IDefllSSrfNslast 
      write(22,*) 'IDefllSSrfDWn     ', giadr_quality%IDefllSSrfDWn 
      write(22,*) 'IDefllSSrfWnfirst ', giadr_quality%IDefllSSrfDWn&
                                       *(giadr_quality%IDefllSSrfNsfirst-1)
      write(22,*) 'IDefllSSrfWnlast  ', giadr_quality%IDefllSSrfDWn&
                                       *(giadr_quality%IDefllSSrfNslast-1)
      write(22,*) 'IDefllSSrf        ', giadr_quality%IDefllSSrf 
      do i = 1, IMCO
        col(i) = i
      end do
      write(23,*) 'giadr_quality%IDefDptIISDeadPix'
      write(23,'(a ,64(i3))') "col",(col(i), i=1,IMCO)
      do j = 1, IMLI
        write(23,*) j,(giadr_quality%IDefDptIISDeadPix(i,j), i=1,IMCO)
      end do
      write(24,*) 'giadr_quality%IDefIISNeDT'
      write(24,'(a ,64(i5))') "col",(col(i), i=1,IMCO)
      do j = 1, IMLI
        write(24,'(i3,64f5.2)') j,(giadr_quality%IDefIISNeDT(i,j), i=1,IMCO)
      end do 
      return
   end subroutine print_giadr_quality

   subroutine read_giadr_l2(uin, fpos, giadr_l2)
      implicit none
      integer(kind=4)        , intent(in)       :: uin
      integer(kind=8)        , intent(in)       :: fpos
      type(RECORD_GIADR_L2)  , intent(out)      :: giadr_l2
      integer(kind=1)                           :: i1value
      integer(kind=4)                           :: i4value
      integer(kind=4)   ,dimension(NLT)         :: vi4valueNLT
      integer(kind=4)   ,dimension(NLQ)         :: vi4valueNLQ
      integer(kind=4)   ,dimension(NLO)         :: vi4valueNLO
      integer(kind=4)   ,dimension(NEW)         :: vi4valueNEW
      integer(kind=2)   ,dimension(NL_CO)       :: vi2valueNL_CO
      integer(kind=2)   ,dimension(NL_HNO3)     :: vi2valueNL_HNO3
      integer(kind=2)   ,dimension(NL_O3)       :: vi2valueNL_O3
      integer(kind=2)   ,dimension(NL_SO2)      :: vi2valueNL_SO2
      ! TEMP
      read(unit=uin, pos=fpos+20) i1value
      giadr_l2%NUM_PRESSURE_LEVELS_TEMP = i1value
      read(unit=uin, pos=fpos+21) vi4valueNLT
      giadr_l2%PRESSURE_LEVELS_TEMP = vi4valueNLT * 1e-2
      ! HUMIDITY
      read(unit=uin, pos=fpos+425) i1value
      giadr_l2%NUM_PRESSURE_LEVELS_HUMIDITY = i1value
      read(unit=uin, pos=fpos+426) vi4valueNLQ
      giadr_l2%PRESSURE_LEVELS_HUMIDITY = vi4valueNLQ * 1e-2
      ! OZONE
      read(unit=uin, pos=fpos+830) i1value
      giadr_l2%NUM_PRESSURE_LEVELS_OZONE = i1value
      read(unit=uin, pos=fpos+831) vi4valueNLO
      giadr_l2%PRESSURE_LEVELS_OZONE = vi4valueNLO * 1e-2
      ! EMISSIVITY
      read(unit=uin, pos=fpos+1235) i1value
      giadr_l2%NUM_SURFACE_EMISSIVITY_WAVELENGTH = i1value
      read(unit=uin, pos=fpos+1236) vi4valueNEW
      giadr_l2%SURFACE_EMISSIVITY_WAVELENGTH = vi4valueNEW * 1e-4
      ! TEMP PCS
      read(unit=uin, pos=fpos+1284) i1value
      giadr_l2%NUM_TEMPERATURE_PCS = i1value
      ! HUMIDITY PCS
      read(unit=uin, pos=fpos+1285) i1value
      giadr_l2%NUM_WATER_VAPOUR_PCS = i1value
      ! OZONE PCS
      read(unit=uin, pos=fpos+1286) i1value
      giadr_l2%NUM_OZONE_PCS = i1value
      ! FORLI CO
      read(unit=uin, pos=fpos+1287) i1value
      giadr_l2%FORLI_NUM_LAYERS_CO = i1value
      read(unit=uin, pos=fpos+1288) vi2valueNL_CO
      giadr_l2%FORLI_LAYERS_HEIGHTS_CO = vi2valueNL_CO * 1e-0
      ! FORLI HNO3
      read(unit=uin, pos=fpos+1326) i1value
      giadr_l2%FORLI_NUM_LAYERS_HNO3 = i1value
      read(unit=uin, pos=fpos+1327) vi2valueNL_HNO3
      giadr_l2%FORLI_LAYERS_HEIGHTS_HNO3 = vi2valueNL_HNO3 * 1e-0
      ! FORLI_O3
      read(unit=uin, pos=fpos+1365) i1value
      giadr_l2%FORLI_NUM_LAYERS_O3 = i1value
      read(unit=uin, pos=fpos+1366) vi2valueNL_O3
      giadr_l2%FORLI_LAYERS_HEIGHTS_O3 = vi2valueNL_O3 * 1e-0
      ! BRESCIA SO2
      read(unit=uin, pos=fpos+1446) i1value
      giadr_l2%BRESCIA_NUM_ALTITUDES_SO2 = i1value
      read(unit=uin, pos=fpos+1447) vi2valueNL_SO2
      giadr_l2%BRESCIA_ALTITUDES_SO2 = vi2valueNL_SO2 * 1e-0
      return
   end subroutine read_giadr_l2

   subroutine read_geadr(uin, fpos, geadr)
      implicit none
      integer(kind=4)   , intent(in)  :: uin, fpos
      type(RECORD_GEADR), intent(out) :: geadr
      read(unit=uin, pos=fpos+20) geadr
      return
   end subroutine read_geadr

   subroutine l1c_getDatIASI(uin, linePos, date_iasi)
      implicit none
      integer(kind=4), intent(in)  :: uin
      integer(kind=8), intent(in)  :: linePos
      type(SHORT_CDS_TIME), dimension(SNOT)  :: date_iasi
      integer(kind=8)                        :: offset
      offset = linePos + 9122
      read(unit=uin, pos=offset) date_iasi
      return   
   end subroutine l1c_getDatIASI

   subroutine l1c_getRadAnal(uin, linePos, radanal)
      implicit none
      ! Arguments
      integer(kind=4), intent(in)  :: uin
      integer(kind=8), intent(in)  :: linePos
      type(AVHRR_RAD_ANAL)        :: radanal
      ! Internal variables
      type(VINTEGER4)             :: values(NBK*NCL*PN*SNOT)
      real(kind=4)                :: vvals(NBK*NCL*PN*SNOT)
      real(kind=4)                :: rvals(NCL*PN*SNOT)
      integer(kind=4)             :: ivals(NCL*PN*SNOT)
      integer(kind=4)             :: j
      ! channelid
      read(unit=uin, pos=linePos + 2365790) radanal % channelid
      ! nbclass
      read(unit=uin, pos=linePos + 2365814) radanal % nbclass
      ! wgt
      read(unit=uin, pos=linePos + 2366294) values(1:NCL*PN*SNOT)
      do j = 1, NCL*PN*SNOT
         rvals(j) = vint42r4_0d(values(j))
      enddo
      !rvals(1:NCL*PN*SNOT) = vint42r4(values(1:NCL*PN*SNOT))
      radanal % wgt = reshape(rvals(1:NCL*PN*SNOT),(/NCL,PN,SNOT/))
      ! Y
      read(unit=uin, pos=linePos + 2370494) ivals
      radanal % Y = reshape(ivals(1:NCL*PN*SNOT)* 1e-6,(/NCL,PN,SNOT/))
      ! Z
      read(unit=uin, pos=linePos + 2373854) ivals
      radanal % Z = reshape(ivals(1:NCL*PN*SNOT)* 1e-6,(/NCL,PN,SNOT/))
      ! mean
      read(unit=uin, pos=linePos + 2377214) values
      do j = 1, NBK*NCL*PN*SNOT
         vvals(j) = vint42r4_0d(values(j))
      enddo
      radanal % mean = reshape(vvals,(/NBK,NCL,PN,SNOT/))
      ! std
      read(unit=uin, pos=linePos + 2402414) values
      do j = 1, NBK*NCL*PN*SNOT
         vvals(j) = vint42r4_0d(values(j))
      enddo
      radanal % std = reshape(vvals,(/NBK,NCL,PN,SNOT/))
      ! imageclassified
      read(unit=uin, pos=linePos + 2427614) radanal % imageclassified
      ! ccsmode
      read(unit=uin, pos=linePos + 2727614) radanal % ccsmode
      ! imageclassifiednblin
      read(unit=uin, pos=linePos + 2727618) radanal % imageclassifiednblin
      ! imageclassifiednbcol
      read(unit=uin, pos=linePos + 2727678) radanal % imageclassifiednbcol
      ! classtype
      read(unit=uin, pos=linePos + 2728038) radanal % classtype
      
      return   
   end subroutine l1c_getRadAnal

   subroutine l1c_getLongLat(uin, linePos, lon, lat)
      implicit none
      integer(kind=4), intent(in)  :: uin
      integer(kind=8), intent(in)  :: linePos
      real(kind=4)   , dimension(PN,SNOT)   :: lon, lat
      integer(kind=8)                       :: offset
      integer(kind=4), dimension(2*PN*SNOT) :: values
      integer(kind=4)                       :: i, j, k
      offset = linePos + 255893
      read(unit=uin, pos=offset) values
      do i = 1, SNOT
         do j = 1, PN
            k = (i-1)*PN + j
            lon(j,i) = values(2*k-1) * 1e-6
            lat(j,i) = values(2*k  ) * 1e-6
         enddo
      enddo
      return   
   end subroutine l1c_getLongLat

   subroutine l1c_getIISLoc(uin, linePos, IISlon, IISlat)
      implicit none
      integer(kind=4), intent(in)  :: uin
      integer(kind=8), intent(in)  :: linePos
      real(kind=4)   , dimension(SGI,SNOT)   :: IISlon, IISlat
      integer(kind=4), dimension(2*SGI*SNOT) :: values
      integer(kind=4)                        :: i, j, k
      read(unit=uin, pos=linePos + 270773) values
      do i = 1, SNOT
         do j = 1, SGI
            k = (i-1)*SGI + j
            IISlon(j,i) = values(2*k-1) * 1e-6
            IISlat(j,i) = values(2*k  ) * 1e-6
         enddo
      enddo
      return   
   end subroutine l1c_getIISLoc

   subroutine l1c_getMetopAngles(uin, linePos, zen, azi)
      implicit none
      integer(kind=4), intent(in)  :: uin
      integer(kind=8), intent(in)  :: linePos
      real(kind=4), dimension(PN,SNOT)      :: zen, azi
      integer(kind=8)                       :: offset
      integer(kind=4), dimension(2*PN*SNOT) :: values
      integer(kind=4)                       :: i, j, k
      offset = linePos + 256853
      read(unit=uin, pos=offset) values
      do i = 1, SNOT
         do j = 1, PN
            k = (i-1)*PN + j
            zen(j,i) = values(2*k-1) * 1e-6
            azi(j,i) = values(2*k  ) * 1e-6
         enddo
      enddo
      return
   end subroutine l1c_getMetopAngles

   subroutine l1c_getSunAngles(uin, linePos, zen, azi)
      implicit none
      integer(kind=4), intent(in)  :: uin
      integer(kind=8), intent(in)  :: linePos
      real(kind=4)   , dimension(PN,SNOT)   :: zen, azi
      integer(kind=8)                       :: offset
      integer(kind=4), dimension(2*PN*SNOT) :: values
      integer(kind=4)                       :: i, j, k
      offset = linePos + 263813
      read(unit=uin, pos=offset) values
      do i = 1, SNOT
         do j = 1, PN
            k = (i-1)*PN + j
            zen(j,i) = values(2*k-1) * 1e-6
            azi(j,i) = values(2*k  ) * 1e-6
         enddo
      enddo
      return
   end subroutine l1c_getSunAngles

   subroutine l1c_getEUMAvhrr(uin, linePos, clc, lfr, sif)
      implicit none
      integer(kind=4), intent(in)  :: uin
      integer(kind=8), intent(in)  :: linePos
      integer(kind=1), dimension(PN,SNOT)   :: clc, lfr, sif
      integer(kind=8)                       :: offset
      integer(kind=1), dimension(3*PN*SNOT) :: values
      offset = linePos + 2728548
      read(unit=uin, pos=offset) values
      clc = reshape(values(          1:1*PN*SNOT),(/PN,SNOT/))
      lfr = reshape(values(  PN*SNOT+1:2*PN*SNOT),(/PN,SNOT/))
      sif = reshape(values(2*PN*SNOT+1:3*PN*SNOT),(/PN,SNOT/))
      return
   end subroutine l1c_getEUMAvhrr

   subroutine l1c_getRadiances( uin, linePos, giadr_sf, rad, &
                                dWn, NsFirst, NsLast )
      implicit none
      ! Arguments
      integer(kind=4), intent(in)  :: uin
      integer(kind=8), intent(in)  :: linePos
      type(RECORD_GIADR_SCALE_FACTORS), intent(in)   :: giadr_sf
      real(kind=4)  ,dimension(:,:,:) , intent(inout):: rad
      real(kind=4)                    , intent(out)  :: dWn
      integer(kind=4)                 , intent(out)  :: NsFirst
      integer(kind=4)                 , intent(out)  :: NsLast
      ! Internal 
      integer(kind=8)                                :: offset
      type(VINTEGER4)                                :: vi4value
      integer(kind=4)                                :: i4value
      integer(kind=2), dimension(:)    ,allocatable  :: values
      integer(kind=2), dimension(:,:,:),allocatable  :: values3d
      real(kind=4)                                   :: powsf
      integer(kind=4)                                :: jp, jc, jsf, j, i, l
      ! Spectral step number IDefSpectDWn1b
      offset = linePos + 276777
      read(unit=uin, pos=offset) vi4value
      dWn = vint42r4_0d(vi4value)
      !
      ! first spectral index IDefNsfirst1b
      offset = linePos + 276782
      read(unit=uin, pos=offset) i4value
      NsFirst = i4value
      !
      ! last spectral index IDefNslast1b
      offset = linePos + 276786
      read(unit=uin, pos=offset) i4value
      NsLast = i4value
      !
      ! radiances 
      offset = linePos + 276790
      allocate(values(8700*PN*SNOT))
      read(unit=uin, pos=offset) values

      allocate(values3d(8700,PN,SNOT))
      values3d = reshape(values(1:8700*PN*SNOT),(/8700,PN,SNOT/))

      do j = 1, SNOT
         do i = 1, PN
            do jsf = 1, giadr_sf%IDefScaleSondNbScale
               powsf = 10.0**(-giadr_sf%IDefScaleSondScaleFactor(jsf))
               do jc = giadr_sf % IDefScaleSondNsFirst(jsf), &
                    min(giadr_sf % IDefScaleSondNsLast(jsf),NsLast)
                  l = jc - NsFirst + 1
                  rad(l,i,j) =  real(values3d(l,i,j),4) * powsf
               end do
            end do
         end do
      end do
      deallocate(values3d)
      deallocate(values)

   end subroutine l1c_getRadiances

   subroutine l1c_getFlagQual_3(uin, linePos, flg)
      implicit none
      integer(kind=4), intent(in)  :: uin
      integer(kind=8), intent(in)  :: linePos
      integer(kind=1), intent(out) :: flg(SB,PN,SNOT)
      
      read(uin, pos=linepos+255260) flg
      
      return
   end subroutine l1c_getFlagQual_3

   subroutine l1c_getIasiMode(uin, linePos, GEPSIasiMode)
      implicit none
      integer(kind=4), intent(in)  :: uin
      integer(kind=8), intent(in)  :: linePos
      integer(kind=2)              :: vali2_a
      integer(kind=2)              :: vali2_b
      real(kind=4)                 :: valr4
      integer(kind=4), intent(out) :: GEPSIasiMode
      
      read(uin, pos=linepos+24) vali2_b
      vali2_a = 0
      call commute32bits2i4( vali2_a, vali2_b, valr4 )
      GEPSIasiMode = int( valr4 )
      
      return
   end subroutine l1c_getIasiMode

   subroutine l1c_getSP(uin, linePos, GEPS_SP)
      implicit none
      integer(kind=4), intent(in)  :: uin
      integer(kind=8), intent(in)  :: linePos
      integer(kind=4), intent(out) :: GEPS_SP(SNOT)
      
      read(uin, pos=linepos+9380) GEPS_SP
      
      return
   end subroutine l1c_getSP

   subroutine l1c_getCCD(uin, linePos, GEPS_CCD)
      implicit none
      integer(kind=4), intent(in)  :: uin
      integer(kind=8), intent(in)  :: linePos
      integer(kind=1), intent(out) :: GEPS_CCD(SNOT)
      
      read(uin, pos=linepos+9350) GEPS_CCD
      
      return
   end subroutine l1c_getCCD

   function rad2brt(wn, rad) result(brt)
      implicit none
      ! Arguments
      real(kind=4), intent(in)   :: wn, rad
      real(kind=4)               :: brt

      ! Auxiliar variables
      real(kind=8), parameter :: planck_c1 = 1.1910427D-16 ! 2.h.c2
      real(kind=8), parameter :: planck_c2 = 1.4387752D-2  ! h.c/k
      real(kind=8)            :: v, a, b 

      v = wn*100
      a = planck_c1*v*v*v
      b = planck_c2*v

      brt = real(b/log(1+a/rad),4)

   end function rad2brt

   function drad2dbrt(t, wn) result(dbrt)
      implicit none
      ! Arguments
      real(kind=4), intent(in)   :: t, wn
      real(kind=4)               :: dbrt

      ! Auxiliar variables
      real(kind=8), parameter :: planck_c1 = 1.1910427D-16 ! 2.h.c2
      real(kind=8), parameter :: planck_c2 = 1.4387752D-2  ! h.c/k
      real(kind=8)            :: v, a, b 

      v = wn*100
      a = planck_c1*v*v*v
      b = planck_c2*v/t

      dbrt = real(a*b/(exp(b)-1),4)

   end function drad2dbrt
   
   function time_sct2date(iasi_time) result(vdate)
      use mod_calendar
      implicit none
      type(SHORT_CDS_TIME), intent(in) :: iasi_time
      integer(kind=4), dimension(8) :: vdate
      real(kind=8)                  :: gday
      integer(kind=4)               :: ierr, i6(6)
      gday = GDAY_IASI_EPOCHTIME + real(iasi_time%day,8)           &
                                 + real(iasi_time%msec,8)/86400*1D-3

      call gregday2date(gday, i6, ierr)
      vdate(1:3) = i6(1:3)
      vdate(4)   = 0
      vdate(5:7) = i6(4:6)
      vdate(8)   = mod(iasi_time%msec,1000)
   end function time_sct2date

   function time_date2sct(vdate) result(sct)
      use mod_calendar
      implicit none
      integer(kind=4), intent(in) :: vdate(8)
      type(SHORT_CDS_TIME)        :: sct
      real(kind=8)                :: rday
      integer(kind=4)             :: ierr
      integer(kind=4)             :: i6(6)
      i6(1:3) = vdate(1:3)
      i6(4:6) = vdate(5:7)
      rday = date2gregday(i6, ierr) - GDAY_IASI_EPOCHTIME
      sct%day  = int(rday,2)
      sct%msec = nint((rday-sct%day)*86400*1000,4) + vdate(8)
   end function time_date2sct

   function time_sctDiff(sctEnd, sctBeg) result(diff)
      ! This function computes the time difference
      ! between two SHORT_CDS_TIME structures. The 
      ! output is given in seconds
      implicit none
      type(SHORT_CDS_TIME), intent(in) :: sctEnd, sctBeg
      real(kind=8)                     :: diff
      diff = real((sctEnd%day-sctBeg%day)*86400,8) &
           + real((sctEnd%msec-sctBeg%msec),8)*1D-3 
   end function time_sctDiff
   
   function vint42r4_0d(vint4) result(vals)
      implicit none
      type(VINTEGER4), intent(in) :: vint4
      real(kind=4)                :: vals
      vals = real(vint4%value,4) * 10**(-real(vint4%sf,4))
   end function

   function vint42r4_1d(vint4) result(vals)
      implicit none
      type(VINTEGER4), intent(in) :: vint4(:)
      real(kind=4)                :: vals(size(vint4))
      vals = real(vint4%value,4) * 10**(-real(vint4%sf,4))
   end function

  function getFileUnit() result(unit)
    integer(kind=4)            :: unit
    ! I guess we won't need more than 2^31-1 units.
    integer(kind=4), parameter :: maxUnitValue = 2147483647
    ! Units under 100 are "often" used. Try to avoid clashes.
    integer(kind=4), parameter :: firstUnitValue = 100 
    logical                    :: exists
    logical                    :: opened
    integer(kind=4)            :: ios 
    do unit = firstUnitValue, maxUnitValue
       inquire(unit = unit, exist = exists, opened = opened, iostat = ios)
       if (exists .and. .not. opened .and. ios == 0) then
          return
       endif
    end do
    unit = -1
  end function getFileUnit

  subroutine location_angular_interp( ylr, yhr )
    implicit none
    real(kind=4)     ,intent(in) ,dimension(NP+2) :: ylr
    real(kind=4)     ,intent(out),dimension(NE)   :: yhr
    integer(kind=4)                               :: i
    real(kind=4)                 ,dimension(NP+2) :: xlr
    real(kind=4)                 ,dimension(NE)   :: xhr
    real(kind=4)                 ,dimension(NP+2) :: ylr_tmp
    !
    xlr(1) = real(1,kind=4)
    xlr(2:NP+1) = (/(real(5+(i-1)*20,kind=4),i=1,NP)/)
    xlr(NP+2) = real(NE,kind=4)
    xhr(1:NE) = (/(real(i,kind=4),i=1,NE)/)
    !
    if(abs(ylr(1)-ylr(NP+2)) >= 180. ) then
       ylr_tmp(:) = mod(ylr(:)+360., 360.)
    else
       ylr_tmp(:) = ylr(:)
    end if
    call inttab( ylr_tmp, xlr, NP+2, yhr, xhr, NE )
    !
    if(abs(ylr(1)-ylr(NP+2)) >= 180. ) then
!!       yhr(:) = mod(yhr(:)-360., 360.)
       do i = 1, NE
          if( yhr(i) > 180. ) yhr(i) = yhr(i) - 360.
       end do
    end if
    !
    return
  end subroutine location_angular_interp

  subroutine avhrr_cloud_information( Cloud_Info,       &
                                      Quality_Indicator,&
                                      Scan_Line_Quality,&
                                      Cloud_Flag_Vect   )
    implicit none
    integer(kind=2) ,intent(in) ,dimension(NE)       :: Cloud_Info
    integer(kind=4) ,intent(in)                      :: Quality_Indicator
    integer(kind=4) ,intent(in)                      :: Scan_Line_Quality
    integer(kind=2) ,intent(inout) ,dimension(4,NE)  :: Cloud_Flag_Vect
    integer(kind=4) ,dimension(8)                    :: Criteria
    integer(kind=4) ,dimension(0:31)                 :: Bit
    integer(kind=4)                                  :: ev
    integer(kind=4)                                  :: Test_Number
    byte                                             :: Octet3,Octet2
    byte                                             :: Octet1,Octet0
    integer(kind=4) ,parameter                       :: Missing = 255

    ! Clould_Flag_Vect(1) 0=clear 1=cloudy
    ! Clould_Flag_Vect(2) 0=sea 1=land
    ! Clould_Flag_Vect(3) 1=snow/ice covered
    ! Clould_Flag_Vect(4) 0=OK 1=NOK

    ! Quality Information decomposition
    call split32_8( Quality_Indicator,          &    
                    Octet3,Octet2,Octet1,Octet0 )
    call octet2bit( Octet3, Bit(24) )
    Cloud_Flag_Vect(:,:) = 0
    ! earth view loop
    do ev = 1, NE
       Criteria(:) = 0
       if( Bit(31)           == 0 .and.  &
           Scan_Line_Quality == 0 .and.  &
           Cloud_Info(ev) /= Missing ) then
          ! pixel OK
          call split16_8( Cloud_Info(ev), &
                          Octet1, Octet0 )                      
          call octet2bit( Octet0, Bit(0) )
          call octet2bit( Octet1, Bit(8) )
          ! cloud criteria
          if( Bit( 4) == 0 .and. Bit( 5) == 1 ) Criteria(1) = 1
          if( Bit( 6) == 0 .and. Bit( 7) == 1 ) Criteria(2) = 1
          if( Bit( 8) == 0 .and. Bit( 9) == 1 ) Criteria(3) = 1
          if( Bit(10) == 0 .and. Bit(11) == 1 ) Criteria(4) = 1
          if( Bit(12) == 0 .and. Bit(13) == 1 ) Criteria(5) = 1
          if( Bit(14) == 0 .and. Bit(15) == 1 ) Criteria(6) = 1
          if( Bit( 4) == 0 .and. Bit( 5) == 0 .and. &
              Bit( 6) == 0 .and. Bit( 7) == 0 .and. &
              Bit( 8) == 0 .and. Bit( 9) == 0 .and. &
              Bit(10) == 0 .and. Bit(11) == 0 .and. &
              Bit(12) == 0 .and. Bit(13) == 0 .and. &
              Bit(14) == 0 .and. Bit(15) == 0 ) Criteria(7) = 1
          ! snow ice criteria
          if( Bit( 4) == 1 .and. Bit( 5) == 1 .and. &
              Bit( 6) == 1 .and. Bit( 7) == 1 ) Criteria(8) = 1
          !
          ! cloud flag building if all test failed
          if( Criteria(7) == 1 ) then
             Cloud_Flag_Vect(1,ev) = 1
             Cloud_Flag_Vect(4,ev) = 1
          else if( Criteria(1) == 1 .or. Criteria(2) == 1 .or. &
                   Criteria(3) == 1 .or. Criteria(4) == 1 .or. &
                   Criteria(5) == 1 .or. Criteria(6) == 1 .and.&
                   Criteria(8) == 0 ) then
             Cloud_Flag_Vect(1,ev) = 1
          end if
          ! land sea flag
          Test_Number = 8*Bit(3) + 4*Bit(2) &
                      + 2*Bit(1) + 1*Bit(0)
          if( Test_Number ==  2 .or. Test_Number ==  3 .or. &
              Test_Number ==  5 .or. Test_Number ==  7 .or. &
              Test_Number ==  8 .or. Test_Number == 10 .or. &
              Test_Number == 11 ) then
             Cloud_Flag_Vect(2,ev) = 1
          end if
          ! sea ice flag
          if( Criteria(8) == 1 ) then
             Cloud_Flag_Vect(3,ev) = 1
          end if
       else
          ! pixel missing or bad quality
          Cloud_Flag_Vect(1,ev) = 1
          Cloud_Flag_Vect(2,ev) = 1
          Cloud_Flag_Vect(3,ev) = 1
          Cloud_Flag_Vect(4,ev) = 1
       end if
    end do
    ! end earth view loop
    return
  end subroutine avhrr_cloud_information

  subroutine split32_8 ( val_int,                   &
                         val_a, val_b, val_c, val_d )
      ! commute int4 into byte
      implicit none
      integer(kind=4)   :: val_int
      byte              :: val_a, val_b, val_c, val_d
      integer(kind=4)   :: reste

      val_a = int(val_int / 2**24,1)
      reste = mod(val_int, 2**24)
      val_b = int(reste / 2**16,1)
      reste = mod(reste, 2**16)
      val_c = int(reste / 2**8,1)
      val_d = int(mod(reste, 2**8),1)
	
      return
  end subroutine split32_8

  subroutine split16_8 ( val_int, &
                         val_a,   &
                         val_b    )
      ! commute int2 into byte
      implicit none
      integer(kind=2)   :: val_int
      byte              :: val_a, val_b 
      integer(kind=4)   :: temp

      temp = val_int
      if( temp .lt. 0 ) then 
        temp = temp + 2**16
      end if
      val_a = int(temp / 2**8,1)
      val_b = int(mod(temp, 2**8),1)

      return
    end subroutine split16_8

    subroutine octet2bit ( octet, &
                           bit    )
     
      implicit none

      byte         :: octet     
      integer(kind=4)   ::  k, reste, valeur 
      integer(kind=4)   ::  bit(8)

      ! Prise en compte des u-byte
      valeur = octet
      if ( octet .lt. 0 ) then
         valeur = 256 + octet
      end if
      ! Passage de la variable valeur (1 octet) a 8 bits
      do k = 8, 1, -1
         reste = mod(valeur, 2**(k-1))
         if (reste.eq.valeur) then
            bit(k) = 0
         else
            bit(k) = 1
         end if
         valeur = reste
      end do

      return
    end subroutine octet2bit

    subroutine commute16bits2bit(val_int, bit)
      ! commute int2 into bits
      implicit none
      integer(kind=2)   :: val_int
      integer(kind=4)   :: bit(16)
      integer(kind=4)   :: k, reste, valeur
      if( val_int < 0 ) then
         valeur = val_int + 2**16
      else
         valeur = val_int
      end if
      ! Passage de la variable valeur a 16 bits
      do k = 16, 1, -1
         reste = mod(valeur, 2**(k-1))
         if (reste.eq.valeur) then
            bit(k) = 0
         else
            bit(k) = 1
         end if
         valeur = reste
      end do
   end subroutine commute16bits2bit

   subroutine commute32bits2r4( int_a, int_b, val_r4 )
     ! commute 32 bits into real 4
     implicit none
     integer(kind=2)   :: int_a
     integer(kind=2)   :: int_b
     integer(kind=4)   :: bit_a(16)
     integer(kind=4)   :: bit_b(16)
     integer(kind=4)   :: bit(32)
     real(kind=4)      :: val_r4
     real(kind=8)      :: val_r8
     integer(kind=4)   :: S
     integer(kind=4)   :: E
     real(kind=4)      :: F
     integer(kind=4)   :: k

     call commute16bits2bit( int_a, bit_a )
     call commute16bits2bit( int_b, bit_b )
     bit(1:16)  = bit_a(16:1:-1)
     bit(17:32) = bit_b(16:1:-1)

     S = bit(1)
     E = 0
     do k = 8, 1 , -1
        E = E + bit(k+1)*2**(8-k)
     end do
     F = 0.
     do k = 1, 23
        F = F + real(bit(k+9))*2.**(-k)
     end do
     if( E == 0 ) then
        val_r4 = (-1)**S * real(2.**(E-128)) * (0. + F)
     else
        val_r4 = (-1)**S * real(2.**(E-127)) * (1. + F)
     end if

   end subroutine commute32bits2r4

   subroutine commute32bits2i4( int_a, int_b, val_r4 )
     ! commute 32 bits into real 4
     implicit none
     integer(kind=2)   :: int_a
     integer(kind=2)   :: int_b
     integer(kind=4)   :: bit_a(16)
     integer(kind=4)   :: bit_b(16)
     integer(kind=4)   :: bit(32)
     real(kind=4)   :: val_r4
     integer(kind=4)   :: k

     call commute16bits2bit( int_a, bit_a )
     call commute16bits2bit( int_b, bit_b )
     bit(1:16)  = bit_a(16:1:-1)
     bit(17:32) = bit_b(16:1:-1)
!!$     write(*,'(a,16i1)') 'bit(1:16)  ', bit(1:16)
!!$     write(*,'(a,16i1)') 'bit(17:32)  ', bit(17:32)
     val_r4 = 0
     do k = 1, 32
        val_r4 = val_r4 + bit(k)*2**(32-k)
     end do
     return
   end subroutine commute32bits2i4

   subroutine decoding_interf_iasi( MAS, FlagSpike, FlagOverfl,&
                                    RawPath, RawInterf )
     implicit none
     integer(kind=2)         ,intent(in)        :: MAS
     integer(kind=4)         ,intent(inout)     :: FlagSpike
     integer(kind=4)         ,intent(inout)     :: FlagOverfl
     integer(kind=4)         ,intent(inout)     :: RawPath
     integer(kind=4)         ,intent(inout)     :: RawInterf
     integer(kind=4)                            :: k
     integer(kind=4)         ,dimension(16)     :: bit
     !
     call commute16bits2bit( MAS, bit )
     ! 
     FlagSpike  = bit(16)
     FlagOverfl = bit(15)
     RawPath    = 0
     do k = 13, 14
        RawPath = RawPath + bit(k)*2**(k-13)
     end do
     RawInterf = 0
     do k = 1, 12
        RawInterf = RawInterf + bit(k)*2**(k-1)
     end do
     !
     return
   end subroutine decoding_interf_iasi

  subroutine inttab (yi, xi, ni, yj, xj, nj)

    integer(kind=4), intent(in)                    :: ni
    integer(kind=4), intent(in)                    :: nj
    real(kind=4)  , dimension(ni),     intent(in)  :: yi
    real(kind=4)  , dimension(ni),     intent(in)  :: xi
    real(kind=4)  , dimension(nj + 1), intent(in)  :: xj

    real(kind=4)  , dimension(nj), intent(inout)   :: yj


    real(kind=4)  :: alpha
    integer(kind=4) :: i, j, im1

    ! if necessary, processing of left over edges
    j = 1
    do while ( (j <= nj) .and. (xj(j) <= xi(1)) )
       yj(j) = yi(1)
       j = j + 1
    end do

    ! point array processing
    do  i = 2, ni
       im1 = i - 1
       alpha = (yi(i) - yi(im1))/(xi(i) - xi(im1))
       do while ((xj(j) < xi(i)) .and. (j <= nj))
          yj(j) = yi(im1) + (xj(j) - xi(im1))*alpha
          j = j + 1
       end do
    end do

    ! processing of right over edges
    if (j <= nj) then 
      yj(j:nj) = yi(ni)
    end if

    return
  end subroutine inttab
!
end module mod_l1c_l2_reading
