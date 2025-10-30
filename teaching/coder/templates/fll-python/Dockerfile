FROM ubuntu:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Los_Angeles

# Install system dependencies (including sudo first)
RUN apt-get update && apt-get install -y \
    sudo \
    curl \
    wget \
    git \
    build-essential \
    python3.11 \
    python3.11-dev \
    python3-pip \
    python3-venv \
    vim \
    nano \
    htop \
    net-tools \
    iputils-ping \
    ca-certificates \
    zsh \
    docker.io \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Create coder user and add to sudoers (after sudo is installed)
RUN useradd -m -s /bin/bash coder && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/coder && \
    chmod 0440 /etc/sudoers.d/coder

# Set Python 3.11 as default
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

# Install pip packages for FLL/Robotics
RUN python3 -m pip install --no-cache-dir --upgrade pip && \
    python3 -m pip install --no-cache-dir \
    # Python essentials
    ipython \
    jupyter \
    notebook \
    # Data science & visualization
    numpy \
    pandas \
    matplotlib \
    scipy \
    # Robotics libraries
    robotframework \
    robotframework-seriallibrary \
    robotframework-pythonlibcore \
    # Web scraping (for research)
    requests \
    beautifulsoup4 \
    # Hardware interfaces
    pyserial \
    # Development tools
    black \
    flake8 \
    pytest \
    # Version control
    pre-commit

# Install Node.js (for some tools kids might use)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install code-server (VS Code in browser)
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/usr/local

# Switch to coder user
USER coder
WORKDIR /home/coder

# Setup zsh with Oh My Zsh (kids are used to zsh from code-server)
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install VS Code extensions to match code-server setup
RUN code-server --install-extension vscode-icons-team.vscode-icons && \
    code-server --install-extension ms-python.black-formatter && \
    code-server --install-extension ms-python.python && \
    code-server --install-extension GitHub.vscode-pull-request-github && \
    code-server --install-extension shyykoserhiy.git-autoconfig && \
    code-server --install-extension usernamehw.errorlens && \
    code-server --install-extension tomoki1207.pdf && \
    code-server --install-extension AnandSingh.pybricks-runner

# Configure VS Code settings to match kids' current setup
RUN mkdir -p /home/coder/.local/share/code-server/User && \
    echo '{ \
    "workbench.colorTheme": "Default Dark Modern", \
    "workbench.iconTheme": "vscode-icons", \
    "vsicons.dontShowNewVersionMessage": true, \
    "git.enableSmartCommit": true, \
    "git.autofetch": true, \
    "git.confirmSync": false, \
    "python.formatting.provider": "black", \
    "editor.formatOnSave": true, \
    "terminal.integrated.defaultProfile.linux": "zsh" \
}' > /home/coder/.local/share/code-server/User/settings.json

# Set zsh as default shell
RUN echo 'export SHELL=/usr/bin/zsh' >> /home/coder/.bashrc

# Create project structure
RUN mkdir -p /home/coder/projects /home/coder/workspace

# Setup directory for repo (will be cloned on first startup with credentials)
RUN mkdir -p /home/coder/robotics && \
    chown -R coder:coder /home/coder/robotics

# Configure git credential helper to use stored credentials
RUN git config --global credential.helper 'store --file /home/coder/.git-credentials'

# Configure git for the workspace
RUN git config --global user.name "Nexus Warrior" && \
    git config --global user.email "fll@lab.local" && \
    git config --global pull.rebase false && \
    git config --global init.defaultBranch main

# Create a welcome script for zsh
RUN echo '#!/usr/bin/zsh' > /home/coder/.welcome.sh && \
    echo 'echo "🤖 Welcome to FLL Python Workspace!"' >> /home/coder/.welcome.sh && \
    echo 'echo "Python: $(python --version)"' >> /home/coder/.welcome.sh && \
    echo 'echo "Robot Framework: $(robot --version | head -1)"' >> /home/coder/.welcome.sh && \
    echo 'echo ""' >> /home/coder/.welcome.sh && \
    echo 'echo "📁 Your code: ~/robotics/"' >> /home/coder/.welcome.sh && \
    echo 'echo "🔧 Work in your folder: ~/robotics/<your-name>/"' >> /home/coder/.welcome.sh && \
    echo 'echo ""' >> /home/coder/.welcome.sh && \
    echo 'echo "💡 Quick commands:"' >> /home/coder/.welcome.sh && \
    echo 'echo "   cd ~/robotics - Go to robot code"' >> /home/coder/.welcome.sh && \
    echo 'echo "   python robot.py - Run your robot code"' >> /home/coder/.welcome.sh && \
    echo 'echo "   Use VS Code tasks for git push/pull"' >> /home/coder/.welcome.sh && \
    chmod +x /home/coder/.welcome.sh

# Add welcome to zshrc
RUN echo 'bash ~/.welcome.sh' >> /home/coder/.zshrc

# Coder agent will override CMD, so this is just a fallback
CMD ["/bin/bash", "-c", "sleep infinity"]
