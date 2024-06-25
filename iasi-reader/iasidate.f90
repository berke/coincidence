module iasidate_mod
  use mod_l1c_l2_reading
  implicit none
contains
  subroutine main
    implicit none
    character(len=:), allocatable :: timestamp
    real(8) :: ts
    integer :: m
    integer(kind=4), dimension(6) :: i6

    call get_command_argument(1,length=m)
    if (m == 0) stop 'Specify timestamp'
    allocate(character(len=m) :: timestamp)
    call get_command_argument(1,timestamp)

    read(timestamp,*) ts
    i6 = time_sct2date(timestamp)
    write (*,*) i6
  end subroutine main
end module iasidate_mod
  
program iasidate
  use iasidate_mod
  implicit none
  call main
end program iasidate
