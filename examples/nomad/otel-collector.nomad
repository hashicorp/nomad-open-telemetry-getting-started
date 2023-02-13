# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Nomad adaption of the Kubernetes example from
# https://github.com/open-telemetry/opentelemetry-collector/blob/main/examples/k8s/otel-config.yaml

variables {
  otel_image = "otel/opentelemetry-collector:0.53.0"
}

job "otel-collector" {
  datacenters = ["dc1"]
  type        = "service"

  group "otel-collector" {
    count = 1

    network {
      port "metrics" {
        to = 8888
      }

      # Receivers
      port "grpc" {
        to = 4317
      }

      port "jaeger-grpc" {
        to = 14250
      }

      port "jaeger-thrift-http" {
        to = 14268
      }

      port "zipkin" {
        to = 9411
      }

      # Extensions
      port "zpages" {
        to = 55679
      }
    }

    service {
      name     = "otel-collector"
      port     = "grpc"
      tags     = ["grpc"]
      provider = "nomad"
    }

    task "otel-collector" {
      driver = "docker"

      config {
        image = var.otel_image

        entrypoint = [
          "/otelcol",
          "--config=local/config/otel-collector-config.yaml",
        ]

        ports = [
          "metrics",
          "grpc",
          "jaeger-grpc",
          "jaeger-thrift-http",
          "zipkin",
          "zpages",
        ]
      }

      resources {
        cpu    = 500
        memory = 2048
      }

      template {
        data = <<EOF
receivers:
  otlp:
    protocols:
      grpc:
      http:
processors:
  batch:
  memory_limiter:
    # 80% of maximum memory up to 2G
    limit_mib: 1500
    # 25% of limit up to 2G
    spike_limit_mib: 512
    check_interval: 5s
extensions:
  zpages: {}
  memory_ballast:
    # Memory Ballast size should be max 1/3 to 1/2 of memory.
    size_mib: 683
exporters:
  otlp:
    endpoint: "http://someotlp.target.com:4317" # Replace with a real endpoint.
    tls:
      insecure: true
service:
  extensions: [zpages, memory_ballast]
  pipelines:
    traces/1:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp]
EOF

        destination = "local/config/otel-collector-config.yaml"
      }
    }
  }
}
