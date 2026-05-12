#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <ctype.h>
#include "map_gen.h"
#include "zappy.h"

t_engine engine = {0};

const char *const tex_file_names[] = {
    "ground.xpm",
    "rsrc_a.xpm",
    "rsrc_b.xpm"
    "rsrc_c.xpm"
    "rsrc_d.xpm",
    "rsrc_e.xpm",
    "rsrc_f.xpm",
    "rsrc_g.xpm",
    "food.xpm",
    "player.xpm"
};

void draw_map(t_world *world) {

}

int check_arg(char **argv) {
    if (atoi(argv[1]) < 10 || atoi(argv[1]) > 1000 || atoi(argv[2]) < 10 || atoi(argv[2]) > 1000) {
        return (1);
    }
    return (0);
}

void print_map(t_tile_content *map, uint32_t width, uint32_t height) {
    for (uint32_t i = 0; i < height; i++) {
        printf("|");
        for (uint32_t j = 0; j < width; j++) {
            uint32_t found_idx = 0;

            for (uint32_t k = 0; k < NB_RESOURCES_; k++) {
                if (map[i * width + j].resources[k] != 0) {
                    found_idx = k;
                    break;
                }
            }
            printf("%04d|", found_idx);
        }
        printf("\n");
    }
}

void init_tex(t_world *world) {
    for(int i = 0; i < countof(tex_file_names); i++) {
        sprintf(engine.path, "%s%s", TEX_PATH, tex_file_names[i]);
        engine.tex[i] = mlx_xpm_file_to_image(engine.mlx, engine.path, &world->width, &world->height); // todo : error management
    }

}

void free_tex(t_world *world) {
    for(int i = 0; i < countof(tex_file_names); i++) {
        // sprintf(engine.path, "%s%s", TEX_PATH, tex_file_names[i]);
        // engine.tex[i] = mlx_xpm_file_to_image(engine.mlx, engine.path, &world->width, &world->height); // todo : error management
        mlx_destroy_image(engine.mlx, engine.tex[i]);
    }
}

int routine (t_world *world) {
    draw_map(world);
    // mlx_put_image_to_window(engine.mlx);
    mlx_loop_end(engine.mlx);
}

int main(int argc, char **argv) {
    if (argc != 3 || check_arg(argv)) {
        printf("wrong arguments\n");
        return (1);
    }
    
    t_world world;
    world.width = atoi(argv[1]);
    world.height = atoi(argv[2]);
    t_tile_content *map = map_gen(world.width, world.height);

    engine.mlx = mlx_init();
    engine.mlx_win = mlx_new_window(engine.mlx, 800, 600, "test");
    void *mlx_img = mlx_new_image(engine.mlx, world.width, world.height);
    init_tex(&world);
    // print_map(map, width, height);

    mlx_loop_hook(engine.mlx, routine, engine.mlx);
    mlx_loop(engine.mlx);

    mlx_destroy_image(engine.mlx, mlx_img);
    mlx_destroy_window(engine.mlx, engine.mlx_win);
    mlx_destroy_display(engine.mlx);

    free(engine.mlx);
    engine.mlx = NULL;
    delete_map(&map);
    
    
    return (0);

}
