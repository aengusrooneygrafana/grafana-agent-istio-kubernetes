#!/bin/bash 

#### Create k8s cluster  (shift option r to run)

export THEDATE=`date +%y%m%d%H%M`
echo $THEDATE

gcloud services enable container.googleapis.com 

gcloud container clusters create se-rooney-$THEDATE \
--cluster-version latest \
--machine-type=n1-standard-2 \
--num-nodes 3 \
--enable-network-policy

#### Check current k8s context 

kubectl config current-context

#### Install Istio service mesh 

mkdir istio && cd istio 
wget https://istio.io/downloadIstio 
chmod a+x downloadIstio 
./downloadIstio
cd istio-* 
export PATH=$PWD/bin:$PATH

# Begin the Istio pre-installation check by running:

istioctl x precheck 

# Install demo profile https://istio.io/latest/docs/setup/additional-setup/config-profiles/
# Set sampling rate to 100% (as we can - Tempo implements a low cost object store back end) 
# Update the tracing service address to be the Grafana Agent's address 

istioctl install --set profile=default -y  
istioctl apply --set meshConfig.defaultConfig.tracing.sampling=100 -y 
istioctl apply --set meshConfig.defaultConfig.tracing.zipkin.address=grafana-agent-traces.default.svc.cluster.local:9411 -y

# Add a namespace label to instruct Istio to automatically inject Envoy sidecar proxies when deploying apps 
# Then deploy the Bookinfo sample application 

kubectl get namespace 
kubectl label namespace default istio-injection=enabled 
kubectl label namespace istio-system istio-injection=enabled 
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml 

# The application will start. As each pod becomes ready, the Istio sidecar will be deployed along with it. 

kubectl get all 
kubectl get namespace
kubectl get services  
kubectl get pods  

# Run this command to verify the app is running inside the cluster and serving HTML pages  
# Then open the application to outside traffic / Associate the application with the Istio gateway: 

kubectl exec "$(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}')" -c ratings -- curl -sS productpage:9080/productpage | grep -o "<title>.*</title>"
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml  

# Ensure that there are no issues with the configuration:

istioctl analyze

# Determine if your k8s cluster is running in an environment that supports external load balancers: 

kubectl get svc istio-ingressgateway -n istio-system

# If so, then open the application to outside traffic by setting the ingress IP and ports: 

export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}') ; 
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}') ; 
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}') ; 

# Set the GATEWAY_URL 
# Then echo to retrieve the external address of the Bookinfo application, and go to that address!  
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT ; 
echo "$GATEWAY_URL"
echo "http://$GATEWAY_URL/productpage"  

#### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### 
#### Grafana.com Create a new Org (Account) or Stack (Tenant)  
#### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### 

open -g -a "Google Chrome" https://grafana.com/orgs/aengusrooneytest 

#### SOURCE THE GRAFANA.COM ENVIRONMENT VARIABLES (env file with your grafana.com credentials)
#### CHECK ENVIRONMENT VARIABLES HAVE BEEN SOURCED 

source ~/grafana-dot-com-env/set_env.sh
env | grep -e YOUR_REMOTE_WRITE_USERNAME 

#### Change back into the package root folder 
#### APPLY THE METRICS AGENT AND CONFIG 

$PWD
cd ../..

envsubst < agent-metrics.yaml | kubectl apply -n default -f - 
envsubst < agent-metrics-configmap.yaml | kubectl apply -n default -f -
kubectl rollout restart statefulset/grafana-agent

#### APPLY THE LOGS AGENT AND CONFIG 

envsubst < agent-logs.yaml | kubectl apply -n default -f -
envsubst < agent-logs-configmap.yaml | kubectl apply -n default -f -
kubectl rollout restart ds/grafana-agent-logs

#### APPLY THE TRACES AGENT AND CONFIG 

envsubst < agent-traces.yaml | kubectl apply -n default -f -
envsubst < agent-traces-configmap.yaml | kubectl apply -n default -f -
kubectl rollout restart deployment/grafana-agent-traces

# [OPTIONAL] Deploy local addons, Kiali, Prometheus, Grafana, and Jaeger on the k8s cluster. 
# (If there are errors trying to install the addons, try running the command again.)

cd istio/istio-* 
kubectl apply -f samples/addons
kubectl rollout status deployment/kiali -n istio-system 

nohup istioctl dashboard grafana & 
nohup istioctl dashboard prometheus & 
nohup istioctl dashboard jaeger & 
nohup istioctl dashboard kiali & 
# In the left navigation menu, select Graph and in the Namespace drop down, select default.
# The Kiali dashboard shows an overview of your mesh with relationships between services in the app 

#### Cleanup Istio dir 

$PWD 
cd ../..
rm -rf istio 

#### CHECK PODS RUNNING OK 

kc get po -n default 
kc get po -n istio-system 

# Generate some activity / traces  

for i in $(seq 1 100); do curl -s -o /dev/null "http://$GATEWAY_URL/productpage"; done 

#### BROWSE METRIECS LOGS AND TRACES 

open -g -a "Google Chrome"  https://aengusrooneytest.grafana.net/explore

#### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### 
#### Alerting  
#### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### 

# k8s integration installs a new set of alerts  

open -g -a "Google Chrome" https://aengusrooneytest.grafana.net/a/grafana-easystart-app/integrations-management/integrations 

# CORTEXTOOL 

cortextool rules load k8s_rules.yml --address=$AM_ADDRESS --id=$AM_ID --key=$AM_PASSWORD 
cortextool rules list --address=$AM_ADDRESS --id=$AM_ID --key=$AM_PASSWORD 

#### Load a tracing application  

open -g -a "Google Chrome" https://grafana.com/blog/2021/08/31/how-istio-tempo-and-loki-speed-up-debugging-for-microservices/

####

