variables {
  otel_image = "otel/opentelemetry-collector:0.38.0"
}

job "otel-agent" {
  datacenters = ["dc1"]
  type        = "system"

  group "otel-agent" {
    network {
      port "metrics" {
        to = 8888
      }

      # Receivers
      port "otlp" {
        to = 4317
      }

      # Extensions
      port "zpages" {
        to = 55679
      }
    }

    service {
      name = "otel-agent"
      port = "otlp"
      tags = ["otlp"]
    }

    service {
      name = "otel-agent"
      port = "metrics"
      tags = ["metrics"]
    }

    service {
      name = "otel-agent"
      port = "zpages"
      tags = ["zpages"]
    }

    task "otel-agent" {
      driver = "docker"

      config {
        image = var.otel_image

        entrypoint = [
          "/otelcol",
          "--config=local/config/otel-agent-config.yaml",
        ]

        ports = [
          "metrics",
          "otlp",
          "zpages",
        ]
      }

      resources {
        cpu    = 500
        memory = 500
      }

      template {
        data        = <<EOF
receivers:
  otlp:
    protocols:
      grpc:
      http:
exporters:
  otlp:
    endpoint: "{{ with service "otel-collector" }}{{ with index . 0 }}{{ .Address }}:{{ .Port }}{{ end }}{{ end }}"
    tls:
      insecure: true
    sending_queue:
      num_consumers: 4
      queue_size: 100
    retry_on_failure:
      enabled: true
processors:
  batch:
  memory_limiter:
    # 80% of maximum memory up to 2G
    limit_mib: 400
    # 25% of limit up to 2G
    spike_limit_mib: 100
    check_interval: 5s
extensions:
  zpages: {}
  memory_ballast:
    # Memory Ballast size should be max 1/3 to 1/2 of memory.
    size_mib: 165
service:
  extensions: [zpages, memory_ballast]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp]
EOF
        destination = "local/config/otel-agent-config.yaml"
      }
    }
  }
}
