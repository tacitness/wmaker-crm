# Headless Window Maker container

A headless, scriptable GNU Window Maker: `Xvfb` + `wmaker` built from this
source tree. This is the **base layer** the `ai-mcp` sandbox builds on — the
downstream consumers are [tacitness/wmaker-ng#16][16] (MCP skeleton over real X)
and [tacitness/wmaker-ng#18][18] (Xvfb + wmaker + ai-mcp; external agent clicks a
button).

## Build & run

```bash
make -f infra.mk image          # docker build -t wmaker-crm:headless .
make -f infra.mk run            # a live headless desktop (Ctrl-C to stop)

# or directly:
docker build -t wmaker-crm:headless .
docker run --rm wmaker-crm:headless
```

## How it starts Xvfb + wmaker

The entrypoint (`docker/entrypoint.sh`, installed as `wmaker-headless`) starts a
virtual X server, waits for it, then launches Window Maker:

- **No command** → `wmaker` runs in the foreground; the container lives as long
  as the window manager does.
- **A command** → `Xvfb` + `wmaker` start in the background, then the command is
  `exec`'d. This is how a downstream image runs its own process against an
  already-running desktop:

  ```dockerfile
  FROM wmaker-crm:headless
  COPY ai-mcp /usr/local/bin/
  CMD ["ai-mcp", "--serve"]      # Xvfb + wmaker come up first, then ai-mcp
  ```

## Configuration

| Env var           | Default        | Meaning                          |
|-------------------|----------------|----------------------------------|
| `DISPLAY`         | `:99`          | X display the WM runs on         |
| `SCREEN_GEOMETRY` | `1280x800x24`  | Xvfb virtual screen `WxHxDepth`  |

```bash
docker run --rm -e SCREEN_GEOMETRY=1920x1080x24 wmaker-crm:headless
```

The image is intentionally minimal (multi-stage: build deps are dropped; the
runtime carries only Xvfb, the shared libs the binaries link against, and a base
font). It ships no VNC/X clients — add what you need in a derived image.

[16]: https://github.com/tacitness/wmaker-ng/issues/16
[18]: https://github.com/tacitness/wmaker-ng/issues/18
