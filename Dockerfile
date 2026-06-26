# ============================================================================
# Dockerfile — headless, scriptable GNU Window Maker (Xvfb + wmaker)
# ----------------------------------------------------------------------------
# Builds Window Maker from THIS source tree and runs it on a virtual X server.
# This is the base layer the ai-mcp sandbox builds on — the downstream
# consumers are tacitness/wmaker-ng#16 (MCP skeleton over real X) and #18
# (Xvfb + wmaker + ai-mcp; external agent clicks a button). Keep it minimal.
#
#   docker build -t wmaker-crm:headless .
#   docker run --rm wmaker-crm:headless              # a running headless WM
#   docker run --rm -it wmaker-crm:headless wmctrl -l   # drive it
# ============================================================================

# ── Stage 1: build Window Maker from source ───────────────────────────────────
FROM ubuntu:24.04 AS build
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential autoconf automake libtool libtool-bin pkg-config gettext \
        libx11-dev libxext-dev libxt-dev libxmu-dev \
        libxft-dev libfontconfig1-dev libxpm-dev \
        libxinerama-dev libxrandr-dev libxfixes-dev \
        libpng-dev libjpeg-dev libtiff-dev libgif-dev libwebp-dev \
        libexif-dev libarchive-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .
# Install into a DESTDIR so the runtime stage copies just the artifacts.
RUN ./autogen.sh \
    && ./configure --prefix=/usr/local --sysconfdir=/etc \
    && make -j"$(nproc)" \
    && make install DESTDIR=/opt/wmaker-root

# ── Stage 2: minimal runtime ──────────────────────────────────────────────────
FROM ubuntu:24.04 AS runtime
ENV DEBIAN_FRONTEND=noninteractive
# Xvfb + the shared libraries the binaries link against (runtime, not -dev).
RUN apt-get update && apt-get install -y --no-install-recommends \
        xvfb \
        libx11-6 libxext6 libxt6 libxmu6 \
        libxft2 libfontconfig1 libxpm4 \
        libxinerama1 libxrandr2 libxfixes3 \
        libpng16-16t64 libjpeg-turbo8 libtiff6 libgif7 libwebp7 \
        libexif12 libarchive13t64 \
        fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /opt/wmaker-root/usr/local /usr/local
COPY --from=build /opt/wmaker-root/etc /etc
RUN ldconfig

COPY docker/entrypoint.sh /usr/local/bin/wmaker-headless
RUN chmod +x /usr/local/bin/wmaker-headless

# Virtual display defaults; override at `docker run` time.
ENV DISPLAY=:99 \
    SCREEN_GEOMETRY=1280x800x24 \
    HOME=/root

# No args  → run wmaker in the foreground (a live headless desktop).
# With args → start Xvfb + wmaker in the background, then exec the args
#             (how ai-mcp / a test harness layers on top).
ENTRYPOINT ["/usr/local/bin/wmaker-headless"]
