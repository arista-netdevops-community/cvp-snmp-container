# Docker image based on alpine.
# This file is used in order to re-create the image in case we want to upgrade either the base image or the snmp package version.

FROM alpine:3.19.0

RUN apk --update --no-cache add net-snmp=5.9.4-r0 net-snmp-tools=5.9.4-r0

COPY container-files /


# Expose the snmp port
EXPOSE 161

# Run snmpd
CMD ["/bootstrap.sh"]


# Commands to build and save the image

# 1. Building image
# docker build --no-cache -t net_snmp_image:latest .

# 2. Tests:
# docker run --name docker-snmp -v $(pwd)/../snmpd.conf:/etc/snmp/snmpd.conf -it -d net_snmp_image:latest
# docker exec -it docker-snmp snmpd --version
# docker exec -it docker-snmp snmpwalk -v2c -c testing 127.0.0.1:161 1.3.6.1.2.1.1.5.0
# docker exec -it docker-snmp snmpwalk -v2c -c testing 127.0.0.1:161 1.3.6.1.2.1.25.1.1

# 3. Saving image as a file
# docker save net_snmp_image:latest -o net_snmp_image
# tar -zcvf ../net_snmp_image-v5.9.tar.gz net_snmp_image
