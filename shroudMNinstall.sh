#!/bin/bash

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -a|--advanced)
    ADVANCED="y"
    shift
    ;;
    -n|--normal)
    ADVANCED="n"
    FAIL2BAN="y"
    UFW="y"
    BOOTSTRAP="y"
    shift
    ;;
    -i|--externalip)
    EXTERNALIP="$2"
    ARGUMENTIP="y"
    shift
    shift
    ;;
    -k|--privatekey)
    KEY="$2"
    shift
    shift
    ;;
    -f|--fail2ban)
    FAIL2BAN="y"
    shift
    ;;
    --no-fail2ban)
    FAIL2BAN="n"
    shift
    ;;
    -u|--ufw)
    UFW="y"
    shift
    ;;
    --no-ufw)
    UFW="n"
    shift
    ;;
    -b|--bootstrap)
    BOOTSTRAP="y"
    shift
    ;;
    --no-bootstrap)
    BOOTSTRAP="n"
    shift
    ;;
    -s|--swap)
    SWAP="y"
    shift
    ;;
    --no-swap)
    SWAP="n"
    shift
    ;;
    -h|--help)
    cat << EOL
DMS Masternode installer arguments:
    -n --normal               : Run installer in normal mode
    -a --advanced             : Run installer in advanced mode
    -i --externalip <address> : Public IP address of VPS
    -k --privatekey <key>     : Private key to use
    -f --fail2ban             : Install Fail2Ban
    --no-fail2ban             : Don't install Fail2Ban
    -u --ufw                  : Install UFW
    --no-ufw                  : Don't install UFW
    -b --bootstrap            : Sync node using Bootstrap
    --no-bootstrap            : Don't use Bootstrap
    -h --help                 : Display this help text.
    -s --swap                 : Create swap for <2GB RAM
EOL
    exit
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

clear

# Check if we are root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root! Aborting..." 1>&2
   exit 1
fi

# Install tools for dig and systemctl
echo "Preparing installation..."
apt-get update 
apt-get upgrade -y
apt-get install git jq dnsutils systemd -y > /dev/null 2>&1

clear

echo "Installing dependencies..."
apt-get install build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils libboost-all-dev libzmq3-dev libminizip-dev -y
add-apt-repository ppa:bitcoin/bitcoin && apt-get update && apt-get install libdb4.8-dev libdb4.8++-dev -y

clear


# Check for systemd
systemctl --version >/dev/null 2>&1 || { echo "systemd is required. Are you using Ubuntu 16.04?"  >&2; exit 1; }

# Getting external IP
if [ -z "$EXTERNALIP" ]; then
    EXTERNALIP=`dig +short myip.opendns.com @resolver1.opendns.com`
fi
clear


if [ -z "$ADVANCED" ]; then

cat << "EOF" 

  ___ _  _ ___  ___  _   _ ___  _  _  ___  ___  ___   ___ _  _ ___ _____ _   _    _    
 / __| || | _ \/ _ \| | | |   \| \| |/ _ \|   \| __| |_ _| \| / __|_   _/_\ | |  | |   
 \__ \ __ |   / (_) | |_| | |) | .` | (_) | |) | _|   | || .` \__ \ | |/ _ \| |__| |__ 
 |___/_||_|_|_\\___/ \___/|___/|_|\_|\___/|___/|___| |___|_|\_|___/ |_/_/ \_\____|____|
                                                                                       

EOF

echo "

     +---------MASTERNODE INSTALLER v1 ---------+
 |                                                  |
 | You can choose between two installation options: |::
 |              default and advanced.               |::
 |                                                  |::
 +--------------------------------------------------+
 ::::::::::::::::::::::::::::::::::::::::::::::::::::

"

sleep 5
fi

if [ -z "$ADVANCED" ]; then
    read -e -p "Use the Advanced Installation? [N/y] : " ADVANCED
fi

if [[ ("$ADVANCED" == "y" || "$ADVANCED" == "Y") ]]; then
    USER=root
    INSTALLERUSED="#Used Advanced Install"

    echo "" && echo 'Using advance install' && echo ""
    sleep 1
else
    USER=root
    UFW="y"
    INSTALLERUSED="#Used Basic Install"
    BOOTSTRAP="y"
fi

