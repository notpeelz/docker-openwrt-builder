FROM debian:bullseye AS env-setup

ARG GIT_CHECKOUT_REF

RUN if [ -z "$GIT_CHECKOUT_REF" ]; then \
    >&2 echo "GIT_CHECKOUT_REF build-arg is required"; \
    exit 1; \
  fi

RUN apt-get update && apt-get upgrade -y \
  && apt-get install -y build-essential \
  gawk \
  gcc-multilib \
  flex \
  git \
  gettext \
  libncurses5-dev \
  libssl-dev \
  python3-distutils \
  zlib1g-dev \
  unzip \
  wget \
  file \
  rsync

RUN git clone git://git.openwrt.org/openwrt/openwrt.git /openwrt

FROM env-setup

WORKDIR /openwrt

RUN git fetch --all --tags --prune \
  && git checkout ${GIT_CHECKOUT_REF}

# Prevent make from complaining about building as root
ENV FORCE_UNSAFE_CONFIGURE=1
