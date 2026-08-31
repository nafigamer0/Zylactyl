#!/bin/bash
set -e

chmod +x Zylactyl-Panel
chmod +x Zylactyl-Node

INSTALL_DIR="$(pwd)"
BINARY="$INSTALL_DIR/Zylactyl-Panel"
PID_FILE="$INSTALL_DIR/.panel.pid"

# Install Docker
if ! command -v docker &>/dev/null; then
    echo "Installing Docker..."
    apt-get update -qq
    apt-get install -y -qq docker.io > /dev/null 2>&1
    systemctl enable --now docker 2>/dev/null || service docker start
    echo "Docker installed"
else
    echo "Docker already installed"
fi

# Ensure dirs
mkdir -p "$INSTALL_DIR"/{servers,backups,uploads,public,eggs}

# Generate secret
if [ ! -f "$INSTALL_DIR/.session_secret" ]; then
    openssl rand -hex 32 > "$INSTALL_DIR/.session_secret"
fi

# Create zylactyl-panel command
cat > /usr/local/bin/zylactyl-panel << CMDEOF
#!/bin/bash
INSTALL_DIR="$INSTALL_DIR"
BINARY="$BINARY"
PID_FILE="$PID_FILE"

case "\$1" in
    up)
        if [ -f "\$PID_FILE" ] && kill -0 \$(cat "\$PID_FILE") 2>/dev/null; then
            echo "Panel already running (PID \$(cat \$PID_FILE))"
            exit 0
        fi
        cd "\$INSTALL_DIR"
        nohup "\$BINARY" > /dev/null 2>&1 &
        echo \$! > "\$PID_FILE"
        echo "Panel started (PID \$!)"
        ;;

    down)
        if [ -f "\$PID_FILE" ]; then
            kill \$(cat "\$PID_FILE") 2>/dev/null
            rm -f "\$PID_FILE"
            echo "Panel stopped"
        else
            echo "Panel not running"
        fi
        ;;

    restart)
        \$0 down
        sleep 1
        \$0 up
        ;;

    status)
        if [ -f "\$PID_FILE" ] && kill -0 \$(cat "\$PID_FILE") 2>/dev/null; then
            echo "Panel running (PID \$(cat \$PID_FILE))"
        else
            echo "Panel not running"
            rm -f "\$PID_FILE" 2>/dev/null
        fi
        ;;

    log|logs)
        tail -f /dev/null &
        kill \$! 2>/dev/null
        journalctl -u zylactactyl-panel -f 2>/dev/null || echo "Logs: nohup output goes to /dev/null"
        ;;

    *)
        echo "Usage: zylactyl-panel {up|down|restart|status|logs}"
        exit 1
        ;;
esac
CMDEOF

chmod +x /usr/local/bin/zylactyl-panel

echo ""
echo "Done! Commands:"
echo "  zylactyl-panel up        Start panel in background"
echo "  zylactyl-panel down      Stop panel"
echo "  zylactyl-panel restart   Restart panel"
echo "  zylactyl-panel status    Check if running"
echo "  zylactyl-panel logs      View logs"
