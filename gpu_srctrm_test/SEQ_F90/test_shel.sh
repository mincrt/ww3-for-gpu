#!/usr/bin/bash
set -e

# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #
#                                                                         #
# Shell script created to handle running the WaveWatch III source term    #
# miniapp. Contains options (currently manual) for Managed Memory,        #
# Explicit data transfers or CPU sequential runs. test_shel.sh should     #
# be run from an interactive job on Ismabard using:                       #
#                                                                         #
# qsub -I -q pascalq -l walltime=36000                                    #
#                                                                         #
# Then navigate to this directory and run ./test_shel.sh, all files       #
# should be made and linked automatically. Running with the -c option     #
# will clear all previous executables and remake them before running.     #
#                                                                         #
# Miniapp runs ww3_grid, ww3_shel, and ww3_outp, before a quick compare   #
# is done with a KGO. This output is generated from the CPU sequential    # 
# run.                                                                    #
#                                                                         #
# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## # 

# Make sure to run the test with -c if changing the compiler flags.

# Mananged memory
FFLAGS="-module mod -O2 -acc -DMM -ta=tesla,managed,cuda10.2 -Minfo=acc"
# Explicit transfers
#FFLAGS="-module mod -O2 -acc -ta=tesla,cuda10.2 -Minfo=acc"
# CPU Sequential
#FFLAGS="-module mod -O2 -Mbounds"

export FFLAGS=$FFLAGS

if [ -z "$1" ]; then 
	if [[ -f ww3_grid && ww3_shel && ww3_outp ]]; then
		make ww3_shel
	else 
		make
	fi
fi

while [ -n "$1" ]; do
    case "$1" in
        -a) make;;
        -c) make clean; make;;
    esac
    shift
done

# Load the nameslist and input files for the executables. 
cd ../RUN/ 

ln -sf inp/ww3_grid.nml .
ln -sf inp/ww3_shel.inp .
ln -sf inp/ww3_outp.inp .

# Run grid preprocessor for WW3
../SEQ_F90/ww3_grid

# Run wave model
nvprof ../SEQ_F90/ww3_shel 2> shel_profile

# Run point output
../SEQ_F90/ww3_outp

# Compare point output with KGO
vimdiff ww3.68060600.spc out/KGO/ww3.68060600.spc

cd ../SEQ_F90

# Alternate options for running ww3_shel, these provide more information for diagnostic and development.

# NVidia profiler only
# nvprof ../SEQ_F90/ww3_shel 2> prof

# NVidia profiler and information for the kernal launches(1) and data transfers(2), or both (3). 
# NV_ACC_NOTIFY=3 nvprof ../SEQ_F90/ww3_shel 2> prof

# Full formed Nvidia profile description. --stats generates summary statistics, --force-overwrite will 
# replace all existing result files with same output file name. 
# nsys profile --force-overwrite true -o profile --stats=true ../SEQ_F90/ww3_shel 2> nsys_prof

# NVidia profiler with device memory read and write throughput. 
# nvprof --metrics dram_read_throughput,dram_write_throughput ../SEQ_F90/ww3_shel 2> metrics

# Cuda debugging option, relevant for issues with Isambard or compiler. 
# cuda-gdb ../SEQ_F90/ww3_shel
