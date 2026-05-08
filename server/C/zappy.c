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

void print_map(t_tile_content *map, uint32_t length, uint32_t height) {
    for (uint32_t i = 0; i < height; i++) {
        printf("|");
        for (uint32_t j = 0; j < length; j++) {
            uint32_t found_idx = 0;

            for (uint32_t k = 0; k < NB_RESOURCES_; k++) {
                if (map[i * length + j].resources[k] != 0) {
                    found_idx = k;
                    break;
                }
            }
            printf("%04d|", found_idx);
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
    t_tile_content *map = map_gen(length, height);
    
    print_map(map, length, height);

    delete_map(&map);

    return (0);
}
