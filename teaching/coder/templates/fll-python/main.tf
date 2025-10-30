terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
    }
    docker = {
      source  = "kreuzwerker/docker"
    }
  }
}

# Admin parameters
variable "docker_host" {
  description = "Docker host to deploy workspaces"
  default     = "unix:///var/run/docker.sock"
  sensitive   = true
}

variable "github_token" {
  description = "GitHub Personal Access Token for cloning repositories"
  sensitive   = true
}

provider "docker" {
  host = var.docker_host
}

provider "coder" {}

data "coder_workspace" "me" {}

# FLL Python workspace for kids
resource "coder_agent" "main" {
  os             = "linux"
  arch           = "amd64"
  auth           = "token"
  startup_script = <<-EOT
    #!/bin/bash
    set -e

    # Wait for container to be ready
    sleep 2

    # Setup git credentials with token
    if [ -n "$GITHUB_TOKEN" ]; then
      echo "https://$GITHUB_TOKEN@github.com" > /home/coder/.git-credentials
      chmod 600 /home/coder/.git-credentials
    fi

    # Clone or update the robotics repository
    if [ ! -d "/home/coder/robotics/.git" ]; then
      echo "📥 Cloning robotics repository..."
      git clone https://github.com/asingh-io/robotics.git /home/coder/robotics

      # Install dependencies after cloning
      if [ -f /home/coder/robotics/requirements.txt ]; then
        echo "📦 Installing Python dependencies..."
        pip install --no-cache-dir -r /home/coder/robotics/requirements.txt
      fi
    else
      echo "📥 Pulling latest code from GitHub..."
      cd /home/coder/robotics
      git pull origin main || echo "Could not pull latest changes (will use existing code)"
    fi

    # Start code-server with robotics folder opened
    code-server --auth none --port 13337 --user-data-dir /home/coder/.local/share/code-server /home/coder/robotics >/tmp/code-server.log 2>&1 &

    echo "🚀 Code-server starting on port 13337..."
    echo "📁 Opening robotics folder..."
    echo "📝 Logs: tail -f /tmp/code-server.log"
  EOT

  # VS Code in browser
  display_apps {
    vscode = true
    vscode_insiders = false
    web_terminal = true
    port_forwarding_helper = true
    ssh_helper = false
  }
}

# App for code-server
resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code"
  url          = "http://localhost:13337"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}

resource "docker_image" "workspace" {
  name = "fll-python:latest"
  keep_locally = true
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = docker_image.workspace.name
  name = "coder-${lower(data.coder_workspace.me.name)}-${substr(data.coder_workspace.me.id, 0, 8)}"

  # CPU and Memory limits
  cpu_shares = 2048  # 2 cores equivalent
  memory     = 2048  # 2GB RAM

  # Run the Coder agent init script
  command = [
    "sh", "-c",
    <<-EOT
    set -e
    # Replace HTTPS URLs with HTTP URLs in the init script
    cat > /tmp/agent-init.sh << 'AGENT_SCRIPT'
${coder_agent.main.init_script}
AGENT_SCRIPT
    # Replace external HTTPS URL with internal HTTP URL
    sed -i 's|https://coder.lab.nexuswarrior.site|http://coder:3000|g' /tmp/agent-init.sh
    # Run the modified agent init script
    sh /tmp/agent-init.sh > /tmp/coder-agent.log 2>&1 &
    # Wait a moment for agent to start
    sleep 2
    # Keep container alive
    exec sleep infinity
    EOT
  ]

  # Environment variables
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "CODER_AGENT_URL=http://coder:3000",
    "GITHUB_TOKEN=${var.github_token}",
  ]

  # Workspace storage
  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.workspace.name
  }

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  networks_advanced {
    name = "proxy"
  }
}

resource "docker_volume" "workspace" {
  name = "coder-${lower(data.coder_workspace.me.name)}-${substr(data.coder_workspace.me.id, 0,8)}"
}

resource "coder_metadata" "container_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = docker_container.workspace[0].id

  item {
    key   = "CPU"
    value = "2 cores"
  }

  item {
    key   = "RAM"
    value = "2 GB"
  }

  item {
    key   = "Disk"
    value = "10 GB"
  }
}
