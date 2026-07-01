#include <arpa/inet.h>
#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define PORT 8080
#define MAX_CLIENTS 100
#define BUFFER_SIZE 1024
#define USERNAME_SIZE 50

#define RESET "\033[0m"

static const char *colors[] = {
    "\033[1;31m",
    "\033[1;32m",
    "\033[1;33m",
    "\033[1;34m",
    "\033[1;35m",
    "\033[1;36m",
    "\033[1;37m"
};

#define COLOR_COUNT 7

typedef struct {
    int socket;
    char username[USERNAME_SIZE];
    const char *color;
} Client;

static Client clients[MAX_CLIENTS];
static int client_count = 0;
static pthread_mutex_t lock;

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

static void log_message(const char *message) {
    FILE *log = fopen("chat.log", "a");
    if (log == NULL) {
        return;
    }

    fputs(message, log);
    fclose(log);
}

static void broadcast(const char *message, int sender_socket) {
    int sockets[MAX_CLIENTS];
    int socket_count = 0;
    size_t message_len = strlen(message);

    pthread_mutex_lock(&lock);
    for (int i = 0; i < client_count; i++) {
        if (clients[i].socket != sender_socket) {
            sockets[socket_count++] = clients[i].socket;
        }
    }
    pthread_mutex_unlock(&lock);

    for (int i = 0; i < socket_count; i++) {
        (void)send_all(sockets[i], message, message_len);
    }

    log_message(message);
}

static int add_client(int sock, const char *username) {
    int result = 0;

    pthread_mutex_lock(&lock);
    if (client_count >= MAX_CLIENTS) {
        result = -1;
    } else {
        clients[client_count].socket = sock;
        strncpy(clients[client_count].username, username, USERNAME_SIZE - 1);
        clients[client_count].username[USERNAME_SIZE - 1] = '\0';
        clients[client_count].color = colors[client_count % COLOR_COUNT];
        client_count++;
    }
    pthread_mutex_unlock(&lock);

    return result;
}

static void remove_client(int sock) {
    char left_username[USERNAME_SIZE] = {0};
    int removed = 0;

    pthread_mutex_lock(&lock);
    for (int i = 0; i < client_count; i++) {
        if (clients[i].socket == sock) {
            strncpy(left_username, clients[i].username, USERNAME_SIZE - 1);
            left_username[USERNAME_SIZE - 1] = '\0';
            close(clients[i].socket);
            clients[i] = clients[client_count - 1];
            client_count--;
            removed = 1;
            break;
        }
    }
    pthread_mutex_unlock(&lock);

    if (removed) {
        char msg[BUFFER_SIZE];
        snprintf(msg, sizeof(msg), ">>> %s left the chat\n", left_username);
        broadcast(msg, sock);
    }
}

static void send_online_users(int sock) {
    char list[BUFFER_SIZE];
    size_t used = (size_t)snprintf(list, sizeof(list), "Online Users:\n");

    if (used >= sizeof(list)) {
        used = sizeof(list) - 1;
    }

    pthread_mutex_lock(&lock);
    for (int i = 0; i < client_count && used < sizeof(list) - 1; i++) {
        int written = snprintf(list + used, sizeof(list) - used, "%s\n", clients[i].username);
        if (written < 0) {
            break;
        }
        if ((size_t)written >= sizeof(list) - used) {
            break;
        }
        used += (size_t)written;
    }
    pthread_mutex_unlock(&lock);

    (void)send_all(sock, list, strlen(list));
}

static void send_private_message(int sender_sock, const char *sender_name, const char *buffer) {
    char target[USERNAME_SIZE] = {0};
    char message[BUFFER_SIZE] = {0};

    if (sscanf(buffer + 5, "%49s %1023[^\n]", target, message) != 2) {
        const char *usage = "Usage: /msg <username> <message>\n";
        (void)send_all(sender_sock, usage, strlen(usage));
        return;
    }

    int target_socket = -1;
    pthread_mutex_lock(&lock);
    for (int i = 0; i < client_count; i++) {
        if (strcmp(clients[i].username, target) == 0) {
            target_socket = clients[i].socket;
            break;
        }
    }
    pthread_mutex_unlock(&lock);

    if (target_socket < 0) {
        const char *not_found = "User not found.\n";
        (void)send_all(sender_sock, not_found, strlen(not_found));
        return;
    }

    char private_msg[BUFFER_SIZE + USERNAME_SIZE + 32];
    snprintf(private_msg,
             sizeof(private_msg),
             "\033[1;95m[Private] %s: %s\033[0m\n",
             sender_name,
             message);
    (void)send_all(target_socket, private_msg, strlen(private_msg));

    if (target_socket != sender_sock) {
        char delivered_msg[BUFFER_SIZE + USERNAME_SIZE + 32];
        snprintf(delivered_msg,
                 sizeof(delivered_msg),
                 "\033[1;90m[To %s] %s\033[0m\n",
                 target,
                 message);
        (void)send_all(sender_sock, delivered_msg, strlen(delivered_msg));
    }
}

