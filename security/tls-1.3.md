# TLS 1.3 support in Metal3 ecosystem

This document details the status of TLS 1.3 support in Metal3 ecosystem at the
time of writing (Jan 2023).

## Ecosystem

The Metal3 ecosystem refers to:

- BMO (Baremetal Operator, including Ironic)
- CAPI (Cluster API)
- CAPM3 (Cluster API Provider Metal3)
- cert-manager (Certificate Manager)
- kube-system (Kubernetes)
- Other (metal3-dev-env)

## Background information

### TLS 1.3 support in Golang

Starting in Go 1.13, TLS 1.3 support has been available. In Go 1.13, TLS 1.3 was
"opt-in", which led many projects adding `GODEBUG=tls13=1` to their
environments. This is only necessary and meaningful in Go 1.13. In later
versions TLS 1.3 is "opt-out", ie. you need to set TLS minimum and maximum
versions in project's `tls.Config`.

### TLS 1.0 and TLS 1.1 in Golang

Starting in Go 1.18, TLS 1.0 and TLS 1.1 have been disabled by default in
Golang. This leaves TLS 1.2 and TLS 1.3 as the only versions of TLS in Go 1.18
and later, unless project explicitly adds support for TLS 1.0 and TLS 1.1 back
via `tls.Config`.

### Configuration of min and max TLS versions

Many of the projects have only recently or not at all added support for
configuring minimum or maximum TLS versions. Without project's support for
configuration, TLS version negotiation is left to server and the client.

## Components

### BMO

**controller-manager**:

- Port `8443`: TLS 1.2, TLS 1.3

TLS version is not configurable with flags.

**ironic**:

For Ironic, it should be noted that:

- IPA image serving from `httpd` port `6180` might be insecure due to BMC or
  (i)PXE firmware limitations, the user has to enable TLS for both
  iPXE and virtual media. In case of iPXE, custom iPXE firmware building
  is required. If TLS is enabled for virtual media and iPXE, additional
  TLS enabled ports will be opened in the form of `8083` and `8084`
  respectively.

