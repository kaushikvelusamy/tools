# Bash script to clone,compile and run ccio feature of HDF5
# Author: Kaushik 
# Date: Apr 27, 2022
# Example : sh ./run-ccio.sh -s "1 2 3" -b ccio -m mac -d prod -p 0
# Example : sh ./run-ccio.sh -s 1 -b ccio 
# Example : sh ./run-ccio.sh -s "2 3" -m mac -d prod -p 0
# Example : sh ./run-ccio.sh -s 3 -m mac
# Stage 1: Setup code : args -b 
# Stage 2: Compile : args -m -d -p
# Stage 3: setup test code : args -m"


#!/bin/sh
set -e
#set -x

stage1()
{
  mkdir -p $HDF5_ROOT/gitrepos
  mkdir -p $HDF5_ROOT/library/build/ccio
  mkdir -p $HDF5_ROOT/library/install/ccio
  cd $HDF5_ROOT/gitrepos
  git clone https://github.com/kaushikvelusamy/hdf5.git
  cd $HDF5_ROOT/gitrepos/hdf5
  git checkout $branch
}

stage2()
{
  if [ "$machine" == "theta" ]; then
      module unload darshan
      module load craype-haswell
      module load craype-mic-knl
      module swap craype-mic-knl craype-haswell
      export LDFLAGS="-llustreapi"
      export CRAYPE_LINK_TYPE=dynamic

      cd $HDF5_ROOT/gitrepos/hdf5
      ./autogen.sh
      cd $HDF5_ROOT/library/build/ccio

      if [ "$debug" == "prod" ]; then
          CC=cc CFLAGS='-O3 -DTHETA -Dtopo_timing' $HDF5_ROOT/gitrepos/hdf5/configure --enable-parallel --enable-build-mode=production --enable-symbols=yes --prefix=$HDF5_ROOT/library/install/ccio
      elif [ "$debug" == "debug" ]; then
          CC=cc CFLAGS='-O3 -DTHETA -Dtopo_timing' $HDF5_ROOT/gitrepos/hdf5/configure --enable-parallel --enable-build-mode=$debug --enable-symbols=yes --prefix=$HDF5_ROOT/library/install/ccio
      else
          echo "debug incorrect"
          exit 0
      fi
  elif [ "$machine" == "mac" ]; then
      cd $HDF5_ROOT/gitrepos/hdf5
      ./autogen.sh
      cd $HDF5_ROOT/library/build/ccio

      if [ "$debug" == "prod" ]; then
          CC=mpicc CFLAGS='-O3 -Dtopo_timing' $HDF5_ROOT/gitrepos/hdf5/configure --enable-parallel --enable-build-mode=production --enable-symbols=yes --prefix=$HDF5_ROOT/library/install/ccio
      elif [ "$debug" == "debug" ]; then
          CC=mpicc CFLAGS='-O3 -Dtopo_timing' $HDF5_ROOT/gitrepos/hdf5/configure --enable-parallel --enable-build-mode=$debug --enable-symbols=yes --prefix=$HDF5_ROOT/library/install/ccio
      else
          echo "debug incorrect"
          exit 0
      fi
  else
      echo "machine incorrect"
      exit 0
  fi
  cd $HDF5_ROOT/library/build/ccio
  if [ "$makeparallel" == 0 ]; then
    make install
  elif [ "$makeparallel" == 1 ]; then
    make -j 16 install
  else
    echo "makeparallel incorrect"
    exit 0
  fi
}


stage3()
{
  HDF5_INSTALL_DIR=${HDF5_ROOT}/library/install/ccio
  cd $HDF5_ROOT/gitrepos
  git clone https://xgitlab.cels.anl.gov/kvelusamy/BuildAndTest.git 
  mkdir -p $HDF5_ROOT/exerciser/ccio
  cd $HDF5_ROOT/exerciser/ccio
  cp $HDF5_ROOT/gitrepos/BuildAndTest/Exerciser/exerciser.c .

  if [ "$machine" == "theta" ]; then
    cp $HDF5_ROOT/gitrepos/BuildAndTest/Exerciser/Theta/Makefile.theta .
    module swap craype-haswell craype-mic-knl
    export CRAYPE_LINK_TYPE=static
    make -f Makefile.theta
  elif [ $machine == "mac" -o $machine == "theta" ]; then
    cp $HDF5_ROOT/gitrepos/BuildAndTest/Exerciser/Theta/Makefile.mac .
    make -f Makefile.mac 
  fi

  mkdir -p $HDF5_ROOT/exerciser/run
  cd $HDF5_ROOT/exerciser/run
  ln -s  ../ccio/hdf5Exerciser hdf5Exerciser-ccio
  cp $HDF5_ROOT/gitrepos/BuildAndTest/Exerciser/Common/run-example.py . 
  #qsub -A datascience -t 30 -n 32 python3 run-example.py --machine theta --exec ./hdf5Exerciser-ccio --ppn 16 --ccio
}

usage() 
{ 
echo "Usage: $0 [-s stages <1|2|3|2 3|..>] 
    \t\t  [-b <develop|ccio|ccio-v2>] 
    \t\t  [-m <mac|theta>]
    \t\t  [-d <prod|debug>]
    \t\t  [-p <0-serialmake|1-parallelmake]
    \t\t  [-c 1- cleaneverything]
    \t\t  [-h <help>]"

echo "Stage 1: Setup code \t :args -b 
Stage 2: Compile\t :args -m -d -p
Stage 3: setup test code :args -m" 1>&2; exit 1; 
}
                          

while getopts s:b:m:d:p:c:h flag
do
    case "${flag}" in
        s) 
          stages=${OPTARG}
          ;;
        b) 
          branch=${OPTARG}
          if [ $branch == "develop" -o $branch == "ccio" -o $branch == "ccio-v2" ]; then
            echo "branch: $branch";
          else
            usage
            exit 1
          fi
          ;;
        m)
          machine=${OPTARG} 
          if [ $machine == "mac" -o $machine == "theta" ]; then
            echo "machine: $machine";
          else
            usage
            exit 1
          fi   
          ;;
        d)
          debug=${OPTARG} 
          if [ $debug == "prod" -o $debug == "debug" ]; then
            echo "debug: $debug";
          else
            usage
            exit 1
          fi
          ;;
        p)
          makeparallel=${OPTARG} 
          if [ $makeparallel == 0 -o $makeparallel == 1 ]; then
            echo "makeparallel: $makeparallel";
          else
            usage
            exit 1
          fi
          ;;

        c)
          cleaneverything=${OPTARG} 
          if [ $cleaneverything == 1 ]; then
            echo "cleaneverything: $cleaneverything";
            rm -rf $(pwd)/gitrepos/
            rm -rf $(pwd)/exerciser/
            rm -rf $(pwd)/library/
            exit 1
          fi
          ;;
        h | *) # Display help.
          usage
          exit 1
          ;;
    esac
done


export HDF5_ROOT=$(pwd)

for stage in $stages;do
      echo stage$stage
      stage$stage
done   

