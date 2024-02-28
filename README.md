# CVP SNMP monitoring with Kubernetes

> **Warning**
> Disclaimer: This project is not an officially endorsed or supported Arista project, and should be treated as a best-effort initiative, without any guarantee of performance or reliability.

The goal of this project is to find a cleaner way to install snmpd packages on CVP: this will allow a _remote management SNMP system to monitor basic CVP server information_ (CPU, memory, disk space, ...).

The following project will install **snmpd** version `5.9.4` in a Kubernetes pod to make a cleaner and easier-to-maintain solution.

This snmpd package does support modern cryptographic algorithms (such as `SHA-512` or `AES-256`).

> **Note**
>  Kubernetes will expose by default the port UDP `161` on each node. So this port needs to be used from the remote devices (NMS system for example).

# Installation process

## Step 1: Get the files in your CVP server in the /cvpi directory

If CloudVision has access to the internet this can be downloaded directly to the CLI of the primary node:

```shell
cd /cvpi/
wget https://github.com/arista-netdevops-community/cvp-snmp-container/archive/main.tar.gz -O cvp-snmp-container-main.tar.gz
tar -xf cvp-snmp-container-main.tar.gz
cd cvp-snmp-container-main/
```

Otherwise, download the package as a zip file (via the github web interface) to your computer and scp it to the CVP server.  
Then:
```
unzip /path/to/file/on/cvp/cvp-snmp-container-main.zip -d /cvpi/
```
> **Note**
>  The repository directory on the cvp server must be exactly `/cvpi/cvp-snmp-container-main/`


## Step 2: Modify the snmpd.conf file to match your requirements.  

By default, the configuration file has the following content (using v2c "testing" community string, and v3 arista user): 

```text
# Global information
sysname "arista-cvp-server-1"
syslocation "arista-cvp-location"
syscontact "admin"

# Warning: Do not modify this port as this is the port open INSIDE the Kubernetes pod. 
# If you wish to modify the host port opened, check the snmpd-monitor.yaml file.
agentAddress udp:161
agentuser root

# For SNMPv2c
rocommunity testing

# For SNMPv3:
createUser arista SHA-512 'arista1234' AES-256 'arista1234'
rouser arista
```

A complete list of examples is available in command [`man 5 snmpd.examples`](https://linux.die.net/man/5/snmpd.examples)


## Step 3: Load the container image.

- For CVP version `>= 2022.3.0` :

```shell
tar -xf net_snmp_image.tar.gz && nerdctl load -i net_snmp_image

# Verification: 
nerdctl image ls  | grep snmp
```

- For older CVP versions, use the following command:

```shell
tar -xf net_snmp_image.tar.gz && docker load -i net_snmp_image

# Verification:
docker image ls | grep snmp
```

## Step 4: Install a cron entry

A cronjob needs to be configured to avoid any downtime after an upgrade of CVP is performed (as during the upgrade all the container images are flushed).  
This can be accomplished by installing the following cron entry.  
Use the following command to edit the crontab:

```shell
crontab -e
```

And add the following:

```shell
@reboot /cvpi/cvp-snmp-container-main/load_image_on_boot.sh >> /cvpi/cvp-snmp-container-main/cron.log 2>&1
```

## Step 5: (for multi-nodes)

If in a multi-node cluster, repeat Step 1, 2, 3 and 4 on the secondary node and tertiary node.

## Step 6: Create the Kubernetes deployment:

This needs to be run only on the primary server.

```shell
kubectl apply -f snmpd-monitor.yaml
```

## Step 7: Validation

From the CVP server, we can verify the status of the pods and deployment:

```shell
kubectl get pods -l app=snmpd-monitor -o wide 
kubectl get daemonset -l app=snmpd-monitor
```

### Expected output

```shell
$ kubectl get pods -l app=snmpd-monitor -o wide 
NAME                  READY   STATUS    RESTARTS   AGE     IP             NODE                               NOMINATED NODE   READINESS GATES
snmpd-monitor-jg9v6   1/1     Running   0          3m46s   10.42.40.144   cva-3-cvp.ire.aristanetworks.com   <none>           <none>
snmpd-monitor-l66jt   1/1     Running   0          3m46s   10.42.8.190    cva-2-cvp.ire.aristanetworks.com   <none>           <none>
snmpd-monitor-nlxxf   1/1     Running   0          3m46s   10.42.65.128   cva-1-cvp.ire.aristanetworks.com   <none>           <none>

$ kubectl get daemonset -l app=snmpd-monitor
NAME            DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
snmpd-monitor   3         3         3       3            3           <none>          30s
```

### SNMP query

From a remote device (for example an Arista switch), do an SNMP query:

```shell
# SNMPv2c - Get sysname:
switch#bash snmpwalk -v2c -c testing 10.83.13.33:161 1.3.6.1.2.1.1.5.0
SNMPv2-MIB::sysName.0 = STRING: "arista-cvp-server-1"

# SNMPv2c - Get uptime:
switch#bash snmpwalk -v2c -c testing 10.83.13.33:161 1.3.6.1.2.1.25.1.1
HOST-RESOURCES-MIB::hrSystemUptime.0 = Timeticks: (36197997) 4 days, 4:32:59.97

# SNMPv3 - Get sysname: 
switch#bash snmpwalk -v3 -u arista 10.83.13.33:161 -a SHA-512 -A arista1234 -x AES-256 -X arista1234 1.3.6.1.2.1.1.5.0
SNMPv2-MIB::sysName.0 = STRING: "arista-cvp-server-1"
```

# How to update the SNMP configuration?

In case you need to modify the SNMP configuration after installation is complete, please follow the below steps.   

- Step 1 - Modify the `/cvpi/cvp-snmp-container-main/snmpd.conf` file on each node:

```shell
vi /cvpi/cvp-snmp-container-main/snmpd.conf
```

- Step 2 - On one node (primary for example), delete and re-apply the Kubernetes daemonset:

```shell
kubectl delete -f /cvpi/cvp-snmp-container-main/snmpd-monitor.yaml
kubectl apply -f /cvpi/cvp-snmp-container-main/snmpd-monitor.yaml
```

- Step 3 - Verification:

```shell
kubectl get pods -l app=snmpd-monitor -o wide 
kubectl get daemonset -l app=snmpd-monitor
```

# SNMP for CVA appliance

If you would need to monitor the CVA appliance, the above steps will not work as the CVAs are not part of a Kubernetes cluster.
We would advise using the SNMP capability of the iDRAC interface. 
You can find more information about this on [Arista Networks website](https://www.arista.com/en/qsg-cva-200cv-250cv/cva-200cv-250cv-snmp-monitoring-support)
