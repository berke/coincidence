.PHONY: all clean

all: iasinat2nex

clean:
	rm -f extract_footprints *.mod *.o

iasinat2nex: mod_calendar.f90 mod_datetime.f90 mod_l1c_l2_reading.f90 iasinat2nex.f90
	gfortran -Wall $^ -o $@
