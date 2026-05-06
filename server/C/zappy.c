#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <ctype.h>
#include "map_gen.h"


int check_arg(char **argv) {
    if (atoi(argv[1]) < 10 || atoi(argv[1]) > 1000 || atoi(argv[2]) < 10 || atoi(argv[2]) > 1000) {
        return (1);
    }
    return (0);
}

void print_map(uint32_t **map, uint32_t length, uint32_t height) {
    for (uint32_t i = 0; i < height; i++) {
        for (uint32_t j = 0; j < length; j++) {
            printf("%c", map[i][j]);
        }
        printf("\n");
    }
}

int main(int argc, char **argv) {
    if (argc != 3 || check_arg(argv)) {
        printf("wrong arguments\n");
        return (1);
    }

    uint32_t length = atoi(argv[1]);
    uint32_t height = atoi(argv[2]);
    uint32_t **map = map_gen(length, height);
    
    print_map(map, length, height);

    delete_map(&map);

    return (0);
}
