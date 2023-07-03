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
### If within the Arista network you can git clone directly from the CVP server:
```
cd /cvpi/
git clone https://gitlab.aristanetworks.com/guillaume.vilar/cvp-snmp-monitor-with-kubernetes.git
cd cvp-snmp-monitor-with-kubernetes/
```
Otherwise, just download the package as a zip and copy it manually to the CVP server.  
  
Then, we will need to load the container image.
If CVP >= 2022.2.0 (TODO: To confirm this version)
```
tar -xf net_snmp_image-v5.9.tar.gz
ctr image import net_snmp_image

# Verification: 
nerdctl image ls  | grep snmp
```

Otherwise, use the following command: 
```
tar -xf net_snmp_image-v5.9.tar.gz
docker load -i net_snmp_image

# Verification:
docker image ls | grep snmp
```

## Step 2: Modify the snmpd.conf files to match your requirements.  
The following files needs the be modified: 
* snmpd-primary.conf
* snmpd-secondary.conf
* snmpd-tertiary.conf  

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

## Step 3: Copy the files to the correct location:
This needs to be run on the primary server. You can ignore the last 2 lines if you are on a single-node cluster.
```
su cvp
cp snmpd-primary.conf /cvpi/snmpd.conf
scp snmpd-secondary.conf root@SECONDARY_HOSTNAME:/cvpi/snmpd.conf
scp snmpd-tertiary.conf root@TERTIARY_HOSTNAME:/cvpi/snmpd.conf
```

## Step 4: Create the Kubernetes deployment and service: 
This needs to be run only on the primary server.
```
kubectl apply -f snmpd-monitor.yaml
```


## Step 5: Validation 
## From the CVP server, we can verify the status of the pods, deployment and service:

```
kubectl get pods -l app=snmpd-monitor
kubectl get deployment -l app=snmpd-monitor
kubectl get service -l app=snmpd-monitor
```
Expected output:
```
[root@cvp-ire-pod2 cvp-snmp-monitor-with-kubernetes]# kubectl get pods -l app=snmpd-monitor
NAME                            READY   STATUS    RESTARTS   AGE
snmpd-monitor-9ddf89db6-m4xjc   1/1     Running   0          14s
[root@cvp-ire-pod2 cvp-snmp-monitor-with-kubernetes]# kubectl get deployment -l app=snmpd-monitor
NAME            READY   UP-TO-DATE   AVAILABLE   AGE
snmpd-monitor   1/1     1            1           21s
[root@cvp-ire-pod2 cvp-snmp-monitor-with-kubernetes]# kubectl get service -l app=snmpd-monitor
NAME            TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)         AGE
snmpd-monitor   NodePort   172.31.232.25   <none>        161:30161/UDP   26s


```

## from a remote device (for example an Arista switch) do a SNMP query:
```
psp119...17:19:39#bash snmpwalk -v2c -c testing 10.83.13.33:30161 HOST-RESOURCES-MIB::hrSystemUptime


HOST-RESOURCES-MIB::hrSystemUptime.0 = Timeticks: (689141680) 79 days, 18:16:56.80
```