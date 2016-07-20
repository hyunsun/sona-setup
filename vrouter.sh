#!/bin/bash

onos=$1

# Remove existing ONOS container
echo "Remove existing ONOS-vRouter container"
sudo docker stop onos-vrouter
sudo docker rm onos-vrouter

# Run ONOS container
echo && echo "Run ONOS-vRouter container"
sudo docker pull onosproject/onos:1.6

if [ -z "$onos" ]; then
    sudo docker run -t -d --name onos-vrouter onosproject/onos:1.6
    onos=$(sudo docker inspect --format '{{ .NetworkSettings.IPAddress }}' 'onos-vrouter')
else
    sudo docker run -t -d --net=none --name onos-vrouter onosproject/onos:1.6
    sudo ~/docker-quagga/pipework docker0 -i eth0 onos-vrouter $1/24
fi

curl="curl --user onos:rocks"
netcfg_url="http://$onos:8181/onos/v1/network/configuration"
app_url="http://$onos:8181/onos/v1/applications"

ssh-keygen -f "/home/$(whoami)/.ssh/known_hosts" -R [$onos]:8101
echo && echo "Wait for ONOS-vRouter to start"
until $($curl -o /dev/null -s --fail -X POST $app_url/org.onosproject.netcfghostprovider/active); do
    printf '.'
    sleep 5
done
echo "Done"

# Push network config
echo && echo "Push network config"
$curl -X POST -H "Content-Type: application/json" $netcfg_url -d @vrouter.json

# Activate applications
echo "Activate ONOS apps"
$curl -X POST $app_url/org.onosproject.drivers/active
echo && $curl -sS -X POST $app_url/org.onosproject.openflow/active
echo && $curl -sS -X POST $app_url/org.onosproject.netcfghostprovider/active
echo && $curl -sS -X POST $app_url/org.onosproject.vrouter/active

echo && echo && echo "Finished setup ONOS-vRouter!"
echo "Access ONOS-vRouter with 'ssh -p 8101 karaf@$onos' password 'karaf'"
