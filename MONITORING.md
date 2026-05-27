# 📊 Prometheus & Grafana — AWS EKS Monitoring

Cluster monitoring using `kube-prometheus-stack` — installs Prometheus, Grafana, AlertManager, and all Kubernetes dashboards in one Helm chart.

---

## Prerequisites

- kubectl configured and connected to your EKS cluster
- Helm installed

---

## Installation

**Step 1 — Add Helm repo**

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

---

**Step 2 — Install kube-prometheus-stack**

```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

---

**Step 3 — Verify all pods are running**

```bash
kubectl get pods -n monitoring
```

Wait until all pods show `Running` before proceeding.

---

## Access Grafana

**Step 4 — Expose Grafana via LoadBalancer or you can use port forwarding**

```bash
kubectl patch svc prometheus-grafana \
  -n monitoring \
  -p '{"spec": {"type": "LoadBalancer"}}'
```

---

**Step 5 — Get the External IP**

```bash
kubectl get svc prometheus-grafana -n monitoring
```

Wait for the `EXTERNAL-IP` column to populate. Open it in your browser.

```
http://<EXTERNAL-IP>
```

---

**Step 6 — Get Grafana admin password**

```bash
kubectl get secret prometheus-grafana \
  -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 -d
```

Login with:
- Username: `admin`
- Password: output from above command

---

## Dashboards

All dashboards come pre-installed.

| Dashboard | What it shows |
|---|---|
| Kubernetes Cluster | Pod, CPU, memory, disk usage across cluster |
| Kubernetes Cluster (Prometheus) | Deployment replicas, pod capacity, node health |
| Node Exporter / Nodes | Per-node CPU, memory, disk, network |
| Node Exporter Full | Detailed node-level system metrics |
| Kubernetes / Networking / Pod | Per-pod network traffic |
| Kubernetes / Networking / Namespace | Namespace-level network usage |
| Kubernetes / Workload | Deployment, daemonset, statefulset overview |
| Prometheus / Overview | Prometheus scrape health and metrics |

Go to **Dashboards** in the left sidebar to browse all of them.

---