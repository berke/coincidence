.PHONY: all clean

all: iasinat2nex iasinatspc iasidate

clean:
	rm -f iasinat2nex iasinatspc *.mod *.o

iasinat2nex: mod_calendar.f90 mod_datetime.f90 mod_l1c_l2_reading.f90 iasinat2nex.f90
	gfortran -Wall -O2 $^ -o $@

iasinatspc: mod_calendar.f90 mod_datetime.f90 mod_l1c_l2_reading.f90 iasinatspc.f90
	gfortran -Wall -fcheck=all $^ -o $@

iasidate: mod_calendar.f90 mod_datetime.f90 mod_l1c_l2_reading.f90 iasidate.f90
	gfortran $^ -o $@
