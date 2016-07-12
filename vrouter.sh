#!/bin/bash

onos=$1

# Remove existing ONOS container
echo "Remove existing ONOS container"
sudo docker stop onos
sudo docker rm onos

# Run ONOS container
echo && echo "Run ONOS container"
sudo docker pull onosproject/onos

if [ -z "$onos" ]; then
    sudo docker run -t -d --name onos onosproject/onos
    onos=$(sudo docker inspect --format '{{ .NetworkSettings.IPAddress }}' 'onos')
else
    sudo docker run -t -d --net=none --name onos onosproject/onos
    sudo ~/docker-quagga/pipework docker0 -i eth0 onos $1/24
fi

curl="curl --user onos:rocks"
netcfg_url="http://$onos:8181/onos/v1/network/configuration"
app_url="http://$onos:8181/onos/v1/applications"

ssh-keygen -f "/home/$(whoami)/.ssh/known_hosts" -R [$onos]:8101
echo && echo "Wait for ONOS to start"
until $($curl -o /dev/null -s --fail -X POST $app_url/org.onosproject.drivers/active); do
    printf '.'
    sleep 5
done
echo "Done"

# Push network config
echo && echo "Push network config"
$curl -X POST -H "Content-Type: application/json" $netcfg_url -d @network-cfg.json

# Activate applications
echo "Activate ONOS apps"
$curl -X POST $app_url/org.onosproject.drivers/active
echo && $curl -sS -X POST $app_url/org.onosproject.openflow/active
echo && $curl -sS -X POST $app_url/org.onosproject.netcfghostprovider/active
echo && $curl -sS -X POST $app_url/org.onosproject.vrouter/active

echo && echo && echo "Finished setup ONOS!"
echo "Access ONOS with 'ssh -p 8101 karaf@$onos' password 'karaf'"
