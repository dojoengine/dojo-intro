#!/bin/bash

# Script to run Dojo development environment
# Starts Katana, builds/migrates contracts, and starts Torii
# All services shut down on script exit

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Store PIDs for cleanup
KATANA_PID=""
TORII_PID=""

# Cleanup function to kill all services
cleanup() {
    echo -e "\n${YELLOW}Shutting down services...${NC}"

    if [ ! -z "$TORII_PID" ] && kill -0 $TORII_PID 2>/dev/null; then
        echo -e "${BLUE}Stopping Torii (PID: $TORII_PID)...${NC}"
        kill $TORII_PID 2>/dev/null || true
        wait $TORII_PID 2>/dev/null || true
    fi

    if [ ! -z "$KATANA_PID" ] && kill -0 $KATANA_PID 2>/dev/null; then
        echo -e "${BLUE}Stopping Katana (PID: $KATANA_PID)...${NC}"
        kill $KATANA_PID 2>/dev/null || true
        wait $KATANA_PID 2>/dev/null || true
    fi

    echo -e "${GREEN}All services stopped${NC}"
    exit 0
}

# Set up trap to call cleanup on script exit
trap cleanup SIGINT SIGTERM EXIT

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${GREEN}=== Dojo Development Environment ===${NC}"
echo -e "${BLUE}Contracts dir: $SCRIPT_DIR${NC}\n"

# Install tools via asdf if available
if command -v asdf &> /dev/null; then
    echo -e "${YELLOW}Installing tools via asdf...${NC}"
    asdf install
    echo -e "${GREEN}✓ asdf install complete${NC}\n"
else
    ASDF_INSTALL_LINK="https://asdf-vm.com/guide/getting-started.html"
    echo -e "${YELLOW}Note: asdf not found. Installation instructions here: $ASDF_INSTALL_LINK${NC}\n"
fi

# Navigate to contracts directory
cd "$SCRIPT_DIR"

# Step 1: Start Katana using the katana.toml config file
echo -e "\n${YELLOW}Step 1: Starting Katana with the katana.toml config file...${NC}"
katana --config katana.toml > /tmp/katana.log 2>&1 &
KATANA_PID=$!
echo -e "${GREEN}Katana started (PID: $KATANA_PID)${NC}"

# Wait for Katana to be ready
echo -e "${YELLOW}Waiting for Katana to be ready...${NC}"
for i in {1..30}; do
    if curl -s http://localhost:5050 > /dev/null 2>&1; then
        echo -e "${GREEN}Katana is ready!${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}Error: Katana failed to start${NC}"
        cat /tmp/katana.log
        exit 1
    fi
    sleep 1
done

# Step 2: Build contracts
echo -e "\n${YELLOW}Step 2: Building contracts...${NC}"
sozo build

# Step 3: Migrate contracts
echo -e "\n${YELLOW}Step 3: Migrating world...${NC}"
sozo migrate --profile dev

# Get the world address from the manifest
WORLD_ADDRESS=$(grep -o '"address": "0x[^"]*"' "$SCRIPT_DIR/manifest_dev.json" | head -1 | cut -d'"' -f4)
echo -e "${GREEN}World deployed at: $WORLD_ADDRESS${NC}"

# Step 4: Start Torii with command-line arguments
echo -e "\n${YELLOW}Step 4: Starting Torii with command-line arguments...${NC}"
torii --world "$WORLD_ADDRESS" --rpc http://localhost:5050 --http.cors_origins "*" > /tmp/torii.log 2>&1 &
TORII_PID=$!
echo -e "${GREEN}Torii started (PID: $TORII_PID)${NC}"

# Wait a moment for Torii to start
sleep 2

# Print status
echo -e "\n${GREEN}=== Environment Ready ===${NC}"
echo -e "${BLUE}Services running:${NC}"
echo -e "  Katana RPC:     http://localhost:5050"
echo -e "  Torii:          http://localhost:8080"
echo -e "  Katana Explorer: http://localhost:5050/explorer"
echo -e "\n${BLUE}World Address:${NC}"
echo -e "  $WORLD_ADDRESS"
echo -e "\n${BLUE}Logs:${NC}"
echo -e "  Katana: /tmp/katana.log"
echo -e "  Torii:  /tmp/torii.log"
echo -e "\n${YELLOW}Press Ctrl+C to stop all services${NC}\n"

# Keep script running and monitor services
while true; do
    # Check if Katana is still running
    if ! kill -0 $KATANA_PID 2>/dev/null; then
        echo -e "${RED}Error: Katana process died${NC}"
        exit 1
    fi

    # Check if Torii is still running
    if ! kill -0 $TORII_PID 2>/dev/null; then
        echo -e "${RED}Error: Torii process died${NC}"
        exit 1
    fi

    sleep 5
done
