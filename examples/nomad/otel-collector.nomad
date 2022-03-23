variables {
  otel_image = "otel/opentelemetry-collector:0.47.0"
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
      port "otlp" {
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
      name = "otel-collector"
      port = "otlp"
      tags = ["otlp"]
    }

    service {
      name = "otel-collector"
      port = "jaeger-grpc"
      tags = ["jaeger-grpc"]
    }

    service {
      name = "otel-collector"
      port = "jaeger-thrift-http"
      tags = ["jaeger-thrift-http"]
    }

    service {
      name = "otel-collector"
      port = "zipkin"
      tags = ["zipkin"]
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
          "otlp",
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
        data        = <<EOF
receivers:
  otlp:
    protocols:
      grpc:
      http:
  jaeger:
    protocols:
      grpc:
      thrift_http:
  zipkin: {}
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
  zipkin:
    endpoint: "http://somezipkin.target.com:9411/api/v2/spans" # Replace with a real endpoint.
  jaeger:
    endpoint: "somejaegergrpc.target.com:14250" # Replace with a real endpoint.
    tls:
      insecure: true
service:
  extensions: [zpages, memory_ballast]
  pipelines:
    traces/1:
      receivers: [otlp, zipkin]
      processors: [memory_limiter, batch]
      exporters: [zipkin]
    traces/2:
      receivers: [otlp, jaeger]
      processors: [memory_limiter, batch]
      exporters: [jaeger]
EOF
        destination = "local/config/otel-collector-config.yaml"
      }
    }
  }
}
