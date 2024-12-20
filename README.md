**Special Requirements**: To perform the evaluation of this artefact the user needs to have access to Google Cloud Platform Compute Engine resources.

---

# Quick-start guide (Kick-the-tires phase)

The repository presents 2 folders for the deployment:

- _opentofu_: with the terraform scripts for the virtual machines deployment;
- _ansible_: with the setup and configuration of the VMs, the deployment of Kubernetes, the VPN creation and finally the tAPP-enabled OpenWhisk deployment.

There are 2 scripts in the root of the repository to automate the deployment and the teardown:

- _setup.sh_: a script that runs all the necessary steps to deploy the VMs, deploy and configure the Kubernetes cluster, deploy and configure OpenWhisk, deploy the functions and run then (using aAPP);
- _stop.sh_: a script to tear down the resource in cloud.

By default the "setup" script will use tAPP. To run the benchmark without tAPP, use the "create_vanilla_actions.sh" script followed by the "run_locust_vanilla_functions.sh" script from the 
"scripts" folder.

The required dependencies to execute the commands are:

- [Google Cloud Platform account](https://cloud.google.com/) with a project and a service account with the necessary permissions to create Compute Engine instances and a credentials.json file;
- [Docker](https://www.docker.com/) to use the provided container equipped with an Ubuntu environment with OpenTofu and Ansible pre-installed.

## Prepare for the VMs deployment:

From the new `aapp-artefact` folder load the amd64 Docker image (there is a aapp-artefact-arm64 as well)
using the command below:

```bash
$ docker image load -i aapp-artefact.tar.gz
Loaded image: aapp-artefact:latest
```

Run the Docker container with the following command:

```bash
docker run -it aapp-artefact bash
```

The container will start and you will be in the `/app` directory with
the repository files available.

Change directory to opentofu:

```bash
cd opentofu
```

Here the `provider.tf` script will deploy 8 machines on Google Cloud Platform, 5 in the `europe-west1-b` zone (1 for Kubernetes control-plane, 1 for OpenWhisk controller, 3 for OpenWhisk workers), the other 3 in the `us-central1-a` zone (3 OpenWhisk workers).

First, create a file called `terraform.tfvars` with the same content as the file `tfvars.example`:

```bash
cp tfvars.example terraform.tfvars
```

The tfvars required are:

1.  project: the Google Cloud Platform project ID;
2.  gc_user: the GCP username owner of the project;
3.  allowed_ip: the allowed IP that will be able to connect to the cluster (you can leave 0.0.0.0/0 to expose it completely);

You can edit the file with nano or vim:

```bash
nano terraform.tfvars
```

A "credentials.json" file is also needed to be present.

It can be obtained following [this guide](https://developers.google.com/workspace/guides/create-credentials). After creating a service account with Compute Engine privileges and requesting the credentials in json format.

You can copy the contents of the json file and in the opentofu folder run:

```bash
nano credentials.json
```

Then paste the content and save the file.

Finally, initialize the provider:

```bash
tofu init
```

## Run the setup:

Now that the VMs can be created on GCP, return to the root (`/app`) directory:

```bash
cd /app
```

And run the setup script:

```bash
./setup.sh
```

The creation of the VMs will take a few minutes to complete. 

Afterward, the script will run the ansible playbook to configure the machines and install OpenWhisk.
The ansible tasks can take around 15 minutes to complete. Once finished, the script will wait for an
additional 15 minutes to ensure that the OpenWhisk installation is completed and all Invokers are ready.

When the ansible playbook is done, the script will 
install and configure the `wsk` CLI tool and create 4 sample functions using the `hello.js` file: 
- `divide` 
- `impera`
- `heavy_us`
- `heavy_eu`

These function will be tagged with their respective policy tags.

Finally, the script will run the 4 functions asynchonously so that the installed aapp script
will go into effect during scheduling.

#### Installed aAPP Script

The controller comes equipped with an aAPP script that uses affinity constraints:

```yaml
- default:
    - workers: "*"
      strategy: random

- impera:
    - workers:
        - workereu1
        - workereu2
        - workereu3
        - workerus1
        - workerus2
        - workerus3
      strategy: random
      affinity:
        - "divide"
        - "!heavy_eu"
        - "!heavy_us"

- divide:
    - workers:
        - workereu1
        - workereu2
        - workereu3
        - workerus1
        - workerus2
        - workerus3
      strategy: random
      affinity:
        - "impera"
        - "!heavy_eu"
        - "!heavy_us"
    - workers:
        - workereu1
        - workereu2
        - workereu3
        - workerus1
        - workerus2
        - workerus3
      strategy: random
      affinity:
        - "!heavy_eu"
        - "!heavy_us"

- heavy_eu:
    - workers:
        - workereu1

- heavy_us:
    - workers:
        - workerus1
```

To create a new function with a specific policy tag, the `-a` flag must be used:

```bash
wsk -i action create <function_name> <function_file> -a tag '["tag": "<policy_tag>"]'
```

And to invoke it asynchonously:

```bash
wsk -i action invoke <function_name>
```

Otherwise, to invoke it synchronously the `-r` flag must be used:

```bash
wsk -i action invoke <function_name> -r
```

# Controller Logs to Monitor Scheduling

The controller logs can be read from the control-plane node. The artefact presents a script to
create an SSH connection to the control-plane node:

```bash
./connect-master.sh
```

Once connected, Kubernetes can be queried. For example, to see the deployed components:

```bash
kubectl get pods -n openwhisk
```

To see the logs of the controller:

```bash
kubectl logs -n openwhisk owdev-controller-0 -n openwhisk | grep ConfigurableLoadBalancer
```

The entries with `[ConfigurableLoadBalancer]` are specific to the LoadBalancer using the aAPP script.

# Clean up

To delete the cluster and remove all the machines, run the `stop.sh` script from the root folder (`/app`):

```bash
./stop.sh
```
