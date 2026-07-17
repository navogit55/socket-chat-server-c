#ifndef UTIL_H
#define UTIL_H

#include <stddef.h>

int send_all(int socket_fd, const char *message, size_t length);

#endif
