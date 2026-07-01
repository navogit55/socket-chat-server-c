#include <arpa/inet.h>
#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define DEFAULT_PORT 8080
#define BUFFER_SIZE 1024
#define USERNAME_SIZE 50

static int sock = -1;
static volatile sig_atomic_t running = 1;

static int send_all(int socket_fd, const char *message, size_t length) {
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

static void *receive_messages(void *arg) {
    (void)arg;
    char buffer[BUFFER_SIZE];

    while (running) {
        ssize_t bytes = recv(sock, buffer, sizeof(buffer) - 1, 0);
        if (bytes <= 0) {
            if (running) {
                fprintf(stderr, "\nDisconnected from server.\n");
            }
            running = 0;
            break;
        }

        buffer[bytes] = '\0';
        fputs(buffer, stdout);
        fflush(stdout);
    }

    return NULL;
}

int main(int argc, char *argv[]) {
    const char *server_ip = "127.0.0.1";
    int port = DEFAULT_PORT;
    struct sockaddr_in serv_addr;
    char buffer[BUFFER_SIZE];
    char username[USERNAME_SIZE];

    if (argc >= 2) {
        server_ip = argv[1];
    }
    if (argc >= 3) {
        port = atoi(argv[2]);
        if (port <= 0 || port > 65535) {
            fprintf(stderr, "Invalid port: %s\n", argv[2]);
            return EXIT_FAILURE;
        }
    }

    signal(SIGPIPE, SIG_IGN);

    printf("Enter username: ");
    if (fgets(username, sizeof(username), stdin) == NULL) {
        fprintf(stderr, "Failed to read username.\n");
        return EXIT_FAILURE;
    }
    username[strcspn(username, "\r\n")] = '\0';
    if (username[0] == '\0') {
        strncpy(username, "guest", sizeof(username) - 1);
        username[sizeof(username) - 1] = '\0';
    }

    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        perror("socket");
        return EXIT_FAILURE;
    }

    memset(&serv_addr, 0, sizeof(serv_addr));
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons((uint16_t)port);

    if (inet_pton(AF_INET, server_ip, &serv_addr.sin_addr) <= 0) {
        fprintf(stderr, "Invalid server address: %s\n", server_ip);
        close(sock);
        return EXIT_FAILURE;
    }

    if (connect(sock, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
        perror("connect");
        close(sock);
        return EXIT_FAILURE;
    }

    if (send_all(sock, username, strlen(username)) < 0) {
        perror("send");
        close(sock);
        return EXIT_FAILURE;
    }

    pthread_t recv_thread;
    if (pthread_create(&recv_thread, NULL, receive_messages, NULL) != 0) {
        perror("pthread_create");
        close(sock);
        return EXIT_FAILURE;
    }

    while (running && fgets(buffer, sizeof(buffer), stdin) != NULL) {
        if (strlen(buffer) <= 1) {
            continue;
        }

        if (send_all(sock, buffer, strlen(buffer)) < 0) {
            perror("send");
            break;
        }

        if (strncmp(buffer, "/quit", 5) == 0) {
            running = 0;
            break;
        }
    }

    running = 0;
    shutdown(sock, SHUT_RDWR);
    close(sock);
    pthread_join(recv_thread, NULL);

    return EXIT_SUCCESS;
}
