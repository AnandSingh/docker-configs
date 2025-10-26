# FLL Python Template

Coder template for FLL kids with Python 3.11, Robot Framework, and VS Code.

## What's Included

- Python 3.11
- Robot Framework
- VS Code (code-server)
- All VS Code extensions kids are familiar with
- Zsh terminal with Oh My Zsh
- Git configuration
- Jupyter notebooks
- Scientific libraries (numpy, pandas, matplotlib)

## Template Files

- `main.tf` - Terraform configuration for Coder
- `Dockerfile` - Custom Docker image with all tools
- `pybricks-runner-0.1.5.vsix` - Pybricks extension for LEGO robotics

## Usage

This template creates a workspace with:
- 2 CPU cores
- 2GB RAM
- 10GB disk storage
- Code-server running on port 13337

## Building the Image

Before using this template, build the Docker image:

```bash
cd /home/dev/docker-configs/teaching/coder/templates/fll-python
docker build -t fll-python:latest .
```

## Deploying to Coder

See the main WORKSPACE-SETUP-GUIDE.md for detailed instructions.
