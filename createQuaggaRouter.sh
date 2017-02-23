#/usr/bin/bash

if [ -f "bgpd.conf" ]
then
    rm bgpd.conf
fi

if [ -f "zebra.conf" ]
then
    rm zebra.conf
fi

# Create bgpd.conf and zebra.conf for quagga-router
quaggaRouterName="router-01"
python -c "from sonaGatewaySetup import SonaGatewaySetup; handler = SonaGatewaySetup(); handler.createQuaggaRouterBgpdConf(\"$quaggaRouterName\"); handler.createQuaggaRouterZebraConf(\"$quaggaRouterName\")"

echo "Created bgpd.conf for quagga"
cat bgpd.conf
echo "Create zebra.conf for quagga"
cat zebra.conf

mv bgpd.conf ./volumes/router/bgpd.conf
mv zebra.conf ./volumes/router/zebra.conf

bgpNeighborIp=$(cat vRouterConfig.ini | grep bgpNeighborIp | awk '{print$3}' | sed "s/\"//g")
quaggaRouterMac="fa:00:00:00:00:01"

echo && echo "run /quagga.sh --name=$quaggaRouterName --ip=$bgpNeighborIp --mac=$quaggaRouterMac --external-router"
./quagga.sh --name=$quaggaRouterName --ip=$bgpNeighborIp --mac=$quaggaRouterMac --external-router

# Change updated uplinkPortNum in vRouterConfig.ini
uplinkPortNum=$(sudo ovs-ofctl dump-ports-desc br-router | grep quagga-router | awk -F'(' '{print $1}')
sed -i.bak '/uplinkPortNum/d' ./vRouterConfig.ini
printf 'uplinkPortNum = \"%d\"\n' $uplinkPortNum >> vRouterConfig.ini
echo && echo "Change updated uplinkPortNum in vRouterConfig.ini"
cat vRouterConfig.ini

# Change vrouter.json
portNumPatchRout=$(sudo ovs-ofctl dump-ports-desc br-router | grep patch-rout | awk -F'(' '{print $1}')
portNumQuagga=$(sudo ovs-ofctl dump-ports-desc br-router | grep quagga\) | awk -F'(' '{print $1}')
python -c "from sonaGatewaySetup import SonaGatewaySetup; handler = SonaGatewaySetup(); handler.createJson($portNumPatchRout, $portNumQuagga)"
python -mjson.tool vrouter.json.temp > vrouter.json
rm vrouter.json.temp

echo && echo "Changed vrouter.json"
cat vrouter.json

# Restart vRouter
./vrouter.sh
