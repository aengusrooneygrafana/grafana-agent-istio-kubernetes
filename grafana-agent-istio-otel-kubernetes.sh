#!/bin/bash 

# REF / Readme1 https://istio.io/latest/docs/setup/getting-started/ 
# REF / Readme2 https://opentelemetry.io/docs/demo/ 

#### Create k8s cluster  (note to self: shift option r)

export THENAME=`shuf -n1 /usr/share/dict/words`
export THEDATE=`date +%y%m%d%H%M`
echo $THENAME 
echo $THEDATE

gcloud services enable container.googleapis.com 

gcloud container clusters create $THENAME-$THEDATE \
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

# Install default profile https://istio.io/latest/docs/setup/additional-setup/config-profiles/
# Set sampling rate to 100% (as we can - Tempo implements a low cost object store back end) 
# Update the tracing service address to be the Grafana Agent's address 

istioctl install --set profile=default -y  --set meshConfig.defaultConfig.tracing.sampling=100 -y --set meshConfig.defaultConfig.tracing.zipkin.address=grafana-agent-traces.default.svc.cluster.local:9411 -y

# Add a namespace label to instruct Istio to automatically inject Envoy sidecar proxies when deploying apps 
# Then deploy the otel-demo demo app 

kubectl get namespace 
kubectl label namespace default istio-injection=enabled 
kubectl label namespace istio-system istio-injection=enabled 
kubectl create namespace otel-demo
kubectl label namespace otel-demo istio-injection=enabled 
kubectl apply --namespace otel-demo -f https://raw.githubusercontent.com/open-telemetry/opentelemetry-demo/main/kubernetes/opentelemetry-demo.yaml

# The application will start. As each pod becomes ready, the Istio sidecar will be deployed along with it. 
# go get a coffee or do some random checks while waiting for all the pods to startup... 

kubectl get all 
kubectl get namespace
kubectl get services -n otel-demo 
kubectl get pods -n otel-demo 

# Ensure that there are no issues with the configuration:

istioctl analyze

# Determine if your k8s cluster is running in an environment that supports external load balancers: 

kubectl get svc istio-ingressgateway -n istio-system

# If so, then open the application to outside traffic by setting the ingress IP and ports: 

export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}') ; 
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}') ; 
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}') ; 

# Set the GATEWAY_URL 
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT ; 
echo "$GATEWAY_URL"

#### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### 
#### Grafana.com Create a new Org (Account) and/or Stack (Tenant)  
#### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### 

open -g -a "Google Chrome" https://grafana.com/

#### SOURCE THE GRAFANA.COM ENVIRONMENT VARIABLES (this creates an env file with your grafana.com credentials)
#### CHECK ENVIRONMENT VARIABLES HAVE BEEN SOURCED 

source ~/grafana-dot-com-env/set_env.sh
env | grep -e YOUR_REMOTE_WRITE_USERNAME 

#### Change back into this package's root folder and then apply the metrics agent and config 

pwd
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

# [OPTIONAL] Deploy Kiali 

cd istio/istio-* 
kubectl apply -f samples/addons
kubectl rollout status deployment/kiali -n istio-system 

nohup istioctl dashboard kiali & 

# Note: in the Kiali UI, on the LHS navigation menu, select Graph and in the Namespace drop down, select default.
# The Kiali dashboard shows an overview of your mesh with relationships between services in the app 

#### Cleanup Istio dir 

pwd 
cd ../..
rm -rf istio 

#### CHECK PODS RUNNING OK 

kc get po -n default 
kc get po -n istio-system 
kc get po -n otel-demo 

#### Port forward the otel-demo shop  (todo: add services to ingress and remove this step)  

nohup kubectl port-forward svc/opentelemetry-demo-frontendproxy 8080:8080 -n otel-demo & 

#### go shopping in the demo UI, select some procucts, add to cart, etc 

http://localhost:8080/ 

#### BROWSE METRICS LOGS AND TRACES 

open -g -a "Google Chrome"  https://<my-grafana-org>.grafana.net/explore

#### END #### 