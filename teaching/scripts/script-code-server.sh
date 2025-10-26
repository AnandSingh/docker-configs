se directory
BASE_DIR="/home/docker/code-server"

# Array of user names
USERS=("anshi" "alice" "emma" "abby" "elly" "meghana" "nitya" "paige" "jessica" "anand")

# Create base directory if it doesn't exist
mkdir -p "$BASE_DIR"

# Create common SSH and keybindings paths
mkdir -p "/home/docker/.ssh"
touch "$BASE_DIR/keybindings.json"

# Loop through each user to set up directories
for user in "${USERS[@]}"; do
    USER_DIR="$BASE_DIR/$user"
    
    # Create the required user-specific directory structure
    echo "Creating directory for $user at $USER_DIR..."
    mkdir -p "$USER_DIR/workspace"
done

echo "All directories created successfully."

# Create the docker-compose.yml
cat > docker-compose.yml <<EOF
version: "3.8"
services:
EOF

PORT=8444

for user in "${USERS[@]}"; do
cat >> docker-compose.yml <<SERVICE
  ${user}-code-server:
    image: lscr.io/linuxserver/code-server:latest
    container_name: ${user}-code-server
    privileged: true
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Los_Angeles
      - PROXY_DOMAIN=${user}.tinkeringturtle.site
      - DEFAULT_WORKSPACE=/config/workspace/
      - DOCKER_MODS=linuxserver/mods:code-server-python3|linuxserver/mods:code-server-zsh|linuxserver/mods:code-server-docker|linuxserver/mods:code-server-extension-arguments
      - VSCODE_EXTENSION_IDS=vscode-icons-team.vscode-icons|ms-python.black-formatter|ms-python.python|GitHub.vscode-pull-request-github|shyykoserhiy.git-autoconfig|usernamehw.errorlens|tomoki1207.pdf
      - GIT_SSH_COMMAND=ssh -i /config/.ssh/id_rsa -o StrictHostKeyChecking=no
    volumes:
      - $BASE_DIR/$user:/config
      - /home/dev/.ssh:/config/.ssh:ro
      - $BASE_DIR/keybindings.json:/config/User/data/keybindings.json:ro
      - /var/run/dbus:/var/run/dbus
    ports:
      - $PORT:8443
    restart: unless-stopped

SERVICE
    PORT=$((PORT + 1))
done

echo "docker-compose.yml generated successfully."

