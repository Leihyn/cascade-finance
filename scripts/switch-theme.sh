#!/bin/bash

# Bank of Mantle Theme Switcher Script
# Usage: ./scripts/switch-theme.sh <theme-name>
# Available themes: classic, cyberpunk, terminal, nordic, maximalist, neumorphic

THEME=$1
FRONTEND_DIR="frontend"
GLOBALS_CSS="$FRONTEND_DIR/app/globals.css"
THEMES_DIR="$FRONTEND_DIR/styles/themes"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

if [ -z "$THEME" ]; then
  echo -e "${RED}Error: No theme specified${NC}"
  echo ""
  echo "Usage: ./scripts/switch-theme.sh <theme-name>"
  echo ""
  echo "Available themes:"
  echo "  classic      - Classic Banking (navy & gold)"
  echo "  cyberpunk    - DeFi Cyberpunk (neon future)"
  echo "  terminal     - Terminal Hacker (Matrix green)"
  echo "  nordic       - Minimalist Nordic (Scandinavian clean)"
  echo "  maximalist   - Gradient Maximalist (bold & colorful)"
  echo "  neumorphic   - Dark Neumorphic (soft & tactile)"
  exit 1
fi

# Map theme names to files
case $THEME in
  classic)
    THEME_FILE="classic-banking.css"
    THEME_NAME="Classic Banking"
    ;;
  cyberpunk)
    THEME_FILE="defi-cyberpunk.css"
    THEME_NAME="DeFi Cyberpunk"
    ;;
  terminal)
    THEME_FILE="terminal-hacker.css"
    THEME_NAME="Terminal Hacker"
    ;;
  nordic)
    THEME_FILE="minimalist-nordic.css"
    THEME_NAME="Minimalist Nordic"
    ;;
  maximalist)
    THEME_FILE="gradient-maximalist.css"
    THEME_NAME="Gradient Maximalist"
    ;;
  neumorphic)
    THEME_FILE="dark-neumorphic.css"
    THEME_NAME="Dark Neumorphic"
    ;;
  *)
    echo -e "${RED}Error: Unknown theme '$THEME'${NC}"
    echo "Available themes: classic, cyberpunk, terminal, nordic, maximalist, neumorphic"
    exit 1
    ;;
esac

# Check if theme file exists
if [ ! -f "$THEMES_DIR/$THEME_FILE" ]; then
  echo -e "${RED}Error: Theme file not found: $THEMES_DIR/$THEME_FILE${NC}"
  exit 1
fi

# Backup current globals.css
echo -e "${YELLOW}Creating backup...${NC}"
cp "$GLOBALS_CSS" "$GLOBALS_CSS.backup"

# Create new globals.css with Tailwind directives + theme
echo -e "${YELLOW}Applying theme: $THEME_NAME${NC}"

cat > "$GLOBALS_CSS" << 'EOF'
@import "@fontsource/inter/400.css";
@import "@fontsource/inter/500.css";
@import "@fontsource/inter/600.css";
@import "@fontsource/inter/700.css";
@import "@fontsource/space-grotesk/400.css";
@import "@fontsource/space-grotesk/500.css";
@import "@fontsource/space-grotesk/600.css";
@import "@fontsource/space-grotesk/700.css";

@tailwind base;
@tailwind components;
@tailwind utilities;

EOF

# Append theme content
cat "$THEMES_DIR/$THEME_FILE" >> "$GLOBALS_CSS"

echo -e "${GREEN}✓ Theme switched to: $THEME_NAME${NC}"
echo ""
echo "Next steps:"
echo "1. Restart dev server: cd frontend && npm run dev"
echo "2. Backup saved to: $GLOBALS_CSS.backup"
echo ""
echo -e "${YELLOW}Note: Some themes may require additional font installations.${NC}"
echo "See THEME_SWITCHER_GUIDE.md for details."
