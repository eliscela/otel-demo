#  **Setting Up OpenTelemetry Collector for Kubernetes Cluster Monitoring**

In today's cloud-native world, monitoring and observability are key pillars for understanding how applications perform in production environments. Kubernetes, a very powerful orchestration tool, manages containerized applications across a cluster of machines. But with great power comes great observability, which is where OpenTelemetry comes in. OpenTelemetry is an open-source observability framework for cloud-native software. This post will focus on setting up the OpenTelemetry Collector to monitor your entire Kubernetes cluster in a simple way, by providing a quick and re-usable configuration that can be a great starting point on your OpenTelemetry journey.

##  **What is OpenTelemetry?**

OpenTelemetry provides a single set of APIs, libraries, agents, and instrumentation to capture distributed traces, metrics and logs from your application. It aims to make it easy to get critical diagnostics data out of your services and into the tools where it can be analyzed. It is context aware, supports multiple programming languages and integrates with various backend systems to store or visualize the collected data.

###  **Benefits of Using OpenTelemetry**

* Unified Observability Framework: OpenTelemetry consolidates metrics, traces, and logs into a single framework, simplifying instrumentation and analysis.
* Vendor Agnostic: It provides flexibility in choosing backend analytics platforms without changing instrumentation.
* Rich Ecosystem: Supports a wide range of languages, frameworks, and tools.
* Context-aware: Enriches telemetry data with contextual information from the environment, improving observability and analysis.
* Community-Driven: Backed by the Cloud Native Computing Foundation (CNCF), ensuring a strong focus on open standards and community needs.


##  **Monitoring Kubernetes with OpenTelemetry**

Kubernetes environments are dynamic and complex, making them challenging to monitor. OpenTelemetry, with its comprehensive instrumentation capabilities, allows capturing detailed information about the state and performance of Kubernetes clusters and the applications running within them. In this post, we will use our configuration to monitor our application's metrics, logs and traces, as well as the cluster's performance itself.


##  **Setting up the base configuration for our demo**

**Pre-requisites**
- A working Kubernetes cluster
- Helm, kubectl and git installed
- The ability to apply Kubernetes manifests to this cluster

As the main intent of this guide is focused on monitoring your Kubernetes infrastructure using OpenTelemetry, we will assume you already have a working Kubernetes cluster ready, either hosted in the Cloud or locally. In our case, this demo will make use of a managed Kubernetes cluster running on AWS EKS. If a Kubernetes cluster is not available to you, please make sure to create one and come back to this point. There are plenty of guides that can help you set this up online.

Additionally, you should have the necessary tools/permissions to install Helm applications and apply Kubernetes YAML manifests.

####  **What we will deploy**

To get up to speed with a sample environment for our monitoring purposes, we need the following 2 components:

