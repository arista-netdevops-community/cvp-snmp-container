SHELL := /bin/sh
.PHONY: build reload sh cp cpmib

VERSION := 5.9.4.1

build:
	docker image prune -a -f ;\
	docker build -f docker/Dockerfile --no-cache -t net_snmp_image:latest -t net_snmp_image:$(VERSION) . ;\
	docker save net_snmp_image -o docker/net_snmp_image ;\
	cd docker ;\
	tar -czvf ../net_snmp_image.tar.gz net_snmp_image


reload:
	kubectl delete -f snmpd-monitor.yaml ;\
	kubectl wait --for=delete pod -l app=snmpd-monitor --timeout=60s ;\
	nerdctl image  --namespace=k8s.io rm  net_snmp_image:latest ;\
	tar -xf net_snmp_image.tar.gz ;\
	nerdctl image   --namespace=k8s.io load -i net_snmp_image ;\
	nerdctl image ls --namespace=k8s.io | grep net_snmp_image ;\
	kubectl apply -f snmpd-monitor.yaml ;\
	kubectl wait --for=condition=ready pod -l app=snmpd-monitor --timeout=60s
	kubectl get pod -l app=snmpd-monitor


test:
	kubectl exec -it $(shell kubectl get pod -l app=snmpd-monitor -o jsonpath='{.items[0].metadata.name}') -- snmpwalk -v2c -c testing 127.0.0.1:161 1.3.6.1.2.1.1.5.0 ;\
	kubectl exec -it $(shell kubectl get pod -l app=snmpd-monitor -o jsonpath='{.items[0].metadata.name}') -- snmpwalk -v2c -c testing localhost .1.3.6.1.3.53.8.0 ;\
	kubectl exec -it $(shell kubectl get pod -l app=snmpd-monitor -o jsonpath='{.items[0].metadata.name}') -- snmpwalk -v2c -c testing localhost ARISTA-KUBERNETES-MIB::k8sNodesInfo ;\
	kubectl exec -it $(shell kubectl get pod -l app=snmpd-monitor -o jsonpath='{.items[0].metadata.name}') -- snmpwalk -v3  -l authPriv  -u arista -a SHA-512 -A 'arista1234' -x AES-256 -X 'arista1234'  localhost ARISTA-KUBERNETES-MIB::k8sPodsInfo

sh:
	kubectl exec -it $(shell kubectl get pod -l app=snmpd-monitor -o jsonpath='{.items[0].metadata.name}') -- sh

cp: 
	kubectl cp docker/container-files/kubernetes.py $(shell kubectl get pod -l app=snmpd-monitor -o jsonpath='{.items[0].metadata.name}'):/
	kubectl exec -it $(shell kubectl get pod -l app=snmpd-monitor -o jsonpath='{.items[0].metadata.name}') -- chmod +x /kubernetes.py

cpmib:
	kubectl cp ARISTA-KUBERNETES-MIB.txt $(shell kubectl get pod -l app=snmpd-monitor -o jsonpath='{.items[0].metadata.name}'):/usr/share/snmp/mibs/