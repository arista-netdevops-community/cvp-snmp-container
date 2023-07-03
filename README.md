# cvp-snmp-with-kubernetes
The goal of this project is to find a cleaner way to install snmpd package on CVP: we would like a remote management SNMP system to be able to monitor basic CVP server information (CPU, memory, etc ...).
Right now, our solution is described here: https://arista.my.site.com/AristaCommunity/s/article/snmpd-on-cvp  
This solution is not the best as it involves installing new RPM packages with yum: this could create issue at the next upgrade.
Moreover, the package installed (snmpd version 5.7), doesn't support modern cryptographic algorithm.   
The following project will install snmpd in a Kubernetes pod to make a cleaner and easier to maintain solution. 

# Warning: Work in progress

# Warning 2: Kubeneretes will expose by default the port UDP 30161. So this port needs to be used from the remote devices (NMS system for example).

# Installation process

## Step 1: Get the files in your CVP server in the /cvpi directory
### If within the Arista network you can download it directly from the CVP server to the primary node:
```
su cvp
cd /cvpi/
wget https://gitlab.aristanetworks.com/guillaume.vilar/cvp-snmp-monitor-with-kubernetes/-/archive/main/cvp-snmp-monitor-with-kubernetes-main.tar.gz
tar -xf cvp-snmp-monitor-with-kubernetes-main.tar.gz
cd cvp-snmp-monitor-with-kubernetes-main/

```
Otherwise, just download the package as a .tar.gz to your computer and scp it manually to the CVP server.  

## Step 2: Modify the snmpd.conf files to match your requirements.  

By default, the configuration files have the following content (using v2c "testing" community string, and v3 arista user): 
```
# Global information
sysname "arista-cvp-server-1"
syslocation "arista-cvp-location"
syscontact "admin"
agentAddress udp:161

# For SNMPv2c
agentuser root
rocommunity testing

# For SNMPv3:
createUser arista SHA-512 "arista1234" AES-256 "arista1234"
rouser arista
```

## Step 3: Copy the config file to the correct location.
```
su cvp
cp snmpd.conf /cvpi/snmpd.conf
```

## Step 4: Load the container image.
For CVP version >= 2022.3.0 :
```
tar -xf net_snmp_image-v5.9.tar.gz && sudo ctr image import net_snmp_image

# Verification: 
sudo nerdctl image ls  | grep snmp
```

For older CVP version, use the following command: 
```
tar -xf net_snmp_image-v5.9.tar.gz && sudo docker load -i net_snmp_image

# Verification:
sudo docker image ls | grep snmp
```

## Step 5: If in a multi-node cluster, repeat Step 1, 2, 3 and 4 on the secondary node and tertiary node.

## Step 6: Create the Kubernetes deployment and service: 
This needs to be run only on the primary server.
```
kubectl apply -f snmpd-monitor.yaml
```


## Step 7: Validation 
## From the CVP server, we can verify the status of the pods, deployment and service:

```
kubectl get pods -l app=snmpd-monitor -o wide 
kubectl get daemonset -l app=snmpd-monitor
kubectl get service -l app=snmpd-monitor
```
Expected output:
```
$ kubectl get pods -l app=snmpd-monitor -o wide 
NAME                  READY   STATUS    RESTARTS   AGE     IP             NODE                               NOMINATED NODE   READINESS GATES
snmpd-monitor-jg9v6   1/1     Running   0          3m46s   10.42.40.144   cva-3-cvp.ire.aristanetworks.com   <none>           <none>
snmpd-monitor-l66jt   1/1     Running   0          3m46s   10.42.8.190    cva-2-cvp.ire.aristanetworks.com   <none>           <none>
snmpd-monitor-nlxxf   1/1     Running   0          3m46s   10.42.65.128   cva-1-cvp.ire.aristanetworks.com   <none>           <none>

$ kubectl get daemonset -l app=snmpd-monitor
NAME            DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
snmpd-monitor   3         3         3       3            3           <none>          30s

$ kubectl get service -l app=snmpd-monitor
NAME            TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)         AGE
snmpd-monitor   NodePort   10.42.217.23   <none>        161:30161/UDP   18s

```

## from a remote device (for example an Arista switch) do a SNMP query:
```
# Get sysname
switch#bash snmpwalk -v2c -c testing 172.28.161.170:30161 1.3.6.1.2.1.1.5.0
SNMPv2-MIB::sysName.0 = STRING: "arista-cvp-server-1"

# Get uptime
switch#bash snmpwalk -v2c -c testing 172.28.161.170:30161 1.3.6.1.2.1.25.1.1
HOST-RESOURCES-MIB::hrSystemUptime.0 = Timeticks: (36197997) 4 days, 4:32:59.97

```