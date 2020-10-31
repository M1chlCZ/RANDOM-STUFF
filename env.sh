echo "Setting up enviromental commands..."
cd ~
mkdir ~/.commands
echo "export PATH="$PATH:~/.commands"" >> ~/.profile

cat > ~/.commands/gethelp << EOL
#!/bin/bash
echo ""
echo "Here is list of commands for you ShroudX service"
echo "you can type these commands anywhere in terminal."
echo ""
echo "Command              | What does it do?"
echo "---------------------------------------------------"
echo "info                 | Get wallet info"
echo ""
echo "status               | Shroudnode status"
echo ""
echo "nodes                | Shroudnode count"
echo ""
echo "connections          | Number of connections"
echo ""
echo "insync               | Status of insync"
echo ""
echo "start                | Start ShroudX deamon"
echo ""
echo "stop                 | Stops ShroudX deamon"
echo ""
echo "peerinfo             | Peer info"
echo ""
echo "baninfo              | List of banned nodes"
echo ""
echo "clearbans            | Unban nodes"
echo ""
echo "shroudUpdate         | Update ShroudX deamon"
echo ""
echo "commandUpdate        | Update list of available commands"
echo ""
echo "help                 | Show help"
echo "---------------------------------------------------"
echo ""


EOL

cat > ~/.commands/info << EOL
#!/bin/bash    
~/ShroudX/shroud-cli getinfo
EOL

cat > ~/.commands/status << EOL
#!/bin/bash    
~/ShroudX/shroud-cli shroudnode status
EOL

cat > ~/.commands/nodes << EOL
#!/bin/bash    
~/ShroudX/shroud-cli shroudnode count
EOL

cat > ~/.commands/connections << EOL
#!/bin/bash    
~/ShroudX/shroud-cli getconnectioncount
EOL

cat > ~/.commands/insync << EOL
#!/bin/bash    
~/ShroudX/shroud-cli insync status
EOL

cat > ~/.commands/start << EOL
#!/bin/bash    
systemctl start ccash.service > /dev/null 2>&1
EOL

cat > ~/.commands/stop << EOL
#!/bin/bash    
systemctl stop ccash.service > /dev/null 2>&1
EOL

cat > ~/.commands/peerinfo << EOL
#!/bin/bash    
~/ShroudX/shroud-cli getpeerinfo
EOL

cat > ~/.commands/baninfo << EOL
#!/bin/bash    
~/ShroudX/shroud-cli listbanned
EOL

cat > ~/.commands/clearbans << EOL
#!/bin/bash    
~/ShroudX/shroud-cli clearbanned
EOL

cat > ~/.commands/commandUpdate << EOL
#!/bin/bash
cd ~ 
wget https://raw.githubusercontent.com/M1chlCZ/CampusCash-MN-install/main/env.sh > /dev/null 2>&1
source env.sh
clear

cat << "EOF"
            Update complete!

           |Brought to you by|         
  __  __ _  ____ _   _ _     ____ _____
 |  \/  / |/ ___| | | | |   / ___|__  /
 | |\/| | | |   | |_| | |  | |     / / 
 | |  | | | |___|  _  | |__| |___ / /_ 
 |_|  |_|_|\____|_| |_|_____\____/____|
       For complains Tweet @M1chl 

SHROUD: SYjaWy3Zh1HjTqeKydzs6fExBWT57qfJLz

EOF

. ~/.commands/help

echo ""
EOL

cat > ~/.commands/shroudUpdate << EOL
#!/bin/bash    
# Check if we are root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root! Aborting..." 1>&2
   exit 1
fi

sudo systemctl stop shroud.service

rm -r ~/ShroudX > /dev/null 2>&1
killall shroudd > /dev/null 2>&1

cd ~
TARBALLURL=$(curl -s https://api.github.com/repos/ShroudProtocol/ShroudX/releases/latest | jq -r ".assets[] | select(.name | contains(\"x86_64-ubuntu\")) | .browser_download_url")
TARBALLNAME=$(echo "${TARBALLURL}"|awk -F '/' '{print $NF}')
BOOTSTRAPURL=""
BOOTSTRAPARCHIVE=""
BWKVERSION="1.0.0"

wget $TARBALLURL
tar -xzvf $TARBALLNAME
rm $TARBALLNAME
rm -f ./shroud-qt
mkdir ShroudX
mv ./shroudd ~/ShroudX
mv ./shroud-cli ~/ShroudX
mv ./shroud-tx ~/ShroudX
mv ./tor ~/ShroudX

sleep 5

sudo systemctl start shroud.service

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

read -p "Press ENTER to continue " -n1 -s

echo ""
EOL

chmod +x /root/.commands/getinfo
chmod +x /root/.commands/mnstatus
chmod +x /root/.commands/shroudUpdate
chmod +x /root/.commands/gethelp

sleep 1
clear