!
    ! Calendar module
!
! Conversions to and from Julian dates and find day_of_the_week.
!
! Author: Robert Iles, March 1994
!
! There is no warranty on this code ........
!
!--------------------------------------------------------------
Module mod_calendar

   implicit none
   
   real(8), parameter :: time2day(3) = (/1D0, 1/6D1, 1/3.6D3/)

contains
!--------------------------------------------------------------
!
! Return the day of the week 
!
!   Input
!     julian :: Integer, Optional
!               If present the julian day for which the weekday is
!               required, if absent the day of the week TODAY is
!               returned
!   Output
!     weekday :: Integer, optional
!               The day of the week, 0 = sunday
!     day :: Character*(*), optional
!               The name of the day of the week, e.g. 'Sunday'
!               Minimum length = 9
!     ierr :: Integer
!               Error return, 0=correct
!                            -1=invalid Julian day
!                            -2=neither day nor weekday specified
!
    subroutine day_of_week(julian, weekday, day, ierr)

      implicit none
      integer,intent(in),optional  :: julian
      integer,intent(out),optional :: weekday
      integer, intent(out)         :: ierr
      integer                      :: iweekday
      character*(*),intent(out),optional:: day
 
      ierr = 0
      if(present(julian)) then   
        if(julian < 0) then
          ierr = -1
          return
        endif
        iweekday = mod(julian+1, 7)
      else
        iweekday = date_to_julian(ierr=ierr)
        if(ierr/=0) return
      endif

      if(.not.present(day).and. .not.present(weekday)) then
        ierr=-2
        return
      endif

      if(present(day)) then
        if(iweekday.eq.0) then
          day = 'Sunday'
        else if(iweekday==1) then
          day = 'Monday'
        else if(iweekday==2) then
          day = 'Tuesday'
        else if(iweekday==3) then
          day = 'Wednesday'
        else if(iweekday==4) then
          day = 'Thursday'
        else if(iweekday==5) then
          day = 'Friday'
        else
          day = 'Saturday'
        endif
      endif
      if(present(weekday)) weekday=iweekday

    end subroutine day_of_week
!-------------------------------------------------------------------------
!
! Convert a Julian day to a day/month/year
!
!   Input
!     julian :: Integer
!               The julian day to convert
!   Output
!     day   :: Integer, optional
!               The day of the month
!     month :: Integer, optional
!               The day of the month
!     year  :: Integer, optional
!               The day of the month
!     values :: Integer(:),optional
!               Array, minimum size=3, values(1)=year
!                                      values(2)=month
!                                      values(3)=day
!     ierr :: Integer
!               Error return, 0=correct
!                            -1=invalid Julian day
!                            -2=no output specified
!
    subroutine julian_to_date(julian,day,month,year,values,ierr)

      implicit none
      integer,parameter      :: igreg=2299161
      integer,parameter      :: k = kind(0.0d0)
      integer,intent(in)     :: julian
      integer,intent(out),optional    :: day, month, year
      integer,intent(out),optional    :: values(:)
      integer,intent(out)             :: ierr
      integer                :: ia, ja, jb, jc, jd, je, iday, imonth, iyear
      real(kind=k)           :: xc

      if(julian < 0) then
        ierr = -1
        return
      else
        ierr = 0
      endif
      if(.not.present(values).and..not.present(day).and. &
         .not.present(month).and..not.present(year)) then
        ierr=-2
        return
      endif

      if (julian.ge.igreg) then
        ia = int((real(julian-1867216,k)-0.25d0)/36524.25d0)
        ja = julian + 1+ia-int(0.25*ia)
      else
        ja = julian
      end if

      jb = ja + 1524
      xc = (real(jb-2439870,k)-122.1d0)/365.25d0
      jc = int(6680.0d0 + xc)
      jd = 365*jc + int(0.25d0*real(jc,k))
      je = int(real(jb-jd,k)/30.6001d0)

      iday = jb - jd - int(30.6001d0*real(je,k))

      imonth = je - 1
      if (imonth.gt.12) imonth = imonth - 12

      iyear = jc - 4715
      if (imonth.gt.2) iyear = iyear - 1
      if (iyear.le.0) iyear = iyear - 1
!
! Assign output values
!
      if(present(values)) then
        values(1) = iyear
        values(2) = imonth
        values(3) = iday
      endif
      if(present(year)) year=iyear
      if(present(month)) month=imonth
      if(present(day)) day=iday

    end subroutine julian_to_date
!-----------------------------------------------------------
!
! Convert a day/month/year to a Julian day 
!
!  If VALUES and one of DAY, MONTH and YEAR are missing this
!  will return the Julian day for TODAY
!
!   Input
!     day   :: Integer, optional
!               The day of the month
!     month :: Integer, optional
!               The day of the month
!     year  :: Integer, optional
!               The day of the month
!     values :: Integer(:),optional
!               Array, minimum size=3, values(1)=year
!                                      values(2)=month
!                                      values(3)=day
!   Output
!     julian :: Integer, Function Result
!               The julian day to convert
!     ierr :: Integer
!               Error return, 0=correct
!                            -1=invalid year
!                            -2=invalid month
!                            -3=invalid day
!                            -4=invalid date (29th Feb, non leap-year)
!
    function date_to_julian(day, month, year, values, ierr) result(julian)
