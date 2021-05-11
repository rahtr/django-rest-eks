# This guide lists the steps to deploy django-rest app to an EKS cluster using NGINX Ingress Controller for Kubernetes

### Pre-requisites
1. install [eksctl](https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html)
2. install [kubectl](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html)
3. install [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
4. configure [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)


### Step 1 (Optional) : Clone repo & build image
1. Clone this repo
`$ git clone https://github.com/ratripathi/django-rest-eks`

2. Build & tag

`$ docker build -t artifactory/repo:tag .`

Example:
`$ docker build -t rahulqelfo/django-rest:v1 .`

3. Push to docker hub(you need to login to docker hub before pushing the tag)

`$ docker push artifactory/repo:tag .`

Example:
`$ docker push rahulqelfo/django-rest:v1 .`

##### Alternatively you can use the pre-built image found here-->rahulqelfo/django-rest:v1

### Step 2: Create an EKS cluster
Invoke the following command to create a single worker node EKS cluster in the us-east-1 region:

```
eksctl create cluster -f aws-eks-cluster.yaml

```

Wait till the cluster is ready and you see similar output:
```

2021-05-11 09:24:40 [ℹ]  waiting for at least 1 node(s) to become ready in "ng-1"
2021-05-11 09:25:19 [ℹ]  nodegroup "ng-1" has 1 node(s)
2021-05-11 09:25:19 [ℹ]  node "ip-192-168-13-162.ec2.internal" is ready
2021-05-11 09:25:21 [ℹ]  kubectl command should work with "/Users/test/.kube/config", try 'kubectl get nodes'
2021-05-11 09:25:21 [✔]  EKS cluster "django-rest" in "us-east-1" region is ready


```


### Step 3: Create Ingress controller
Deploy the [NGINX Ingress Controller for Kubernetes](https://docs.nginx.com/nginx-ingress-controller/installation/installation-with-manifests/)
1.    Download the NGINX Ingress Controller for Kubernetes:

```
$ git clone https://github.com/nginxinc/kubernetes-ingress/
$ cd kubernetes-ingress/deployments
$ git checkout v1.11.1
```


2. Apply manifests

````
$ kubectl apply -f common/ns-and-sa.yaml
$ kubectl apply -f common/default-server-secret.yaml
$ kubectl apply -f common/nginx-config.yaml
$ kubectl apply -f rbac/rbac.yaml
$ kubectl apply -f common/ingress-class.yaml
$ kubectl apply -f deployment/nginx-ingress.yaml
$ kubectl apply -f common/crds/k8s.nginx.org_virtualservers.yaml
$ kubectl apply -f common/crds/k8s.nginx.org_virtualserverroutes.yaml
$ kubectl apply -f common/crds/k8s.nginx.org_transportservers.yaml
$ kubectl apply -f common/crds/k8s.nginx.org_policies.yaml

````

3. Wait till the Ingress Controller is Running. Check the status by executing this command:

```
$ kubectl get pods --namespace=nginx-ingress
```

4. Create a LoadBalancer Service for the Ingress Controller Pods

```
$ kubectl apply -f service/loadbalancer-aws-elb.yaml
```

5. Update the `common/nginx-config.yaml` file and add the following:

````
proxy-protocol: "True"
real-ip-header: "proxy_protocol"
set-real-ip-from: "0.0.0.0/0"
````
invoke the following command:
 
 ```
$ kubectl apply -f common/nginx-config.yaml
```

6. Get the public IP of the load balancer to access the Ingress controller. To get the public IP:

```
$ kubectl get svc nginx-ingress --namespace=nginx-ingress

```


### Step 4: Deploy Django Rest API Application:
1. Update `deployment.yaml` and add the ALB public dns you got in the above step:

```
        env:
        - name: LOAD_BALANCER_IP
          value: '<your LB Public DNS>'
```

example:

```
        env:
        - name: LOAD_BALANCER_IP
          value: 'a7696fa160a424a4f8650e473ca0a1a5-302710909.us-east-1.elb.amazonaws.com'
```

2. Update `django-rest-ingress.yaml` and add the ALB public dns you got in the above step:
   
   ```
    - host: a7696fa160a424a4f8650e473ca0a1a5-302710909.us-east-1.elb.amazonaws.com
   
   ```
   
   example:
   
   ```
    - host: a7696fa160a424a4f8650e473ca0a1a5-302710909.us-east-1.elb.amazonaws.com
   
   ```

3. Apply the k8s resources:

````
$ kubectl apply -f django-rest-deployment.yaml
$ kubectl apply -f django-svc.yaml
$ kubectl apply -f django-rest-ingress.yaml

````

### Step 5: Consume the route

Example:
```
Request:
$ curl --location --request GET 'a7696fa160a424a4f8650e473ca0a1a5-302710909.us-east-1.elb.amazonaws.com/bucketlists' \
> --header 'Host: a7696fa160a424a4f8650e473ca0a1a5-302710909.us-east-1.elb.amazonaws.com' \
> --header 'Authorization: Basic YWRtaW46cGFzc3dvcmQ='

[{"id":1,"name":"The Fountainhead","owner":"admin","date_created":"2021-02-19T19:52:45.623157Z","date_modified":"2021-02-19T19:52:45.623188Z"},{"id":2,"name":"I have a dream","owner":"admin","date_created":"2021-02-19T19:52:59.078666Z","date_modified":"2021-02-19T19:52:59.078698Z"}]

```


### Step 6 (Optional): Tear down
Run the following command to delete the cluster. Please note that you would loose all the data:
````
eksctl delete cluster -f aws-eks-cluster.yaml
````