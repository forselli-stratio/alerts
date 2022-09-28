#!/bin/bash

set -e

kubectl --kubeconfig=${KUBECONFIG_FILE} apply -f $CLIENTE/alertmanagerconfig.yaml

helm --kubeconfig=${KUBECONFIG_FILE} upgrade -i -f $CLIENTE/rules-values.yaml

helm --kubeconfig=${KUBECONFIG_FILE} upgrade -i -f $CLIENTE/dashboards-values.yaml


for rules_values_file in "clientes/${CLIENTE}/rules"*.yaml; do
  echo "Installing stratio-rules helm chart using values file $rules_values_file"
  helm --kubeconfig=${KUBECONFIG_FILE} upgrade -i -n keos-metrics -f clientes/$CLIENTE/rules-values.yaml stratio-rules
done

