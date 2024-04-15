#!/usr/bin/env bash

set -eux

rt_delete_artifact() {
  DST_PATH="${1:?}"
  ANONYMOUS="${2:-1}"

  _CMD="curl -s \
    $( ([[ "${ANONYMOUS}" != 1 ]] && echo " -u${RT_USER:?}:${RT_TOKEN:?}") || true) \
    -XDELETE \
    ${RT_URL}/${DST_PATH}"

  eval "${_CMD}" > /dev/null 2>&1
}

rt_upload_artifact() {
  SRC_PATH="${1:?}"
  DST_PATH="${2:?}"
  ANONYMOUS="${3:-1}"

  _CMD="curl \
    $( ([[ "${ANONYMOUS}" != 1 ]] && echo " -u${RT_USER:?}:${RT_TOKEN:?}") || true) \
    ${RT_URL}/${DST_PATH} \
    -T ${SRC_PATH}"

  eval "${_CMD}"
}

rt_list_directory() {
  DST_PATH="${1:?}"
  ANONYMOUS="${2:-1}"

  _CMD="curl -s \
    $( ([[ "${ANONYMOUS}" != 1 ]] && echo " -u${RT_USER:?}:${RT_TOKEN:?}") || true) \
    -XGET \
    ${RT_URL}/api/storage/${DST_PATH}"

  eval "${_CMD}"
}

upload_node_image() {

    img_name="$1"

    # Upload image with new name
    rt_upload_artifact "${img_name}.qcow2" "${RT_FOLDER}/${img_name}" "0"

    # Remove outdated node images, keep n number of latest ones
    # Get list of artifacts into an array
    mapfile -t < <(rt_list_directory "${RT_FOLDER}" 0 | \
    jq '.children | .[] | .uri' | \
    sort -r |\
    grep "${img_name}_20" | \
    sed -e 's/\"\/\([^"]*\)"/\1/g') 

    #   Delete artifacts
    for ((i="${RETENTION_NUM}"; i<${#MAPFILE[@]}; i++)); do
    rt_delete_artifact "${RT_FOLDER}/${MAPFILE[i]}" "0"
    echo "${MAPFILE[i]} has been deleted!"
    done
}
