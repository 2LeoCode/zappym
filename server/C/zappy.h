#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>

typedef struct s_point {
    uint32_t x;
    uint32_t y;
} t_point;

typedef struct s_world {
    uint32_t length;
    uint32_t height;

    uint32_t **map;
} t_world;

void print_map(uint32_t **map, uint32_t length, uint32_t height);