static const char *get_client_color(int sock) {
    const char *user_color = RESET;

    pthread_mutex_lock(&lock);
    for (int i = 0; i < client_count; i++) {
        if (clients[i].socket == sock) {
            user_color = clients[i].color;
            break;
        }
    }
    pthread_mutex_unlock(&lock);

    return user_color;
}

static void *handle_client(void *arg) {
    int sock = *(int *)arg;
    char buffer[BUFFER_SIZE];
    char username[USERNAME_SIZE];

    free(arg);

    ssize_t bytes = recv(sock, username, sizeof(username) - 1, 0);
    if (bytes <= 0) {
        close(sock);
        return NULL;
    }

    username[bytes] = '\0';
    username[strcspn(username, "\r\n")] = '\0';

    if (username[0] == '\0') {
        snprintf(username, sizeof(username), "guest-%d", sock);
    }

    if (add_client(sock, username) != 0) {
        const char *server_full = "Server full. Try again later.\n";
        (void)send_all(sock, server_full, strlen(server_full));
        close(sock);
        return NULL;
    }

    char join_msg[BUFFER_SIZE];
    snprintf(join_msg, sizeof(join_msg), ">>> %s joined the chat\n", username);
    broadcast(join_msg, sock);

    while (1) {
        bytes = recv(sock, buffer, sizeof(buffer) - 1, 0);
        if (bytes <= 0) {
            break;
        }

        buffer[bytes] = '\0';

        if (strncmp(buffer, "/quit", 5) == 0) {
            break;
        } else if (strncmp(buffer, "/users", 6) == 0) {
            send_online_users(sock);
        } else if (strncmp(buffer, "/msg ", 5) == 0) {
            send_private_message(sock, username, buffer);
        } else {
            const char *user_color = get_client_color(sock);
            char final_msg[BUFFER_SIZE + USERNAME_SIZE + 32];
            snprintf(final_msg,
                     sizeof(final_msg),
                     "%s%s: %s%s",
                     user_color,
                     username,
                     buffer,
                     RESET);
            broadcast(final_msg, sock);
        }
    }

    remove_client(sock);
    return NULL;
}

int main(void) {
    int server_fd;
    int opt = 1;
    struct sockaddr_in address;

    signal(SIGPIPE, SIG_IGN);

    if (pthread_mutex_init(&lock, NULL) != 0) {
        fprintf(stderr, "Failed to initialize mutex.\n");
        return EXIT_FAILURE;
    }

    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("socket");
        pthread_mutex_destroy(&lock);
        return EXIT_FAILURE;
    }

    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
        perror("setsockopt");
    }

    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(PORT);

    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        perror("bind");
        close(server_fd);
        pthread_mutex_destroy(&lock);
        return EXIT_FAILURE;
    }

    if (listen(server_fd, MAX_CLIENTS) < 0) {
        perror("listen");
        close(server_fd);
        pthread_mutex_destroy(&lock);
        return EXIT_FAILURE;
    }

    printf("Chat Server running on port %d\n", PORT);

    while (1) {
        int new_socket = accept(server_fd, NULL, NULL);
        if (new_socket < 0) {
            if (errno == EINTR) {
                continue;
            }
            perror("accept");
            continue;
        }

        int *pclient = malloc(sizeof(*pclient));
        if (pclient == NULL) {
            perror("malloc");
            close(new_socket);
            continue;
        }
        *pclient = new_socket;

        pthread_t tid;
        if (pthread_create(&tid, NULL, handle_client, pclient) != 0) {
            perror("pthread_create");
            close(new_socket);
            free(pclient);
            continue;
        }
        pthread_detach(tid);
    }

    close(server_fd);
    pthread_mutex_destroy(&lock);
    return EXIT_SUCCESS;
}
