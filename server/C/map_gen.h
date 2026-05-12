#ifndef MAP_GEN_H
#define MAP_GEN_H

#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>
#include "zappy.h"

typedef enum e_resource_kind {
    NOURRITURE,
    A,
    B,
    C,
    D,
    E,
    F,
NB_RESOURCES_} t_resource_kind;


typedef struct s_tile_content {
    size_t resources[NB_RESOURCES_];
} t_tile_content;


t_tile_content *map_gen(const uint32_t width, const uint32_t height);
void delete_map(t_tile_content **map);

#endif