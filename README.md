# SONA
SONA is a project implements OpenStack Neutron ML2 mechanism driver and L3 service plugin with ONOS(onosproject.org). See https://wiki.onosproject.org/display/ONOS/DC+Network+Virtualization for the details.
Here it describes how to set up a gateway node for SONA. 

# SONA Gateway Node
SONA gateway node is composed of a couple of bridge controlled by `ONOS-SONA` and `ONOS-vRouter` respectively. SONA ONOS takes care of creating the bridges and patch link between the bridges, and flow rules on the `br-int` bridge. vRouter ONOS, on the other hand, takes care of flow rules on `br-router` and communications with external routers.
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
Check the nodes states are `COMPLETE`. Use `openstack-node-check` command for more detailed states of the node. Pushing network configuration triggers reinitialization of the nodes. It's no harm to reinitialize COMPLETE state node. If you want to reinitialize a particular compute node, use `openstack-node-init` command with hostname.
```
onos> openstack-nodes
hostname=compute-01, type=COMPUTE, managementIp=10.203.25.244, dataIp=10.134.34.222, intBridge=of:00000000000000a1, routerBridge=Optional.empty init=COMPLETE
hostname=compute-02, type=COMPUTE, managementIp=10.203.229.42, dataIp=10.134.34.223, intBridge=of:00000000000000a2, routerBridge=Optional.empty init=COMPLETE
hostname=gateway-01, type=GATEWAY, managementIp=10.203.198.125, dataIp=10.134.33.208, intBridge=of:00000000000000a3, routerBridge=Optional[of:00000000000000b1] init=COMPLETE
hostname=gateway-02, type=GATEWAY, managementIp=10.203.198.131, dataIp=10.134.33.209, intBridge=of:00000000000000a4, routerBridge=Optional[of:00000000000000b2] init=COMPLETE
Total 4 nodes
```

# vRouter ONOS setup
**Quagga**<br>Modify `volumes/gateway/zebra.conf` and `volumes/gateway/bgpd.conf` as you want. Note that `fpm connection ip` in `zebra.conf` should be the same with `routerController`.<br>Run Quagga container with the IP address, which equals to `router-id` in `bgpd.conf` and any MAC address. This MAC address will be used in `vrouter.json` later.
```
$ ./quagga.sh --name=gateway-01 --ip=172.18.0.254/24 --mac=fe:00:00:00:00:01
```
If you check the result of `ovs-vsctl show`, there should be a new port named `quagga` on `br-router` bridge.
<br><br>
**External Router**<br>
If there's no external router in your setup, add another quagga container in ecah gateway node, which acts as an external router.<br>Modify `volumes/router/zebra.conf` and `volumes/router/bgpd.conf` as you want, and use the same command above but with additional argument `--external-router` to bring up the router container.
```
$ ./quagga.sh --name=router-01 --ip=172.18.0.1/24 --mac=fa:00:00:00:00:01 --external-router
```
<br><br>
**vRouter ONOS**<br>
Prepare network configuration file for vRouter with external connection information. One example is `vrouter.json` in this repository. For more details about vRouter, check out https://wiki.onosproject.org/display/ONOS/vRouter.<br>Now run `vrouter.sh` script with the `routerController` IP address to bring up `ONOS-vRouter` container. The same command can be used to re-run the container.
```
$ vrouter.sh 172.17.0.3
```
Check `ports`.
```
$ ssh -p 8101 karaf@172.17.0.3
# password is karaf

onos> ports
id=of:00000000000000b1, available=true, role=MASTER, type=SWITCH, mfr=Nicira, Inc., hw=Open vSwitch, sw=2.3.0, serial=None, driver=softrouter, channelId=172.17.0.1:58292, managementAddress=172.17.0.1, name=of:00000000000000b1, protocol=OF_13
  port=local, state=disabled, type=copper, speed=0 , portName=br-router, portMac=e6:a0:79:f9:d1:4a
  port=1, state=enabled, type=copper, speed=0 , portName=patch-rout, portMac=fe:da:85:15:b1:bf
  port=2, state=enabled, type=copper, speed=10000 , portName=veth1, portMac=a2:fe:d4:6a:e9:c1
  port=24, state=enabled, type=copper, speed=10000 , portName=quagga, portMac=06:96:1b:36:32:77
  port=25, state=enabled, type=copper, speed=10000 , portName=quagga-router, portMac=ea:1e:71:d1:fd:81
```
If any port number does not match to the ones in `vrouter.json`, modify the config file with the correct port numbers.
* port number of `quagga` -> `controlPlaneConnectPoint` of router config
* port number of `quagga-router` -> `ports` of interface with `172.18.0.254/24` IP address
* port number of `veth1` (set via `uplinkPort` field in `sona.json`) -> `ports` of interface with `192.168.0.254/24`
Once you modify `vrouter.json`, re-run the ONOS-vRouter.
```
$ vrouter.sh 172.17.0.3
```

