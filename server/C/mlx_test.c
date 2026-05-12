#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include "mlx/mlx.h"

int mafunct (void *mlx) {
    mlx_loop_end(mlx);
}

int main(void) {
    void *mlx = mlx_init();
    void *mlx_win = mlx_new_window(mlx, 800, 600, "test");

    mlx_loop_hook(mlx, mafunct, mlx);
    mlx_loop(mlx);

    mlx_destroy_window(mlx, mlx_win);
    mlx_destroy_display(mlx);

    free(mlx);
    mlx = NULL;
    return (0);
}