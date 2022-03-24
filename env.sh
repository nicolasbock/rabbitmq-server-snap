#!/bin/bash

set -e -u

echo "Env inside snap:"

env | sort

echo "SNAP: ${SNAP}"
echo "ERL_DIR: ${ERL_DIR}"
