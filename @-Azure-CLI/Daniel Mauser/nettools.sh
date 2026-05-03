# This script has been tested on Ubuntu
# Update repository
sudo sed -i 's|http://za.archive.ubuntu.com/ubuntu|http://old-releases.ubuntu.com/ubuntu|g' /etc/apt/sources.list
sudo apt-get update
sudo apt-get upgrade
# NetTools
apt-get install net-tools -y
#Traceroute
apt-get install traceroute -y
# TCP traceroute
apt-get install tcptraceroute -y
# Nmap
apt-get install nmap -y
# Hping3
apt-get install hping3 -y
# iPerf
apt-get install iperf3 -y
# Nginx and adds machine name on main page
apt-get install nginx -y && hostname > /var/www/html/index.html
# Speedtest
apt-get install speedtest-cli -y
# Moreutils 
apt-get install moreutils -y
