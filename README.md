# Socket Chat Server in C

A multiclient terminal chat application built with POSIX sockets and threads. The server coordinates public and private messages while each client uses a background receive thread for live updates.

## Features

- Supports up to 100 connected clients
- Broadcasts public messages to other users
- Sends private messages with `/msg <username> <message>`
- Lists connected users with `/users`
- Records server activity in `chat.log`
- Handles client joins, disconnects, and `/quit`

## Technologies Used

- C11
- POSIX TCP sockets
- POSIX threads (`pthread`)
- Make

## Project Structure

```text
.
├── client.c   # Terminal chat client
├── server.c   # Concurrent chat server
└── Makefile   # Build targets
```

## How to Run

This project requires a POSIX-compatible system such as Linux or macOS, a C compiler, and Make.

```bash
make
./server
```

In a second terminal:

```bash
./client 127.0.0.1 8080
```

The client accepts an optional server IPv4 address and port. The server listens on port `8080`.

## Example Usage

```text
Hello everyone
/users
/msg alice Hi Alice
/quit
```

## Future Improvements

- Make the server port configurable
- Add encrypted transport and user authentication
- Add automated integration tests
- Support graceful server shutdown

## Author

Navoneel Bhattacharya

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
