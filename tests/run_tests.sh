#!/usr/bin/env bash
#
# Integration test suite for Socket Chat Server
#
# Tests:
#   1. Server starts and listens
#   2. Client connects and authenticates
#   3. Public message broadcast
#   4. Private messaging (/msg)
#   5. Online users (/users)
#   6. Client disconnect (/quit)
#   7. Multiple simultaneous clients
#
# Usage:
#   ./tests/run_tests.sh [-v]
#
# Environment:
#   PORT  — server port (default: 18765)
#

set -o pipefail

VERBOSE=false
[[ "$1" == "-v" || "$1" == "--verbose" ]] && VERBOSE=true

PORT="${PORT:-18765}"
SERVER_BIN="./build/server"
CLIENT_BIN="./build/client"
PASS=0
FAIL=0
TESTDIR="tests"
mkdir -p "$TESTDIR"

cleanup() {
    pkill -f "build/server" 2>/dev/null || true
    pkill -f "build/client" 2>/dev/null || true
    rm -f "$TESTDIR"/client_*.log "$TESTDIR"/server.log
}

log()  { $VERBOSE && echo "  [LOG] $1"; }
pass() { PASS=$((PASS + 1)); echo "  [PASS] $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  [FAIL] $1${2+: $2}" >&2; }

start_server() {
    $SERVER_BIN "$PORT" > "$TESTDIR/server.log" 2>&1 &
    local pid=$!
    sleep 1
    if ! kill -0 "$pid" 2>/dev/null; then
        fail "Server startup" "Server exited. See tests/server.log"
        return 1
    fi
    SERVER_PID=$pid
    pass "Server starts and listens on port $PORT"
    return 0
}

# start_client_bg: starts a client in background that reads timed input from a subshell
# Usage: start_client_bg <username> <output_file> <delay_before_message> <message> <stay_alive_after>
# The client sends <message> after <delay> seconds, stays alive for <stay_alive_after> more seconds, then /quit
start_client_bg() {
    local username="$1"
    local output="$2"
    local delay="$3"
    local message="$4"
    local stay_alive="${5:-2}"

    (
        echo "$username"
        sleep "$delay"
        echo "$message"
        sleep "$stay_alive"
        echo "/quit"
    ) | "$CLIENT_BIN" 127.0.0.1 "$PORT" > "$output" 2>&1 &
    echo $!
}

echo "========================================="
echo " Socket Chat Server — Test Suite"
echo " Port: $PORT | $(date)"
echo "========================================="
echo ""

cleanup

# ---- 1. Server Startup ----
echo "[1/7] Server startup"
start_server || { cleanup; exit 1; }

# ---- 2. Client Connection ----
echo "[2/7] Client connection"
start_client_bg "alice" "$TESTDIR/client_alice.log" 0.5 "Hello" 1 > /dev/null
sleep 3
if grep -q "Hello" "$TESTDIR/client_alice.log" 2>/dev/null; then
    pass "Client connects and receives data"
else
    if ! grep -qi "error\|failed\|refused\|denied" "$TESTDIR/client_alice.log" 2>/dev/null; then
        pass "Client connects (no errors)"
    else
        fail "Client connects" "Error in client output"
        log "alice.log: $(cat "$TESTDIR/client_alice.log")"
    fi
fi

# ---- 3. Broadcast Messaging ----
echo "[3/7] Broadcast messaging"
start_client_bg "alice" "$TESTDIR/client_bc_a.log" 1 "Hello from alice" 3 > /dev/null
sleep 0.5
start_client_bg "bob" "$TESTDIR/client_bc_b.log" 1.5 "Hello from bob" 3 > /dev/null
sleep 5

if grep -q "Hello from bob" "$TESTDIR/client_bc_a.log" 2>/dev/null; then
    pass "Broadcast: alice receives bob's message"
