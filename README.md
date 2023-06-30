# cvp-snmp-with-kubernetes
The goal of this project is to find a cleaner way to install SNMP monitoring ability on CVP.   
SNMP monitoring is a common access by big companies.   
Right now, our solution is described here: https://arista.my.site.com/AristaCommunity/s/article/snmpd-on-cvp  
This solution is not the best as it involves installing new RPM packages with yum: this could create issue at the next upgrade.  
The following project will install that in a Kubernetes pod to make it cleaner. 

# Installation process

## Step 1: Get the files in your CVP server in the /cvpi directory
### If within the Arista network you can git clone directly from the CVP server:
```
cd /cvpi/
git clone https://gitlab.aristanetworks.com/guillaume.vilar/cvp-snmp-monitor-with-kubernetes.git
cd cvp-snmp-monitor-with-kubernetes/
```
Otherwise, just download the package as a zip and copy it manually to the CVP server



## Step 3: Modify the snmpd.conf file to match your requirements.  
By default, the configuration file has the following content (using v2c and "testing" community string): 
```
$ cat snmpd.conf
rocommunity testing
syslocation “NewEngland”
syscontact "admin"
agentAddress udp:161
agentuser root
```

## Step 4: Create the Kubernetes deployment and service: 
```
kubectl apply -f deployment-snmpd.yaml
kubectl apply -f service-snmpd.yaml
```


## Step 5: Test from a remote device (for example an Arista switch)
```
$ snmpwalk -v2c -c testing 10.83.13.33:30161 HOST-RESOURCES-MIB::hrSystemUptime
```