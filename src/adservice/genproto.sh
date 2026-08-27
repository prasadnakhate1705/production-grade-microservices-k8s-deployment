#!/bin/bash -eu

# [START gke_adservice_genproto]
# protos are needed in adservice folder for compiling during Docker build.

mkdir -p proto && \
cp ../../protos/demo.proto src/main/proto

# [END gke_adservice_genproto]