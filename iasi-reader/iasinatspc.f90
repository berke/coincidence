module extract_spectra_mod
  use mod_l1c_l2_reading
  implicit none
contains
  subroutine main
    implicit none
    character(len=:), allocatable :: in_fn,out_fn
    integer :: m
    character(len=32) :: buf

    ! type(L1C_GRANULE)                                :: granule
    ! integer(kind=4)                                  :: uin 
    ! integer(kind=4)                                  :: fpos
    ! type(RECORD_GIADR_SCALE_FACTORS)                 :: giadr_sf
    ! type(RECORD_GIADR_QUALITY)                       :: giadr_quality
    ! type(RECORD_ID)                                  :: recs(MAX_RECORDS)
    ! integer(kind=4)                                  :: k, j
    integer(kind=4) :: nrec
    type(RECORD_ID) :: recs(MAX_RECORDS)
    type(RECORD_GIADR_SCALE_FACTORS) :: giadr_sf
    type(RECORD_GIADR_QUALITY):: giadr_quality
    type(RECORD_MDR_L1C) :: mdr
    integer :: unit,ounit,st
    ! integer :: i,j,k
    integer :: nsel
    integer, allocatable :: sel(:,:)
    integer :: narg
    integer :: isel,igra,ipix
    
    ! Get arguments
    call get_command_argument(1,length=m)
    if (m == 0) stop 'Specify input file'
    allocate(character(len=m) :: in_fn)
    call get_command_argument(1,in_fn)

    call get_command_argument(2,length=m)
    if (m == 0) stop 'Specify output file'
    allocate(character(len=m) :: out_fn)
    call get_command_argument(2,out_fn)

    narg = command_argument_count()
    nsel = narg - 2

    write(*,*) 'Number of selected pixels: ',nsel
    allocate(sel(2,nsel))
    do isel=1,nsel
       call get_command_argument(2+isel,buf)
       read(buf,'(I3,X,I1)') sel(1,isel),sel(2,isel)
       write(*,'(I3,"/",I1)') sel(1,isel),sel(2,isel)
    end do

    ! Get list of records and scale factors
    call read_iasi_l1c_file_recs(in_fn,nrec,recs,giadr_sf,giadr_quality)

    write (*,*) 'Number of records: ',nrec

    open(newunit=ounit,file=out_fn,status='replace',iostat=st)
    if (st/=0) then
       write (*,*) 'Cannot open output file ',out_fn
       stop
    end if

    open(newunit=unit,file=in_fn,access='stream',status='old',action='read',convert='big_endian')
    do isel=1,nsel
       igra = sel(1,isel)
       ipix = sel(2,isel)

       write (*,*) 'Processing granule ',igra,' pixel ',ipix
       call read_iasi_mdr_l1c(unit,recs(igra)%pos,giadr_sf,mdr)

       mdr%vdate(:,ipix) = time_sct2date(mdr%cds_date(ipix))
       write (ounit,'(I8,X,I4,X,I4.4,6(X,I2.2),X,I3,4(1X,F10.4),4(1X,F10.4))') &
            igra, &
            ipix, &
            mdr%vdate(1,ipix), &
            mdr%vdate(2,ipix), &
            mdr%vdate(3,ipix), &
            mdr%vdate(4,ipix), &
            mdr%vdate(5,ipix), &
            mdr%vdate(6,ipix), &
            mdr%vdate(7,ipix), &
            mdr%clc(1,ipix),mdr%lon(:,ipix),mdr%lat(:,ipix)

       ! Write out spectrum
       ! PN = 4
       ! SNOT = 30
      !real(kind=4), dimension(nbrIasi,PN,SNOT)    :: rad            ! radiance
       mdr%rad(ipix)
    end do
    close(ounit)
    close(unit)
  end subroutine main
end module extract_spectra_mod

program extract_spectra
  use extract_spectra_mod
  implicit none
  call main
end program extract_spectra
