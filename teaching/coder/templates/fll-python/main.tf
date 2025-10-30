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

provider "docker" {
  host = var.docker_host
}

provider "coder" {}

data "coder_workspace" "me" {}

# FLL Python workspace for kids
resource "coder_agent" "main" {
  os             = "linux"
  arch           = "amd64"
  startup_script = <<-EOT
    #!/bin/bash
    set -e

    # Wait for container to be ready
    sleep 2

    # Start code-server (already installed in image)
    code-server --auth none --port 13337 --user-data-dir /home/coder/.local/share/code-server >/tmp/code-server.log 2>&1 &

    echo "🚀 Code-server starting on port 13337..."
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
    # Download and run Coder agent
    ${coder_agent.main.init_script} &
    # Keep container alive
    exec sleep infinity
    EOT
  ]

  # Environment variables
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
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
