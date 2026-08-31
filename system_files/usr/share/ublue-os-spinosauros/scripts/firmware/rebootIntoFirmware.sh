#!/usr/bin/env bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================${NC}"
echo -e "${YELLOW}Reboot into UEFI Setup${NC}"
echo -e "${BLUE}=====================================${NC}"
echo

read -rp "$(echo -e ${YELLOW}Continue? [y/N]: ${NC}) " choice

case "$choice" in
  y|Y|yes|YES)
    echo -e "${GREEN}Rebooting into UEFI setup...${NC}"
    systemctl reboot --firmware-setup
    ;;
  *)
    echo -e "${RED}Cancelled.${NC}"
    exit 0
    ;;
esac
