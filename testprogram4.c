// parallel Example collective

#include "hdf5.h"
#include <mpi.h>
#define H5FILE_NAME "SDS.h5"
#define DATASETNAME "IntArray"
#define NX     5                      /* dataset dimensions */
#define RANK   2

int main( int argc, char* argv[] )
{
    int nprocs, rank;
    hid_t       file, dataset_id, datatype, memspace, filespace, fapl_id, xferPropList;         /* file and dataset handles */
    hsize_t     offset, dimsf = NX;     /* dataset dimensions */
    herr_t      status;
    int         data[NX];               /* data to write */
    int         i, j;


    MPI_Init(&argc,&argv);
	MPI_Comm_size(MPI_COMM_WORLD,&nprocs);
	MPI_Comm_rank(MPI_COMM_WORLD,&rank);
	MPI_Comm comm = MPI_COMM_WORLD;
    printf ("My rank is %d", rank);


    /*
     * Data  initialization.
     */
    printf ("\nWriting\n");
    for(i = 0; i < NX; i++)
    {
        data[i] = rank;
        printf (" %d", data[i]);
        printf ("\t");
    }
        printf ("\n");

    datatype = H5Tcopy(H5T_NATIVE_INT);
    status = H5Tset_order(datatype, H5T_ORDER_LE);
    fapl_id = H5Pcreate(H5P_FILE_ACCESS);
    H5Pset_fapl_mpio(fapl_id, comm, MPI_INFO_NULL);


    file = H5Fcreate(H5FILE_NAME, H5F_ACC_TRUNC, H5P_DEFAULT, fapl_id);

    memspace = H5Screate_simple(1, &dimsf, NULL);

    dataset_id = H5Dcreate2(file, DATASETNAME, datatype, memspace, H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT);

    offset = rank * dimsf;
    filespace = H5Screate_simple(1, &offset, NULL);

    H5Sselect_hyperslab(filespace, H5S_SELECT_SET, &offset, NULL, &dimsf, NULL);


    xferPropList = H5Pcreate(H5P_DATASET_XFER);
    H5Pset_dxpl_mpio(xferPropList, H5FD_MPIO_COLLECTIVE);


    status = H5Dwrite(dataset_id, H5T_NATIVE_INT, memspace, filespace, xferPropList, data);

    status = H5Dread(dataset_id, H5T_NATIVE_INT, memspace, filespace, xferPropList, data);

    printf ("\nReading\n");

    for(i = 0; i < NX; i++)
    {
        printf (" %i", data[i]);
        printf ("\t");
    }
        printf ("\n");


    /*
     * Close/release resources.
     */


    H5Pclose(xferPropList);
    H5Sclose(memspace);
    H5Tclose(datatype);
    H5Dclose(dataset_id);
    H5Fclose(file);
    


    MPI_Finalize();
    return 0;
}

