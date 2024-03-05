#!/bin/bash

# This script will load the image in nerdctl and delete / apply the Kubernetes daemonset and service. 
# This needs to be configured as a cronjob like the following: 
# @reboot /cvpi/cvp-snmp-container-main/load_image_on_boot.sh >> /cvpi/cvp-snmp-container-main/cron.log 2>&1
# The reason we need to do that, is that during a CVP upgrade, all the nerdctl images are removed. 
# Thus, at the next boot of the server, post-upgrade, the SNMP pod will fail to start. 
# This script will re-load the images at each boot to make sure the container image is present.

source /root/.bashrc
# Sleep 300 seconds to let the time to containerd and Kubernetes to come up at boot time.
echo $(date) - sleep - $(sleep 300)

# Load image with nerdctl (CVP version >= 2022.3.0)
echo $(date) - load image nerdctl - $(nerdctl load -i /cvpi/cvp-snmp-container-main/net_snmp_image)
# Load image with docker (CVP version < 2022.3.0)
echo $(date) - load image docker - $(docker load -i /cvpi/cvp-snmp-container-main/net_snmp_image)

# Delete and re-apply Kubernetes file
echo $(date) - delete deployment -  $(kubectl delete -f /cvpi/cvp-snmp-container-main/snmpd-monitor.yaml) 
echo $(date) - apply deployment - $(kubectl apply -f /cvpi/cvp-snmp-container-main/snmpd-monitor.yaml)
