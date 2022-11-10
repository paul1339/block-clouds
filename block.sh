#!/bin/bash
# This script will block all traffic from the cloud providers
ASNS="132203 45090 20473 14061 9009 136258 135377 15169 16509 14618 62785 7224 8987 63949 48337 23724 4808"

# Get args
args=("$@")
# Get the number of args
numargs=$#

# Check if we have the right number of args
if [ $numargs -ne 1 ]; then
    echo "Usage: $0 <init | flush>"
    exit 1
fi

# Check if we are flushing or initializing
if [ ${args[0]} == "init" ]; then
    # Initialize the rules
    rm -rf blacklist

    for ASN in $ASNS; do
        echo "Fetching $ASN"
        curl -s "https://bgpview.io/asn/$ASN#prefixes-v4" | grep -oE "([0-9]{1,3}[\.]){3}[0-9]{1,3}/[0-9]{1,2}" >> blacklist
    done

    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -F

    for IP in $(cat blacklist); do
        echo "Blocking $IP"
        iptables -A INPUT -s $IP -j DROP
        iptables -A OUTPUT -d $IP -j DROP
    done

    #/sbin/iptables-save
elif [ ${args[0]} == "flush" ]; then
    # Flush the rules
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -F
else
    exit 1
fi


#cat blacklist/aggregated.lst | sort -u >> /etc/zmap/blacklist.conf
echo "Updated /etc/zmap/blacklist.conf"
ping -c 5 178.79.131.141
