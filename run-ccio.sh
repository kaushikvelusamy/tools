# Bash script to clone,compile and run ccio feature of HDF5
# Author: Kaushik 
# Date: Apr 27, 2022
# Example : sh ./run-ccio.sh -s "1 2" -b ccio -m local -d debug -p 0
# Example : sh ./run-ccio.sh -s "1 2" -b ccio-v2 -m local -d debug -p 0
# Example : sh ./run-ccio.sh -s "2" -m local -d debug -p 0 
# Example : sh ./run-ccio.sh -s "2" -m theta -d debug -p 1 
# Example : sh ./run-ccio.sh -s 4   //To run quick recompiling
# Example : sh ./run-ccio.sh -c 1   //To make clean
# Stage 1: Setup code : args -b 
# Stage 2: Compile : args -m -d -p
# Stage 3: setup test code : args -m"
# If linux, in autogen.sh replace "HDF5_LIBTOOL=$(which libtool)" with "HDF5_LIBTOOL=$(which libtoolize)"
# compiling just hdf5 (without test app) requires module craype-haswell and compiling (hdf5 with test app) if running on compute needs module craype-mic-knl.
# If testing on theta login node, remove -DTHETA to avoid the PMI issue and unload nompirun ( or run it with -m local)

#!/bin/sh
set -e
set -x

export HDF5_ROOT=$(pwd)"/.."
echo $HDF5_ROOT
export CRAYPE_LINK_TYPE=dynamic
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HDF5_ROOT/library/install/ccio/lib
#export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/lus/grand/projects/datascience/kaushikv/test-ccio-v2-dev/ccio-v2-dev/library/install/ccio/lib
#use mpicc(nompirun-debug/local) or cc (prod-pmi.h) or h5pcc 
mycompiler="mpicc"
#extra arguments for hdf5 compile " --enable-shared --enable-threadsafe --enable-unsupported --enable-map-api"

stage1()
{
  echo "Setting up HDF5 code and branch"
  mkdir -p $HDF5_ROOT/gitrepos
  mkdir -p $HDF5_ROOT/library/build/ccio
  mkdir -p $HDF5_ROOT/library/install/ccio
  cd $HDF5_ROOT/gitrepos
  git clone https://github.com/kaushikvelusamy/hdf5.git
  cd $HDF5_ROOT/gitrepos/hdf5
  git checkout $branch
  echo "Setting up HDF5 code and branch - Done"
}

