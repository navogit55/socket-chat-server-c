#include <errno.h>
#include <sys/socket.h>

#include "util.h"

int send_all(int socket_fd, const char *message, size_t length) {
    size_t total_sent = 0;

    while (total_sent < length) {
        ssize_t sent = send(socket_fd, message + total_sent, length - total_sent, 0);
        if (sent < 0) {
            if (errno == EINTR) {
                continue;
            }
            return -1;
        }
        if (sent == 0) {
            return -1;
        }
        total_sent += (size_t)sent;
    }

    return 0;
}
