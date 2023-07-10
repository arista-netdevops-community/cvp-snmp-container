# cvp-snmp-with-kubernetes
The goal of this project is to find a cleaner way to install snmpd packages on CVP: we would like a remote management SNMP system to be able to monitor basic CVP server information (CPU, memory, disk space, ...).
Right now, our solution is described here: https://arista.my.site.com/AristaCommunity/s/article/snmpd-on-cvp  
This solution is not the best as it involves installing new RPM packages with yum: this could create issues at the next upgrade.
Moreover, the package installed (snmpd version 5.7), doesn't support modern cryptographic algorithms (such as SHA-512 or AES-256).   
The following project will install snmpd version 5.9 in a Kubernetes pod to make a cleaner and easier-to-maintain solution. 

# Warning: Kubernetes will expose by default the port UDP 30161. So this port needs to be used from the remote devices (NMS system for example).

# Installation process

## Step 1: Get the files in your CVP server in the /cvpi directory
### If CloudVision has access to the internet this can be downloaded directly to the CLI of the primary node:
```
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
cp snmpd.conf /cvpi/snmpd.conf
```

## Step 4: Load the container image.
For CVP version >= 2022.3.0 :
```
tar -xf net_snmp_image-v5.9.tar.gz && nerdctl load -i net_snmp_image 

# Verification: 
nerdctl image ls  | grep snmp
```

For older CVP versions, use the following command: 
```
tar -xf net_snmp_image-v5.9.tar.gz && docker load -i net_snmp_image

# Verification:
docker image ls | grep snmp
```

## Step 5: Install a cron entry
A cronjob needs to be configured to avoid any downtime after an upgrade of CVP is performed (as during the upgrade all the container images are flushed).  
This can be accomplished by installing the following cron entry.  
Use the following command to edit the crontab:
```
crontab -e
```
And add the following:
```
@reboot /cvpi/cvp-snmp-monitor-with-kubernetes-main/load_image_on_boot.sh >> /cvpi/cvp-snmp-monitor-with-kubernetes-main/cron.log 2>&1
```

## Step 6: If in a multi-node cluster, repeat Step 1, 2, 3, 4 and 5 on the secondary node and tertiary node.
## Step 7: Create the Kubernetes deployment and service: 
This needs to be run only on the primary server.
```
kubectl apply -f snmpd-monitor.yaml
```



## Step 8: Validation
From the CVP server, we can verify the status of the pods, deployment and service:

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

## from a remote device (for example an Arista switch), do an SNMP query:
```
# SNMPv2c - Get sysname:
switch#bash snmpwalk -v2c -c testing 10.83.13.33:30161 1.3.6.1.2.1.1.5.0
SNMPv2-MIB::sysName.0 = STRING: "arista-cvp-server-1"

# SNMPv2c - Get uptime:
switch#bash snmpwalk -v2c -c testing 10.83.13.33:30161 1.3.6.1.2.1.25.1.1
HOST-RESOURCES-MIB::hrSystemUptime.0 = Timeticks: (36197997) 4 days, 4:32:59.97

# SNMPv3 - Get sysname: 
switch#bash snmpwalk -v3 -u arista 10.83.13.33:30161 -a SHA-512 -A arista1234 -x AES-256 -X arista1234 1.3.6.1.2.1.1.5.0
SNMPv2-MIB::sysName.0 = STRING: "arista-cvp-server-1"

```

# How to update the SNMP configuration?
In case you need to modify the SNMP configuration after installation is complete, please follow the below steps.   
Step 1 - Modify the `/cvpi/snmpd.conf` file on each node:
```
vi /cvpi/snmpd.conf
```
Step 2 - On one node (primary for example), delete and re-apply the Kubernetes daemonset and service:
```
kubectl delete -f /cvpi/cvp-snmp-monitor-with-kubernetes-main/snmpd-monitor.yaml
kubectl apply -f /cvpi/cvp-snmp-monitor-with-kubernetes-main/snmpd-monitor.yaml
```
Step 3 - Verification: 
```
kubectl get pods -l app=snmpd-monitor -o wide 
kubectl get daemonset -l app=snmpd-monitor
kubectl get service -l app=snmpd-monitor
```

# SNMP for CVA appliance
If you would need to monitor the CVA appliance, the above steps will not work as the CVAs are not part of a Kubernetes cluster.
We would advise using the SNMP capability of the iDRAC interface. 
You can find more information about this here: 
https://www.arista.com/en/qsg-cva-200cv-250cv/cva-200cv-250cv-snmp-monitoring-support