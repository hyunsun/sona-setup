#!/bin/bash

# Prints usage help
function usage {
    echo "usage: quagga.sh --name=gateway-01 --ip=172.18.0.254/24 --mac=fe:00:00:00:00:01 [--bridge=br-router]" >&2
    echo "       -h --help"
    echo "       -n --name    name of the quagga container"
    echo "       -i --ip      IP address for peering"
    echo "       -m --mac     MAC address for peering interface"
    echo "       -b --bridge  bridge name to add peering interface, br-router is used by default"
    exit 1
}

while [ "$1" != "" ]; do
    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | awk -F= '{print $2}'`
    case $PARAM in
        -h | --help)
            usage
            exit
            ;;
        -n | --name)
            CONTAINER_NAME=$VALUE
            ;;
        -i | --ip)
            ETH1_IP_CIDR=$VALUE
            ;;
        -m | --mac)
            ETH1_MAC=$VALUE
            ;;
        -b | --bridge)
            BRIDGE_NAME=$VALUE
            ;;
        --no-default)
            DEFAULT=false
            ;;
        *)
            echo "ERROR: unknown parameter \"$PARAM\""
            usage
            exit 1
            ;;
    esac
    shift
done

if [ -z $CONTAINER_NAME ]; then
  usage
  exit 1
fi

if [ -z $ETH1_IP_CIDR ]; then
  usage
  exit 1
fi

if [ -z $ETH1_MAC ]; then
  usage
  exit 1
fi

if [ -z $BRIDGE_NAME ]; then
  BRIDGE_NAME="br-router"
fi

# clean up existing container with same name and IP
sudo docker pull hyunsun/quagga-fpm
sudo docker stop $CONTAINER_NAME
sudo docker rm $CONTAINER_NAME
sudo ovs-vsctl del-port quagga

sudo docker run --privileged --cap-add=NET_ADMIN --cap-add=NET_RAW --name $CONTAINER_NAME --hostname $CONTAINER_NAME -d -v ~/sona-setup/quagga:/usr/etc hyunsun/quagga-fpm
sudo ~/sona-setup/pipework $BRIDGE_NAME -i eth1 -l quagga $CONTAINER_NAME $ETH1_IP_CIDR $ETH1_MAC
sudo docker exec -d $CONTAINER_NAME iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo docker exec -d $CONTAINER_NAME route del default gw 172.17.0.1
