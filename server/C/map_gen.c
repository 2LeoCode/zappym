#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>
#include <fcntl.h>
#include "zappy.h"

#define NRESSOURCES 7

enum ressource_kind {
    NOURRITURE,
    A,
    B,
    C,
    D,
    E,
    F
};


struct tile_content {
    size_t resources[NRESSOURCES];
};


void	delete_map(uint32_t ***map) {

	  for (uint32_t i = 0; (*map)[i]; i++) {
	  	  free((*map)[i]);
	  	  (*map)[i] = NULL;
	  }
	  free(*map);
    *map = NULL;
}


ssize_t random_gen(int fd, void *buf) {
    ssize_t ret = read(fd, buf, sizeof(size_t));
    return (ret);
}


uint32_t **map_gen(const uint32_t length, const uint32_t height) {
    uint32_t **map = calloc(height + 1, sizeof(uint32_t *));
    if (!map) {
        return (NULL);
    }

    for (uint32_t i = 0; i < height; i++) {
        map[i] = calloc(length + 1, sizeof(uint32_t));
        if (!map[i]) {
            delete_map(&map);
            return (NULL);
        }
    }

    for (uint32_t i = 0; i < height; i++) {
        for (uint32_t j = 0; j < length; j++) {
            map[i][j] = '0';
        }
    }

    int nb_cells_x = (float)length / 10.0f;
    nb_cells_x = (nb_cells_x > 0) ? nb_cells_x : 1; // Inutile si length forcément > 10 dans les arg
    int nb_cells_y = (float)height / 10.0f;
    nb_cells_y = (nb_cells_y > 0) ? nb_cells_y : 1; // Inutile si height forcément > 10 dans les arg
    float cell_size_x = length / nb_cells_x;
    float cell_size_y = height / nb_cells_y;
    float current_cell_x = 0;
    float current_cell_y = 0;

    int fd = open("/dev/random", O_RDONLY);
    if (fd == -1) {
        // to do : error management
        return (NULL);
    }


    size_t seed = 0;
    t_point cur_rand = {0, 0};
    t_point *resources = calloc(nb_cells_x * nb_cells_y, sizeof(t_point));
    if (!resources) {
        delete_map(&map);
        return (NULL);
    }

    for (int i = 0; i < nb_cells_y; i++) {
        for (int j = 0; j < nb_cells_x; j++) {
            random_gen(fd, &seed); // todo : error management
            cur_rand.x = (seed & (uint32_t)0xFFFFFFFF) % (int)cell_size_x + current_cell_x;
            cur_rand.y = (seed >> 16) % (int)cell_size_y + current_cell_y;
            printf("base : %zx | first_half : %zx | second_half : %zx\n", seed, seed & (uint32_t)0xFFFFFFFF, seed >> 32);
            resources[(i * (int)nb_cells_x + j)] = cur_rand;
            current_cell_x += cell_size_x;
        }
        current_cell_x = 0;
        current_cell_y += cell_size_y;
    }

    
    for (int i = 0; i < nb_cells_x * nb_cells_y; i++) {
        map[resources[i].y][resources[i].x] = '1';
    }

    free(resources);
    resources = NULL;

    return map;
}
