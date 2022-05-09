# Script to run CCIO programs with their environment variables

#!/bin/sh
set -e
set -x

# Example sh ./run-test-run.sh modeNumber BuildMachine Ranks Executable debug
# Example sh ./run-test-run.sh 1 mac 2 ./tes.exe debug
# Example sh ./run-test-run.sh 1 mac 2 ./tes.exe 

# $1 is modeNumber
# $1 = 1 "Mode set to Default-Collective ( No CCIO)"
# $1 = 2 "Mode set to Default for CCIO"
# $1 = 3 "Mode set to Topology Aware CCIO"

# $2 is BuildMachine
# $3 is Ranks
# $4 is Executable
# $5 is Debug

#cb_nodes   = (lfs_count * cb_mult) / cb_div
#cb_stride  = (nranks) / cb_nodes
#fsb_size   = lfs_size * (1024 * 1024)
#fsb_count  = lfs_count

mode=""


# HDF5 Default Collective resetting everything to null
if [ "$1" == "1" ]; then
    echo "All HDF5 CCIO Env variables set to NULL"
    mode="Mode set to Default-Collective (No CCIO)"
    export HDF5_CCIO_FD_AGG=""
    export HDF5_CCIO_TOPO_PPN=""
    export HDF5_CCIO_CB_SIZE=""
    export HDF5_CCIO_FS_BLOCK_SIZE=""
    export HDF5_CCIO_FS_BLOCK_COUNT=""
    export HDF5_CCIO_DEBUG=""
    export HDF5_CCIO_WR_METHOD=""
    export HDF5_CCIO_RD_METHOD=""
    export HDF5_CCIO_WR=""
    export HDF5_CCIO_RD=""
    export HDF5_CCIO_ASYNC=""
    export HDF5_CCIO_CB_NODES=""
    export HDF5_CCIO_CB_STRIDE=""
    export HDF5_CCIO_TOPO_CB_SELECT=""

elif [ "$1" == "2" ]; then
    mode="Mode set to CCIO=Default"
    export HDF5_CCIO_FD_AGG="yes" # [RECOMMENDED FOR GPFS]
    export HDF5_CCIO_TOPO_PPN="ranks" # ranks > 0 
    export HDF5_CCIO_CB_SIZE="8388608"
    export HDF5_CCIO_FS_BLOCK_SIZE="8388608"
    export HDF5_CCIO_FS_BLOCK_COUNT="8"
    export HDF5_CCIO_DEBUG="no"
    export HDF5_CCIO_WR_METHOD="2"
    export HDF5_CCIO_RD_METHOD="2"
    export HDF5_CCIO_WR="yes"
    export HDF5_CCIO_RD="yes"
    export HDF5_CCIO_ASYNC="no"
    export HDF5_CCIO_CB_NODES="8.0"
    export HDF5_CCIO_CB_STRIDE="0"
    export HDF5_CCIO_TOPO_CB_SELECT="no"

elif [ "$1" == "3" ]; then
    mode="Mode set to CCIO=Topology Aware"
    export HDF5_CCIO_FD_AGG="yes" # [RECOMMENDED FOR GPFS]
    export HDF5_CCIO_TOPO_PPN="ranks" # ranks > 0 
    export HDF5_CCIO_CB_SIZE="8388608"
    export HDF5_CCIO_FS_BLOCK_SIZE="8388608"
    export HDF5_CCIO_FS_BLOCK_COUNT="8"
    export HDF5_CCIO_DEBUG="no"
    export HDF5_CCIO_WR_METHOD="2"
    export HDF5_CCIO_RD_METHOD="2"
    export HDF5_CCIO_WR="yes"
    export HDF5_CCIO_RD="yes"
    export HDF5_CCIO_ASYNC="no"
    export HDF5_CCIO_CB_NODES="8.0"
    export HDF5_CCIO_CB_STRIDE="0"
    export HDF5_CCIO_TOPO_CB_SELECT="data"
fi

printenv | grep "HDF5*"

if [ "$5" == "debug" ]; then
    export H5FD_mpio_Debug="yes"
    export HDF5_CCIO_DEBUG="yes"
fi


if [ "$2" == "mac" ]; then
    echo "Build Machine = $2"
    echo $mode
    echo "Num Ranks = $3 " 
    mpirun -n $3 $4

elif [ "$2" == "theta" ]; then
    # Set lustre stripe properties
    #subprocess.run(["lfs","setstripe","-c",str(lfs_count),"-S",str(lfs_size)+"m","."])

    echo "Setting extra MPICH environment variables"
    export MPICH_MPIIO_HINTS='*:cray_cb_write_lock_mode=1'
    export MPICH_NEMESIS_ASYNC_PROGRESS= 'ML'
    export MPICH_MAX_THREAD_SAFETY= 'multiple'
    printenv | grep "MPICH*"

    echo "Build Machine = $2"
    echo $mode
    echo "Num Ranks = $3 " 
    echo "$3 ranks" 
    #aprun -n $3 -N 8 $3 $4 
fi