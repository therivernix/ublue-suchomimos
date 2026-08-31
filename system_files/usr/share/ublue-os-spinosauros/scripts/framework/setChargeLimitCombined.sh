#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${CYAN}${BOLD}🔋 Battery Configuration Tool${NC}"
echo "----------------------------------------"

# Charge limit selection
echo -e "${YELLOW}Select charge limit:${NC}"
echo -e "  ${BLUE}1)${NC} 80%"
echo -e "  ${BLUE}2)${NC} 100%"

read -rp "👉 Enter choice (1 or 2): " choice

charge_limit=""

case "$choice" in
    1)
        charge_limit=80
        sudo -E env "PATH=$PATH" framework_tool --charge-limit 80
        echo -e "${GREEN}✔ Charge limit set to 80%${NC}"
        ;;
    2)
        charge_limit=100
        sudo -E env "PATH=$PATH" framework_tool --charge-limit 100
        echo -e "${GREEN}✔ Charge limit set to 100%${NC}"
        ;;
    *)
        echo -e "${RED}❌ Invalid choice. Exiting.${NC}"
        read -rp "Press Enter to close..."
        exit 1
        ;;
esac

echo ""

# Charge rate limit selection
echo -e "${YELLOW}Choose charge rate limit:${NC}"

select option in "0.5" "1.0"; do
    case "$REPLY" in
        1)
            charge_rate="0.5"
            sudo -E env "PATH=$PATH" framework_tool --charge-rate-limit 0.5
            echo -e "${GREEN}✔ Charge rate limit set to 0.5${NC}"
            break
            ;;
        2)
            charge_rate="1.0"
            sudo -E env "PATH=$PATH" framework_tool --charge-rate-limit 1.0
            echo -e "${GREEN}✔ Charge rate limit set to 1.0${NC}"
            break
            ;;
        *)
            echo -e "${RED}❌ Invalid choice, try again.${NC}"
            ;;
    esac
done

echo ""
echo -e "${CYAN}${BOLD}📋 Final Configuration Summary${NC}"
echo "----------------------------------------"
echo -e "🔋 Charge limit      : ${BOLD}${charge_limit}%${NC}"
echo -e "⚡ Charge rate limit : ${BOLD}${charge_rate}${NC}"
echo "----------------------------------------"
echo -e "${GREEN}✅ Settings successfully applied!${NC}"

# Keep window open
echo ""
read -rp "Press Enter to exit..."
