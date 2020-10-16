### Running kubernetes job locally

#### Prerequisites

- [minikube](https://minikube.sigs.k8s.io/docs/start/)
- [docker] (https://docs.docker.com/get-docker/)


#### 1. Start minikube cluster

```sh
minikube start
```

#### 2. Build perf docker image

The following commands have to be run in the same terminal session. See the [official instructions](https://minikube.sigs.k8s.io/docs/handbook/pushing/#1-pushing-directly-to-the-in-cluster-docker-daemon-docker-env).

1. Point your terminal to use the docker daemon inside minikube:

```
eval $(minikube docker-env)
```

2. Build docker image:

```
docker build -f Dockerfile -t perf:latest .
```

#### 3. Add host alias of your machine to the k8s job

1. Get minikube intenal ip:

```
minikube ssh grep host.minikube.internal /etc/hosts | cut -f1
```

2. Replace the following `ip` field with ip returned from the previous command in `k8s_job.yaml` file:

```
...
    spec:
      hostAliases:
      - ip: "192.168.64.1"
        hostnames:
        - "host.minikube.internal"
...
```

#### 4. Run the k8s job

1. Start the required elixir-omg services, for example, with docker-compose
2. Replace environment variables in `k8s_job` if it's needed.
3. Start job:

```
kubectl apply -f k8s_job.yaml
```

4. Monitor logs:

```
kubectl logs --follow job.batch/perf-job
```

5. To delete job use:

```
kubectl delete -f k8s_job.yaml
```
