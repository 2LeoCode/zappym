#ifndef ZAPPY_H
#define ZAPPY_H

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>
#include <linux/limits.h>
#include "map_gen.h"
#include "mlx/mlx.h"

#define TEX_PATH "./assets/textures/"

#define countof(arr) (sizeof(arr) / sizeof(*(arr)))

typedef enum e_tex_indexer {
    GROUND_XPM,
    RSRC_A_XPM,
    RSRC_B_XPM,
    RSRC_C_XPM,
    RSRC_D_XPM,
    RSRC_E_XPM,
    RSRC_F_XPM,
    RSRC_G_XPM,
    FOOD_XPM,
    PLAYER_XPM,
    TEX_COUNT
} t_tex_indexer;



extern const char *const tex_file_names[];


typedef struct s_tile_content t_tile_content;

typedef struct s_point {
    uint32_t x;
    uint32_t y;
} t_point;

typedef struct s_engine {
    void *mlx;
    void *mlx_win;
    void *mlx_frame;
    void *tex[TEX_COUNT];
    char path[PATH_MAX];
} t_engine;

typedef struct s_world {
    uint32_t width;
    uint32_t height;
    
    uint32_t **map;
} t_world;

void print_map(t_tile_content *map, uint32_t width, uint32_t height);

extern t_engine engine;

#endif