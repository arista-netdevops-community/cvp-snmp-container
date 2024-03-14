SHELL := /bin/sh
.PHONY: build redeploy-dev redeploy sh

VERSION := 5.9.4.1

build: ## Build the docker image
	docker image prune -a -f ;\
	docker build -f docker/Dockerfile --no-cache -t net_snmp_image:latest -t net_snmp_image:$(VERSION) . ;\
	docker save net_snmp_image -o docker/net_snmp_image ;\
	cd docker ;\
	tar -czvf ../net_snmp_image.tar.gz net_snmp_image


redeploy-dev: ## Redeploy the snmpd-monitor pod in dev environment (within k8s.io namespace)
	kubectl delete -f snmpd-monitor.yaml ;\
	kubectl wait --for=delete pod -l app=snmpd-monitor --timeout=60s ;\
	nerdctl image  --namespace=k8s.io rm  net_snmp_image:latest ;\
	tar -xf net_snmp_image.tar.gz ;\
	nerdctl image   --namespace=k8s.io load -i net_snmp_image ;\
	nerdctl image ls --namespace=k8s.io | grep net_snmp_image ;\
	kubectl apply -f snmpd-monitor.yaml ;\
	kubectl wait --for=condition=ready pod -l app=snmpd-monitor --timeout=60s
	kubectl get pod -l app=snmpd-monitor

redeploy: ## Redeploy the snmpd-monitor pod in default namespace (works only on single-node CVP cluster)
	kubectl delete -f snmpd-monitor.yaml ;\
	kubectl wait --for=delete pod -l app=snmpd-monitor --timeout=60s ;\
	nerdctl image rm  net_snmp_image:latest ;\
	tar -xf net_snmp_image.tar.gz ;\
	nerdctl image load -i net_snmp_image ;\
	nerdctl image ls | grep net_snmp_image ;\
	kubectl apply -f snmpd-monitor.yaml ;\
	kubectl wait --for=condition=ready pod -l app=snmpd-monitor --timeout=60s
	kubectl get pod -l app=snmpd-monitor

test: ## Test the snmpd-monitor pod. This only works with default SNMP credentials
	kubectl exec -it $(shell kubectl get pod -l app=snmpd-monitor -o jsonpath='{.items[0].metadata.name}') -- snmpwalk -v2c -c testing 127.0.0.1:161 1.3.6.1.2.1.1.5.0 ;\
	kubectl exec -it $(shell kubectl get pod -l app=snmpd-monitor -o jsonpath='{.items[0].metadata.name}') -- snmpwalk -v2c -c testing localhost .1.3.6.1.3.53.8.0 ;\
	kubectl exec -it $(shell kubectl get pod -l app=snmpd-monitor -o jsonpath='{.items[0].metadata.name}') -- snmpwalk -v2c -c testing localhost ARISTA-KUBERNETES-MIB::nbNodesInReadyState ;\
	kubectl exec -it $(shell kubectl get pod -l app=snmpd-monitor -o jsonpath='{.items[0].metadata.name}') -- snmpwalk -v2c -c testing localhost ARISTA-KUBERNETES-MIB::k8sNodesInfo ;\
	kubectl exec -it $(shell kubectl get pod -l app=snmpd-monitor -o jsonpath='{.items[0].metadata.name}') -- snmpwalk -v3  -l authPriv  -u arista -a SHA-512 -A 'arista1234' -x AES-256 -X 'arista1234'  localhost ARISTA-KUBERNETES-MIB::k8sPodsInfo

sh: ## Open a shell in the snmpd-monitor pod
	kubectl exec -it $(shell kubectl get pod -l app=snmpd-monitor -o jsonpath='{.items[0].metadata.name}') -- sh
