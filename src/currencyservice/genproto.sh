#!/bin/bash -eu

# [START gke_currencyservice_genproto]

# protos are loaded dynamically for node, simply copies over the proto.
mkdir -p proto
cp -r ../../protos/* ./proto

# [END gke_currencyservice_genproto]