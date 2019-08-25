ARG RISK=edge
ARG UBUNTU=xenial

FROM ubuntu:$UBUNTU as builder

RUN echo "Building snapcraft:$RISK in ubuntu:$UBUNTU"

# Grab dependencies
RUN apt update
RUN apt dist-upgrade --yes
RUN apt install --yes curl jq squashfs-tools

# Grab the core snap from the stable channel and unpack it in the proper place
RUN curl -L $(curl -H 'X-Ubuntu-Series: 16' 'https://api.snapcraft.io/api/v1/snaps/details/core' | jq '.download_url' -r) --output core.snap
RUN mkdir -p /snap/core
RUN unsquashfs -d /snap/core/current core.snap

# Grab the snapcraft snap from the $RISK channel and unpack it in the proper place
RUN curl -L $(curl -H 'X-Ubuntu-Series: 16' 'https://api.snapcraft.io/api/v1/snaps/details/snapcraft?channel='$RISK | jq '.download_url' -r) --output snapcraft.snap
RUN mkdir -p /snap/snapcraft
RUN unsquashfs -d /snap/snapcraft/current snapcraft.snap

# Create a snapcraft runner (TODO: move version detection to the core of snapcraft)
RUN mkdir -p /snap/bin
RUN echo "#!/bin/sh" > /snap/bin/snapcraft
RUN snap_version="$(awk '/^version:/{print $2}' /snap/snapcraft/current/meta/snap.yaml)" && echo "export SNAP_VERSION=\"$snap_version\"" >> /snap/bin/snapcraft
RUN echo 'exec "$SNAP/usr/bin/python3" "$SNAP/bin/snapcraft" "$@"' >> /snap/bin/snapcraft
RUN chmod +x /snap/bin/snapcraft

# Multi-stage build, only need the snaps from the builder. Copy them one at a
# time so they can be cached.
FROM ubuntu:$UBUNTU
COPY --from=builder /snap/core /snap/core
COPY --from=builder /snap/snapcraft /snap/snapcraft
COPY --from=builder /snap/bin/snapcraft /snap/bin/snapcraft

# Generate locale
RUN apt update && apt dist-upgrade --yes && apt install --yes sudo locales && locale-gen en_US.UTF-8

# Preinstall build-packages
RUN apt install --yes cmake cmake-data libarchive13 libjsoncpp1 librhash0 libuv1
RUN apt install --yes git zlib1g-dev libpng-dev libcairo2-dev libfreetype6-dev libjson-c-dev libfontconfig1-dev libgtkmm-3.0-dev libpangomm-1.4-dev libgl-dev libglu-dev libspnav-dev build-essential libgtk-3-dev

# Set the proper environment
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"
ENV PATH="/snap/bin:$PATH"
ENV SNAP="/snap/snapcraft/current"
ENV SNAP_NAME="snapcraft"
ENV SNAP_ARCH="amd64"
