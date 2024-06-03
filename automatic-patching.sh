#!/bin/bash

# Patch pod annotations
printf "\n### Automatically patching Boutique pod annotations to support auto-instrumentation ###\n"
kubectl patch deployment -n boutique emailservice -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-python": "otel/instrumentation"}}}}}'
kubectl patch deployment -n boutique loadgenerator -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-python": "otel/instrumentation"}}}}}'
kubectl patch deployment -n boutique recommendationservice -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-python": "otel/instrumentation"}}}}}'
kubectl patch deployment -n boutique cartservice -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-dotnet": "otel/instrumentation"}}}}}'

kubectl patch deployment -n boutique frontend --type='json' -p='[
    {"op": "add", "path": "/spec/template/spec/containers/0/securityContext/capabilities/add", "value": [SYS_PTRACE]},
    {"op": "add", "path": "/spec/template/metadata/annotations", "value": {
        "instrumentation.opentelemetry.io/inject-go": "otel/instrumentation",
        "instrumentation.opentelemetry.io/otel-go-auto-target-exe": "/src/server"
        }
    }
]'

kubectl patch deployment -n boutique productcatalogservice --type='json' -p='[
    {"op": "add", "path": "/spec/template/spec/containers/0/securityContext/capabilities/add", "value": [SYS_PTRACE]},
    {"op": "add", "path": "/spec/template/metadata/annotations", "value": {
        "instrumentation.opentelemetry.io/inject-go": "otel/instrumentation",
        "instrumentation.opentelemetry.io/otel-go-auto-target-exe": "/src/server"
        }
    }
]'

kubectl patch deployment -n boutique shippingservice --type='json' -p='[
    {"op": "add", "path": "/spec/template/spec/containers/0/securityContext/capabilities/add", "value": [SYS_PTRACE]},
    {"op": "add", "path": "/spec/template/metadata/annotations", "value": {
        "instrumentation.opentelemetry.io/inject-go": "otel/instrumentation",
        "instrumentation.opentelemetry.io/otel-go-auto-target-exe": "/src/shippingservice"
        }
    }
]'

kubectl patch deployment -n boutique checkoutservice --type='json' -p='[
    {"op": "add", "path": "/spec/template/spec/containers/0/securityContext/capabilities/add", "value": [SYS_PTRACE]},
    {"op": "add", "path": "/spec/template/metadata/annotations", "value": {
        "instrumentation.opentelemetry.io/inject-go": "otel/instrumentation",
        "instrumentation.opentelemetry.io/otel-go-auto-target-exe": "/src/checkoutservice"
        }
    }
]'

printf "\n### Script execution finished ###\n"
