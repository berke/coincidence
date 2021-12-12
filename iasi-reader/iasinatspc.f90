module extract_spectra_mod
  use mod_l1c_l2_reading
  implicit none

  integer, parameter :: jgra = 1, jscan = 2, jpix = 3
  integer, parameter :: ichan_ref = 2119
  real(8), parameter :: nuchan_ref = 1174.5, dnu = 0.25
  real(8), parameter :: nu1 = 1180.0, nu2 = 1360.0 ! 1345.0
contains
  function channel_of_nu(nu,hi)
    real(8), intent(in) :: nu
    logical, intent(in) :: hi
    integer :: channel_of_nu
    real(8) :: rnu

    rnu = ichan_ref + (nu - nuchan_ref) / dnu

    if (hi) then
       channel_of_nu = ceiling(rnu)
    else
       channel_of_nu = floor(rnu)
    end if
  end function channel_of_nu

  subroutine main
    implicit none
    character(len=:), allocatable :: in_fn,out_fn
    integer :: m
    character(len=32) :: buf
    integer(kind=4) :: nrec
    type(RECORD_GIADR_SCALE_FACTORS) :: giadr_sf
    type(RECORD_ID), allocatable :: recs(:)
    type(RECORD_GIADR_QUALITY), allocatable :: giadr_quality
    type(RECORD_MDR_L1C), allocatable :: mdr
    integer :: unit,ounit,st
    integer :: nsel
    integer, allocatable :: sel(:,:)
    integer :: narg
    integer :: isel,igra,iscan,ipix,ichan,ichan1,ichan2

    allocate(mdr,giadr_quality,recs(MAX_RECORDS))
    
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
    allocate(sel(3,nsel))
    do isel=1,nsel
       call get_command_argument(2+isel,buf)
       read(buf,'(I3,X,I2,X,I1)') sel(jgra,isel),sel(jscan,isel),sel(jpix,isel)
       write(*,'(I3,"/",I2,"/",I1)') sel(jgra,isel),sel(jscan,isel),sel(jpix,isel)
    end do

    ! Get list of records and scale factors
    call read_iasi_l1c_file_recs(in_fn,nrec,recs,giadr_sf,giadr_quality)

    write (*,*) 'Number of records: ',nrec

    open(newunit=ounit,file=out_fn,status='replace',iostat=st)
    if (st/=0) then
       write (*,*) 'Cannot open output file ',out_fn
       stop
    end if

    ichan1 = channel_of_nu(nu1,.false.)
    ichan2 = channel_of_nu(nu2,.true.)

    open(newunit=unit,file=in_fn,access='stream',status='old',action='read',convert='big_endian')
    do isel=1,nsel
       igra = sel(jgra,isel)
       iscan = sel(jscan,isel)
       ipix = sel(jpix,isel) + 1

       write (*,*) 'Processing granule ',igra,' scan ',iscan,' pixel ',ipix - 1
       call read_iasi_mdr_l1c(unit,recs(igra)%pos,giadr_sf,mdr)

       write (*,*) 'Quality :',mdr%flg(:,ipix,iscan)

       mdr%vdate(:,iscan) = time_sct2date(mdr%cds_date(iscan))
       write (ounit,'("[",I0,".",I0,".",I0,"]")') igra,iscan,ipix - 1
       write (ounit,'("timestamp = ",I4.4,"-",I2.2,"-",I2.2,"T",I2.2,":",I2.2,":",I2.2,"Z")') &
            mdr%vdate(1:3,iscan), &
            mdr%vdate(5:7,iscan)
       write (ounit,'("lon = ",F12.6)') mdr%lon(ipix,iscan)
       write (ounit,'("lat = ",F12.6)') mdr%lat(ipix,iscan)
       write (ounit,'("flg = [",I0,",",I0,",",I0,"]")') mdr%flg(:,ipix,iscan)
       write (ounit,'("sza = ",F8.3)') mdr%sza(ipix,iscan)
       write (ounit,'("saz = ",F8.3)') mdr%saa(ipix,iscan)
       write (ounit,'("oza = ",F8.3)') mdr%iza(ipix,iscan)
       write (ounit,'("oaz = ",F8.3)') mdr%iaa(ipix,iscan)
       write (ounit,'("clc = ",I0)') mdr%clc(ipix,iscan)
       write (ounit,'("lfr = ",I0)') mdr%lfr(ipix,iscan)
       write (ounit,'("sif = ",I0)') mdr%sif(ipix,iscan)
       write (ounit,'("nu1 = ",F8.3)') nu1
       write (ounit,'("dnu = ",F8.3)') dnu
       write (ounit,'("ichan1 = ",I0)') ichan1
       write (ounit,'("nchan = ",I0)') ichan2 - ichan1 + 1
       write (ounit,'("radiance = [")')
       do ichan=ichan1,ichan2
          write(ounit,*) mdr%rad(ichan,ipix,iscan)*1e2,"," ! W/cm^-1/m^2/sr?
       end do
       write (ounit,'("]")')
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
