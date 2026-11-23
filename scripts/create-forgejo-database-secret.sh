#!/bin/bash

set -eu

script_dir=`realpath "$(dirname $0)"`
project_dir=`realpath "${script_dir}/.."`

create_secret() {
    local env="$1"
    local database_type="$2"

    local secret_name="forgejo-${database_type}"

    local secret_yaml="${project_dir}/${env}/sops-age/${secret_name}.yaml"

    local database_dir="${NGUILAND_CONFIG_DIR}/${env}/forgejo/${database_type}"

    local username=$(cat "${database_dir}/username")
    local password=$(cat "${database_dir}/password")
    local database=$(cat "${database_dir}/database")
    local host=$(cat "${database_dir}/host")

    kubectl create secret generic "${secret_name}" \
        --from-literal=username="${username}" \
        --from-literal=password="${password}" \
        --from-literal=database="${database}" \
        --from-literal=host="${host}" \
        --from-literal=type="${database_type}" \
        --namespace="${env}" \
        --dry-run=client \
        -o yaml \
        | kubectl label --local -f - \
            ${database_type}-provisioner.io/managed=true \
            ${database_type}-provisioner.io/instance=main \
            -o yaml \
        | sed '/^[[:space:]]*creationTimestamp: null$/d' \
        > "${secret_yaml}"
    
    cd "${project_dir}"

    sops -e -i "${secret_yaml}"

    printf "The %s secret was created in the %s file" "${secret_name}" "${secret_yaml}"
}

main() {
    local expected_arg_count=2

    if [ "$#" -lt "${expected_arg_count}" ]; then
        printf "Error: Not enough arguments provided.\n"
        printf "Usage: $0 <env>\n"
        exit 1
    fi

    local env="$1"
    local database_type="$2"

    create_secret "$env" "$database_type"
}

main "$@"
