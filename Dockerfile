FROM eclipse-temurin:17-jre-jammy

ARG MINDUSTRY_VERSION=v155.4
ARG MINDUSTRY_SHA256=cb96a68d2a9badf58a0640062607f953b1ed551ed7b4af0c2bf393d8ce8d6643

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/mindustry

RUN curl -fsSL "https://github.com/Anuken/Mindustry/releases/download/${MINDUSTRY_VERSION}/server-release.jar" \
    -o /opt/mindustry/server-release.jar \
    && echo "${MINDUSTRY_SHA256}  /opt/mindustry/server-release.jar" | sha256sum -c -

COPY docker/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

WORKDIR /data

ENTRYPOINT ["/entrypoint.sh"]
