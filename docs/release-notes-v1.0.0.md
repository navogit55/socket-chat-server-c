# Release Notes - v1.0.0

## Highlights

Initial release of the Socket Chat Server - a concurrent, multi-client terminal chat application built from scratch in C using POSIX sockets and threads. The project demonstrates low-level network programming, thread-safe resource management, and clean build engineering.

## Features

- **Concurrent clients** - supports up to 100 simultaneous connections via pthreads
- **Public chat** - broadcast messages to all connected users
- **Private messaging** - whisper directly to a specific user with `/msg <username> <message>`
- **Online user listing** - see who is connected with `/users`
- **Colored output** - each user is assigned a distinct terminal color
- **Activity logging** - all chat activity is logged to `chat.log`
- **Graceful disconnect** - clients can leave with `/quit`; server notifies others
- **Configurable server address** - client accepts IP and port arguments
- **Configurable server port** - server accepts an optional port number
- **Signal safety** - `SIGPIPE` is ignored to prevent abrupt crashes

## Technologies

- C11 (`-std=c11`)
- POSIX TCP sockets (`<sys/socket.h>`, `<arpa/inet.h>`)
- POSIX threads (`<pthread.h>`)
- Make build system
- Compatible with Linux, macOS, and BSD

## Build

```bash
make          # builds server and client binaries
make clean    # removes build artifacts
make lint     # syntax-only verification
make test     # runs automated integration tests
make debug    # build with debug symbols
make release  # build with full optimizations
```

Output binaries are placed in `build/`.

## Testing

Automated shell-based integration tests cover:

- Server startup and shutdown
- Client connection and authentication
- Public message broadcast
- Private messaging (`/msg`)
- Online user listing (`/users`)
- Client disconnect handling
- Multiple simultaneous clients

Run with:

```bash
make test
```

## Limitations

- No encryption - messages are transmitted in plaintext
- No authentication - any username is accepted
- No persistent user accounts or message history beyond the session log
- Server does not support a graceful shutdown signal (Ctrl+C kills all)

## Future Work

- TLS/SSL encrypted transport
- User authentication with passwords
- Chat rooms / channels
- File transfer support
- Web-based front-end
- Graceful server shutdown (`SIGINT` handler)
- Rate limiting and anti-spam measures
- IPv6 support
