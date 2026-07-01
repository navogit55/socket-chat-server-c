CC ?= cc
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic -O2
LDLIBS ?= -pthread

.PHONY: all clean

all: server client

server: server.c
	$(CC) $(CFLAGS) $< -o $@ $(LDLIBS)

client: client.c
	$(CC) $(CFLAGS) $< -o $@ $(LDLIBS)

clean:
	rm -f server client *.o chat.log
