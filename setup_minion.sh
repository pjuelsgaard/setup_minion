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

# Check OS Distro
OS_DISTRO=$(lsb_release -d | cut -f2 | cut -f1 -d' ')
if [[ "${OS_DISTRO}" != "Ubuntu" ]]; then
   echo "This script only supports Ubuntu"
   exit 1
fi
UBUNTU_VERSION=$(lsb_release -r | cut -f2)
UBUNTU_VERSION_CODENAME=$(lsb_release -c | cut -f2)

# Determine the Salt version we wish to install
declare -A SALT_VERSION_MAP
SALT_VERSION_MAP["24.04"]="3006"
SALT_VERSION_MAP["22.04"]="3006"
SALT_VERSION_MAP["20.04"]="3006"

SALT_VERSION=${SALT_VERSION_MAP[${UBUNTU_VERSION}]}
if [[ -z "${SALT_VERSION}" ]]; then
    echo "Unable to determine Salt Version from Ubuntu Version"
    exit 1
fi

# Check that we are sudo
if [[ ${EUID} -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Installing salt-minion
#-----------------------
banner "Installing salt-minion"

# https://docs.saltproject.io/salt/install-guide/en/latest/topics/install-by-operating-system/linux-deb.html

# Ensure keyrings dir exists
mkdir -p /etc/apt/keyrings
# Download public key
sudo curl -fsSL -o /etc/apt/keyrings/salt-archive-keyring.pgp https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public

# Create apt repo target configuration
echo "deb [signed-by=/etc/apt/keyrings/salt-archive-keyring.pgp] https://packages.broadcom.com/artifactory/saltproject-deb stable main" > /etc/apt/sources.list.d/salt.list

# Pin salt version
echo "Package: salt-*
Pin: version ${SALT_VERSION}.*
Pin-Priority: 1001" > /etc/apt/preferences.d/salt-pin-1001

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

sleep 5
while [ ! -f /etc/salt/pki/minion/minion.pub ]
do
    echo "Waiting for /etc/salt/pki/minion/minion.pub to appear."
    sleep 10
done

# Output pillar data
echo ""
echo "${CUT_HERE}"
echo ""

indent() { sed "s/^/  /"; }
MINION_IP=$(curl -s ipinfo.io/ip)

echo "${MINION_ID}:"
echo "public_key: |" | indent
cat /etc/salt/pki/minion/minion.pub | indent | indent
echo ""
echo "ip: ${MINION_IP}" | indent
