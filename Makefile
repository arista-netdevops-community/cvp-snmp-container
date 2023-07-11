.PHONY: copy_component_files_new copy_component_files_old copy_k8s_files install install-old

# Create CVPI component post 2022.3.0
copy_component_files_new:
	cp ./cvpi/conf/components/post_2022.3.0/* /cvpi/conf/components/
	@if [ "$(CVP_MODE)" = "multinode" ]; then \
			scp ./cvpi/conf/components/post_2022.3.0/* $(SECONDARY_HOSTNAME)://cvpi/conf/components/; \
			scp ./cvpi/conf/components/post_2022.3.0/* $(TERTIARY_HOSTNAME)://cvpi/conf/components/; \
	fi

# Create CVPI component pre 2022.3.0
copy_component_files_old:
	cp ./cvpi/conf/components/pre_2022.3.0/* /cvpi/conf/components/
	@if [ "$(CVP_MODE)" = "multinode" ]; then \
		scp ./cvpi/conf/components/pre_2022.3.0/* $(SECONDARY_HOSTNAME)://cvpi/conf/components/; \
		scp ./cvpi/conf/components/pre_2022.3.0/* $(TERTIARY_HOSTNAME)://cvpi/conf/components/; \
	fi

# Copy the k8s manifest file
copy_k8s_files:
	cp ./cvpi/conf/kubernetes/snmpd-monitor.yaml /cvpi/conf/kubernetes/
	@if [ "$(CVP_MODE)" = "multinode" ]; then \
		scp ./cvpi/conf/kubernetes/snmpd-monitor.yaml $(SECONDARY_HOSTNAME)://cvpi/conf/kubernetes/; \
		scp ./cvpi/conf/kubernetes/snmpd-monitor.yaml $(TERTIARY_HOSTNAME)://cvpi/conf/kubernetes/; \
	fi

# Extract container image and move to all nodes
extract_ctr:
	tar -xf net_snmp_image-v5.9.tar.gz
	cp net_snmp_image /cvpi/docker/
	@if [ "$(CVP_MODE)" = "multinode" ]; then \
		scp net_snmp_image $(SECONDARY_HOSTNAME)://cvpi/docker/; \
		scp net_snmp_image $(TERTIARY_HOSTNAME)://cvpi/docker/; \
	fi

# Copy snmp config file to /cvpi/
copy_snmp_config:
	cp snmpd.conf /cvpi/snmpd.conf
	@if [ "$(CVP_MODE)" = "multinode" ]; then \
		scp ./snmpd.conf $(SECONDARY_HOSTNAME)://cvpi/snmpd.conf; \
		scp ./snmpd.conf $(TERTIARY_HOSTNAME)://cvpi/snmpd.conf; \
	fi

# Copy all the necessary files on a single node instance post 2022.3.0
install: copy_component_files_new copy_k8s_files extract_ctr

# Copy all the necessary files on a single node instance pre 2022.3.0
install-old: copy_component_files_old copy_k8s_files extract_ctr
