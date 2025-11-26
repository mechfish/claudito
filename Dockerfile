FROM public.ecr.aws/docker/library/debian:bookworm

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Upgrade all packages to latest versions and install core dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    locales \
    netbase \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN sed -i "s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g" /etc/locale.gen && \
    locale-gen
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en \
    LC_ALL=en_US.UTF-8 \
    LC_CTYPE=en_US.UTF-8

# Security labels
LABEL security.sandbox="true" \
    security.user="unprivileged:claudito:1000" \
    security.capabilities="restricted" \
    security.sudo="enabled" \
    org.opencontainers.image.description="Sandboxed Claude Code environment with full development tooling"

# Install core dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # System essentials
    ca-certificates \
    curl \
    wget \
    gnupg \
    # Archive tools
    unzip \
    zip \
    tar \
    # Development tools
    git \
    git-lfs \
    vim \
    nano \
    jq \
    less \
    pv \
    ripgrep \
    unicode-data \
    sudo \
    # Network tools
    netcat-traditional \
    # Database clients
    libpq-dev \
    libsqlite3-dev \
    postgresql-client \
    redis-tools \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (version 20.x via NodeSource)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends \
    nodejs \
    && rm -rf /var/lib/apt/lists/*

# Create unprivileged user (remove any existing UID 1000 user first)
RUN if id 1000 2>/dev/null; then userdel -r $(id -un 1000); fi && \
    useradd -m -s /bin/bash -u 1000 claudito && \
    echo "claudito ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Make sure shared directories are accessible by claudito user
# Pre-create .claude directory so volume mount has correct permissions
RUN mkdir -p /home/claudito/.claude && \
    chown -R claudito:claudito /home/claudito

# Copy scripts
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to unprivileged user
USER claudito

# Configure npm and install Claude Code as claudito user (enables auto-updates)
RUN mkdir -p /home/claudito/.npm-global && \
    npm config set prefix '/home/claudito/.npm-global' && \
    npm install -g @anthropic-ai/claude-code

# Update PATH to include npm global bin directory
ENV PATH="/home/claudito/.npm-global/bin:${PATH}"

# Set working directory
WORKDIR /src

# Set entrypoint to our wrapper script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
