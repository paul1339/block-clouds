#!/bin/bash
# This script will block all traffic from ASNs in below list
ASNS="132203 45090 20473 14061 9009 136258 135377 15169 16509 \
      14618 62785 7224 8987 63949 48337 23724 4808"

# Get args
args=("$@")
# Get the number of args
numargs=$#

# Check if we have the right number of args
if [ $numargs -lt 1 ]; then
    echo "Usage: $0 <init | flush | check | ping1>"
    exit 1
fi

# Check if we have the right args
if [ "${args[0]}" != "init" ] && [ "${args[0]}" != "flush" ] && [ "${args[0]}" != "check" ] && [ "${args[0]}" != "ping" ]; then
    echo "Usage: $0 <init | flush | check | ping2>"
    exit 1
fi

# Check if blacklist file exists 
if [ ! -f /etc/iptables/blacklist ]; then
    > $(pwd)/blacklist
fi

# Check if anew, mapcidr and iptables are installed 
if [ ! -f /go/bin/anew ] || [ ! -f /go/bin/mapcidr ] || [ ! -f /sbin/iptables ]; then
    echo "Please install anew, mapcidr and iptables"
    exit 1
fi


# Check if we are flushing or initializing
if [ ${args[0]} == "init" ]; then
    # Initialize the rules
    iptables -N BLOCK

    for ASN in $ASNS; do
        echo "Fetching AS$ASN"
        curl -s "https://api.bgpview.io/asn/$ASN/prefixes" | jq -r '.data.ipv4_prefixes[].prefix' | grep -v null | anew -q $(pwd)/blacklist
        sleep 0.5
    done

    # Aggregate the blacklist cidrs
    mv $(pwd)/blacklist $(pwd)/.blacklist_tmp
    cat $(pwd)/.blacklist_tmp | mapcidr -silent -a | anew -q $(pwd)/blacklist


    iptables -F
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT

    for IP in $(cat blacklist); do
        echo "Blocking $IP"
        #iptables -A INPUT -s $IP -j DROP
        iptables -A OUTPUT -d $IP -j DROP
    done

    #iptables-save

elif [ ${args[0]} == "flush" ]; then
    # Flush the rules
    iptables -F
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT

elif [ ${args[0]} == "check" ]; then
    # Check the rules
    X=$(iptables -L -n | grep DROP | wc -l)
    echo "There are $X rules"

elif [ ${args[0]} == "ping" ]; then
    if [ $numargs -ne 2 ]; then
        echo "Usage: $0 ping <ip>"
        exit 1
    fi
    echo "Pinging ${args[1]} ..."
    C=$(ping -c 1 ${args[1]} | grep "100% packet loss" | wc -l)
    if [ $C -eq 1 ]; then
        echo "Blocked"
    else
        echo "Not blocked"
    fi

else
    exit 1
fi