# Tutorial: Node, Docker, Kubernetes and Helm
This tutorial provides a guided introduction to using docker and kubernetes, using a simple node application as an example.

It covers the following capabilities:

* Creating a simple node.js app
* Creating a docker image for the node.js app
* Using Minikube to run a pod running the node.js app image, in Kubernetes
* Creating and running 2 pods, each with 2 node.js containers which communicate inside the pod
* Demonstrating the built in pod healthcheck and auto recovery

## Environment

Note:
* These instructions were written and tested on OS X.
* All installation requirements should be mentioned where needed.

## Create node app

* Install node.js
* Create a simple node application, for example that returns 'Hello' on port 8080 using express: See: [hello.js](hello.js)
* Ensure you create a package.json with dependencies and a 'start' script. See: [package.json](package.json)

## Create Docker image
*NOTE*: While this image will not be used in the Kubernetes part of this tutorial, it is useful to create and use a docker container as a learning exercise.
* Install [Docker for Mac](https://docs.docker.com/docker-for-mac/install/)
* Create a Dockerfile. See: [Dockerfile](Dockerfile)
  * This file includes instructions that:
    * specify the base image to use, in this case the 'boron' version of the official node
    * Specify which port the container uses
    * make a new directory to use for the app (optional) and set this as the working directory - where the CMD will be executed.
    * copy all local files to the working directory (excluding those in the .dockerignore file)
    * run `npm install` to install the app's dependencies from package.json
    * specify the command (CMD) that kicks off the application on this container
* create .dockerignore, specifying any local files not required in the container. See: [.dockerignore](.dockerignore)
* Build the docker image: `docker build -t <name> .`
  Select a name of your choice. You can use this same command to rebuild the image if you make changes to the Dockerfile or node app.
  * Note: the . is part of the command
* Verify image exists: `docker images`
  * Note: when creating the image we didn't specify a version, so it is shown as 'latest'
* Run the docker image: `docker run -p 8081:8080 -d <name of image>`
  * Note for demonstration purposes we tell docker to make the app available externally on port 8081, linked to port 8080 on the docker container.
* Confirm docker image running: `docker ps`
  * If not, confirm it exited: `docker ps -a`, and check your dockerfile and node app.
* Check app output: `docker logs <container id from ps>`
* Invoke node app, on redirected port (8081): `curl localhost:8081/hello`
  * Note: 8080 will not work outside the docker container.
* Log into docker container: `docker exec -it <container id> /bin/bash`
  * Invoke the node app again
    * Note: `curl localhost:8080/hello` works, and `localhost:8081/hello` doesnt.
* Exit the docker container: `exit`
* stop the docker container: `docker stop <container id>`
* confirm it stopped: `docker ps`

## Run the node app using kubernetes with MiniKube
Note: this creates a single pod containing a single container. The container is the running node docker image.
* Install homebrew: https://brew.sh/
* Install MiniKube: Follow steps in section 'Create a Minikube cluster' here: https://kubernetes.io/docs/tutorials/stateless-application/hello-minikube/
NOTE: if you have VirtualBox installed already, you may be able to skip the xhyve steps and just use 'minikube start'
* You should have run `minikube start`. Confirm minikube is running with: `kubectl cluster-info`
* Tell you system to use the docker in minikube: `eval $(minikube docker-env)`
  * Note, this can be undone later with: `eval $(minikube docker-env -u)`
  * Confirm that `docker images` now does not show your node image you created in the previous section.
* Recreate your docker image of your node app, using the docker in minikube:
`docker build -t <name>:<version> .` Again, choose your own name for the image, and the . is part of the command.
  * Note: we have chosen to specify a version for the image this time, for example, v1.
* Verify the new image exists: `docker images`
* Run a deployment: `kubectl run <deployment name> --image=<name>:<version> --port=8080`
  * Choose your own `<deployment name>`. This creates a pod, containing 1 container - the running node docker image. Use the `<name>:<version>` you specified in the docker build command in the previous step.
  * Note: the port is the port exposed by the image
* view deployments: `kubectl get deployments`
* view pods: `kubectl get pods`
* view cluster events: `kubectl get events`
<!--  * view config: `kubectl config view` -->
* Note that the app is of course not accessible outside the docker container. `curl locahost:8080/hello` fails as expected
* Note, in fact local host will never work as the pod/containers are running inside the Kubernetes cluster virtual network

* Create a service to expose port outside of cluster: `kubectl expose deployment <deployment name> --type=LoadBalancer`

* View service details: `kubectl get service <deployment name>`

* Test the deployed app:
To do this, you will need the external ip address of the minikube cluster, and the service port. (On cloud providers that support load balancers, an external IP address would be provisioned to access the Service. On Minikube, the LoadBalancer type makes the Service accessible through the minikube service command, or you can use the Minikube cluster ip).
  * find minikube cluster ip from: `minikube ip`
  * find external port from : `kubectl get services`. Note under PORT(S) you can see the apps port and the port it has been made available under, e.g/ 8080/30956.
  * Test the app: `curl ip:port/hello`
  *  Alternatively, to test the app, you can just use `minikube service <service name>`, which opens a browser with the url in, and then add `/hello` to the url.

* Remove deployment and service (i.e. the exposed port):

  * `kubectl get services`
  * `kubectl delete service <service name>`
  * `kubectl get services`

  * `kubectl get deployments`
  * `kubectl delete deployment <deployment name>`
  * `kubectl get deployments`

## Run two containers in the one pods
* Create and run the same deployment as above from a file instead of specifying details on the command line
  * create a yaml file describing the deployment: see [hello-deployment.yaml](hello-deployment.yaml), changing the image name and versionto match your docker image.
    * Note: in the example file, we have chosen to specify 2 replicas.
  * create deployment from yaml: `kubectl create -f hello-deployment.yaml`
  * expose app with external port: `kubectl expose deployment <deployment name> --type=LoadBalancer`
    * Note: the deployment name is specified in the yaml file
  * confirm app running: `minikube service hello-node` and add `/hello` to URL

* Create and deploy a second node app in same pod. The new node app calls the first node app - the hello app.
Note: communication between containers can be done on localhost, as containers in a pod share networking, or using a volume - shared disk space. Here we use localhost networking.
  * create a new directory to contain the new app and associated docker files: see [app2](app2)`
  * create node app which calls the hello app on localhost:8080/hello, and exposes an API on port 8081: see [app2/app2-invoke.js](app2/app2-invoke.js)
  * create Dockerfile for this app: see [app2/Dockerfile](app2/Dockerfile)
  * create docker image: `docker build -t <image name:version> .`
   * create new kubernetes deployment yaml file containing both containers: [multi-container-deployment.yaml](multi-container-deployment.yaml). Note: update image names to match your hello and invoke app image names
* deploy: `kubectl create -f multi-container-deployment.yaml`
* confirm: `kubectl get deployments`
* expose: `kubectl expose deployment <deployment name> --type=LoadBalancer --name=<service name>`
* view exposed external ports: `kubectl get services`
  * Note: there are 2 port mappings, different internal ports to different external ports
* Run: `docker ps`
* test with curl:
  * `curl <minikube cluster ip:service port/hello>`
  * `curl <minikube cluster ip:service port/app2-invoke>`
  * *Note*: We created 2 replicas for the pod. Call an API multiple times, and you see that the ip address of the server varies between the 2 pods ip addresses.
  * Alternatively test with `minikube service <service name>` and add `/hello` and `/app2-invoke`.
  * *Note*: If you used the example node apps which print ip and port, note that the two containers share the same internal ip address, as they run in the same pod.
* View Dashboard: `minikube dashboard`
  * Note: this command opens the Kubernetes dashboard for the Minikube cluster.

## Healthcheck demonstration

By default kubernetes monitors pods, and restarts them if needed. Using 2 terminal windows follow these steps to confirm this:
* In terminal window 1, call the externally exposed load balancera number of times to confirm the hello app is running and being balanced across both ips: `curl <minikube cluster ip>:<hello app exposed port>/hello`. You should see the reponse coming from 2 different ips.
* In terminal window 2, Open the Kubernetes Dashboard: `minikube dashboard`
* Click on `Pods` and confirm the number of restarts for each pod (probably 0).
* Find the running docker containers: `docker ps`
* Log into one of the hello containers: `docker exec -it <container id> /bin/bash`
* Confirm the node app is running correctly: `curl localhost:8080/hello`
* find the proc id for the node app: `ps -ef | grep node`
* While repeatedly invoking the load balanced hello api in window 1, in window 2 kill the node process: `kill -9 <node pid>`. You will be kicked out of the container.
* Continue to call the loadbalanced API in window 1. You may see a failed attempt to call the exposed hello API, but quickly you will see all calls come from the pod that you didn't break. After a few seconds calls will again be balanced across the 2 IPs.
* Note: you can see exactly the same if you cal the load balanced app2-invoke API. The entire pod is recovered, so you won't find you are calling the app2-invoke API which is trying to talk to the broken hello API.
* Refresh the Dashboard page and the restart count for the killed pod will be incremented by 1.
The system has auto recovered with no additional work from you!

## Adding helm

In this section we create a Helm chart to manage the deployment created above.

#### Installing Helm
* Followed documentation here: https://github.com/kubernetes/helm
* However, the tiller pod and replica set didn't start up. Pod and ReplicaSet logs in Dahsboard showed a cert issue. Ran command from here: https://github.com/kubernetes/helm/issues/2064
  `minikube addons enable registry-creds`
The restarted minikube: `minikube stop; minikube start`

#### Creating a chart

* Using documentation at: https://github.com/kubernetes/helm/blob/master/docs/charts.md which shows a basic structure of:
```
wordpress/
  Chart.yaml          # A YAML file containing information about the chart
  LICENSE             # OPTIONAL: A plain text file containing the license for the chart
  README.md           # OPTIONAL: A human-readable README file
  values.yaml         # The default configuration values for this chart
  charts/             # OPTIONAL: A directory containing any charts upon which this chart depends.
  templates/          # OPTIONAL: A directory of templates that, when combined with values,
                      # will generate valid Kubernetes manifest files.
  templates/NOTES.txt # OPTIONAL: A plain text file containing short usage notes
```

* At a minimum, we therefore need:
 * Chart.yaml, see: [helm-chart-multi-container/Chart.yaml](helm-chart-multi-container/Chart.yaml)
 * values.yaml [helm-chart-multi-container/values.yaml](helm-chart-multi-container/values.yaml)
 * templates/thedeploymentyaml.yaml, see: [helm-chart-multi-container/templates/heml-template-multi-container-deployment.yaml](helm-chart-multi-container/templates/helm-template-multi-container-deployment.yaml)
 *  templates/theserviceyaml.yaml, see which we created for the first time to use helm instead of cmdline for creation of service: [helm-chart-multi-container/templates/heml-template-multi-container-service.yaml](helm-chart-multi-container/templates/helm-template-multi-container-service.yaml)
These exist already in this repo, or you can create your own.

The basic principle is to take working Kubernetes yaml files (for example defining a deployment or service, that would be used with kubectl create -f <file.yaml> ), and specify where in these files you want to insert variables, and then use values.yaml to specify what those values are.

A useful example here is specifying the port once for the deployment and the service, by making it a variable in values.yaml.

#### Install using Helm
* Run helm to launch the deployment and service: `helm install helm-chart-multi-container --name helm-chart-multi-container-release`
  * NOTE: use `--replace` flag to reuse the name. Name is preserved so that `helm status helm-chart-multi-container-release` returns information even after delete.

#### Update using helm
* update hello.js and build a new docker container hello:v2
* Run helm to update the deployment and service using a second helm chart, which points at the second helm chart: `helm upgrade helm-chart-multi-container-release helm-chart-multi-container-2`

#### Rollback using helm
* View history: `helm history helm-chart-multi-container-release`
* Roll back to a specific revision: `helm rollback helm-chart-multi-container-release 20`


### Debugging issues
Some debugging options:
* Docker image
  * create an instance of the docker image using `docker run` and use `docker exec` to log into the image and check the file system looks as expected, `ps -ef` shows the expected commands, and `curl localhost:<port>/<path>` works.

## Push deployment to Kubernetes in bluemix

#### Create Kubernetes cluster in Bluemix and install plugins

* Create Kubernetes cluster in Bluemix UI (or using cli)

* Configure CLI
To gain access to your cluster, download and install a few CLI tools and the IBM Bluemix Container Service plug-in.
* Bluemix  - https://clis.ng.bluemix.net/
* Kubernetes CLI - https://kubernetes.io/docs/user-guide/prereqs/

* Install Bluemix Container Service
This allows creation and management of kubernetes clusters in Bluemix
```
bx plugin install container-service -r Bluemix
bx plugin list
```

* Gain local access to your cluster
Log in to your Bluemix account.
```
bx login -a https://api.ng.bluemix.net
```

* Initialize the IBM Bluemix Container Service plug-in.
```
bx cs init
```

* Set your terminal context to point at your cluster.
```
bx cs cluster-config drbcluster
```

* In the output, the path to your configuration file is displayed as a command to set an environment variable, for example:
```
export KUBECONFIG=/Users/ibm/.bluemix/plugins/container-service/clusters/drbcluster/kube-config-prod-hou02-drbcluster.yml
```

* Verify the CLI can talk to the cluster
```
kubectl version  --short
```
The output should show local client and server version

* verify your cluster exists and is up
```
bx cs clusters
```

* Verify your worker nodes by running some Kubernetes commands.
```
kubectl get nodes
```

* Access your Kubernetes dashboard.
```
kubectl proxy
```
Use http://127.0.0.1:8001/ui to view your Kubernetes dashboard.

#### Push images to private Bluemix Docker registry
* If you have a bluemix account, it seems you can push images already. You just need a namespace, which you may get by default. (can create alternative using `bx cr namespace-add <my_namespace>` if needed.)

* Install Container Registry plugin
This provides a CLI to manage and push images to the Bluemix Container Registry
```
bx plugin install container-registry -r Bluemix
```

* Log in to Bluemix API
```
bluemix login
```
You many need to also log into the Container Registry: `bx cr login`

* Find your namespace(s)
```
bx cr namespaces
```

* Tag the image with your private namespace in the IBM Containers Registry
```
docker tag image_id registry.eu-gb.bluemix.net/<namespace>/image_name:image_tag
```

* Push this image to the IBM Containers Registry
```
docker push registry.eu-gb.bluemix.net/<namespace>/image_name:image_tag
```

#### Create new deployment yaml with new images names/locations
* see [kube-multi-container-deployment.yaml](kube-multi-container-deployment.yaml)

#### Deploy Deployment to kubernetes in Bluemix
```
kubectl create -f kube-multi-container-deployment.yaml
```

#### Configure Service to expose container ports
```
kubectl expose deployment multi-containers-deployment --type=LoadBalancer --name=multi-containers-service
```
Note, could instead have created a yaml file and use `kubectl create -f thefile.yaml`

#### test service is up
* view dashboard
```
kubectl proxy &
```
Open displayed url: i.e. locahost:8001/ui

* Alternatively view on the cli
```
kubectl get deployments
kubectl get pods
```

#### Test deployments
NOTE: free accounts do not include ingress, so you cannot expose an external port. Instead we can use port forwarding:

* set port forwarding for a pod
Find the pod name.
```
kubectl port-forward multi-containers-deployment-1832379792-fdxfv 8881:8081
```
This exposes the port 8081 which the container exposes, and makes it available externally on port 8881

* Test the api
```
curl 127.0.0.1:8881/app2-invoke
```

## Useful resources:
This tutorial was built up using knowledge acquired by following these tutorials:
* Dockerise a node app: https://nodejs.org/en/docs/guides/nodejs-docker-webapp/
* Minikube intro: https://kubernetes.io/docs/tutorials/stateless-application/hello-minikube/
* Bluemix Kubernetes documentation: https://console.bluemix.net/docs/containers/container_index.html
