#!/usr/bin/env bash

# wget https://raw.githubusercontent.com/divyamohan1993/devops-shell-scripts/refs/heads/main/springboot/run-latest.sh
# chmod 755 run-latest.sh 
# sudo ./run-latest.sh 
set -Eeuo pipefail

URL="https://raw.githubusercontent.com/divyamohan1993/devops-shell-scripts/refs/heads/main/springboot/autoconfig.sh"

cd ~/ && mkdir springboot && cd springboot

# cache-bust via timestamp param + no-cache headers
wget -O autoconfig.sh --header="Cache-Control: no-cache" "${URL}?nocache=$(date +%s)"
chmod 755 autoconfig.sh

# VERBOSE=1 for xtrace; otherwise quiet
sudo DEBUG=1 ./autoconfig.sh