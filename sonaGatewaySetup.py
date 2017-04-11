#!usr/bin/python
import json
import ipaddress
from oslo_config import cfg

class SonaGatewaySetup:

    def __init__(self):
        CONFIG_FILE = 'vRouterConfig.ini'
    
        CONF = cfg.CONF
        default_group = cfg.OptGroup(name='DEFAULT')
        default_conf = [cfg.StrOpt('routerBridge'),
            cfg.StrOpt('floatingCidr'),
            cfg.StrOpt('quaggaMac'),
            cfg.StrOpt('quaggaIp'),
            cfg.StrOpt('uplinkPortNum'),
            cfg.StrOpt('gatewayName'),
            cfg.StrOpt('bgpNeighborIp'),
            cfg.StrOpt('asNum'),
            cfg.StrOpt('peerAsNum')]
    
    
        CONF.register_group(default_group)
        CONF.register_opts(default_conf, default_group)
        CONF(default_config_files=[CONFIG_FILE])
    
        self.routerBridge = CONF.DEFAULT.routerBridge
        self.floatingCidr = CONF.DEFAULT.floatingCidr.split(",")
        self.quaggaMac = CONF.DEFAULT.quaggaMac
        self.quaggaIp = CONF.DEFAULT.quaggaIp
        self.uplinkPortNum = CONF.DEFAULT.uplinkPortNum
        self.gatewayName = CONF.DEFAULT.gatewayName
        self.bgpNeighborIp = CONF.DEFAULT.bgpNeighborIp
        self.asNum = CONF.DEFAULT.asNum
        self.peerAsNum = CONF.DEFAULT.peerAsNum
    
    def createJson(self, portNumPatchRout, portNumQuagga):
    #Initialize
        data = dict()
        if portNumQuagga == None:
            portNumQuagga = 3
        hostMac = "fe:00:00:00:00:02/-1"
    
    #apps
        interfacesList = list()
        interfacesList.append("b1-1")
        interfacesList.append("b1-2")
        routerDict = dict()
        routerDict["controlPlaneConnectPoint"] = self.routerBridge + "/" + str(portNumQuagga)
        routerDict["interfaces"] = interfacesList
        routerDict["ospfEnabled"] = "true"
    
        orgOnosprojectRouterDict = dict()
        orgOnosprojectRouterDict["router"] = routerDict
    
        appsDict = dict()
        appsDict["org.onosproject.router"] = orgOnosprojectRouterDict
    
        data["apps"] = appsDict
    
    # devices
        driverDict = dict()
        driverDict["driver"] = "softrouter"
        basicDict = dict()
        basicDict["basic"] = driverDict
    
        routerBridgeDict = dict()
        routerBridgeDict[self.routerBridge] = basicDict
    
        data["devices"] = routerBridgeDict
    
    # hosts
        ipList = list()
        for ip in self.floatingCidr:
            ipList.append(str(ipaddress.ip_network(unicode(ip))[1]))
        basicDict = dict()
        basicDict["ips"] = ipList
        basicDict["location"] = self.routerBridge + "/" + str(portNumPatchRout)
    
        hostMacDict = dict()
        hostMacDict["basic"] =basicDict
    
        hostDict = dict()
        hostDict[hostMac] = hostMacDict
    
        data["hosts"] = hostDict
    
    # ports
        ipList = list()
        for ip in self.floatingCidr:
            ipList.append(str(ipaddress.ip_network(unicode(ip))[-2]) + "/" + ip.split("/")[1])

        interfaceDict = dict()
        interfaceDict["ips"] = ipList
        interfaceDict["mac"] = self.quaggaMac
        interfaceDict["name"] = "b1-2"
    
        interfaceList = list()
        interfaceList.append(interfaceDict)
    
        patchRoutInterfaceDict = dict()
        patchRoutInterfaceDict["interfaces"] = interfaceList
    
        portDict = dict()
        portDict[self.routerBridge + "/" + str(portNumPatchRout)] = patchRoutInterfaceDict
    
        ipList = list()
        ipList.append(self.quaggaIp)
        interfaceDict = dict()
        interfaceDict["ips"] = ipList
        interfaceDict["mac"] = self.quaggaMac
        interfaceDict["name"] = "b1-1"
    
        interfaceList = list()
        interfaceList.append(interfaceDict)
    
        uplinkInterfaceDict = dict()
        uplinkInterfaceDict["interfaces"] = interfaceList
    
        portDict[self.routerBridge + "/" + self.uplinkPortNum] = uplinkInterfaceDict
    
        data["ports"] = portDict
    
        with open("vrouter.json.temp", "w") as jsonFile:
            jsonFile.write(json.dumps(data))
            jsonFile.close()
    
    def createBgpdConf(self):
        f = open("bgpd.conf", "w")
        f.write("hostname %s\n" %self.gatewayName)
        f.write("password zebra\n\n")
        f.write("router bgp %s\n" %self.asNum)
        f.write("  bgp router-id %s\n" %self.quaggaIp.split("/")[0])
        f.write("  timers bgp 3 9\n")
        f.write("  neighbor %s remote-as %s\n" %(self.bgpNeighborIp.split("/")[0], self.peerAsNum))
        f.write("  neighbor %s ebgp-multihop\n" %self.bgpNeighborIp.split("/")[0])
        f.write("  neighbor %s timers connect 5\n" %self.bgpNeighborIp.split("/")[0])
        f.write("  neighbor %s advertisement-interval 5\n" %self.bgpNeighborIp.split("/")[0])
        for ipRange in self.floatingCidr:
            f.write("  network %s\n" %ipRange)

        f.write("\nlog file /var/log/quagga/bgpd.log\n")
        f.close()

    def createZebraConf(self, onosIp):
        f = open("zebra.conf", "w")
        f.write("hostname %s\n" %self.gatewayName)
        f.write("password zebra\n\n")
        f.write("fpm connection ip %s port 2620\n" %onosIp)
        f.close()

    def jsonModInCaseQuaggaRestarted(self, portNum):
        with open("vrouter.json", "r") as jsonFile:
            data = json.load(jsonFile)
            jsonFile.close()

        data["apps"]["org.onosproject.router"]["router"]["controlPlaneConnectPoint"] = self.routerBridge + "/"  + str(portNum)

        with open("vrouter.json", "w") as jsonFile:
            jsonFile.write(json.dumps(data))
            jsonFile.close()

    def createQuaggaRouterBgpdConf(self, quaggaRouterName):
        f = open("bgpd.conf", "w")
        f.write("hostname %s\n" %quaggaRouterName)
        f.write("password zebra\n\n")
        f.write("router bgp %s\n" %self.peerAsNum)
        f.write("  bgp router-id %s\n" %self.bgpNeighborIp.split("/")[0])
        f.write("  timers bgp 3 9\n")
        f.write("  neighbor %s remote-as %s\n" %(self.quaggaIp.split("/")[0], self.asNum))
        f.write("  neighbor %s ebgp-multihop\n" %self.quaggaIp.split("/")[0])
        f.write("  neighbor %s timers connect 5\n" %self.quaggaIp.split("/")[0])
        f.write("  neighbor %s advertisement-interval 5\n" %self.quaggaIp.split("/")[0])
        f.write("  neighbor %s default-originate\n\n" %self.quaggaIp.split("/")[0])
        f.write("log file /var/log/quagga/bgpd.log\n")
        f.close()

    def createQuaggaRouterZebraConf(self, quaggaRouterName):
        f = open("zebra.conf", "w")
        f.write("hostname %s\n" %quaggaRouterName)
        f.write("password zebra\n\n")
        f.close()

    