1. The OpenTelemetry components (using the OpenTelemetry Operator)
2. A sample microservice-based application to monitor (using the [OnlineBoutique application](https://github.com/GoogleCloudPlatform/microservices-demo))

####  **1. Setting Up the OpenTelemetry Operator in Kubernetes**

To monitor a Kubernetes cluster with OpenTelemetry, we will first deploy the OpenTelemetry Kubernetes Operator, which provides us with an easy way to configure and manage our OpenTelemetry Configuration as Kubernetes manifests. This will make our monitoring setup portable, readable and re-usable, as we can have a seemingly complex setup in just small(ish) file. The best way to install the Operator, is by using the official open-telemetry/opentelemetry-operator Helm chart. Here's how to install it:

```
helm upgrade --install otel open-telemetry/opentelemetry-operator -n otel --create-namespace \
  --set "manager.collectorImage.repository=otel/opentelemetry-collector-k8s" \
  --set "admissionWebhooks.certManager.enabled=false" \
  --set "admissionWebhooks.autoGenerateCert.enabled=true"
```

This will install the Helm release in the **otel** namespace (it will be created in case it does not exist). This namespace will only be tasked with managing the OpenTelemetry Operator component as well as all other subcomponents (instrumentation, sidecar, gateway) and to provide a logical separation from the application namespaces. This way developers can keep their project namespaces clean and not have to deal with monitoring components.

#### **Important note: For demo purposes, we are generating self-signed certificates to deploy the operator. In production environments, you absolutely should deploy cert-manager corrently and let it manage your certificates instead.**

###
####  **2. Deploying a sample microservice based application**

For demonstration purposes, we'll use the Online Boutique, which is a cloud-native microservices demo application. Deploy it in the **boutique** namespace using Helm:

```
helm upgrade --install boutique oci://us-docker.pkg.dev/online-boutique-ci/charts/onlineboutique -n boutique --create-namespace
```

##  **Understanding the OpenTelemetry Configuration Architecture**

The configuration file provided outlines a sophisticated setup involving multiple components of OpenTelemetry within a Kubernetes environment. Here are key points about the architecture and the rationale behind the design decisions:

####  OpenTelemetry Components
* **Instrumentation**: The `instrumentation` component is one of the most unique components of an OpenTelemetry monitoring system. It enables you to receive telemetry (metrics, traces, logs) from applications directly. On certain programming languages, the auto-instrumentation feature is available, which allows you to receive telemetry without modifying your application's source code. This can help you get started quickly with OpenTelemetry without extra overhead for developers, as they do not have to concern themselves with supporting a OpenTelemetry backend. The auto-instrumentation feature is available on [certain programming languages](https://opentelemetry.io/docs/kubernetes/operator/automatic/).

###
* **Collectors**: There are 2 kinds of OpenTelemetry Collectors: Sidecars and Gateways.
    * `Sidecar` collectors, also known as agent collectors, modify your existing Kubernetes pods by adding a sidecar container (named `otc-container`), which is responsible for receiving telemetry data from your application pods and sending it to a different backend. This can be quite resource intensive for your cluster, but can guarantee a reliable, decentralized and customizable configuration for each specific application.
    * `Gateway` collectors work in a simpler configuration. Once configured, Gateway pods wait for telemetry data on the pre-configured "receiver" endpoints, and then processes or pushes this information to another backend, based on your setup. This works quite nicely in combination with an auto-instrumentation component. Gateway configurations are much more efficient at scale, however, they can also introduce a single point of failure as compared to sidecar collectors.

###
In our case, we are using auto-instrumentation as well as a gateway to collect our telemetry data. This data is later processed and cleaned up based on our rules (we will see these in action later) and sent to 2 different backends: a cloud Grafana Stack, as well as a NewRelic instance. Since we plan on also monitoring our Kubernetes nodes themselves, we are deploying the Gateway Collector a Daemonset, ensuring that an instance of the collector runs on every node.
###

####  Receivers, Processors, and Exporters

The choice of receivers, processors, and exporters in the configuration reflects a comprehensive approach to capturing, processing, and exporting telemetry data:

* **Receivers:** `kubeletstats`, `filelog`, and `otlp` are configured to capture a broad spectrum of data, from Kubernetes metrics to container/pod logs and OpenTelemetry Protocol (OTLP) data respectively. This setup ensures that the collector gathers information from both the infrastructure and the applications.

* **Processors:** The configuration employs a variety of processors such as `batch`, `resource`, `resourcedetection/eks`, and `k8sattributes`. This selection underlines the need to enrich, organize, and optimize the telemetry data before exporting. For instance, the `resource`processor modifies the resources by adding attributes to them. `batch` ensures data is sent in batches to not spam the Kubernetes cluster with requests. `resourcedetection/eks` tags components with EKS tags if they are part of an EKS cluster. In combination with other resourcedetection processors, this can be very valuable in multi-cloud setups. In this case we are only using AWS, so we have not configured other cloud providers. Lastly, the `k8sattributes` processor enriches data with Kubernetes context, which is invaluable for correlating data across the cluster.

* **Exporters:** The `debug` exporter is primarily used for demonstration purposes in this configuration, as it directly shows the information being captures as part of the Kubernetes otel pod logs. Additionally, we have demonstrated two different example exporters, one for NewRelic, and one for the Grafana Cloud stack. The choice of exporters will depend on your backend systems and the specific insights you wish to gain. This is the part where you should review your monitoring providers documentation on how to send data using OpenTelemetry.

* **Extensions:** Provide additional capabilities like health checks and memory management.

* **Service:** Orchestrates the data flow through receivers, processors, and exporters and brings the entire configuration together.



###  **Design Decisions**

* DaemonSet Mode for Cluster-Wide Monitoring: The `otel-gateway` collector runs as a DaemonSet, ensuring a collector instance on each node for comprehensive coverage. This is especially necessary with the `kubeletstats` and `filelog` receivers, ensuring the ability to gather metrics and logs from every node.

* Security and Access: The configuration includes RBAC settings ensuring the collector has necessary access to Kubernetes APIs for metrics and logs.

* Flexibility in Data Processing: The use of multiple processors and receivers demonstrates the flexibility in processing and enriching telemetry data before exporting it.


###  **Considerations and Gotchas**

When implementing this setup, there are several considerations and potential pitfalls to keep in mind:

* Security: The use of `insecure_skip_verify: true` and `tls: insecure: true` in the configuration is suitable for demonstration purposes but poses a significant security risk in production. Always ensure communication is secured via TLS and proper certificate validation is in place.

* Performance Impact: Running a Sidecar collector on every pod can have performance implications compared to using a Gateway collector. Monitor the resource usage and choose your own deployment strategy based on your requirements to prevent impact on your applications.

* Log Collection Configuration: The `filelog` receiver is configured to exclude logs from containers named `otel-collector` to avoid self-monitoring loops. It's crucial to maintain such exclusions and carefully manage include/exclude patterns to prevent unnecessary data collection that can lead to performance degradation and increased costs.

* Data Enrichment: While the `k8sattributes` processor significantly enriches telemetry data with Kubernetes context, it's important to ensure that this does not lead to excessive data in your metrics and traces, which can strain your monitoring systems and increase costs.

* Compatibility and Updates: Kubernetes and OpenTelemetry both evolve rapidly. Keep an eye on compatibility issues and be prepared to update your configurations and deployments as new versions are released.

##  **Deploying the OpenTelemetry monitoring configuration**

Now that you have a better understanding of the configuration components and the decision-making behind them, it is time to deploy our configuration.

In order to deploy the OpenTelemetry configuration, run the following command:
```
kubectl apply -f https://raw.githubusercontent.com/eliscela/otel-demo/main/otel-components.yml
```

This will create the desired OTel components, meaning the instrumentation and the gateway collector. The collector should create 1 Pod for each node we have, due to our DaemonSet configuration. Additionally, you should also see Pods for the Operator itself, that manages and deploys all these resources.

![Deployed OTel Components](images/deployed_components.png?raw=true "Deployed OTel Components")

Now that the components are installed, you should start seeing data coming in your exporter backends (make sure to have configured these before-hand)
A lot of this data will be related to logs from the nodes, and kubernetes metrics. However, unless you have manually connected your application to the OpenTelemetry endpoints, you will not be able to receive application-level traces. In these situations, if your applications' programming language supports it, you can enable auto-instrumentation to automatically inject the necessary changes into your application. This comes mostly in the form of adding some specific annotations to your Pod metadata. For this demo, I have created a script that will patch a few specific Pods from our OnlineBoutique demo application in order for us to see auto-instrumentation in action.

```
curl -sL https://raw.githubusercontent.com/eliscela/otel-demo/main/automatic-patching.sh | bash
```

![Debug exporter showing information that is being sent](images/log_output.png?raw=true "Debug exporter showing information that is being sent")

##  **Conclusion**

Setting up OpenTelemetry Collector for Kubernetes monitoring provides deep insights into your applications and infrastructure. By following the steps outlined in this blog, you can gain visibility into your cluster's performance, helping you make informed decisions and ensure the reliability of your services. By understanding the architecture decisions and maintaining awareness of potential gotchas, you can create a robust monitoring solution that provides deep insights into your microservices architecture while ensuring scalability and security. As OpenTelemetry continues to evolve, it is becoming the go-to standard for observability in cloud-native ecosystems.
