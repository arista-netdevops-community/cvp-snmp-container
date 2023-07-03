# Docker image based on alpine 3.18.2
# This file is used in order to re-create the image in case we want to upgrade either the base image or the snmp package version.

FROM alpine:3.18.2

RUN apk --update --no-cache add net-snmp net-snmp-tools

COPY container-files /


# Expose the snmp port
EXPOSE 161

# Run snmpd
CMD ["/bootstrap.sh"]


# Commands to build and save the image

# docker build -t net_snmp_image:latest .
# docker save net_snmp_image:latest -o net_snmp_image
# tar -zcvf ../net_snmp_image-v5.9.tar.gz net_snmp_image
