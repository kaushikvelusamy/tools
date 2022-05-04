# Bash script to run simple hdf5 test program
# Author: Kaushik 
# Date: Apr 27, 2022
 


#!/bin/bash
set -e
set -x


export HDF5_ROOT=$(pwd)
echo $1
bindir=$HDF5_ROOT/library/install/ccio/bin/
incldir=$HDF5_ROOT/library/install/ccio/include
libdir=$HDF5_ROOT/library/install/ccio/lib
testprog=$1
objfile=${testprog::3}".o"
exefile=${testprog::3}".exe"
echo $objfile
echo $exefile
echo $bindir
echo $incldir

$bindir/h5pcc -c -g -O3 -I$incldir $testprog -o $objfile

$bindir/h5pcc $objfile -o $exefile -L$libdir -lhdf5 -lz 

rm $objfile dset.h5 

