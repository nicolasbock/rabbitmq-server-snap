#!/bin/bash

set -e -u

: ${NAME:=rabbitmq-server-snap}

cleanup() {
  rm -rf ${tempdir}
}

remote() {
  local wd=$1
  shift
  multipass exec --working-directory ${wd} ${NAME} -- "$@"
}

if multipass info ${NAME}; then
  multipass delete --purge ${NAME}
fi

if virsh dominfo ${NAME}; then
  virsh destroy ${NAME}
fi

while virsh dominfo ${NAME}; do
  sleep 1
done

dev-container.sh --series focal \
  --name ${NAME} \
  --backend multipass \
  --memory 32G

tempdir=$(mktemp --directory)

trap cleanup EXIT

cat <<EOF > ${tempdir}/local-user-data
#cloud-config
package_update: true
apt:
  http_proxy: ${http_proxy}
  https_proxy: ${https_proxy}
write_files:
  - encoding: b64
    content: $(base64 --wrap=0 /usr/local/share/ca-certificates/squid-deb-proxy.crt)
    path: /usr/local/share/ca-certificates/squid-deb-proxy.crt
    permissions: '0644'
snap:
  commands:
    01: snap set system proxy.http="${http_proxy}"
    02: snap set system proxy.https="${https_proxy}"
runcmd:
  - update-ca-certificates --verbose
  - systemctl restart snapd.service
EOF

set -x

# Remember that the default behavior of `multipass exec` is to run in the
# mounted directory

remote . git config --global user.email 'nicolabock@gmail.com'
remote . git config --global user.name 'Nicolas Bock'
remote . git clone --branch test https://github.com/nicolasbock/snapcraft.git
remote ./snapcraft git tag --annotate --message test v1.2.3
remote . sudo groupadd --force --system lxd
remote . sudo usermod --append --groups lxd ubuntu
remote . sudo snap refresh lxd
remote . sudo lxd init --auto
remote . sudo lxc profile set default user.user-data - < ${tempdir}/local-user-data
remote . sudo iptables -P FORWARD ACCEPT
remote . sudo snap install --channel stable --classic snapcraft
remote ./snapcraft sg lxd -c 'snapcraft --use-lxd'
remote ./snapcraft sudo snap install --dangourous --classic ./snapcraft*snap
