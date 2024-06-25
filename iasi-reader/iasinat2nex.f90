module extract_footprints_mod
  use mod_l1c_l2_reading
  implicit none
contains
  subroutine main
    implicit none
    character(len=:), allocatable :: in_fn,out_fn
    integer :: m

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
    integer :: i,j,k

    ! Get arguments
    call get_command_argument(1,length=m)
    if (m == 0) stop 'Specify input file'
    allocate(character(len=m) :: in_fn)
    call get_command_argument(1,in_fn)

    call get_command_argument(2,length=m)
    if (m == 0) stop 'Specify output file'
    allocate(character(len=m) :: out_fn)
    call get_command_argument(2,out_fn)

    ! Get list of records and scale factors
    call read_iasi_l1c_file_recs(in_fn,nrec,recs,giadr_sf,giadr_quality)

    write (*,*) 'Number of records: ',nrec

    open(newunit=ounit,file=out_fn,status='replace',iostat=st)
    if (st/=0) then
       write (*,*) 'Cannot open output file ',out_fn
       stop
    end if

    open(newunit=unit,file=in_fn,access='stream',status='old',action='read',convert='big_endian')
    do i=1,nrec
       write (*,*) 'Processing granule (reduced) ',i
       ! call read_iasi_mdr_l1c_reduced(unit,recs(i)%pos,giadr_sf,mdr)
       call read_iasi_mdr_l1c(unit,recs(i)%pos,giadr_sf,mdr)

       do j=1,SNOT
          mdr%vdate(:,j) = time_sct2date(mdr%cds_date(j))
          write (ounit,'(I8,X,I4,X,I4.4,6(X,I2.2),X,4(1X,I3),4(1X,F10.4),4(1X,F10.4))') &
               i, &
               j, &
               mdr%vdate(1,j), &
               mdr%vdate(2,j), &
               mdr%vdate(3,j), &
               mdr%vdate(4,j), &
               mdr%vdate(5,j), &
               mdr%vdate(6,j), &
               mdr%vdate(7,j), &
               mdr%clc(:,j),mdr%lon(:,j),mdr%lat(:,j)
       end do
    end do
    close(ounit)
    close(unit)
  end subroutine main
end module extract_footprints_mod

program extract_footprints
  use extract_footprints_mod
  implicit none
  call main
end program extract_footprints