!
!  gregorian started midday oct 15 1582
!
      implicit none
      integer,parameter :: igreg=15+31* (10+(12*1582))
      integer,parameter :: limit(12) = &
                           (/31,29,31,30,31,30,31,31,30,31,30,31/)
      real(kind=kind(0.0d0))::xi
      integer,intent(in),optional :: day, month, year
      integer,intent(in),optional :: values(:)
      integer:: julian, v(9)
   
      integer :: iy, ja, jm, jy, ierr
      integer :: iday,imonth,iyear

      julian = 0
      
      if(present(values)) then
        iyear = values(1)
        imonth = values(2)
        iday = values(3)      
      else if(present(day).and.present(month).and.present(year)) then
        iyear = year ; imonth = month ; iday = day
      else
        call date_and_time(values=v)
        iyear = v(1)
        imonth = v(2)
        iday = v(3)      
      endif

      if (iyear==0) then
        ierr=-1
        return
      endif
      if (imonth <= 0 .or. imonth > 12) then
        ierr=-2
        return
      endif
      if (iday > limit(imonth)) then
        ierr=-3
        return
      endif
      if(imonth==2.and.iday==29.and.iyear>1582)then
        if(mod(iyear,4)/=0) then
          ierr=-4
          return
        endif
      endif
      iy = iyear
      if (iyear.lt.0) iy = iy + 1
      if (imonth.gt.2) then
        jy = iy
        jm = imonth + 1
      else
        jy = iy - 1
        jm = imonth + 13
      end if
!
!  note: SLIGHTLY STRANGE CONSTRUCTIONS REQUIRED TO AVOID PROBLEMS WITH
!        OPTIMISATION OR GENERAL ERRORS UNDER VMS!
!
        julian = iday + int(30.6001d0*real(jm))
        if (jy.lt.0) then
          xi = 365.25d0*real(jy)
          if(int(xi).ne.xi) xi = xi -1
          julian = julian + int(xi)
        else
          julian = julian + 365*jy
          julian = julian + int(0.25*real(jy))
        end if
        julian = julian + 1720995

        if (iday+ (31* (imonth + (12*iy))) >= igreg) then
          ja=jy/100
          julian = julian - ja
          julian = julian + 2
          julian = julian + ja/4
        end if

    end function date_to_julian
      
    function day_of_year(day,month,year) result(dia)
        ! Function added by Javier Andrey on February 6, 2009
        implicit none
!        integer :: i
!       integer, intent(out), optional :: ierr
        integer, intent(in) :: day, month, year
        integer :: dia
        integer, parameter, dimension(12) :: dmonth = (/31,28,31,30,31,30,31,31,30,31,30,31/)
        dia = sum(dmonth(1:month-1))
!       do i =1,month-1
!           dia = dia + dmonth(i)
!       end do
        dia = dia + day
        if (leap_year(year) .and. month > 2) dia = dia + 1
    end function

    pure elemental function leap_year(y) result(is_leap)
        ! Determines if year is leap or not
        implicit none
        logical :: is_leap
        integer,intent(in) :: y    
       
        is_leap = (mod(y,4)==0 .and. .not. mod(y,100)==0) .or. (mod(y,400)==0) 
 
    end function leap_year

    !
    ! Converts dates (year,month,day,hour,minute,second) to gregorian date
    !
    function date2gregday(values,ierr) result(gday)
    
        implicit none
        ! Arguments
        integer, intent(in)     :: values(6)
        integer, intent(out)    :: ierr
        ! Result
        real(8)     :: gday
        
        gday = real(date_to_julian(values=values(1:3),ierr=ierr),8) + &
            sum(real(values(4:6),8)*time2day)/24D0 - 0.5D0
            ! First day 4713 AC / 01 / 01 at midday  =>  substract halfday
        
    end function date2gregday

    subroutine gregday2date(gday,vdate,ierr)
        implicit none
        ! Arguments
        real(8), intent(in)     :: gday
        integer, intent(out)    :: vdate(6)
        integer, intent(out)    :: ierr
        !Internal variables
        real(8) :: gdayfixed, resto

        ! Last term in the sume is made to fix rounding error
        gdayfixed = gday + 0.5D0 + 5D-6
        
        call julian_to_date(julian=int(gdayfixed),values=vdate(1:3),ierr=ierr)

        resto = mod(gdayfixed,1.)
        vdate(4) = int(resto*24)
        vdate(5) = int(resto*1440) - vdate(4)*60
        vdate(6) = int(resto*86400) - vdate(4)*3600 - vdate(5)*60
        
    end subroutine gregday2date

      

end module mod_calendar