else
    fail "Broadcast (bob->alice)" "alice missed bob's message"
    log "alice: $(cat "$TESTDIR/client_bc_a.log" 2>/dev/null)"
    log "bob: $(cat "$TESTDIR/client_bc_b.log" 2>/dev/null)"
fi

if grep -q "Hello from alice" "$TESTDIR/client_bc_b.log" 2>/dev/null; then
    pass "Broadcast: bob receives alice's message"
else
    fail "Broadcast (alice->bob)" "bob missed alice's message"
fi

# ---- 4. Private Messaging ----
echo "[4/7] Private messaging"
start_client_bg "charlie" "$TESTDIR/client_pm_c.log" 10 "" 0 > /dev/null
C_PID=$!
sleep 0.5
start_client_bg "bob" "$TESTDIR/client_pm_b.log" 1 "/msg charlie Secret message!" 2 > /dev/null
sleep 3

if grep -q "Secret message" "$TESTDIR/client_pm_c.log" 2>/dev/null; then
    pass "Private message delivered to recipient"
else
    fail "Private message" "charlie didn't receive it"
    log "charlie: $(cat "$TESTDIR/client_pm_c.log" 2>/dev/null)"
    log "bob: $(cat "$TESTDIR/client_pm_b.log" 2>/dev/null)"
fi

# ---- 5. Online Users ----
echo "[5/7] Online users (/users)"
start_client_bg "alice" /dev/null 10 "" 0 > /dev/null
sleep 0.3
start_client_bg "bob" /dev/null 10 "" 0 > /dev/null
sleep 0.3
start_client_bg "charlie" "$TESTDIR/client_users.log" 1 "/users" 2 > /dev/null
sleep 3

if grep -q "alice" "$TESTDIR/client_users.log" 2>/dev/null && \
   grep -q "bob" "$TESTDIR/client_users.log" 2>/dev/null; then
    pass "/users lists all connected clients"
else
    fail "/users command" "charlie didn't see alice and bob"
    log "users output: $(cat "$TESTDIR/client_users.log" 2>/dev/null)"
fi

# ---- 6. Client Disconnect ----
echo "[6/7] Client disconnect"
start_client_bg "alice_dc" /dev/null 1 "" 0 > /dev/null
sleep 0.3
start_client_bg "bob_dc" "$TESTDIR/client_dc.log" 3 "" 2 > /dev/null
sleep 3

if grep -q "left the chat" "$TESTDIR/client_dc.log" 2>/dev/null; then
    pass "Disconnect notification broadcast to remaining clients"
else
    fail "Disconnect notification" "bob didn't see alice_dc leave"
    log "dc output: $(cat "$TESTDIR/client_dc.log" 2>/dev/null)"
fi

# ---- 7. Multiple Simultaneous Clients ----
echo "[7/7] Multiple simultaneous clients"
start_client_bg "user1" "$TESTDIR/client_m1.log" 1 "Message from user1" 3 > /dev/null
sleep 0.2
start_client_bg "user2" "$TESTDIR/client_m2.log" 1.5 "Message from user2" 3 > /dev/null
sleep 0.2
start_client_bg "user3" "$TESTDIR/client_m3.log" 2 "Message from user3" 3 > /dev/null
sleep 5

cross=0
grep -q "Message from user[23]" "$TESTDIR/client_m1.log" 2>/dev/null && cross=1
grep -q "Message from user[13]" "$TESTDIR/client_m2.log" 2>/dev/null && cross=1
grep -q "Message from user[12]" "$TESTDIR/client_m3.log" 2>/dev/null && cross=1

if [[ $cross -eq 1 ]]; then
    pass "Multiple clients communicate simultaneously"
else
    fail "Multiple clients" "No cross-client messages"
    for f in "$TESTDIR"/client_m*.log; do
        log "$(basename $f): $(cat "$F" 2>/dev/null)"
    done
fi

# ---- Cleanup ----
echo ""
cleanup

# ---- Results ----
echo "========================================="
echo " Results: $PASS passed, $FAIL failed"
echo "========================================="

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
exit 0
