# One2n Metrics Collection and Monitoring
A project for collecting, monitoring, and storing node metrics using Kubernetes

## Folder Structure
```
TaskO2n
├── containerisation
│   ├── Dockerfile
│   ├── metrics.sh
├── node-exporter
│   ├── daemonset.yaml
│   ├── service.yaml
├── metrics_cron
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates
│       ├── cronjob.yaml
│       ├── pvc.yaml
```

## Components
### Dockerfile
```
# Base image
FROM alpine:latest

# dependancy packages
RUN apk add --no-cache bash curl

COPY metrics.sh /usr/local/bin/metrics.sh

# Permission for the script
RUN chmod +x /usr/local/bin/metrics.sh

# Entrypoint
ENTRYPOINT ["/usr/local/bin/metrics.sh"]
```

### metrics.sh
```
#!/bin/bash
METRICS_URL=${METRICS_URL:-"http://node-exporter:9100/metrics"}
OUTPUT_DIR=${OUTPUT_DIR:-"/metrics"}
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
OUTPUT_FILE="$OUTPUT_DIR/node-metrics-$TIMESTAMP.txt"
mkdir -p "$OUTPUT_DIR"
curl -s "$METRICS_URL" > "$OUTPUT_FILE"
echo "Metrics are sent to $OUTPUT_FILE"
```

## Node Exporter

### daemonset.yaml
```
apiVersion: apps/v1
kind: DaemonSet
metadata:
  labels:
    app.kubernetes.io/component: exporter
    app.kubernetes.io/name: node-exporter
  name: node-exporter
  namespace: one2n
spec:
  selector:
    matchLabels:
      app.kubernetes.io/component: exporter
      app.kubernetes.io/name: node-exporter
  template:
    metadata:
      labels:
        app.kubernetes.io/component: exporter
        app.kubernetes.io/name: node-exporter
    spec:
      containers:
      - args:
        - --path.sysfs=/host/sys
        - --path.rootfs=/host/root
        - --no-collector.wifi
        - --no-collector.hwmon
        - --collector.filesystem.ignored-mount-points=^/(dev|proc|sys|var/lib/docker/.+|var/lib/kubelet/pods/.+)($|/)
        - --collector.netclass.ignored-devices=^(veth.*)$
        name: node-exporter
        image: prom/node-exporter
        ports:
          - containerPort: 9100
            protocol: TCP
        resources:
          limits:
            cpu: 250m
            memory: 180Mi
          requests:
            cpu: 102m
            memory: 180Mi
        volumeMounts:
        - mountPath: /host/sys
          mountPropagation: HostToContainer
          name: sys
          readOnly: true
        - mountPath: /host/root
          mountPropagation: HostToContainer
          name: root
          readOnly: true
      volumes:
      - hostPath:
          path: /sys
        name: sys
      - hostPath:
          path: /
        name: root
```

### service.yaml
```
kind: Service
apiVersion: v1
metadata:
  name: node-exporter
  namespace: one2n
  annotations:
    prometheus.io/scrape: 'true'
    prometheus.io/port: '9100'
spec:
  type: NodePort
  selector:
    app.kubernetes.io/component: exporter
    app.kubernetes.io/name: node-exporter
  ports:
    - name: node-exporter
      protocol: TCP
      port: 9100
      targetPort: 9100
      nodePort: 30000
```


## metrics_cron helm chart

### chart.yaml
```
apiVersion: v1
name: node-metrics-cron
type: application
version: 1.0.0
appVersion: "1.0"
namespace: one2n
```

### values.yaml
```
# CronJob
cronJob:
  # Currently set to 5 minutes to kirb resource consumption, but can be set to "* * * * *"
  schedule: "*/5 * * * *" 
  image:
    repository: indrasohoni/o2n
    tag: latest
  outputDir: "/metrics"
  metricsUrl: "http://node-exporter:9100/metrics"

# PV Config
persistence:
  enabled: true
  size: 1Gi
  storageClass: ""
```


### templates/cronjob.yaml
```
apiVersion: batch/v1
kind: CronJob
metadata:
  name: node-metrics-cron
  namespace: {{ .Release.Namespace }}
spec:
  schedule: "{{ .Values.cronJob.schedule }}"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: node-metrics
              image: "{{ .Values.cronJob.image.repository }}:{{ .Values.cronJob.image.tag }}"
              args:
                - "{{ .Values.cronJob.metricsUrl }}"
                - "{{ .Values.cronJob.outputDir }}"
              volumeMounts:
                - name: metrics-volume
                  mountPath: "{{ .Values.cronJob.outputDir }}"
          restartPolicy: OnFailure
          volumes:
            - name: metrics-volume
              hostPath:
                path: /metrics
                type: DirectoryOrCreate
```

### pvc.yaml
```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: metrics-pvc
  namespace: one2n
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: {{ .Values.persistence.size }}
  {{- if .Values.persistence.storageClass }}
  storageClassName: {{ .Values.persistence.storageClass }}
  {{- end }}
{{- end }}
```

## How to deploy

### Deploy node exporter
```
kubectl create ns one2n
kubectl apply -f node-exporter/daemonset.yaml
kubectl apply -f node-exporter/service.yaml
```

### Deploy the Helm chart
```
helm install metrics-cron metrics_cron -n one2n
```

### Check logs
```
kubectl logs <pod-name> -n one2n
```

Since I am running the setup on Minikube I am limited with resources

The above command should return a output as below
![image](https://github.com/user-attachments/assets/60a585a2-8c31-4716-8e9d-ac340e8ebed3)


When I ssh to minikube and navigate to /metrics I can see all the files created by my pod
![image](https://github.com/user-attachments/assets/71a36335-f1ba-4356-bbff-c89816e577b9)

If I do a cat in any of the files I receive below logs that are scraped from node exporter we deployed
![image](https://github.com/user-attachments/assets/183af706-36f0-4c0c-9e4f-5786709b6888)


## Authors
https://github.com/Indrajeet1995


