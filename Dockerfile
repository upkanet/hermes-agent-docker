FROM nousresearch/hermes-agent:latest

USER root

# Install system dependencies: jq, curl, chromium for browser tools
# Install python3-pip + ensurepip to be able to install packages in the venv
RUN apt-get update && apt-get install -y --no-install-recommends \
    jq \
    curl \
    chromium \
    chromium-driver \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

#Check PIP
RUN /opt/hermes/.venv/bin/python -m ensurepip --upgrade

# Install faster-whisper into the venv using system pip with --target fallback
RUN /opt/hermes/.venv/bin/python -m pip install --no-cache-dir faster-whisper \
    || python3 -m pip install --no-cache-dir faster-whisper --target=/opt/hermes/.venv/lib/python3.13/site-packages/ \
    && rm -rf /root/.cache/pip

# Ensure hermes binary (installed in user local bin) is in PATH
ENV PATH="/usr/local/bin:/root/.local/bin:/home/ben/.local/bin:${PATH}"

# Add custom provider profiles (project-specific)
COPY plugins/model-providers/mistral /opt/hermes/plugins/model-providers/mistral/

# ── CodeGraph MCP (code intelligence) ──────────────────────────
RUN npm install -g @colbymchenry/codegraph

# ── Bootstrap script (cron, post-install hooks) ────────────────
COPY scripts/docker-bootstrap.sh /opt/hermes/docker/bootstrap.sh
COPY scripts/ops-watchdog.sh /opt/hermes/scripts/ops-watchdog.sh

# ── Patch entrypoint: run bootstrap before final exec ──────────
RUN sed -i '/^exec hermes "\$@"/i\\n# Hermes bootstrap — one-shot setup on first boot\nif [ -x /opt/hermes/docker/bootstrap.sh ]; then\n    /opt/hermes/docker/bootstrap.sh\nfi\n' /opt/hermes/docker/entrypoint.sh

# ── Add MCP section to default config example ──────────────────
RUN printf '\n# ── MCP Servers (code intelligence) ────────────────────────────\nmcp_servers:\n  codegraph:\n    command: codegraph\n    args: ["serve", "--mcp"]\n    timeout: 300\n' >> /opt/hermes/cli-config.yaml.example

# Healthcheck for the gateway API
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -fsS http://localhost:8642/health > /dev/null || exit 1

# NOTE: Do NOT switch to USER hermes here.

# The base image entrypoint drops privileges automatically based on
# HERMES_UID / HERMES_GID env vars and needs root to chown /opt/data.
