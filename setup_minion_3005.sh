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
SALT_VERSION_MAP["22.04"]="3005"
SALT_VERSION_MAP["20.04"]="3002"
SALT_VERSION_MAP["18.04"]="3002"
SALT_VERSION_MAP["16.04"]="3002"

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

# Add repository gpg public key
if [[ $SALT_VERSION -eq "3005" ]]; then
    curl -fsSL -o /etc/apt/keyrings/salt-archive-keyring.gpg https://repo.saltproject.io/salt/py3/ubuntu/${UBUNTU_VERSION}/amd64/minor/${SALT_VERSION}.3/salt-archive-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/salt-archive-keyring.gpg arch=amd64] https://repo.saltproject.io/salt/py3/ubuntu/${UBUNTU_VERSION}/amd64/minor/${SALT_VERSION}.3 jammy main" | sudo tee /etc/apt/sources.list.d/salt.list
else
    wget -O - https://repo.saltstack.com/py3/ubuntu/${UBUNTU_VERSION}/amd64/${SALT_VERSION}/SALTSTACK-GPG-KEY.pub | sudo apt-key add -

    # Add repository to apt sources
    echo "deb http://repo.saltstack.com/py3/ubuntu/${UBUNTU_VERSION}/amd64/${SALT_VERSION} ${UBUNTU_VERSION_CODENAME} main" > /etc/apt/sources.list.d/saltstack.list
fi

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
