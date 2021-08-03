# Getting Started with OpenTelemetry on HashiCorp Nomad

This repository contains reference job files to run the [OpenTelemetry collector](https://opentelemetry.io/docs/collector/)
in different deployment scenarios, as described in the [Getting Started](https://opentelemetry.io/docs/collector/getting-started/)
guide.

_These job files are provided as reference only, and are not designed for
production use._

## Deployment

From the official documentation:

> The OpenTelemetry Collector consists of a single binary and two primary deployment methods:
>
>  - **Agent**: A Collector instance running with the application or on the same host as the application (e.g. binary, sidecar, or daemonset).
>  - **Gateway**: One or more Collector instances running as a standalone service (e.g. container or deployment) typically per cluster, datacenter or region.

To run the job files you will need access to a Nomad cluster and, optionally, a
Consul cluster as well. You can start a local dev agent for Nomad and Consul by
downloading the [`nomad`](https://www.nomadproject.io/downloads) and
[`consul`](https://www.consul.io/downloads) binary and running the following
commands in two different terminals:

```shell-session
$ nomad agent -dev -network-interface='{{ GetPrivateInterfaces | attr "name" }}'
```

```shell-session
$ consul agent -dev
```

### Gateway

The OpenTelemetry Collector can run as a gateway by registering a
[service](https://www.nomadproject.io/docs/schedulers#service) job.

```shell-session
$ nomad run https://raw.githubusercontent.com/hashicorp/nomad-open-telemetry-getting-started/main/examples/nomad/otel-collector.nomad
```

### Agent

The OpenTelemetry Collector can run as an agent by registering a
[system](https://www.nomadproject.io/docs/schedulers#system) job.

It connects to the gateway deployed in the previous section as an OTLP
exporter, so make sure the gateway job is running as well.

```shell-session
$ nomad run https://raw.githubusercontent.com/hashicorp/nomad-open-telemetry-getting-started/main/examples/nomad/otel-agent.nomad
```

### Demo

The demo job deploys the OpenTelemetry Collector as agent and gateway, load
generators, and the Jaeger, Zipkin and Prometheus back-ends.

```shell-session
$ nomad run https://raw.githubusercontent.com/hashicorp/nomad-open-telemetry-getting-started/main/examples/nomad/otel-demo.nomad
```

The following services are available:

* Jaeger: http://<YOUR_IP>:16686
* Zipkin: http://<YOUR_IP>:9411
* Prometheus: http://<YOUR_IP>:9090
