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

# Check for systemd
systemctl --version >/dev/null 2>&1 || { echo "systemd is required. Are you using Ubuntu 16.04?"  >&2; exit 1; }

# Getting external IP
if [ -z "$EXTERNALIP" ]; then
    EXTERNALIP=`dig +short myip.opendns.com @resolver1.opendns.com`
fi
clear


if [ -z "$ADVANCED" ]; then

cat << "EOF" 
  ___  __  __ ___    __  __ _  _    ___ ___ _____ _   _ ___  ___ 
 |   \|  \/  / __|  |  \/  | \| |  / __| __|_   _| | | | _ \/ __|
 | |) | |\/| \__ \  | |\/| | .` |  \__ \ _|  | | | |_| |  _/\__ \
 |___/|_|  |_|___/  |_|  |_|_|\_|  |___/___| |_|  \___/|_|  |___/
EOF

echo "

     +---------MASTERNODE INSTALLER v1 ---------+
 |                                                  |
 | You can choose between two installation options: |::
 |              default and advanced.               |::
 |                                                  |::
 |  The advanced installation will install and run  |::
 |   the masternode under a non-root user. If you   |::
 |   don't know what that means, use the default    |::
 |               installation method.               |::
 |                                                  |::
 |  Otherwise, your masternode will not work, and   |::
 |    the Documentchain Team WILL NOT assist you    |::
 |                 in repairing it.                 |::
 |                                                  |::
 |           You will have to start over.           |::
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
    USER=ccash

    adduser $USER --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password > /dev/null

    INSTALLERUSED="#Used Advanced Install"

    echo "" && echo 'Added user "ccash"' && echo ""
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
    sudo fallocate -l 3G /swapfile
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

# update packages and install dependencies
echo "Installing dependencies..."
add-apt-repository -y ppa:bitcoin/bitcoin 
apt-get update 
apt-get -qq -y libdb4.8-dev libdb4.8++-dev
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

# Set these to change the version of DMS to install
TARBALLURL=$(curl -s https://api.github.com/repos/Krekeler/documentchain/releases/latest | jq -r ".assets[] | select(.name | contains(\"x86_64-linux-gnu\")) | .browser_download_url")
TARBALLNAME=$(echo "${TARBALLURL}"|awk -F '/' '{print $NF}')
BOOTSTRAPURL=""
BOOTSTRAPARCHIVE=""
BWKVERSION="1.0.0"


# Install CBN daemon
echo "Installing DMS deamon"
wget $TARBALLURL
tar -xzvf $TARBALLNAME
rm $TARBALLNAME
rm -f ./dms-qt
rm -f ./test-dms
mkdir dms
mv ./dmsd ~/dms
mv ./dms-cli ~/dms
mv ./dms-tx ~/dms

# Create dms directory
mkdir /root/.dmscore

# Create dms.conf
touch /root/.dmscore/dms.conf
cat > /root/.dmscore/dms.conf << EOL
${INSTALLERUSED}
rpcuser=${RPCUSER}
rpcpassword=${RPCPASSWORD}
rpcallowip=127.0.0.1
server=1
listen=1
daemon=1
maxconnections=125
masternode=1
externalip=${IP}
bind=${IP}:41319
masternodeaddr=${IP}:41319
masternodeprivkey=${KEY}
EOL
chmod 0600 /root/.dmscore/dms.conf
chown -R $USER:$USER /root/.dmscore

sleep 1
clear

# Install bootstrap file
if [[ ("$BOOTSTRAP" == "y" || "$BOOTSTRAP" == "Y" || "$BOOTSTRAP" == "") ]]; then
  echo "skipping"
fi

# Set up system deamon (for server shutdown, crash, etc)
cat > /etc/systemd/system/dms.service << EOL
[Unit]
Description=DMS service
After=network.target
[Service]
User=root
Group=root
Type=forking
ExecStart=/root/dms/dmsd -daemon
ExecStop=/root/dms/dms-cli stop
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
sudo systemctl enable dms.service
sudo systemctl start dms.service

clear

#Set up enviroment variables
echo "Setting up enviromental commands..."
cd ~
mkdir .commands
echo "export PATH="$PATH:/root/.commands"" >> ~/.profile

cat > ~/.commands/gethelp << EOL
#!/bin/bash
echo ""
echo "Here is list of commands for you DMS service"
echo "you can type these commands anywhere in terminal."
echo ""
echo "Command              | What does it do?"
echo "---------------------------------------------------"
echo "getinfo              | Get wallet info"
echo ""
echo "mnstatus             | Status of the masternode sync"
echo ""
echo "dmsUpdate            | Update DMS deamon"
echo ""
echo "gethelp              | Show help"
echo "---------------------------------------------------"
echo ""

EOL

cat > ~/.commands/getinfo << EOL
#!/bin/bash    
~/dms/dms-cli getinfo
EOL

cat > ~/.commands/mnstatus << EOL
#!/bin/bash    
~/dms/dms-cli mnsync status
EOL

cat > ~/.commands/dmsUpdate << EOL
#!/bin/bash    
# Check if we are root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root! Aborting..." 1>&2
   exit 1
fi

sudo systemctl stop dms.service

rm -r ~/dms > /dev/null 2>&1
killall dmsd > /dev/null 2>&1
rm -r ~/dms > /dev/null 2>&1

cd ~
TARBALLURL=$(curl -s https://api.github.com/repos/Krekeler/documentchain/releases/latest | jq -r ".assets[] | select(.name | contains(\"x86_64-linux-gnu\")) | .browser_download_url")
TARBALLNAME=$(echo "${TARBALLURL}"|awk -F '/' '{print $NF}')
BOOTSTRAPURL=""
BOOTSTRAPARCHIVE=""
BWKVERSION="1.0.0"

wget $TARBALLURL
tar -xzvf $TARBALLNAME
rm $TARBALLNAME
rm -f ./dms-qt
rm -f ./test-dms
mkdir dms
mv ./dmsd ~/dms
mv ./dms-cli ~/dms
mv ./dms-tx ~/dms

sleep 5

sudo systemctl start dms.service

sleep 5

source ~/.profile

cat << "EOF"
            Update complete!

           |Brought to you by|         
  __  __ _  ____ _   _ _     ____ _____
 |  \/  / |/ ___| | | | |   / ___|__  /
 | |\/| | | |   | |_| | |  | |     / / 
 | |  | | | |___|  _  | |__| |___ / /_ 
 |_|  |_|_|\____|_| |_|_____\____/____|
       For complains Tweet @M1chl 


EOF

read -p "You may need run mnstart command to start a masternode after update. Press ENTER to continue " -n1 -s

echo ""
EOL

chmod +x /root/.commands/getinfo
chmod +x /root/.commands/mnstatus
chmod +x /root/.commands/dmsUpdate
chmod +x /root/.commands/gethelp

sleep 1
clear

echo "" && echo "Masternode setup complete" && echo ""
read -p "Press Enter to continue after read to continue. " -n1 -s
rm -rf ~/dmsMNinstall.sh
clear