USERHOME=`eval echo "~$USER"`

if [ -z "$KEY" ]; then
    read -e -p "Masternode Private Key : " KEY
fi

if [ -z "$SWAP" ]; then
    read -e -p "Does VPS use less than 2GB RAM? [Y/n] : " SWAP
fi

if [ -z "$UFW" ]; then
    read -e -p "Install UFW and configure ports? [Y/n] : " UFW
fi

if [ -z "$ARGUMENTIP" ]; then
    read -e -p "Server IP Address: " -i $EXTERNALIP -e IP
fi

#if [ -z "$BOOTSTRAP"]; then
#    read -e -p "Download bootstrap for fast sync? [Y/n] : " BOOTSTRAP
#fi

clear



# Generate random passwords
RPCUSER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
RPCPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)


# Configuring SWAP
echo "Configuring swap file..."
if [[ ("$SWAP" == "y" || "$SWAP" == "Y" || "$SWAP" == "") ]]; then
    cd ~
    sudo fallocate -l 4G /swapfile
    ls -lh /swapfile
    sudo chmod 600 /swapfile
    ls -lh /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    sudo swapon --show
    sudo cp /etc/fstab /etc/fstab.bak
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi
clear

echo "Configuring UFW..."
# Install UFW
if [[ ("$UFW" == "y" || "$UFW" == "Y" || "$UFW" == "") ]]; then
  apt-get -qq install ufw
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow ssh
  ufw allow 41319/tcp
  yes | ufw enable
fi
clear

# Set these to change the version of ShroudX to install
TARBALLURL=$(curl -s https://api.github.com/repos/ShroudProtocol/ShroudX/releases/latest | jq -r ".assets[] | select(.name | contains(\"x86_64-ubuntu\")) | .browser_download_url")
TARBALLNAME=$(echo "${TARBALLURL}"|awk -F '/' '{print $NF}')
BOOTSTRAPURL=""
BOOTSTRAPARCHIVE=""
BWKVERSION="1.0.0"


# Install ShroudX daemon
echo "Installing ShroudX deamon"
wget $TARBALLURL
tar -xzvf $TARBALLNAME
rm $TARBALLNAME
rm -f ./shroud-qt
mkdir ShroudX
mv ./shroudd ~/ShroudX
mv ./shroud-cli ~/ShroudX
mv ./shroud-tx ~/ShroudX
mv ./tor ~/ShroudX

# Create shroud directory
mkdir ~/.shroud

# Create shroud.conf
touch ~/.shroud/shroud.conf
cat > ~/.shroud/shroud.conf << EOL
${INSTALLERUSED}
rpcuser=${RPCUSER}
rpcpassword=${RPCPASSWORD}
rpcallowip=127.0.0.1
debug=1
txindex=1
daemon=1
server=1
listen=1
maxconnections=24
shroudnode=1
externalip=${IP}
bind=${IP}:42998
masternodeaddr=${IP}:42998
masternodeprivkey=${KEY}
EOL
chmod 0600 ~/.shroud/shroud.conf
chown -R $USER:$USER ~/.shroud

sleep 1
clear

# Install bootstrap file
if [[ ("$BOOTSTRAP" == "y" || "$BOOTSTRAP" == "Y" || "$BOOTSTRAP" == "") ]]; then
  echo "skipping"
fi

# Set up system deamon (for server shutdown, crash, etc)
cat > /etc/systemd/system/shroud.service << EOL
[Unit]
Description=Shroud service
After=network.target
[Service]
User=root
Group=root
Type=forking
ExecStart=~/ShroudX/shroudd -daemon
ExecStop=~/ShroudX/shroud-cli stop
Restart=always
RestartSec=15
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOL
sudo systemctl daemon-reload
sudo systemctl enable shroud.service
sudo systemctl start shroud.service

clear

#Set up enviroment variables

cd ~
mkdir .commands
echo "export PATH="$PATH:~/.commands"" >> ~/.profile
wget https://raw.githubusercontent.com/M1chlCZ/RANDOM-STUFF/main/env.sh
source env.sh
source ~/.profile

clear

echo "" && echo "Masternode setup complete" && echo ""
read -p "Press Enter to continue after read to continue. " -n1 -s
rm -rf ~/dmsMNinstall.sh
clear