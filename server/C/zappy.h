#ifndef ZAPPY_H
#define ZAPPY_H

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>
#include "map_gen.h"

typedef struct s_tile_content t_tile_content;

typedef struct s_point {
    uint32_t x;
    uint32_t y;
} t_point;

typedef struct s_world {
    uint32_t length;
    uint32_t height;

    uint32_t **map;
} t_world;

void print_map(t_tile_content *map, uint32_t length, uint32_t height);

#endif