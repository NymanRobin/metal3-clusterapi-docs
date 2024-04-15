#!/usr/bin/env bash

set -eux

export IMAGE_OS="${IMAGE_OS}"
export IMAGE_TYPE="${IMAGE_TYPE}"

current_dir="$(dirname "$(readlink -f "${0}")")"

# shellcheck disable=SC1091
source "./upload-ci-image.sh"
# shellcheck disable=SC1091
source "./upload-node-image.sh"

# Disable needrestart interactive mode
sudo sed -i "s/^#\$nrconf{restart} = 'i';/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf > /dev/null

sudo apt-get update
sudo apt-get install python3-pip qemu qemu-kvm -y
sudo pip3 install diskimage-builder python-openstackclient

export ELEMENTS_PATH="${current_dir}/dib_elements"
export DIB_DEV_USER_USERNAME="metal3ci"
export DIB_DEV_USER_PWDLESS_SUDO="yes"
export DIB_DEV_USER_AUTHORIZED_KEYS="${current_dir}/id_ed25519_metal3ci.pub"
if [[ "${IMAGE_TYPE}" == "node" ]]; then
  # The default data source for cloud-init element is exclusively Amazon EC2
  export KUBERNETES_VERSION="${KUBERNETES_VERSION:-"v1.29"}"
  export CRIO_VERSION="${CRIO_VERSION:-"v1.29"}"
  export DIB_CLOUD_INIT_DATASOURCES="ConfigDrive"
fi

if [[ "${IMAGE_OS}" == "ubuntu" ]]; then
  export DIB_RELEASE=jammy
else
  export DIB_RELEASE=9
fi

commit_short="$(git rev-parse --short HEAD)"
img_date="$(date --utc +"%Y%m%dT%H%MZ")"
img_name="metal3${IMAGE_TYPE}-${IMAGE_OS}-${img_date}-${commit_short}"
export HOSTNAME="${img_name}"

disk-image-create --no-tmpfs -a amd64 -o "${img_name}".qcow2 "${IMAGE_OS}"-"${IMAGE_TYPE}" block-device-efi

if [[ "${IMAGE_TYPE}" == "node" ]]; then
  upload_node_image "${img_name}"
else
  upload_ci_image "${img_name}"
fi