stage2()
{
  rm -r $HDF5_ROOT/library/build/ccio/*
  rm -r $HDF5_ROOT/library/install/ccio/*
  echo "Starting scripts for HDF5 Compile, Make and install"
  if [ "$machine" = "theta" ]; then
      module unload darshan
      module load craype-haswell
      #module swap craype-mic-knl craype-haswell #comment if running on login uncomment if compute theta
      module swap craype-mic-knl craype-haswell
      #module unload craype-mic-knl
      #module load PrgEnv-gnu
      #module unload nompirun
      #module swap PrgEnv-intel PrgEnv-gnu
      export LDFLAGS="-llustreapi"
      cd $HDF5_ROOT/gitrepos/hdf5
      ./autogen.sh
      cd $HDF5_ROOT/library/build/ccio

      if [ "$debug" = "prod" ]; then
          CC=$mycompiler CFLAGS='-O3 -DTHETA -Dtopo_timing' $HDF5_ROOT/gitrepos/hdf5/configure --enable-parallel --enable-build-mode=production --enable-symbols=yes --prefix=$HDF5_ROOT/library/install/ccio
      elif [ "$debug" = "debug" ]; then
          CC=$mycompiler CFLAGS='-O3 -DTHETA -Donesidedtrace  -DH5FDmpio_DEBUG' $HDF5_ROOT/gitrepos/hdf5/configure --enable-parallel --enable-build-mode=$debug --enable-symbols=yes --prefix=$HDF5_ROOT/library/install/ccio
      else
          echo "debug incorrect"
          exit 0
      fi
  elif [ "$machine" = "local" ]; then
      #module unload nompirun
      cd $HDF5_ROOT/gitrepos/hdf5
      ./autogen.sh
      cd $HDF5_ROOT/library/build/ccio

      if [ "$debug" = "prod" ]; then
          CC=$mycompiler CFLAGS='-O3 -Dtopo_timing' $HDF5_ROOT/gitrepos/hdf5/configure --enable-parallel --enable-build-mode=production --enable-symbols=yes --prefix=$HDF5_ROOT/library/install/ccio --enable-shared
      elif [ "$debug" = "debug" ]; then
          CC=$mycompiler CFLAGS='-O3 -Donesidedtrace -DH5FDmpio_DEBUG' $HDF5_ROOT/gitrepos/hdf5/configure --enable-parallel --enable-build-mode=$debug --enable-symbols=yes --prefix=$HDF5_ROOT/library/install/ccio --enable-shared
      else
          echo "debug incorrect"
          exit 0
      fi
  else
      echo "machine incorrect"
      exit 0
  fi
  cd $HDF5_ROOT/library/build/ccio
  if [ "$makeparallel" = 0 ]; then
    make install
  elif [ "$makeparallel" = 1 ]; then
    make -j 16 install
  else
    echo "makeparallel incorrect"
    exit 0
  fi
  echo "Starting scripts for HDF5 Compile, Make and install - Done"
}


stage3()
{
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HDF5_ROOT/library/install/ccio/lib

  echo "Starting scripts for Exerciser test code setup"
  HDF5_INSTALL_DIR=${HDF5_ROOT}/library/install/ccio
  cd $HDF5_ROOT/gitrepos
  if [ ! -e $HDF5_ROOT/gitrepos/BuildAndTest ]; then
    git clone https://xgitlab.cels.anl.gov/kvelusamy/BuildAndTest.git 
  fi
  
  if [ ! -e $HDF5_ROOT/exerciser/ccio ]; then
    mkdir -p $HDF5_ROOT/exerciser/ccio
  elif [ ! -d $HDF5_ROOT/exerciser/ccio ]; then
    echo "$HDF5_ROOT/exerciser/ccio already exists" 1>&2
  fi

  cd $HDF5_ROOT/exerciser/ccio
  cp $HDF5_ROOT/gitrepos/BuildAndTest/Exerciser/exerciser.c .

  if [ "$machine" = "theta" ]; then
    cp $HDF5_ROOT/gitrepos/BuildAndTest/Exerciser/Theta/Makefile.theta .
    module swap craype-haswell craype-mic-knl
    export CRAYPE_LINK_TYPE=static
    make -f Makefile.theta
  elif [ "$machine" = "local" ]; then
    cp $HDF5_ROOT/gitrepos/BuildAndTest/Exerciser/Theta/Makefile.mac .

    make -f Makefile.mac 
  fi

  if [ ! -e $HDF5_ROOT/exerciser/run ]; then
    mkdir -p $HDF5_ROOT/exerciser/run
  elif [ ! -d $HDF5_ROOT/exerciser/run ]; then
    echo "$HDF5_ROOT/exerciser/run already exists" 1>&2
  fi

  cd $HDF5_ROOT/exerciser/run
  ln -s  ../ccio/hdf5Exerciser hdf5Exerciser-ccio
  cp $HDF5_ROOT/gitrepos/BuildAndTest/Exerciser/Common/run-example.py . 
  #qsub -A datascience -t 30 -n 32 python3 run-example.py --machine theta --exec ./hdf5Exerciser-ccio --ppn 16 --ccio
  echo "Exerciser test code setup - Done"
}

stage4()
{
  echo "just make install - helpful during debuging"
  cd $HDF5_ROOT/library/build/ccio
  make install
  echo "just make install - helpful during debuging - Done"
}

usage() 
{ 
echo "Usage: $0 [-s stages <1|2|3|2 3|..>] 
    \t\t  [-b <develop|ccio|ccio-v2>] 
    \t\t  [-m <local|theta>]
    \t\t  [-d <prod|debug>]
    \t\t  [-p <0-serialmake|1-parallelmake]
    \t\t  [-c 1- cleaneverything]
    \t\t  [-h <help>]"

echo "Stage 1: Setup code \t :args -b 
Stage 2: Compile\t :args -m -d -p
Stage 3: Setup test code :args -m
Stage 4: just make install - helpful during debuging" 1>&2; exit 1; 
}
                          

while getopts s:b:m:d:p:c:h flag
do
    case "${flag}" in
        s) 
          stages=${OPTARG}
          ;;
        b) 
          branch=${OPTARG}
          if [ $branch = "develop" -o $branch = "ccio" -o $branch = "ccio-v2" ] 
          then
            echo "branch: $branch";
          else
            usage
            exit 1
          fi
          ;;
        m)
          machine=${OPTARG} 
          echo $machine
          if [ $machine = "local" -o $machine = "theta" ]
          then
            echo "machine: $machine";
          else
            usage
            exit 1
          fi   
          ;;
        d)
          debug=${OPTARG} 
          if [ $debug = "prod" -o $debug = "debug" ] 
          then
            echo "debug: $debug";
          else
            usage
            exit 1
          fi
          ;;
        p)
          makeparallel=${OPTARG} 
          if [ $makeparallel = 0 -o $makeparallel = 1 ]; then
            echo "makeparallel: $makeparallel";
          else
            usage
            exit 1
          fi
          ;;

        c)
          cleaneverything=${OPTARG} 
          if [ $cleaneverything = 1 ]; then
            echo "cleaneverything: $cleaneverything";
            cd $HDF5_ROOT/library/build/ccio
            make clean
            echo " make clean - Done"
            exit 1
          fi
          ;;
        h | *) # Display help.
          usage
          exit 1
          ;;
    esac
done

for stage in $stages;do
      echo stage$stage
      stage$stage
done   
