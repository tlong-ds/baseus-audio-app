#!/usr/bin/env bash

# Baseus H1S CLI Controller
# Usage: ./baseus_h1s.sh [mode]
# Examples: 
#   ./baseus_h1s.sh anc indoor
#   ./baseus_h1s.sh transparency
#   ./baseus_h1s.sh off

COMMAND=$1
SUBCOMMAND=$2

# The write characteristic UUID for Baseus H1S
CHARACTERISTIC="EE684B1A"
# Use the control script we already built
CONTROL_SCRIPT="./h1s_control.sh"

case "$COMMAND" in
    off)
        echo "Turning ANC Off..."
        $CONTROL_SCRIPT BA3400FF
        ;;
    transparency)
        echo "Enabling Transparency Mode..."
        $CONTROL_SCRIPT BA3402FF
        ;;
    anc)
        case "$SUBCOMMAND" in
            commuting)
                echo "Enabling ANC (Commuting)..."
                $CONTROL_SCRIPT BA340165
                ;;
            indoor)
                echo "Enabling ANC (Indoor)..."
                $CONTROL_SCRIPT BA340166
                ;;
            outdoor)
                echo "Enabling ANC (Outdoor)..."
                $CONTROL_SCRIPT BA340167
                ;;
            *)
                # Default to Indoor if no submode is specified
                echo "Enabling ANC (Indoor)..."
                $CONTROL_SCRIPT BA340166
                ;;
        esac
        ;;
    spatial)
        echo "Enabling Spatial Audio..."
        $CONTROL_SCRIPT BA4301
        ;;
    balanced)
        echo "Enabling Balanced Audio..."
        $CONTROL_SCRIPT BA4300
        ;;
    *)
        echo "Usage: $0 {off|transparency|anc [commuting|indoor|outdoor]|spatial|balanced}"
        exit 1
        ;;
esac
