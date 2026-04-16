FROM ubuntu:24.04
LABEL org.opencontainers.image.authors="Mohamed Eldeeb <mohamed.eldeeb@metu.edu.tr>"
LABEL org.opencontainers.image.vendor="WINS Lab, Middle East Technical University"
LABEL org.opencontainers.image.licenses="Academic-Public-License-v1.1 AND LGPL-3.0-only"
LABEL org.opencontainers.image.description="\
    Image containing source code and binaries for OMNeT++, INET, and Simu5G. \
    OMNeT++ is subject to APL. INET and Simu5G are subject to LGPL. See /usr/share/licenses/ for details."

# This image builds OMNeT++, INET, and Simu5G from source.
# Using a multi-stage build will not help much since INET depends on OMNeT++, Simu5G depends on INET, etc
#  so an update to any of them will require rebuilding subsequent layers.
# However, we still keep the final image smaller by removing build cache.

# This is provided by docker buildx in multi-arch builds
# TODO: Setup cross compiling so that arm64 builds can be done on x86 hosts without emulation
ARG TARGETARCH

# BUILD_DEBUG=true/false to build/skip debug versions (release is always built)
# WITH_IDE=true/false to download/skip the OMNeT++ IDE and build with QT support
ARG BUILD_DEBUG=true
ARG WITH_IDE=true

ARG OMNETPP_VERSION
ARG INET_VERSION
ARG SIMU5G_VERSION

SHELL ["/bin/bash", "-exo", "pipefail", "-c"]

# Needed to retain apt cache at the end of the layer
RUN rm -f /etc/apt/apt.conf.d/docker-clean

# Install build dependencies
# We use cache mounts to speed up subsequent builds by caching apt data between builds
# Even if the layer changes because of the WITH_IDE arg, the cached packages will still be reused.
# Use different cache ids per architecture so they don't lock each other out
RUN --mount=type=cache,id=apt-${TARGETARCH},target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-${TARGETARCH},target=/var/lib/apt,sharing=locked \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    echo "omnetpp build dependencies" > /dev/null && \
    apt-get install -y --no-install-recommends \
        wget ca-certificates \
        make diffutils pkg-config ccache clang lld gdb lldb \
        bison flex perl sed gawk python3 python3-pip python3-venv python3-dev \
        libxml2-dev zlib1g-dev doxygen graphviz xdg-utils libdw-dev && \
    if [ "$WITH_IDE" = "true" ]; then \
        echo "qtenv dependencies" > /dev/null && \
        apt-get install -y --no-install-recommends \
            qt6-base-dev qt6-base-dev-tools qmake6 libqt6svg6 qt6-wayland libwebkit2gtk-4.1-0 libopenscenegraph-dev \
    ; fi && \
    echo "inet dependencies" > /dev/null && \
    apt-get install -y --no-install-recommends \
        libavcodec-dev libavformat-dev
    # rm -rf /var/lib/apt/lists/* && \
    # apt-get clean

# We do all our work in /opt, so users can copy everything from this image to their own /opt without having to set LD_LIBRARY_PATH, etc 
WORKDIR /opt

# ------------ OMNeT++ Installation ------------
RUN if [ "$TARGETARCH" = "amd64" ]; then ARCH=x86_64; elif [ "$TARGETARCH" = "arm64" ]; then ARCH=aarch64; fi && \
    if [ "$WITH_IDE" = "true" ]; then OMNETPP_DIST=linux-$ARCH; else OMNETPP_DIST=core; fi && \
    wget https://github.com/omnetpp/omnetpp/releases/download/omnetpp-$OMNETPP_VERSION/omnetpp-$OMNETPP_VERSION-$OMNETPP_DIST.tgz \
        --referer=https://omnetpp.org/ -O omnetpp-dist.tgz --progress=dot:giga && \
    tar xf omnetpp-dist.tgz && rm omnetpp-dist.tgz && mv omnetpp-$OMNETPP_VERSION omnetpp

# Build OMNeT++. Default target builds both release and debug versions
WORKDIR /opt/omnetpp
RUN python3 -m venv /opt/venv --upgrade-deps --clear --prompt "omnetpp/.venv" && \
    source /opt/venv/bin/activate && \
    python3 -m pip install --no-cache-dir -r python/requirements.txt && \
    source ./setenv && \
    if [ "$WITH_IDE" = "true" ]; then \
        ./configure WITH_QTENV=yes WITH_OSG=yes WITH_OSGEARTH=no WITH_LIBXML=yes CXXFLAGS=-std=c++17 \
    ; else \
        ./configure WITH_QTENV=no WITH_OSG=no WITH_OSGEARTH=no WITH_LIBXML=yes CXXFLAGS=-std=c++17 \
    ; fi && \
    make -j $(nproc) MODE=release && \
    if [ "$BUILD_DEBUG" = "true" ]; then \
        make -j $(nproc) MODE=debug \
    ; fi && \
    rm -rf out /root/.cache

# ------------ INET Installation ------------
WORKDIR /opt
RUN wget https://github.com/inet-framework/inet/releases/download/v$INET_VERSION/inet-$INET_VERSION-src.tgz \
         --referer=https://omnetpp.org/ -O inet-src.tgz --progress=dot:mega && \
         tar xf inet-src.tgz && rm inet-src.tgz && mv inet*/ inet

# Set the environment and build INET
# INET has python requirements but they are not needed for building
RUN cd /opt/omnetpp && source setenv && \
    cd /opt/inet && source setenv && \
    if [ "$WITH_IDE" = "true" ]; then \
        opp_featuretool enable VisualizationOsg VisualizationOsgShowcases VoipStream VoipStreamExamples \
    ; else \
        opp_featuretool enable VoipStream VoipStreamExamples \
    ; fi && \
    make makefiles && \
    make -j $(nproc) MODE=release && \
    if [ "$BUILD_DEBUG" = "true" ]; then \
        make -j $(nproc) MODE=debug \
    ; fi && \
    rm -rf out /root/.cache

# ------------ Simu5G Installation ------------
WORKDIR /opt
RUN wget https://github.com/Unipisa/Simu5G/releases/download/v$SIMU5G_VERSION/simu5g-$SIMU5G_VERSION-src.tgz \
    && tar xf simu5g-$SIMU5G_VERSION-src.tgz && rm simu5g-$SIMU5G_VERSION-src.tgz && mv Simu5G-$SIMU5G_VERSION simu5g

RUN cd /opt/omnetpp && source setenv && \
    cd /opt/inet && source setenv && \
    cd /opt/simu5g && source setenv -f && \
    make makefiles && \
    make -j $(nproc) MODE=release && \
    if [ "$BUILD_DEBUG" = "true" ]; then \
        make -j $(nproc) MODE=debug \
    ; fi && \
    rm -rf out /root/.cache

# Copy licenses to a standard location (they still remain in the source directories as well)
RUN mkdir -p /usr/share/licenses/omnetpp /usr/share/licenses/inet /usr/share/licenses/simu5g && \
    cp /opt/omnetpp/doc/License /usr/share/licenses/omnetpp/LICENSE && \
    cp /opt/omnetpp/README /usr/share/licenses/omnetpp/README && \
    cp /opt/inet/LICENSE.md /usr/share/licenses/inet/LICENSE && \
    cp /opt/inet/README.md /usr/share/licenses/inet/README && \
    cp /opt/simu5g/LICENSE.md /usr/share/licenses/simu5g/LICENSE && \
    cp /opt/simu5g/README.md /usr/share/licenses/simu5g/README
