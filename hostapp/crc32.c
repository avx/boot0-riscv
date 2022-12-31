#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <crc32.h>

int main(int argc, char *argv[])
{
    unsigned int crc, in_size, size = 0;
    unsigned char *in_buf;
    int fd, ret;

    if (argc != 2) {
        printf ("Usage: %s <filename>\n", argv[0]);
        exit(-1);
    }

    fd = open(argv[1], O_RDONLY, S_IRUSR | S_IRGRP);
        if (fd < 0) {
            printf ("Can open %s\n", argv[1]);
            exit(EXIT_FAILURE);
    }

    in_size = lseek(fd, 0, SEEK_END);
    if (in_size == -1) {
        printf("failed to lseek %s\n", argv[1]);
        exit(EXIT_FAILURE);
    }

    lseek(fd, 0, SEEK_SET);

    in_buf = malloc(in_size);
    if (!in_buf)
        exit(EXIT_FAILURE);

    size = 0;
    while ((ret = read(fd, &in_buf[size], in_size - size)) > 0)
        size += ret;

    close(fd);

    if (size != in_size) {
        printf("read error\n");
        exit(EXIT_FAILURE);
    }

    crc = crc32(in_buf, in_size);

    printf("%x\n", crc);

    exit(0);
}