- The `node image server` could use `HTTPS` but that would require an IPA build
  process that injects the relevant certificate to the IPA. In addition to IPA,
  Ironic would also need access to the node image server certificates. Once the
  certificates are supplied, both IPA and Ironic supports TLS 1.3 during the
  `node image download` workflow, the process is facilitated via the third
  party request [library](https://pypi.org/project/requests/), same library is
  used by Ironic for `validating the node images`. Currently there is no way to
  enable TLS support for the `node image server` in case `ironic-image` is used
  to provide the `node image server` functionality.

- Ironic external endpoints are secured via `httpd` (Apache) that handles TLS
  termination. Between the `http proxy` and Ironic/Inspector the communication
  could go via UNIX socket or http depending on configuration. Ironic and
  Ironic Inspector internal http ports can be substituted with `UNIX sockets`
  if `IRONIC_INSPECTOR_PRIVATE_PORT` and the `IRONIC_PROVIATE_PORT` environment
  variables are configured to have the special `unix` string value.

- Currently Ironic pod is attached to the host network thus the internal
  ports are available from the host machine as well as from within the pod.

Ironic Ports:

- Port `5049`: HTTP (Ironic Inspector API) replaceable with UNIX socket
- Port `5050`: TLS 1.2, TLS 1.3 (httpd - Inspector endpoint)
- Port `6180`: HTTP (httpd - serving IPA images) .
- Port `80`: HTTP (httpd - deployed externally to the Ironic pod, hosts node
  images)
- Port `8083`: TLS 1.2, TLS 1.3 (httpd - serving IPA via vmedia+TLS)
- Port `8084`: TLS 1.2, TLS 1.3 (httpd - serving IPA via custom iPXE+TLS)
- Port `6385`: TLS 1.2, TLS 1.3 (httpd - Ironic endpoint)
- Port `6388`: HTTP (Ironic API) replaceable with UNIX socket

Ironic endpoints support setting minimum and maximum TLS versions.

Ironic Python Agent ports:

- Port `9999`: TLS 1.2/1.3 auto-negotiation by default,
  TLS 1.3 exclusive connection can't be enforced

More info:

- [OSLO library](https://docs.openstack.org/oslo.service/latest/configuration/index.html#ssl.version)
  officially does not mention TLS 1.3 support but by default TLS 1.2 and
  TLS 1.3 are enabled with auto negotiation ability thus TLS 1.3 is supported
  but can't be enforced.
- [IPA TLS configuration documentation](https://docs.openstack.org//ironic-python-agent/latest/doc-ironic-python-agent.pdf)

### CAPI

All CAPI controllers support setting minimum and maximum TLS versions, with the
exception of `CAPD` which is a test provider.

**capi-kubeadm-bootstrap**:

- Port `9443`: TLS 1.2, TLS 1.3
- Port `9440`: HTTP (healthz)
- Port `8080`: HTTP (metrics)

**capi-kubeadm-control-plane**:

- Port `9443`: TLS 1.2, TLS 1.3
- Port `9440`: HTTP (healthz)
- Port `8080`: HTTP (metrics)

**capi-controller-manager**:

- Port `9443`: TLS 1.2, TLS 1.3
- Port `9440`: HTTP (healthz)
- Port `8080`: HTTP (metrics)

### CAPM3

**capm3-controller-manager**:

- Port `9443`: TLS 1.2, TLS 1.3
- Port `9440`: HTTP (healthz)
- Port `8080`: HTTP (metrics)

TLS version is not configurable with flags.

**ipam-controller-manager**:

- Port `9443`: TLS 1.2, TLS 1.3
- Port `9440`: HTTP (healthz)
- Port `8080`: HTTP (metrics)

TLS version is not configurable with flags.

### cert-manager

**cert-manager**:

- Port `9402`: HTTP (metrics)

**cert-manager-cainjector**:

- no listening ports

**cert-manager-webhook**:

- Port `10250`: TLS 1.2, TLS 1.3
- Port `6080`: HTTP (healthz)

### kube-system

**coredns**:

- Port `53` TCP/UDP: DNS
- Port `9153`: HTTP (metrics)

**etcd**:

For etcd, TLS 1.3 support was
[contributed by EST](https://github.com/etcd-io/etcd/pull/15156) and was added
to the 3.5.8 (April 13 2023). Etcd versions from `3.5.0` to `3.5.7` have
hardcoded TLS 1.2 version. Some versions of etcd `3.4.x` have support for
TLS 1.3 as they lack this hardcoding of TLS version, and using new enough
Golang enables TLS 1.3 for them. TLS 1.3 can be explicitly enabled starting
from `3.4.25` in case of `3.4.x` series is used or starting from `3.5.8` in
case `3.5.x` series is used.

- Port `2379`: TLS 1.2, TLS 1.3
- Port `2380`: TLS 1.2, TLS 1.3

**apiserver**:

- Port `8443`: TLS 1.2, TLS 1.3

`apiserver` supports setting minimum and maximum TLS versions.

**controller-manager**:

- Port `8443`: TLS 1.2, TLS 1.3

`controller-manager` supports setting minimum and maximum TLS versions.

**kube-proxy**:

- Port `8443`: TLS 1.2, TLS 1.3

`kube-proxy` supports setting minimum and maximum TLS versions.

**scheduler**:

- Port `8443`: TLS 1.2, TLS 1.3

`scheduler` supports setting minimum and maximum TLS versions.

**kubelet**:

- Port `10250`: TLS 1.2, TLS 1.3

`kubelet` supports setting minimum and maximum TLS versions.

### Other (metal3-dev-env)

Tools in development environment are not secured, since hardening them would
hinder developer experience. Development environment is not for production use.

**httpd-infra**:

`httpd-infra` is deployment specific server, hosting node images.

- Port `80`: HTTP (Ironic httpd-infra)

**registry**:

- Port `5000`: HTTP

**sushy-tools**:

- Port `8000`: HTTP

**kind**:

- Port `44037`: TLS 1.2, TLS 1.3

**vbmc**:

- Port `50891`: non-HTTP

## Summary

TLS 1.3 is well supported in Metal3 ecosystem, with a few caveats
as of 29.1.2024:

- Ironic Python Agent (IPA), where the Oslo library is not
  supporting TLS 1.3 officially but because of implementation characteristics
  of `oslo.service` and the nature of Python 3 (from 3.7 up to 3.12) TLS 1.3
  and 1.2 auto-negotiation is enabled by default but TLS 1.3 exclusive
  connection can't be enforced.

- Ironic and Ironic Inspector internal ports are available via HTTP from
  within the pod or the host machine by default, but could be switched to
  utilize `UNIX sockets`.

- httpd node image server doesn't support https but that is not an inherent
  limitation of either the Ironic, IPA or httpd but only how ironic-image httpd
  configuration is implemented as it expects the default IPA to lack
  necessary certificates. In production environments node images can be
  hosted from a https enabled server if the user builds and uses a custom IPA
  and provides the necessary certificates during IPA build.

- TLS support for virtual media and iPXE IPA boot process has to be enabled
  manually.
