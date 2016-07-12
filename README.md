# SONA
SONA is a project implements OpenStack Neutron ML2 mechanism driver and L3 service plugin with ONOS(onosproject.org). See https://wiki.onosproject.org/display/ONOS/DC+Network+Virtualization for the details.
Here it describes how to set up a gateway node for SONA. 

# SONA Gateway Node
SONA gateway node is composed of a couple of bridge controlled by `SONA ONOS` and `vRouter ONOS` respectively. SONA ONOS takes care of creating the bridges and patch link between the bridges, and flow rules on the `br-int` bridge. vRouter ONOS, on the other hand, takes care of flow rules on `br-router` and communications with external routers.
![](https://66.media.tumblr.com/f41999bd5184bbdb437071981e0d6379/tumblr_oa7tlwI2nz1s0jpjfo1_1280.png)

# SONA ONOS setup
Prepare the network configuration file for SONA with the information about compute and gateway nodes. There is an example named with `sona.json` in this repository. Now activate SONA applications and push the network configuration file to running ONOS.<br>Note that `routerController` field will be used to bring up `vRouter ONOS` later. This address does not span gateway nodes, that is, you can use the same address in multiple gateway nodes.
```
# activate applications
$ curl --user onos:rocks -X POST http://onos_ip:8181/onos/v1/applications/org.onosproject.drivers/active
$ curl --user onos:rocks -X POST http://onos_ip:8181/onos/v1/applications/org.onosproject.openflow/active
$ curl --user onos:rocks -X POST http://onos_ip:8181/onos/v1/applications/org.onosproject.networking/active

# push network config
$ curl --user onos:rocks -X POST -H "Content-Type: application/json" http://onos_ip:8181/onos/v1/network/configuration/ -d @sona.json
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
**Quagga**<br>Modify `quagga/zebra.conf` and `quagga/bgpd.conf`. Note that `fpm connection ip` in `zebra.conf` should be the same with `routerController`.<br>Run Quagga container with the IP address, which equals to `router-id` in `bgpd.conf` and any MAC address. This MAC address will be used in `vrouter.json` later.
```
$ /quagga.sh --name=gateway-01 --ip=172.18.0.254/24 --mac=fe:00:00:00:00:01
```
If you check the result of `ovs-vsctl show`, there should be a new port named `quagga` on `br-router` bridge.
<br><br>
**vRouter ONOS**<br>
Prepare network configuration file for vRouter with external connection information. One example is `vrouter.json` in this repository. For more details about vRouter, check out https://wiki.onosproject.org/display/ONOS/vRouter.<br>Now run `vrouter.sh` script with the `routerController` IP address. The same command can be used to re-run the container.
```
$ vrouter.sh 172.17.0.3
```
Check `ports` and `hosts`.
```
$ ssh -p 8101 karaf@172.17.0.3
# password is karaf

onos> ports
id=of:00000000000000b1, available=true, role=MASTER, type=SWITCH, mfr=Nicira, Inc., hw=Open vSwitch, sw=2.3.0, serial=None, driver=softrouter, channelId=172.17.0.1:56160, managementAddress=172.17.0.1, name=of:00000000000000b1, protocol=OF_13
  port=local, state=disabled, type=copper, speed=0 , portName=br-router, portMac=e6:a0:79:f9:d1:4a
  port=1, state=enabled, type=copper, speed=0 , portName=patch-rout, portMac=fe:da:85:15:b1:bf
  port=2, state=enabled, type=copper, speed=10000 , portName=veth1, portMac=a2:fe:d4:6a:e9:c1
  port=4, state=enabled, type=copper, speed=10000 , portName=quagga, portMac=5e:ba:a0:ae:f9:98
```
If any port number does not match to the ones in `vrouter.json`, modify the config file with the correct port numbers.
* port number of `quagga` -> `controlPlaneConnectPoint` of router config
* port number of `veth1` (set via `uplinkPort` field in `sona.json`) -> listed in `ports`
* port number of `patch-rout` -> `hosts`
Once you modify `vrouter.json`, re-run the ONOS-vRouter.
```
$ vrouter.sh 172.17.0.3
```
Once everything goes well, you should be able to see routes from external router with `routes` command.
```
onos> routes
Table: ipv4
   Network            Next Hop
   0.0.0.0/0          172.18.0.1
   Total: 1

Table: ipv6
   Network            Next Hop
   Total: 0
```
