FROM codercom/code-server:4.128.0

USER root

# curl is required by the compose healthcheck in Task 3 — do not drop it.
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-pip python3-venv git ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

USER coder

# Extensions come from Open VSX — code-server cannot use the MS Marketplace.
RUN code-server --install-extension ms-python.python@2026.4.0 \
 && code-server --install-extension charliermarsh.ruff@2026.60.0 \
 && code-server --install-extension vsls-contrib.gitdoc@0.2.3

COPY --chown=coder:coder settings.json /home/coder/.local/share/code-server/User/settings.json

RUN mkdir -p /home/coder/robot
WORKDIR /home/coder/robot
