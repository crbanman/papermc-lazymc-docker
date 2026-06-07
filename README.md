# PaperMC Docker with lazymc

Linux Docker image for a PaperMC Minecraft server managed by
[lazymc](https://github.com/timvisee/lazymc).

PaperMC is an optimized Minecraft server with plugin support. lazymc lets the
server sleep while idle and wakes it when a player connects.

This image does not redistribute Minecraft or Paper server files. It downloads
Paper and lazymc from their official release sources at container startup.

## Current Defaults

- Base image: `eclipse-temurin:25-jre-noble`
- Paper download service: `https://fill.papermc.io/v3`
- Paper channel: `STABLE`
- lazymc: latest GitHub release
- Supported image platforms: `linux/amd64`, `linux/arm64`

As of June 7, 2026, Paper's actively supported lines are:

- `26.1.2`, latest stable build `69`, Java minimum `25`
- `1.21.11`, latest stable build `132`, Java minimum `21`

The `latest`, `java25`, and `temurin25` image tags use Java 25 so the default
`latest` Paper line works. The `java21` and `temurin21` tags default to
`MC_VERSION=1.21.11` for the older supported Paper line.

Paper 26.1 changed world storage layout. Back up existing worlds before moving
to 26.1 or newer. After upgrading a world to 26.1, do not expect to downgrade it
back to an older Paper version.

## Usage

Running this image indicates agreement to the Minecraft EULA.

```sh
docker run \
  --name papermc \
  -p 25565:25565 \
  -v papermc:/papermc \
  crbanman/papermc-lazymc
```

For production servers, pin `MC_VERSION` and `PAPER_BUILD`. The default
`latest` values can update the server on container restart.

```sh
docker run \
  --name papermc \
  -p 25565:25565 \
  -v papermc:/papermc \
  -e MC_VERSION="26.1.2" \
  -e PAPER_BUILD="69" \
  -e MC_RAM="4G" \
  crbanman/papermc-lazymc
```

## Docker Options

- `-p <host-port>:25565`: publish the Minecraft server port.
- `-p <host-port>:25575`: publish RCON if you enable it in `server.properties`.
- `-v <volume-or-path>:/papermc`: persist server files.
- `-d`: run detached.
- `-it`: keep an interactive console available for `docker attach`.
- `--restart on-failure`: restart if the server process crashes.
- `--name <name>`: set a stable container name.

## Environment Variables

| Name | Default | Description |
| --- | --- | --- |
| `MC_VERSION` | `latest` | Paper/Minecraft version. `latest` uses the newest Paper version from the Fill v3 API. |
| `PAPER_BUILD` | `latest` | Paper build number. `latest` uses the newest build matching `PAPER_CHANNEL`. |
| `PAPER_CHANNEL` | `STABLE` | Paper release channel to use when `PAPER_BUILD=latest`. |
| `LAZYMC_VERSION` | `latest` | lazymc GitHub release tag, for example `v0.2.11`. |
| `MC_RAM` | empty | Sets both `-Xms` and `-Xmx`, for example `4G` or `4096M`. |
| `JAVA_OPTS` | empty | Extra Java options appended to the server command. |
| `PAPER_USER_AGENT` | project default | User-Agent sent to Paper's download service. Change this for derived images. |

## Build Args

| Name | Default | Description |
| --- | --- | --- |
| `JAVA_VERSION` | `25` | Eclipse Temurin Java major version used in the base image. |
| `DEFAULT_MC_VERSION` | `latest` | Baked-in default for `MC_VERSION`. |

## Files

Server files live in `/papermc`. Use a Docker volume or host bind mount so
worlds, plugins, configs, and the generated `lazymc.toml` persist across
container restarts.

## Links

- [PaperMC](https://papermc.io/)
- [PaperMC downloads service](https://docs.papermc.io/misc/downloads-service/)
- [lazymc](https://github.com/timvisee/lazymc)
- [GitHub repository](https://github.com/crbanman/papermc-lazymc-docker)
- [Docker Hub repository](https://hub.docker.com/r/crbanman/papermc-lazymc)
