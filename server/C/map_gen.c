#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>
#include <fcntl.h>
#include "zappy.h"
#include "map_gen.h"

#define DENSITY 5

void	delete_map(t_tile_content **map) {
    if (map && *map) {
        free(*map);
    }
    *map = NULL;
}


ssize_t random_gen(int fd, void *buf) {
    ssize_t ret = read(fd, buf, sizeof(size_t));
    return (ret);
}

void set_tile(t_tile_content *map, t_point pos, int kind, size_t width) {
    map[pos.y * width + pos.x].resources[kind] = rand() % 100;
}


t_tile_content *map_gen(const uint32_t width, const uint32_t height) {
    t_tile_content *map = calloc(height * width, sizeof(t_tile_content)); // todo : error management

    // for (size_t i = 0; i < height * width; i++) {
    //     for (size_t j = 0; j < NB_RESOURCES_; j++) {
    //         map[i].resources[j] = '0';
    //     }
    // }

    // uint32_t **map = calloc(height + 1, sizeof(uint32_t *));
    // if (!map) {
    //     return (NULL);
    // }

    // for (uint32_t i = 0; i < height; i++) {
    //     map[i] = calloc(width + 1, sizeof(uint32_t));
    //     if (!map[i]) {
    //         delete_map(&map);
    //         return (NULL);
    //     }
    // }

    // for (uint32_t i = 0; i < height; i++) {
    //     for (uint32_t j = 0; j < width; j++) {
    //         map[i][j] = '0';
    //     }
    // }

    int nb_cells_x = width / DENSITY;
    nb_cells_x = (nb_cells_x > 0) ? nb_cells_x : 1; // Inutile si width forcément > 10 dans les arg
    int nb_cells_y = height / DENSITY;
    nb_cells_y = (nb_cells_y > 0) ? nb_cells_y : 1; // Inutile si height forcément > 10 dans les arg
    float cell_size_x = width / nb_cells_x;
    float cell_size_y = height / nb_cells_y;
    float current_cell_x = 0;
    float current_cell_y = 0;
    
    int fd = open("/dev/random", O_RDONLY); // to do : error management
    size_t seed = 0;
    read(fd, &seed, sizeof(size_t)); // to do : error management
    srand(seed);
    
    t_point cur_rand = {0, 0};
    // t_point *resource_positions = calloc(nb_cells_x * nb_cells_y, sizeof(t_point));
    // if (!resource_positions) {
    //     delete_map(&map);
    //     return (NULL);
    // }
    
    for (int k = 0; k < NB_RESOURCES_; k++) {
        for (int i = 0; i < nb_cells_y; i++) {
            for (int j = 0; j < nb_cells_x; j++) {
                cur_rand.x = rand() % (int)cell_size_x + current_cell_x;
                cur_rand.y = rand() % (int)cell_size_y + current_cell_y;
                set_tile(map, cur_rand, k, width);
                // resource_positions[(i * (int)nb_cells_x + j)] = cur_rand;
                current_cell_x += cell_size_x;
            }
            current_cell_x = 0;
            current_cell_y += cell_size_y;
        }
        current_cell_y = 0;
    }

    // for (int i = 0; i < nb_cells_x * nb_cells_y; i++) {
    //     random_gen(fd, &seed); // todo : error management
    //     map[resource_positions[i].y].resources[resource_positions[i].x] = '1';
    // }

    close(fd);
    // free(resource_positions);
    // resource_positions = NULL;

    return map;
}
