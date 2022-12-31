#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#define LZ4HC_HEAPMODE 1

#include <lz4.h>
#include <lz4hc.h>

int main(int argc, char *argv[])
{
    long size, in_size, out_size;
    char *in_buf, *out_buf;
    int fin, fout, ret;

    if (argc != 3) {
        printf ("Usage: %s <in> <out>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    fin = open(argv[1], O_RDONLY, S_IRUSR | S_IRGRP);
    if (fin < 0) {
        printf ("Can open %s\n", argv[1]);
        exit(EXIT_FAILURE);
    }

    in_size = lseek(fin, 0, SEEK_END);
    if (in_size == -1)
    {
        printf("failed to lseek %s\n", argv[1]);
        exit(EXIT_FAILURE);
    }

    in_buf = malloc(in_size);
    if (!in_buf)
        exit(EXIT_FAILURE);

    lseek(fin, 0, SEEK_SET);
    size = 0;
    while ((ret = read(fin, &in_buf[size], in_size - size)) > 0)
        size += ret;

    close(fin);

    out_buf = malloc(in_size);
    if (!out_buf)
        exit(EXIT_FAILURE);

    out_size = LZ4_compress_HC(in_buf, out_buf, in_size, in_size, 12);

    free(in_buf);

//    printf("%lu -> %lu\n", in_size, out_size);

    fout = open(argv[2], O_CREAT | O_TRUNC | O_WRONLY, S_IRUSR | S_IWUSR | S_IRGRP);
    if (fout < 0) {
        printf("can't open %s\n", argv[2]);
        exit(EXIT_FAILURE);
    }

    size = 0;
    while ((ret = write(fout, &out_buf[size], out_size - size)) > 0)
        size += ret;

    close(fout);

    free(out_buf);

    exit(0);
}
