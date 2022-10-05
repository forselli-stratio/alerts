#!/bin/bash

set -e

# Usage info
show_help() {
cat << EOF
Usage: ${0##*/} [-apg] [-t TENANT]
Configures Prometheus, Alertmanager and Grafana.

    -h              display this help and exit
    -f FOLDER       folder containing configuration files
    -t TENANT       tenant to configure
    -k KUBECONFIG   kubeconfig file
    -a              configure Alertmanager
    -p              configure Prometheus
    -g              configure Grafana
EOF
}

# Initialize our own variables:
folder=""
tenant=""
kubeconfig=""

# Show help if no argument is passed to the script
if [[ $# -eq 0 ]] ; then
    show_help
    exit 0
fi

while :; do
    case $1 in
        -h|-\?|--help)   # Call a "show_help" function to display a synopsis, then exit.
            show_help
            exit
            ;;
        -f|--folder)       # Takes an option argument, ensuring it has been specified.
            if [ -n "$2" ]; then
                folder=$2
                shift
            else
                printf 'ERROR: "--folder" requires a non-empty option argument.\n' >&2
                exit 1
            fi
            ;;
        --folder=?*)
            folder=${1#*=} # Delete everything up to "=" and assign the remainder.
            ;;
        --folder=)         # Handle the case of an empty --tenant=
            printf 'ERROR: "--tenant" requires a non-empty option argument.\n' >&2
            exit 1
            ;;
        -t|--tenant)       # Takes an option argument, ensuring it has been specified.
            if [ -n "$2" ]; then
                tenant=$2
                shift
            else
                printf 'ERROR: "--tenant" requires a non-empty option argument.\n' >&2
                exit 1
            fi
            ;;
        --tenant=?*)
            tenant=${1#*=} # Delete everything up to "=" and assign the remainder.
            ;;
        --tenant=)         # Handle the case of an empty --tenant=
            printf 'ERROR: "--tenant" requires a non-empty option argument.\n' >&2
            exit 1
            ;;
        -k|--kubeconfig)       # Takes an option argument, ensuring it has been specified.
            if [ -n "$2" ]; then
                kubeconfig=$2
                shift
            else
                printf 'ERROR: "--kubeconfig" requires a non-empty option argument.\n' >&2
                exit 1
            fi
            ;;
        --kubeconfig=?*)
            file=${1#*=} # Delete everything up to "=" and assign the remainder.
            ;;
        --kubeconfig=)         # Handle the case of an empty --tenant=
            printf 'ERROR: "--kubeconfig" requires a non-empty option argument.\n' >&2
            exit 1
            ;;
        -a|--alertmanager)
            configure_alertmanager=true
            ;;
        -p|--prometheus)
            configure_prometheus=true
            ;;
        -g|--grafana)
            configure_grafana=true
            ;;
        --)              # End of all options.
            shift
            break
            ;;
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            ;;
        *)               # Default case: If no more options then break out of the loop.
            break
    esac

    shift
done

# Exit if tenant or kubeconfig file are not specified
if [ -z "$folder" ] || [ -z "$tenant" ] || [ -z "$kubeconfig" ]
then
      echo "Configuration folder, tenant and kubeconfig file must be specified"
      exit 1
fi

if [ "$configure_alertmanager" = true ] ; then
    echo 'Configuring Alertmanager...'
    if [ "$tenant" = "keos" ] ; then
    kubectl --kubeconfig=${kubeconfig} apply -n keos-metrics -f clientes/${folder}/alertmanagerconfig.yaml
    else
    kubectl --kubeconfig=${kubeconfig} apply -n ${tenant}-metrics -f clientes/${folder}/${tenant}/alertmanagerconfig.yaml
    fi
fi

if [ "$configure_prometheus" = true ] ; then
    echo 'Configuring Prometheus...'
    if [ "$tenant" = "keos" ] ; then
      for rules_values_file in "clientes/${folder}/rules"*.yaml; do
        echo $rules_values_file
        release_name="$(echo ${rules_values_file} | grep -o -P '(?<=rules-).*(?=-values)' | cat)"
        echo $release_name
        echo "Installing stratio-rules helm chart using values file $rules_values_file"
        helm --kubeconfig=${kubeconfig} upgrade -i ${release_name:-operations}-rules -n keos-metrics -f ${rules_values_file} stratio-rules
      done
    else
      for rules_values_file in "clientes/${folder}/${tenant}/rules"*.yaml; do
        release_name="$(echo ${rules_values_file} | grep -o -P '(?<=rules-).*(?=-values)' | cat)"
        echo "Installing stratio-rules helm chart using values file $rules_values_file"
        helm --kubeconfig=${kubeconfig} upgrade -i ${release_name:-operations}-rules -n ${tenant}-metrics -f ${rules_values_file} stratio-rules
      done
    fi
fi

if [ "$configure_grafana" = true ] ; then
    echo 'Configuring Grafana...'
    helm --kubeconfig=${kubeconfig} upgrade -i operations-dashboards -n keos-metrics -f clientes/${folder}/dashboards-values.yaml stratio-dashboards
fi
