# JRE base
FROM openjdk:17-slim
LABEL org.opencontainers.image.source https://github.com/rssnyder/papermc-lazymc-docker

# Environment variables
ENV MC_VERSION="latest" \
    LAZYMC_VERSION="latest" \
    PAPER_BUILD="latest" \
    MC_RAM="" \
    JAVA_OPTS=""

COPY papermc.sh .
RUN apt-get update \
    && apt-get install -y wget jq \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /papermc

# Start script
CMD ["sh", "./papermc.sh"]

# Container setup
EXPOSE 25565/tcp
EXPOSE 25565/udp
VOLUME /papermc
