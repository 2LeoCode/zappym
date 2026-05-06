#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>
#include "zappy.h"


uint32_t **map_gen(const uint32_t length, const uint32_t height);
void delete_map(uint32_t ***map);
