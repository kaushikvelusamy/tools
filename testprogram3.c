// parallel Example independent

#include "hdf5.h"
#include <mpi.h>
#define H5FILE_NAME "SDS.h5"
#define DATASETNAME "IntArray"
#define NX     5                      /* dataset dimensions */
#define NY     6
#define RANK   2

int main( int argc, char* argv[] )
{
    int nprocs, rank;
    hid_t       file, dataset;         /* file and dataset handles */
    hid_t       datatype, memspace;   /* handles */
    hsize_t     dimsf[2];              /* dataset dimensions */
    herr_t      status;
    int         data[NX][NY];          /* data to write */
    int         i, j;
	
    MPI_Init(&argc,&argv);
	MPI_Comm_size(MPI_COMM_WORLD,&nprocs);
	MPI_Comm_rank(MPI_COMM_WORLD,&rank);
	MPI_Comm comm = MPI_COMM_WORLD;
    printf ("My rank is %d", rank);
    /*
     * Data  and output buffer initialization.
     */
    printf ("\nWriting\n");

    for(i = 0; i < NX; i++)
    {
    	for(j = 0; j < NY; j++)
	    {
            data[i][j] = i + j;
            printf (" %d", data[i][j]);
        }
        printf ("\n");
    }

    hid_t fapl_id;
    fapl_id = H5Pcreate(H5P_FILE_ACCESS);
    H5Pset_fapl_mpio(fapl_id, comm, MPI_INFO_NULL);

    file = H5Fcreate(H5FILE_NAME, H5F_ACC_TRUNC, H5P_DEFAULT, fapl_id);

    dimsf[0] = NX;
    dimsf[1] = NY;
    memspace = H5Screate_simple(1, dimsf, NULL);

    datatype = H5Tcopy(H5T_NATIVE_INT);
    status = H5Tset_order(datatype, H5T_ORDER_LE);

    dataset = H5Dcreate2(file, DATASETNAME, datatype, memspace,
			H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT);


    hid_t xferPropList = H5Pcreate(H5P_DATASET_XFER);
    H5Pset_dxpl_mpio(xferPropList, H5FD_MPIO_INDEPENDENT);

    status = H5Dwrite(dataset, H5T_NATIVE_INT, H5S_ALL, H5S_ALL, xferPropList, data);

    status = H5Dread(dataset, H5T_NATIVE_INT, H5S_ALL, H5S_ALL, xferPropList, data);

    printf ("\nReading\n");

    for(i = 0; i < NX; i++)
    {
    	for(j = 0; j < NY; j++)
	    {
            printf (" %i", data[i][j]);
        }
        printf ("\n");
    }

    /*
     * Close/release resources.
     */
    H5Pclose(xferPropList);
    H5Sclose(memspace);
    H5Tclose(datatype);
    H5Dclose(dataset);
    H5Fclose(file);
    
    MPI_Finalize();
    return 0;
}

