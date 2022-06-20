# Nomad adaption of the Docker Compose demo from
# https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/examples/demo

variables {
  otelcol_img  = "otel/opentelemetry-collector-contrib-dev:latest"
  otelcol_args = []
}

job "otel-demo" {
  datacenters = ["dc1"]
  type        = "service"

  # Jaeger
  group "jaeger-all-in-one" {
    network {
      port "ui" {
        to     = 16686
        static = 16686
      }

      port "thrift" {
        to = 14268
      }

      port "grpc" {
        to = 14250
      }
    }

    service {
      name     = "otel-demo-jaeger"
      port     = "grpc"
      tags     = ["grpc"]
      provider = "nomad"
    }

    task "jaeger-all-in-one" {
      driver = "docker"

      config {
        image = "jaegertracing/all-in-one:latest"
        ports = ["ui", "thrift", "grpc"]
      }

      resources {
        cpu    = 200
        memory = 100
      }
    }
  }

  # Zipkin
  group "zipkin-all-in-one" {
    network {
      port "http" {
        to     = 9411
        static = 9411
      }
    }

    service {
      name     = "otel-demo-zipkin"
      port     = "http"
      provider = "nomad"
    }

    task "zipkin-all-in-one" {
      driver = "docker"

      config {
        image = "openzipkin/zipkin:latest"
        ports = ["http"]
      }

      resources {
        cpu    = 250
        memory = 350
      }
    }
  }

  # Collector
  group "otel-collector" {
    network {
      # Prometheus metrics exposed by the collector
      port "metrics" {
        to     = 8888
        static = 8888
      }

      # Receivers
      port "grpc" {
        to = 4317
      }

      # Extensions
      port "pprof" {
        to     = 1888
        static = 1888
      }

      port "zpages" {
        to     = 55679
        static = 55679
      }

      port "health-check" {
        static = 13133
        to     = 13133
      }

      # Exporters
      port "prometheus" {
        to     = 8889
        static = 8889
      }
    }

    service {
      name     = "otel-demo-collector"
      port     = "grpc"
      tags     = ["grpc"]
      provider = "nomad"
    }

    service {
      name     = "otel-demo-collector"
      port     = "metrics"
      tags     = ["metrics"]
      provider = "nomad"
    }

    service {
      name     = "otel-demo-collector"
      port     = "prometheus"
      tags     = ["prometheus"]
      provider = "nomad"
    }

    task "otel-collector" {
      driver = "docker"

      config {
        image = var.otelcol_img
        args  = concat(["--config=/etc/otel-collector-config.yaml"], var.otelcol_args)

        ports = [
          "pprof",
          "metrics",
          "prometheus",
          "grpc",
          "health-check",
          "zpages",
        ]

        volumes = [
          "local/otel-collector-config.yaml:/etc/otel-collector-config.yaml",
        ]
      }

      resources {
        cpu    = 200
        memory = 64
      }

      template {
        data = <<EOF
receivers:
  otlp:
    protocols:
      grpc:

exporters:
  prometheus:
    endpoint: "0.0.0.0:{{env "NOMAD_PORT_prometheus"}}"
    const_labels:
      label1: value1

  logging:

  zipkin:
    endpoint: "http://{{with nomadService "otel-demo-zipkin"}}{{with index . 0}}{{.Address}}:{{.Port}}{{end}}{{end}}/api/v2/spans"
    format: proto

  jaeger:
    endpoint: {{with nomadService "grpc.otel-demo-jaeger"}}{{with index . 0}}{{.Address}}:{{.Port}}{{end}}{{end}}
    tls:
      insecure: true

processors:
  batch:

extensions:
  health_check:
  pprof:
    endpoint: :{{env "NOMAD_PORT_pprof"}}
  zpages:
    endpoint: :{{env "NOMAD_PORT_zpages"}}

service:
  extensions: [pprof, zpages, health_check]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [logging, zipkin, jaeger]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [logging, prometheus]
EOF

        destination = "local/otel-collector-config.yaml"
      }
    }
  }

  # Demo client and server
  group "demo-client" {
    task "client" {
      driver = "docker"

      config {
        image = "laoqui/otel-demo-client:latest"
      }

      template {
        data = <<EOF
OTEL_EXPORTER_OTLP_ENDPOINT={{with nomadService "grpc.otel-demo-collector"}}{{with index . 0}}{{.Address}}:{{.Port}}{{end}}{{end}}
DEMO_SERVER_ENDPOINT=http://{{with nomadService "otel-demo-server"}}{{with index . 0}}{{.Address}}:{{.Port}}{{end}}{{end}}/hello
EOF

        destination = "local/env"
        env         = true
      }
    }
  }

  group "demo-server" {
    network {
      port "http" {
        to = 7080
      }
    }

    service {
      name     = "otel-demo-server"
      port     = "http"
      provider = "nomad"
    }

    task "server" {
      driver = "docker"

      config {
        image = "laoqui/otel-demo-server:latest"
        ports = ["http"]
      }

      template {
        data = <<EOF
OTEL_EXPORTER_OTLP_ENDPOINT={{with nomadService "grpc.otel-demo-collector"}}{{with index . 0}}{{.Address}}:{{.Port}}{{end}}{{end}}
EOF

        destination = "local/env"
        env         = true
      }
    }
  }

  # Prometheus
  group "prometheus" {
    network {
      port "http" {
        to     = 9090
        static = 9090
      }
    }

    task "prometheus" {
      driver = "docker"

      config {
        image   = "prom/prometheus:latest"
        ports   = ["http"]
        volumes = ["local/prometheus.yaml:/etc/prometheus/prometheus.yml"]
      }

      template {
        data = <<EOF
scrape_configs:
  - job_name: 'otel-collector'
    scrape_interval: 10s
    static_configs:
      - targets: [{{range nomadService "prometheus.otel-demo-collector"}}'{{.Address}}:{{.Port}}',{{end}}]
      - targets: [{{range nomadService "metrics.otel-demo-collector"}}'{{.Address}}:{{.Port}}',{{end}}]
EOF

        destination = "local/prometheus.yaml"
      }
    }
  }
}
