# Docker image based on alpine.
# This file is used in order to re-create the image in case we want to upgrade either the base image or the snmp package version.

FROM alpine:3.19.1

RUN apk --update --no-cache add \
net-snmp=5.9.4-r0 \
net-snmp-tools=5.9.4-r0 \
kubectl=1.28.4-r0 \
python3=3.11.8-r0 \
py3-pip=23.3.1-r0 \
&& pip3 install snmp_passpersist==2.1.0 --break-system-packages



COPY --chmod=0777 docker/container-files/kubernetes.py /kubernetes.py


# Expose the snmp port
EXPOSE 161

# Run snmpd
# CMD sleep infinity
CMD snmpd -a -c /etc/snmp/snmpd.conf -f -Lo -C -p /var/run/snmpd.pid

# Commands to build and save the image

# 1. Building image
# docker build --no-cache -t net_snmp_image:latest -t net_snmp_image:5.9.4 .

# 2. Tests:
# docker run --name docker-snmp -v $(pwd)/../snmpd.conf:/etc/snmp/snmpd.conf -it -d net_snmp_image:latest
# docker exec -it docker-snmp snmpd --version
# docker exec -it docker-snmp snmpwalk -v2c -c testing 127.0.0.1:161 1.3.6.1.2.1.1.5.0
# docker exec -it docker-snmp snmpwalk -v2c -c testing 127.0.0.1:161 1.3.6.1.2.1.25.1.1
# docker exec -it docker-snmp snmpwalk -v3  -l authPriv  -u arista -a SHA-512 -A 'arista1234' -x AES-256 -X 'arista1234'  localhost .1.3.6.1.3.53.8.0.2

# 3. Saving image as a file
# docker save net_snmp_image -o net_snmp_image
# tar -zcvf ../net_snmp_image-v5.9.tar.gz net_snmp_image
