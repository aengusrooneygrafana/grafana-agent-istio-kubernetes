#!/bin/bash 

#### Create k8s cluster  (shift option r to run)

export THEDATE=`date +%y%m%d%H`
gcloud container clusters create se-rooney-$THEDATE --num-nodes 3 
kubectl config current-context

#### Create a new org or stack on Grafana.com 

open -g -a "Google Chrome" https://grafana.com/orgs/aengusrooneytest 

#### SOURCE THE GRAFANA.COM ENVIRONMENT VARIABLES (env file with your grafana.com credentials)

source /Users/aengusrooney/grafana-dot-com-env/set_env.sh

#### CHECK ENVIRONMENT VARIABLES HAVE BEEN SOURCED 

env | grep -e YOUR_REMOTE_WRITE_USERNAME 

#### APPLY THE METRICS AGENT AND CONFIG 

envsubst < agent-metrics.yaml | kubectl apply -n default -f - 
envsubst < agent-metrics-configmap.yaml | kubectl apply -n default -f -
kubectl rollout restart deployment/grafana-agent

#### APPLY THE LOGS AGENT AND CONFIG 

envsubst < agent-logs.yaml | kubectl apply -n default -f -
envsubst < agent-logs-configmap.yaml | kubectl apply -n default -f -
kubectl rollout restart ds/grafana-agent-logs

#### APPLY THE TRACES AGENT AND CONFIG 

envsubst < agent-traces.yaml | kubectl apply -n default -f -
envsubst < agent-traces-configmap.yaml | kubectl apply -n default -f -
kubectl rollout restart deployment/grafana-agent-traces

#### CHECK PODS RUNNING OK 

kc get po -n default 

#### BROWSE METRIECS AND LOGS 

open -g -a "Google Chrome"  https://aengusrooneytest.grafana.net/explore

#### Alerting  

# k8s integration installs a new set of alerts  

open -g -a "Google Chrome" https://aengusrooneytest.grafana.net/a/grafana-easystart-app/integrations-management/integrations 

# CORTEXTOOL 

cortextool rules load k8s_rules.yml --address=$AM_ADDRESS --id=$AM_ID --key=$AM_PASSWORD 
cortextool rules list --address=$AM_ADDRESS --id=$AM_ID --key=$AM_PASSWORD 

#### Tracing app 

open -g -a "Google Chrome" https://grafana.com/blog/2021/08/31/how-istio-tempo-and-loki-speed-up-debugging-for-microservices/

####

