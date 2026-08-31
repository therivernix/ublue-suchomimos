#!/bin/bash

# Path to framework_tool
FRAMEWORK_TOOL="/home/linuxbrew/.linuxbrew/bin/framework_tool"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${CYAN}${BOLD}🌬️  Fan & Thermal Control Tool${NC}"
echo "----------------------------------------"

# Always show thermal status at start
echo -e "${CYAN}🌡️ Current Thermal Status (startup)${NC}"
echo "----------------------------------------"
sudo "$FRAMEWORK_TOOL" --thermal
echo ""

mode=""

PS3=$'\n👉 Choose fan/thermal setting: '

select option in \
    "Fan 30%" \
    "Fan 40%" \
    "Fan 50%" \
    "Fan 100%" \
    "Auto Fan Control" \
    "Thermal Status"; do

    case "$REPLY" in
        1)
            mode="Fan 30%"
            sudo "$FRAMEWORK_TOOL" --fansetduty 30
            echo -e "${GREEN}✔ Set fan duty to 30%${NC}"
            break
            ;;
        2)
            mode="Fan 40%"
            sudo "$FRAMEWORK_TOOL" --fansetduty 40
            echo -e "${GREEN}✔ Set fan duty to 40%${NC}"
            break
            ;;
        3)
            mode="Fan 50%"
            sudo "$FRAMEWORK_TOOL" --fansetduty 50
            echo -e "${GREEN}✔ Set fan duty to 50%${NC}"
            break
            ;;
        4)
            mode="Fan 100%"
            sudo "$FRAMEWORK_TOOL" --fansetduty 100
            echo -e "${GREEN}✔ Set fan duty to 100%${NC}"
            break
            ;;
        5)
            mode="Auto Fan Control"
            sudo "$FRAMEWORK_TOOL" --autofanctrl
            echo -e "${GREEN}✔ Enabled automatic fan control${NC}"
            break
            ;;
        6)
            mode="Thermal Status"
            echo -e "${CYAN}🌡️ Current Thermal Status:${NC}"
            sudo "$FRAMEWORK_TOOL" --thermal
            ;;
        *)
            echo -e "${RED}❌ Invalid choice, try again.${NC}"
            ;;
    esac
done

# Always show thermal status after fan changes (but not duplicated for option 6)
if [[ "$mode" != "Thermal Status" ]]; then
    echo ""
    echo -e "${CYAN}🌡️ Thermal Status (after changes)${NC}"
    echo "----------------------------------------"
    sudo "$FRAMEWORK_TOOL" --thermal
fi

echo ""
echo -e "${CYAN}${BOLD}📋 Final Selection Summary${NC}"
echo "----------------------------------------"
echo -e "Mode selected : ${BOLD}${mode}${NC}"
echo "----------------------------------------"
echo -e "${GREEN}✅ Operation completed successfully${NC}"

echo ""
read -rp "Press Enter to exit..."
