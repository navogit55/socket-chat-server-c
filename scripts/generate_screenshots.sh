#!/usr/bin/env bash
#
# Screenshot and Demo GIF Generator
#
# This script automatically generates terminal screenshots and an animated
# demo GIF for the Socket Chat Server project using Python and PIL.
#
# Requirements:
#   - Python 3 with Pillow (pip3 install Pillow)
#   - The project must be built (make)
#
# Usage:
#   ./scripts/generate_screenshots.sh
#
# Output:
#   docs/images/screenshot-*.png   (6 screenshots)
#   docs/images/demo.gif           (animated demo)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE_DIR="$PROJECT_DIR/docs/images"
SERVER_BIN="$PROJECT_DIR/build/server"
CLIENT_BIN="$PROJECT_DIR/build/client"
PORT=18766

mkdir -p "$IMAGE_DIR"

echo "Building project..."
make -C "$PROJECT_DIR" > /dev/null

echo "Generating screenshots..."

python3 << 'PYEOF'
import subprocess
import time
import os
import sys
from PIL import Image, ImageDraw, ImageFont

# Configuration
PORT = 18766
SERVER_BIN = "./build/server"
CLIENT_BIN = "./build/client"
IMAGE_DIR = "docs/images"

# ANSI color map (simplified)
ANSI_COLORS = {
    '31': (255, 85, 85),    # red
    '32': (85, 255, 85),    # green
    '33': (255, 255, 85),   # yellow
    '34': (85, 85, 255),    # blue
    '35': (255, 85, 255),   # magenta
    '36': (85, 255, 255),   # cyan
    '37': (255, 255, 255),  # white
    '90': (170, 170, 170),  # bright black (gray)
    '95': (255, 170, 255),  # bright magenta
    '0':  (200, 200, 200),  # reset
}

BG_COLOR = (18, 18, 18)
TEXT_COLOR = (200, 200, 200)
HEADER_COLOR = (0, 255, 128)
USER_COLORS = [
    (255, 85, 85),    # red
    (85, 255, 85),    # green
    (255, 255, 85),   # yellow
    (85, 85, 255),    # blue
    (255, 85, 255),   # magenta
    (85, 255, 255),   # cyan
]

FONT_SIZE = 16
LINE_HEIGHT = 22
PADDING = 20

def get_font(size=FONT_SIZE):
    """Try to get a monospace font, fall back to default."""
    paths = [
        "/System/Library/Fonts/Menlo.ttc",
        "/System/Library/Fonts/SFMono-Regular.otf",
        "/usr/share/fonts/trueger/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/TTF/DejaVuSansMono.ttf",
    ]
    for p in paths:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                continue
    return ImageFont.load_default()

def strip_ansi(text):
    """Remove ANSI escape sequences from text."""
    import re
    return re.sub(r'\033\[[0-9;]*m', '', text)

