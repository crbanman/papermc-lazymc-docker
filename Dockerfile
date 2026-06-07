# JRE base
ARG JAVA_VERSION=25
ARG DEFAULT_MC_VERSION=latest
FROM eclipse-temurin:${JAVA_VERSION}-jre-noble

ARG DEFAULT_MC_VERSION

# Environment variables
ENV MC_VERSION="${DEFAULT_MC_VERSION}" \
    LAZYMC_VERSION="latest" \
    PAPER_BUILD="latest" \
    PAPER_CHANNEL="STABLE" \
    PAPER_USER_AGENT="papermc-lazymc-docker/1.0 (https://github.com/crbanman/papermc-lazymc-docker)" \
    MC_RAM="" \
    JAVA_OPTS=""

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl jq \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /papermc

COPY papermc.sh /papermc.sh

# Start script
CMD ["sh", "/papermc.sh"]

# Container setup
EXPOSE 25565/tcp
EXPOSE 25565/udp
VOLUME /papermc