If everything's right, check `fpm-connections`, `hosts` and `routes`. `172.18.0.1` is the external default gateway in this example. The host with IP address `192.168.0.1` is for the internal network which will explain later.
```
onos> hosts
id=FA:00:00:00:00:01/None, mac=FA:00:00:00:00:01, location=of:00000000000000b1/2, vlan=None, ip(s)=[172.18.0.1]
id=FE:00:00:00:00:01/None, mac=FE:00:00:00:00:01, location=of:00000000000000b1/12, vlan=None, ip(s)=[172.18.0.254]
id=FE:00:00:00:00:02/None, mac=FE:00:00:00:00:02, location=of:00000000000000b1/1, vlan=None, ip(s)=[192.168.0.1], name=FE:00:00:00:00:02/None

onos> fpm-connections
172.17.0.2:52332 connected since 6m ago

onos> next-hops
ip=172.18.0.1, mac=FA:00:00:00:00:01, numRoutes=1

onos> routes
Table: ipv4
   Network            Next Hop
   0.0.0.0/0          172.18.0.1
   Total: 1

Table: ipv6
   Network            Next Hop
   Total: 0
```
**Register internal network**<br>
Now let's add routes for the internal network, `192.168.0.0/24` in this example. This network might be the `floating IP` range in Neutron data model.<br>First, define fake `host` and `interface` for the internal network gateway to the network config file, and push it to the `ONOS-vRouter` (or you can re-run `ONOS-vRouter`). The port number should equal to the one of `patch-rout` port. (Example `vrouter.json` already has the configuration and you don't need to do it again if it's already set correctly)
```
# vrouter.json
    "hosts" : {
        "fe:00:00:00:00:02/-1" : {
            "basic": {
                "ips": ["192.168.0.1"],
                "location": "of:00000000000000b1/1"
            }
        }
    }
    
    "ports" : {
        "of:00000000000000b1/1" : {
            "interfaces" : [
                {
                    "name" : "b1-2",
                    "ips"  : [ "192.168.0.254/24" ],
                    "mac"  : "fe:00:00:00:00:01"
                }
            ]
        }

# push network config
$ curl --user onos:rocks -X POST http://172.17.0.3:8181/onos/v1/network/configuration -d @vrouter.json

# or simply re-run the container
$ ./vrouter.sh 172.17.0.3

onos> hosts
id=FA:00:00:00:00:01/None, mac=FA:00:00:00:00:01, location=of:00000000000000b1/2, vlan=None, ip(s)=[172.18.0.1]
id=FE:00:00:00:00:01/None, mac=FE:00:00:00:00:01, location=of:00000000000000b1/12, vlan=None, ip(s)=[172.18.0.254]
id=FE:00:00:00:00:02/None, mac=FE:00:00:00:00:02, location=of:00000000000000b1/1, vlan=None, ip(s)=[192.168.0.1], name=FE:00:00:00:00:02/None
```
Add route.
```
onos> route-add 192.168.0.0/24 192.168.0.1

onos> routes
Table: ipv4
   Network            Next Hop
   0.0.0.0/0          172.18.0.1
   192.168.0.0/24     192.168.0.1
   Total: 2

Table: ipv6
   Network            Next Hop
   Total: 0
   
onos> next-hops
ip=172.18.0.1, mac=FA:00:00:00:00:01, numRoutes=1
ip=192.168.0.1, mac=FE:00:00:00:00:02, numRoutes=1
```