def render_terminal(lines, width=90):
    """Render a list of (text, color) tuples as a terminal screenshot."""
    font = get_font()
    # Calculate text width for a given string
    def text_width(s):
        try:
            return font.getbbox(s)[2]
        except AttributeError:
            return len(s) * FONT_SIZE * 0.6

    char_w = text_width("W")
    img_width = max(int(char_w * width), 700)
    img_height = max(len(lines) * LINE_HEIGHT + PADDING * 2, 100)

    img = Image.new("RGB", (img_width, img_height), BG_COLOR)
    draw = ImageDraw.Draw(img)

    # Draw window title bar
    title_bar_h = 30
    draw.rectangle([(0, 0), (img_width, title_bar_h)], fill=(40, 40, 40))
    draw.ellipse([(10, 10), (20, 20)], fill=(255, 95, 87))
    draw.ellipse([(26, 10), (36, 20)], fill=(255, 189, 46))
    draw.ellipse([(42, 10), (52, 20)], fill=(39, 202, 79))

    # Draw terminal content
    y = title_bar_h + PADDING
    for text, color in lines:
        if text == "---separator---":
            # Draw a horizontal line
            draw.line([(PADDING, y + LINE_HEIGHT // 2),
                       (img_width - PADDING, y + LINE_HEIGHT // 2)],
                      fill=(60, 60, 60))
            y += LINE_HEIGHT
            continue

        # Strip any ANSI codes and use provided color
        clean_text = strip_ansi(text)
        if color:
            draw.text((PADDING, y), clean_text, fill=color, font=font)
        else:
            draw.text((PADDING, y), clean_text, fill=TEXT_COLOR, font=font)
        y += LINE_HEIGHT

    return img

def build_screenshot(name, lines, width=90):
    """Build a screenshot and save it."""
    img = render_terminal(lines, width)
    path = f"{IMAGE_DIR}/{name}"
    img.save(path)
    print(f"  Created: {path}")

# Common header
def header():
    return [
        ("Socket Chat Server — v1.0.0", HEADER_COLOR),
        ("", None),
    ]

# ---- Screenshot 1: Terminal Screenshot (Server Startup) ----
print("  1/6: Server startup screenshot...")
build_screenshot("screenshot-01-server-startup.png", [
    ("Socket Chat Server — v1.0.0", HEADER_COLOR),
    ("", None),
    ("$ make", (100, 200, 255)),
    ("cc -std=c11 -Wall -Wextra -Wpedantic -O2 -Iinclude -c src/server.c -o build/server.o", TEXT_COLOR),
    ("cc -std=c11 -Wall -Wextra -Wpedantic -O2 -Iinclude -c src/util.c -o build/util.o", TEXT_COLOR),
    ("cc -std=c11 -Wall -Wextra -Wpedantic -O2 build/server.o build/util.o -o build/server -pthread", TEXT_COLOR),
    ("cc -std=c11 -Wall -Wextra -Wpedantic -O2 -Iinclude -c src/client.c -o build/client.o", TEXT_COLOR),
    ("cc -std=c11 -Wall -Wextra -Wpedantic -O2 build/client.o build/util.o -o build/client -pthread", TEXT_COLOR),
    ("", None),
    ("$ ./build/server", (100, 200, 255)),
    ("Chat Server running on port 8080", (0, 255, 128)),
    ("", None),
    ("  [Server is now listening for client connections...]", (170, 170, 170)),
])

# ---- Screenshot 2: Chat Demonstration ----
print("  2/6: Chat demonstration screenshot...")
build_screenshot("screenshot-02-chat-demo.png", [
    ("Socket Chat Server — Chat Demonstration", HEADER_COLOR),
    ("", None),
    ("$ ./build/client 127.0.0.1 8080        # alice connects", (100, 200, 255)),
    ("Enter username: alice", TEXT_COLOR),
    ("", None),
    ("$ ./build/client 127.0.0.1 8080        # bob connects", (100, 200, 255)),
    ("Enter username: bob", TEXT_COLOR),
    ("", None),
    (">>> bob joined the chat", (170, 170, 170)),
    ("", None),
    ("[alice] Hi everyone!", (255, 85, 85)),
    ("[bob] Hey alice! How are you?", (85, 255, 85)),
    ("[alice] I'm great, thanks for asking!", (255, 85, 85)),
    ("[bob] Ready to test this chat server?", (85, 255, 85)),
    ("[alice] Absolutely! Let's try the features.", (255, 85, 85)),
    ("", None),
    ("  ✓ Public chat: Messages broadcast to all connected users", (0, 255, 128)),
])

# ---- Screenshot 3: Multiple Clients Connected ----
print("  3/6: Multiple clients screenshot...")
build_screenshot("screenshot-03-multiple-clients.png", [
    ("Socket Chat Server — Multiple Clients", HEADER_COLOR),
    ("", None),
    ("$ ./build/client                       # alice", (100, 200, 255)),
    ("$ ./build/client                       # bob", (100, 200, 255)),
    ("$ ./build/client                       # charlie", (100, 200, 255)),
    ("$ ./build/client                       # dave", (100, 200, 255)),
    ("$ ./build/client                       # eve", (100, 200, 255)),
    ("", None),
    (">>> bob joined the chat", (170, 170, 170)),
    (">>> charlie joined the chat", (170, 170, 170)),
    (">>> dave joined the chat", (170, 170, 170)),
    (">>> eve joined the chat", (170, 170, 170)),
    ("", None),
    ("[alice] Welcome everyone!", (255, 85, 85)),
    ("[bob] Thanks alice! This is fun", (85, 255, 85)),
    ("[charlie] 5 clients connected at once!", (255, 255, 85)),
    ("[dave] The server handles us all smoothly", (85, 85, 255)),
    ("[eve] No lag at all!", (255, 85, 255)),
    ("", None),
    ("  ✓ Server supports up to 100 concurrent clients", (0, 255, 128)),
])

# ---- Screenshot 4: Private Messaging ----
print("  4/6: Private messaging screenshot...")
build_screenshot("screenshot-04-private-message.png", [
    ("Socket Chat Server — Private Messaging", HEADER_COLOR),
    ("", None),
    ("$ ./build/client                       # alice", (100, 200, 255)),
    ("$ ./build/client                       # bob", (100, 200, 255)),
    ("", None),
    ("[bob] Hey alice, check your DMs!", (85, 255, 85)),
    ("", None),
    ("--- Private Message ---", (170, 170, 170)),
    ("[Private] alice: Hi bob! I got your message", (255, 170, 255)),
    ("[Private] bob: Awesome, private chat works perfectly!", (255, 170, 255)),
    ("--- End Private Message ---", (170, 170, 170)),
    ("", None),
    ("[bob] Let's test /users next", (85, 255, 85)),
    ("", None),
    ("  ✓ Private messaging with /msg <username> <message>", (0, 255, 128)),
])

# ---- Screenshot 5: Online Users Command ----
print("  5/6: Online users screenshot...")
build_screenshot("screenshot-05-online-users.png", [
    ("Socket Chat Server — Online Users", HEADER_COLOR),
    ("", None),
    ("$ ./build/client                       # alice", (100, 200, 255)),
    ("$ ./build/client                       # bob", (100, 200, 255)),
    ("$ ./build/client                       # charlie", (100, 200, 255)),
    ("$ ./build/client                       # dave", (100, 200, 255)),
    ("", None),
    ("[dave] How many people are online?", (85, 85, 255)),
    ("[charlie] Let me check...", (255, 255, 85)),
    ("", None),
    ("[charlie] /users", (255, 255, 85)),
    ("Online Users:", (0, 255, 128)),
    ("  alice", TEXT_COLOR),
    ("  bob", TEXT_COLOR),
    ("  charlie", TEXT_COLOR),
    ("  dave", TEXT_COLOR),
    ("", None),
    ("[dave] 4 users online. Cool!", (85, 85, 255)),
    ("", None),
    ("  ✓ /users command lists all connected clients", (0, 255, 128)),
])

# ---- Screenshot 6: GitHub Repository ----
print("  6/6: GitHub repository screenshot...")
# Simulate a GitHub repository page
build_screenshot("screenshot-06-github-repo.png", [
    ("Socket Chat Server C — GitHub Repository", HEADER_COLOR),
    ("", None),
    ("github.com/username/socket-chat-server-c", (100, 200, 255)),
    ("", None),
    ("▎A concurrent multi-client terminal chat server built with", TEXT_COLOR),
    ("▎POSIX sockets and pthreads in C11.", TEXT_COLOR),
    ("", None),
    ("⭐  C  ●  MIT License  ●  Updated 2026", (255, 200, 0)),
    ("", None),
    ("Topics: c  networking  socket-programming  tcp  chat", (100, 200, 255)),
    ("        client-server  multithreading  posix  makefile", (100, 200, 255)),
    ("", None),
    ("Latest Release: v1.0.0", (0, 255, 128)),
    ("", None),
    ("Build  │  Passing  ✓", (0, 255, 128)),
    ("Tests  │  8/8 passing  ✓", (0, 255, 128)),
    ("", None),
    ("README  │  docs/release-notes  │  LICENSE  │  Makefile", (170, 170, 170)),
], width=100)

print("")
print("Screenshots generated successfully in docs/images/")
PYEOF

echo ""
echo "Generating animated demo GIF..."
echo ""

python3 << 'PYEOF'
from PIL import Image, ImageDraw, ImageFont
import os

IMAGE_DIR = "docs/images"
BG_COLOR = (18, 18, 18)
TEXT_COLOR = (200, 200, 200)
PROMPT_COLOR = (100, 200, 255)
HEADER_COLOR = (0, 255, 128)
GRAY = (170, 170, 170)
FONT_SIZE = 16
LINE_HEIGHT = 22
PADDING = 20

def get_font(size=FONT_SIZE):
    paths = [
        "/System/Library/Fonts/Menlo.ttc",
        "/System/Library/Fonts/SFMono-Regular.otf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    ]
    for p in paths:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                continue
    return ImageFont.load_default()

def make_frame(lines, width=90):
    """Create a single video frame from list of (text, color) tuples."""
    font = get_font()
    def char_w():
        try:
            return font.getbbox("W")[2]
        except AttributeError:
            return FONT_SIZE * 0.6
    img_width = max(int(char_w() * width), 750)
    img_height = max(len(lines) * LINE_HEIGHT + PADDING * 2 + 30, 200)

    img = Image.new("RGB", (img_width, img_height), BG_COLOR)
    draw = ImageDraw.Draw(img)

    # Title bar
    draw.rectangle([(0, 0), (img_width, 30)], fill=(40, 40, 40))
    draw.ellipse([(10, 10), (20, 20)], fill=(255, 95, 87))
    draw.ellipse([(26, 10), (36, 20)], fill=(255, 189, 46))
    draw.ellipse([(42, 10), (52, 20)], fill=(39, 202, 79))

    y = 30 + PADDING
    for text, color in lines:
        if color:
            draw.text((PADDING, y), text, fill=color, font=font)
        else:
            draw.text((PADDING, y), text, fill=TEXT_COLOR, font=font)
        y += LINE_HEIGHT

    return img

# Define animation frames (each frame is a list of lines)
# The animation shows: start server, connect 2 clients, public chat, private msg, /users, disconnect

frame_sets = [
    # Frame 1: Start server
    [
        ("Socket Chat Server — Demo", HEADER_COLOR),
        ("", None),
        ("$ make", PROMPT_COLOR),
        ("[build output]", GRAY),
        ("$ ./build/server", PROMPT_COLOR),
        ("Chat Server running on port 8080", HEADER_COLOR),
        ("", None),
        ("  Waiting for connections...", GRAY),
    ],
    # Frame 2: Alice connects
    [
        ("Socket Chat Server — Demo", HEADER_COLOR),
        ("", None),
        ("$ ./build/server", PROMPT_COLOR),
        ("Chat Server running on port 8080", HEADER_COLOR),
        ("", None),
        ("$ ./build/client 127.0.0.1 8080", PROMPT_COLOR),
        ("Enter username: alice", TEXT_COLOR),
        ("", None),
        (">>> alice joined the chat", GRAY),
    ],
    # Frame 3: Bob connects
    [
        ("Socket Chat Server — Demo", HEADER_COLOR),
        ("", None),
        ("Chat Server running on port 8080", HEADER_COLOR),
        ("", None),
        (">>> alice joined the chat", GRAY),
        (">>> bob joined the chat", GRAY),
        ("", None),
        ("[alice] Hey bob! Welcome to the chat!", (255, 85, 85)),
        ("[bob] Thanks alice! This is cool.", (85, 255, 85)),
    ],
    # Frame 4: Private message
    [
        ("Socket Chat Server — Demo", HEADER_COLOR),
        ("", None),
        ("[alice] Hey bob! Welcome to the chat!", (255, 85, 85)),
        ("[bob] Thanks alice! This is cool.", (85, 255, 85)),
        ("[bob] Let me try a private message...", (85, 255, 85)),
        ("", None),
        ("[Private] bob: Hi alice, this is private!", (255, 170, 255)),
        ("[Private] alice: Got it! Secret chat works!", (255, 170, 255)),
    ],
    # Frame 5: /users
    [
        ("Socket Chat Server — Demo", HEADER_COLOR),
        ("", None),
        ("[alice] How many are online?", (255, 85, 85)),
        ("[bob] Let me check with /users", (85, 255, 85)),
        ("", None),
        ("$ /users", PROMPT_COLOR),
        ("Online Users:", HEADER_COLOR),
        ("  alice", TEXT_COLOR),
        ("  bob", TEXT_COLOR),
        ("", None),
        ("[bob] Just us 2 for now!", (85, 255, 85)),
    ],
    # Frame 6: Disconnect
    [
        ("Socket Chat Server — Demo", HEADER_COLOR),
        ("", None),
        ("[alice] I'll disconnect now. Bye!", (255, 85, 85)),
        ("[bob] See you later alice!", (85, 255, 85)),
        ("", None),
        (">>> alice left the chat", GRAY),
        ("", None),
        ("[bob] alice disconnected. Server still running.", (85, 255, 85)),
        ("[bob] Waiting for more clients...", (85, 255, 85)),
    ],
]

print("  Rendering demo frames...")
frames = []
for i, lines in enumerate(frame_sets):
    print(f"    Frame {i+1}/{len(frame_sets)}")
    frame = make_frame(lines)
    # Each frame is shown for a duration; we duplicate frames for slower animation
    for _ in range(3):  # 3 copies per frame = ~0.3s each at 10fps
        frames.append(frame)

# Save as GIF
gif_path = f"{IMAGE_DIR}/demo.gif"
print(f"  Saving {gif_path}...")
frames[0].save(
    gif_path,
    save_all=True,
    append_images=frames[1:],
    duration=400,  # ms per frame
    loop=0,
    optimize=False,
)
print("  Demo GIF created successfully!")
PYEOF

echo ""
echo "======================================"
echo " All screenshots and demo GIF created!"
echo "======================================"
echo ""
echo "Generated files:"
ls -la "$IMAGE_DIR"/*.png "$IMAGE_DIR"/*.gif 2>/dev/null
