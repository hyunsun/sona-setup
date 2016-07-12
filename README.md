# SONA
SONA is a project implements OpenStack Neutron ML2 mechanism driver and L3 service plugin with ONOS(onosproject.org). See https://wiki.onosproject.org/display/ONOS/DC+Network+Virtualization for the details.
Here it describes how to set up a gateway node for SONA. 

# SONA Gateway Node
SONA gateway node is composed of a couple of bridge controlled by `SONA ONOS` and `vRouter ONOS` respectively. SONA ONOS takes care of creating the bridges and patch link between the bridges, and flow rules on the `br-int` bridge. vRouter ONOS, on the other hand, takes care of flow rules on `br-router` and communications with external routers.
![](https://66.media.tumblr.com/f41999bd5184bbdb437071981e0d6379/tumblr_oa7tlwI2nz1s0jpjfo1_1280.png)

# SONA ONOS setup
Prepare the network configuration file for SONA with information about compute and gateway nodes. There is an example named with `sona.json` in this repository. Activate SONA applications and push the network configuration file to running ONOS. Note that `routerController` field in each gateway node will be used to bring up vRouter ONOS later. This address does not span gateway nodes so you can use the same address for all gateways.
```
# activate applications
$ curl --user onos:rocks -X POST http://onos:8181/onos/v1/applications/org.onosproject.drivers/active
$ curl --user onos:rocks -X POST http://onos:8181/onos/v1/applications/org.onosproject.openflow/active
$ curl --user onos:rocks -X POST http://onos:8181/onos/v1/applications/org.onosproject.networking/active

# push network config
$ curl --user onos:rocks -X POST -H "Content-Type: application/json" http://onos:8181/onos/v1/network/configuration/ -d @sona.json
```
Check the nodes states are `COMPLETE`. Use `openstack-node-check` command for more detailed states of the node. Pushing network configuration triggers reinitialize the nodes. It's no harm to reinitialize COMPLETE state node. If you want to reinitialize a particular compute node, use `openstack-node-init` command with hostname.
```
onos> openstack-nodes
hostname=compute-01, type=COMPUTE, managementIp=10.203.25.244, dataIp=10.134.34.222, intBridge=of:00000000000000a1, routerBridge=Optional.empty init=COMPLETE
hostname=compute-02, type=COMPUTE, managementIp=10.203.229.42, dataIp=10.134.34.223, intBridge=of:00000000000000a2, routerBridge=Optional.empty init=COMPLETE
hostname=gateway-01, type=GATEWAY, managementIp=10.203.198.125, dataIp=10.134.33.208, intBridge=of:00000000000000a3, routerBridge=Optional[of:00000000000000b1] init=COMPLETE
hostname=gateway-02, type=GATEWAY, managementIp=10.203.198.131, dataIp=10.134.33.209, intBridge=of:00000000000000a4, routerBridge=Optional[of:00000000000000b2] init=COMPLETE
Total 4 nodes
```

# vRouter ONOS setup
Prepare network configuration file for vRouter with external connection information. There is an example named with `vrouter.json` in this repository. Refer to the ONOS wiki for the details about vRouter application(https://wiki.onosproject.org/display/ONOS/vRouter) and modify the file as you want. Now run `vrouter.sh` script with the `routerController` address in `sona.json`. 
```
$ vrouter.sh 172.17.0.2
```
Check `fpm-connections`, `hosts`, and `devices`.
