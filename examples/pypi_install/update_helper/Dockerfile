# This Dockerfile sets up a container with the minimum number of things to make
# //:requirements.update target happy.

FROM ubuntu:22.04

RUN apt update
RUN DEBIAN_FRONTEND=noninteractive apt install --no-install-recommends -y python3
RUN DEBIAN_FRONTEND=noninteractive apt install --no-install-recommends -y pkgconf
