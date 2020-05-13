#!/bin/bash
# The authoritative source for this script is https://github.com/magenta-aps/setup_minion


MASTER_SERVER=$1
MINION_ID=$2

# Helpers
banner() {
    msg="# $* #"
    edge=$(echo "$msg" | sed 's/./#/g')
    echo ""
    echo "$edge"
    echo "$msg"
    echo "$edge"
}
CUT_HERE="----------------8<-------------[ cut here ]------------------"

# Check preconditions
#--------------------
banner "Checking preconditions"

# Check number of arguments
if [ $# -lt 2 ]; then
    echo "Not enough arguments provided."
    echo "Usage: setup.sh MASTER_SERVER MINION_ID"
    exit 1
fi

# Check minion id
if ! echo "${MINION_ID}" | grep -Eq '([^\.]*\.){5,}[^\.]*'; then
    echo "Invalid minion id: \"${MINION_ID}\""
    echo "Please see: https://git.magenta.dk/labs/salt-automation#minion-naming"
    exit 1
fi
echo "Minion id OK"

# Check master server

until nc -z "${MASTER_SERVER}" 4505; do
    echo "waiting for master (port 4505)"
    sleep 1
done

until nc -z "${MASTER_SERVER}" 4506; do
    echo "waiting for master (port 4506)"
    sleep 1
done
echo "Master server is up and running"

# Check that we are sudo
if [[ ${EUID} -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Installing salt-minion
#-----------------------
banner "Installing salt-minion"

# Add repository gpg public key
wget -O - https://repo.saltstack.com/py3/ubuntu/18.04/amd64/latest/SALTSTACK-GPG-KEY.pub | sudo apt-key add -

# Add repository to apt sources
echo "deb http://repo.saltstack.com/py3/ubuntu/18.04/amd64/latest bionic main" > /etc/apt/sources.list.d/saltstack.list

# Update apt cache
sudo apt-get update

# Install the salt-minion client
sudo apt-get install -y salt-minion

# Configuring salt-minion
#------------------------
banner "Configuring salt-minion"

# Setup master server
echo "master: ${MASTER_SERVER}" > /etc/salt/minion.d/magenta.conf

# Setup minion id
echo "${MINION_ID}" > /etc/salt/minion_id 

banner "Restarting salt-minion"
# Restart salt-minion
sudo systemctl restart salt-minion
