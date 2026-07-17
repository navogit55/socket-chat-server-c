CC       ?= cc
CFLAGS   ?= -std=c11 -Wall -Wextra -Wpedantic -O2
LDLIBS   ?= -pthread

SRCDIR   := src
INCDIR   := include
BUILDDIR := build
TARGETS  := server client

.PHONY: all clean test lint debug release

all: CFLAGS := -std=c11 -Wall -Wextra -Wpedantic -O2
all: $(TARGETS)

debug: CFLAGS := -std=c11 -Wall -Wextra -Wpedantic -g -O0
debug: $(TARGETS)

release: CFLAGS := -std=c11 -Wall -Wextra -Wpedantic -O2 -DNDEBUG
release: $(TARGETS)

$(BUILDDIR)/util.o: $(SRCDIR)/util.c include/util.h | $(BUILDDIR)
	$(CC) $(CFLAGS) -I$(INCDIR) -c $< -o $@

$(BUILDDIR)/server.o: $(SRCDIR)/server.c include/chat.h include/util.h | $(BUILDDIR)
	$(CC) $(CFLAGS) -I$(INCDIR) -c $< -o $@

$(BUILDDIR)/client.o: $(SRCDIR)/client.c include/chat.h include/util.h | $(BUILDDIR)
	$(CC) $(CFLAGS) -I$(INCDIR) -c $< -o $@

server: $(BUILDDIR)/server.o $(BUILDDIR)/util.o
	$(CC) $(CFLAGS) $^ -o $(BUILDDIR)/$@ $(LDLIBS)

client: $(BUILDDIR)/client.o $(BUILDDIR)/util.o
	$(CC) $(CFLAGS) $^ -o $(BUILDDIR)/$@ $(LDLIBS)

$(BUILDDIR):
	mkdir -p $(BUILDDIR)

test: all
	@tests/run_tests.sh

clean:
	rm -rf $(BUILDDIR) *.o chat.log

lint: all
	$(CC) $(CFLAGS) -I$(INCDIR) -fsyntax-only $(SRCDIR)/server.c
	$(CC) $(CFLAGS) -I$(INCDIR) -fsyntax-only $(SRCDIR)/client.c
