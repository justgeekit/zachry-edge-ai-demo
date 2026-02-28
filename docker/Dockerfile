# =============================================================================
# Ollama v0.17.2 for JetPack 5 / L4T r35.4.1 (CUDA 11.4, aarch64)
#
# BEFORE BUILDING — download two archives from the Ollama GitHub release page:
#   https://github.com/ollama/ollama/releases/tag/v0.17.2
#
#   1. ollama-linux-arm64.tar.zst        → rename to: ollama-arm64.tar.zst
#   2. ollama-linux-arm64-jetpack5.tar.zst → rename to: ollama-jetpack5.tar.zst
#
# Place both files in the same directory as this Dockerfile, then build:
#   docker build -t ollama-jp5:v0.17.2 .
# =============================================================================

FROM dustynv/ollama:r35.4.1

# Install zstd for archive extraction
RUN apt-get update && apt-get install -y --no-install-recommends zstd \
    && rm -rf /var/lib/apt/lists/*

# Copy release archives into build context
COPY ollama-arm64.tar.zst      /tmp/ollama-arm64.tar.zst
COPY ollama-jetpack5.tar.zst   /tmp/ollama-jp5.tar.zst

# Replace Ollama binary + libraries with v0.17.2
RUN zstd -d /tmp/ollama-arm64.tar.zst --stdout | tar -x -C /usr \
    && zstd -d /tmp/ollama-jp5.tar.zst --stdout | tar -x -C /usr \
    && rm /tmp/ollama-arm64.tar.zst /tmp/ollama-jp5.tar.zst \
    && chmod +x /usr/bin/ollama \
    && ollama --version

ENV OLLAMA_HOST=0.0.0.0:11434
