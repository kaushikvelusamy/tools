#include "hdf5.h"
#define FILE "dset.h5"

int main()
{

    hid_t  file_id, dataset_id; /* identifiers */
    herr_t status;
    int    i, j, dset_data[4][6], drecv_data[4][6];

    /* Initialize the dataset. */
    for (i = 0; i < 4; i++)
        for (j = 0; j < 6; j++)
            dset_data[i][j] = i * 6 + j + 1;

    /* Open an existing file. */
    file_id = H5Fopen(FILE, H5F_ACC_RDWR, H5P_DEFAULT);

    /* Open an existing dataset. */
    dataset_id = H5Dopen2(file_id, "/dset", H5P_DEFAULT);

    printf ("\nWriting\n");
    for (i = 0; i<4; i++){
       for (j = 0; j<6; j++)
           printf (" %i", dset_data[i][j]);
       printf ("\n");
    }

    /* Write the dataset. */
    status = H5Dwrite(dataset_id, H5T_NATIVE_INT, H5S_ALL, H5S_ALL, H5P_DEFAULT, dset_data);

    status = H5Dread(dataset_id, H5T_NATIVE_INT, H5S_ALL, H5S_ALL, H5P_DEFAULT, drecv_data);

    printf ("\nReading\n");
    for (i = 0; i<4; i++){
       for (j = 0; j<6; j++)
           printf (" %i", drecv_data[i][j]);
       printf ("\n");
    }
    
    /* Close the dataset. */
    status = H5Dclose(dataset_id);

    /* Close the file. */
    status = H5Fclose(file_id);
}