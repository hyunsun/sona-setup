#/usr/bin/bash

if [ -f "vrouter.json" ]
then
    rm vrouter.json
fi

if [ -f "vrouter.json.temp" ]
then
    rm vrouter.json.temp
fi

# Create vrouter.json
portNumPatchRout=$(sudo ovs-ofctl dump-ports-desc br-router | grep patch-rout | awk -F'(' '{print $1}')
portNumQuagga=$(sudo ovs-ofctl dump-ports-desc br-router | grep quagga\) | awk -F'(' '{print $1}')
if [ -z "$portNumQuagga" ];
then
   portNumQuagga="None"
fi
 
python -c "from sonaGatewaySetup import SonaGatewaySetup; handler = SonaGatewaySetup(); handler.createJson($portNumPatchRout, $portNumQuagga)"
python -mjson.tool vrouter.json.temp > vrouter.json
rm vrouter.json.temp

echo "Created vrouter.json"
cat vrouter.json

# Start vRouter
./vrouter.sh





