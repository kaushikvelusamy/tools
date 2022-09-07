// parallel Example independent

#include "hdf5.h"
#include <mpi.h>
#include <unistd.h>
#define H5FILE_NAME "SDS.h5"
#define DATASETNAME "IntArray"
#define NX     5                   

int main( int argc, char* argv[] )
{
    {
    int gdb_timer=0;
    while (gdb_timer == 0)
            sleep(10);
    }   


    int nprocs, rank;
    hid_t       file_id, dataset_id, datatype, memspace, filespace, fapl_id, xferPropList;         /* file and dataset handles */
    hsize_t     offset, dimsf = NX;      
    herr_t      status;
    int         in_data[NX], out_data[NX]={0};              
    int         i, j;

    MPI_Init(&argc,&argv);
	MPI_Comm_size(MPI_COMM_WORLD,&nprocs);
	MPI_Comm_rank(MPI_COMM_WORLD,&rank);
	MPI_Comm comm = MPI_COMM_WORLD;

    printf ("\nWriting from rank %d \n", rank);
    for(i = 0; i < NX; i++)
    {
        in_data[i] = 100+rank;
        printf (" %d \t", in_data[i]);
    }
    printf ("\n");

    datatype    = H5Tcopy(H5T_NATIVE_INT);
    status      = H5Tset_order(datatype, H5T_ORDER_LE);
    fapl_id     = H5Pcreate(H5P_FILE_ACCESS);
    H5Pset_fapl_mpio(fapl_id, comm, MPI_INFO_NULL); 

    xferPropList= H5Pcreate(H5P_DATASET_XFER);
    H5Pset_dxpl_mpio(xferPropList, H5FD_MPIO_COLLECTIVE);

    file_id     = H5Fcreate(H5FILE_NAME, H5F_ACC_TRUNC, H5P_DEFAULT, fapl_id);

    memspace    = H5Screate_simple(1, &dimsf, NULL);
    
    hsize_t dim_total = dimsf*nprocs;
    filespace   = H5Screate_simple(1, &dim_total, NULL);
    
    offset      = rank * dimsf;
    H5Sselect_hyperslab(filespace, H5S_SELECT_SET, &offset, NULL, &dimsf, NULL);

    dataset_id  = H5Dcreate(file_id, DATASETNAME, datatype, filespace, H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT);

    printf("dataset_id is %ld \t datatype is %ld \t memspaceis %ld \t filespace is %ld \t xferPropList is %ld \t in_data is %ld \n", dataset_id, datatype, memspace, filespace, xferPropList, in_data);

    status      = H5Dwrite(dataset_id, datatype, memspace, filespace, xferPropList, in_data);
    printf("dataset_id is %ld \t datatype is %ld \t memspaceis %ld \t filespace is %ld \t xferPropList is %ld \t out_data is %ld \n", dataset_id, datatype, memspace, filespace, xferPropList, out_data);

    status      = H5Dread(dataset_id, datatype, memspace, filespace, xferPropList, out_data);

    printf ("\nReading from rank %d \n", rank);
    for(i = 0; i < NX; i++)
    {
        printf (" %i \t", out_data[i]);
    }
    printf ("\n");

    H5Pclose(xferPropList);
    H5Sclose(memspace);
    H5Tclose(datatype);
    H5Dclose(dataset_id);
    H5Fclose(file_id);
    
    MPI_Finalize();
    return 0;
}

