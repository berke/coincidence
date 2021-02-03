.PHONY: all clean

all: extract_footprints

clean:
	rm -f extract_footprints *.mod *.o

extract_footprints: mod_calendar.f90 mod_datetime.f90 mod_l1c_l2_reading.f90 extract_footprints.f90
	gfortran -Wall $^ -o $@
