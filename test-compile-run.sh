#!/bin/sh

# Example : sh ./test-compile-run.sh -s "compile run" -p testprogram5.c -m local -d debug -o 1 -r 1 -l no
# Example : sh ./test-compile-run.sh -s "compile" -p testprogram5.c -m local -d debug -o 1 -r 1 -l no
# Example : sh ./test-compile-run.sh -s "run" -p testprogram5.c -m local -d debug -o 1 -r 1 -l no
# Example : sh ./test-compile-run.sh -s "compile run" -p testprogram5.c -m theta -d prod -o 1 -r 1 -l no
# Notes for running on theta compute 
# when running on theta compute node : run module load craype-mic-knl from mom node before compiling test app
# when running on theta compute node : export CRAYPE_LINK_TYPE=static and manually set LD_LIBRARY_PATH on the terminal before running

set -e
set -x 

objfile="testprogram.o"
exefile="testprogram.exe"
export HDF5_ROOT=$(pwd)"/.."
echo $HDF5_ROOT
export CRAYPE_LINK_TYPE=dynamic
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HDF5_ROOT/library/install/ccio/lib
#export LD_LIBRARY_PATH=/home/kvelusamy/Desktop/lin-ccio-v2/library/install/ccio/lib
#use mpicc(local) or cc (prod-pmi.h-nompirun) or h5pcc 
mycompiler="mpicc"


stage_compile()
{
  rm ./testprogram.exe.*
  bindir=$HDF5_ROOT/library/install/ccio/bin
  incldir=$HDF5_ROOT/library/install/ccio/include
  libdir=$HDF5_ROOT/library/install/ccio/lib
  testprog=$prog
  echo $objfile
  echo $exefile
  echo $bindir #for compiled h5pcc 
  echo $incldir
  $mycompiler -c -g -O3 -I$incldir $testprog -o $objfile
  $mycompiler $objfile -o $exefile -L$libdir -lhdf5 -lz 
  # mpicc -g -O3 -I../library/install/ccio/include -L../library/install/ccio/lib testprogram5.c -o testprogram.exe -lhdf5 -lz  
  rm $objfile
  echo "Executable File Name is $exefile" 
}

stage_run()
{
  mode=""
  # HDF5 Default Collective resetting everything to null
  if [ "$run_mode" = "1" ]; then
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

  elif [ "$run_mode" = "2" ]; then
      mode="Mode set to CCIO=Default"
      export HDF5_CCIO_FD_AGG="yes" # [RECOMMENDED FOR GPFS]
      export HDF5_CCIO_TOPO_PPN="ranks" # ranks > 0 291*7
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

  elif [ "$run_mode" = "3" ]; then
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

  if [ "$debug" = "debug" ]; then
      export HDF5_CCIO_DEBUG="yes"
      export H5FD_mpio_Debug='t'
      printenv | grep "H5FD_mpio_Debug"
      printenv | grep "HDF5_CCIO_DEBUG"
  fi

  if [ "$machine" = "local" ]; then
      echo "Build Machine = $machine"
      echo $mode
      echo "Num Ranks = $ranks " 
      mpiexec -np $ranks ./$exefile

  elif [ "$machine" = "theta" ]; then
      # Set lustre stripe properties
      #subprocess.run(["lfs","setstripe","-c",str(lfs_count),"-S",str(lfs_size)+"m","."])
      export LDFLAGS="-llustreapi"
      echo "Setting extra MPICH environment variables"
      export MPICH_MPIIO_HINTS='*:cray_cb_write_lock_mode=1'
      export MPICH_NEMESIS_ASYNC_PROGRESS= 'ML'
      export MPICH_MAX_THREAD_SAFETY= 'multiple'
      printenv | grep "MPICH*"

      echo "Build Machine = $machine"
      echo $mode
      echo "Num Ranks = $ranks " 
      echo "$ranks ranks" 

      if [ "$mycompiler" = "mpicc" ]; then
        mpirun -np $ranks gdb ./$exefile 
        #mpirun -np $ranks xterm -e gdb ./$exefile 
      else
        #aprun -n $ranks -N 2 gdb ./$exefile 
        aprun -n $ranks -N 1 ./$exefile 
      fi
  fi
}

usage() 
{ 
echo "Usage: $0 [-s stages <compile|run|compile run..>] 
    \t\t  [-p <programName.c>] 
    \t\t  [-m <local|theta>]
    \t\t  [-d <debug>]
    \t\t  [-o <1|2|3|No CCIO, CCIO default, TA CCIO]
    \t\t  [-r <1|2|3|4 ranks]
    \t\t  [-c <clean everything]
    \t\t  [-h <help>]"

echo " Test" 1>&2; exit 1; 
}
      
while getopts s:p:m:d:o:r:c:l:h flag
do
    case "${flag}" in
        s) 
          stages=${OPTARG}
          for stage in $stages;do
                echo stage $stage
                #stage$stage
          done    
          ;;
        p) 
          prog=${OPTARG}
          echo "Program Name = $prog";
          ;;
        m)
          machine=${OPTARG} 
          if [ $machine = "local" -o $machine = "theta" ]; then
            echo "Run Machine = $machine";
          else
            usage
            exit 1
          fi   
          ;;
        d)
          debug=${OPTARG} 
          if [ $debug = "prod" -o $debug = "debug" ]; then
            echo "Debug = $debug";
          else
            usage
            exit 1
          fi
          ;;
        l)
        selection_io=${OPTARG} 
        if [ $selection_io = "yes" ]; then
          echo "selection_io = $selection_io";
          export HDF5_USE_SELECTION_IO="yes"
        elif [ $selection_io = "no" ]; then
          echo "selection_io = $selection_io";
          export HDF5_USE_SELECTION_IO="no"
        else
          usage
          exit 1
        fi
        ;;
        o)
          run_mode=${OPTARG} 
          echo "Run Mode = $run_mode"
          ;;
        r)
          ranks=${OPTARG} 
          echo "Run Num Ranks = $ranks"
          ;;          
        c)
          cleaneverything=${OPTARG} 
          if [ $cleaneverything = 1 ]; then
            echo "cleaneverything: $cleaneverything";
#            rm -rf $(pwd)/gitrepos/
            exit 1
          fi
          ;;
        h | *) # Display help.
          usage
          exit 1
          ;;
    esac
done

echo $HDF5_ROOT
for stage in $stages;do
      echo stage = $stage
      stage_$stage
done   

