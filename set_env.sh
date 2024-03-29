# change the values to your own - ref https://grafana.com/orgs/<my-org>/stacks/<my-stack-id> 
#
#### ENVIRONMENT - METRICS
export YOUR_REMOTE_WRITE_URL=https://prometheus-<change-me>.grafana.net/api/prom/push 
export YOUR_REMOTE_WRITE_USERNAME=<my-metrics-user-id>
export YOUR_REMOTE_WRITE_PASSWORD=<my-metrics-api-token>
export NAMESPACE=<my-ns>
export MANIFEST_URL=https://raw.githubusercontent.com/grafana/agent/main/production/kubernetes/agent-bare.yaml
#
#### ENVIRONMENT - LOGS
export YOUR_LOKI_ENDPOINT=https://logs-prod-<change-me>.grafana.net/loki/api/v1/push
export YOUR_LOKI_USERNAME=<my-logs-user-id>
export YOUR_LOKI_PASSWORD=<my-logs-api-token>
export YOUR_NAMESPACE=<my-ns>
export NAMESPACE=<my-ns>
#
#### ENVIRONMENT - TRACES
export YOUR_TEMPO_ENDPOINT=tempo-<change-me>.grafana.net:443
export YOUR_TEMPO_USER=<my-traces-user-id>
export YOUR_TEMPO_PASSWORD=<my-traces-api-token>
export YOUR_NAMESPACE=<my-ns>
#
#### ENVIRONMENT - ALERTMANAGER (if setting up alerting) 
export AM_ADDRESS=https://prometheus-<change-me>.grafana.net
export AM_ID=<my-AM-user-id>
export AM_PASSWORD=<my-AM-api-token>
