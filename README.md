Reference CI/CD Template
===

> DISCLAIMER: This is a template repository implementation of a **sample** CI/CD pipeline. This repository should not be considered production-ready and is intended for use as a demonstration only. It is intended only to provide an opportunity to learn how to use Ping Identity Containerized Software in a GitOps Model.

Welcome, Developer!

The demonstration flow is as follows:

- Launch an integrated Ping Software stack into a Kubernetes cluster
- Explore what is running to understand how things are deployed and configured
- Complete a simple feature flow where you can make a change and see the resulting activity
- Next steps, including customization options available from this demo.

**Table of Contents**
- [Reference CI/CD Template](#reference-cicd-template)
  - [General Information](#general-information)
  - [Prerequisites](#prerequisites)
    - [Recommended](#recommended)
  - [Launch an Environment](#launch-an-environment)
  - [Description of the default environment deployment](#description-of-the-default-environment-deployment)
  - [Cleanup](#cleanup)
  - [Prepare Profiles](#prepare-profiles)
    - [Use Ping Identity's Baseline Server Profiles](#use-ping-identitys-baseline-server-profiles)
    - [Bring Your Own Profiles](#bring-your-own-profiles)
  - [Adjust Default Deployment](#adjust-default-deployment)
    - [Ingress](#ingress)
    - [Products](#products)
  - [](#)
  - [Push to Prod](#push-to-prod)

## General Information

**Development Model** - Interaction follows a development model similar to [Github Flow](https://docs.github.com/en/get-started/quickstart/github-flow) or trunk-based.

**Deployment architecture** - A Single Region implementation based on guidelines from [devops.pingidentity.com](devops.pingidentity.com).

**Default Branch** - prod

**Variables**

Files in the `helm` and `manifest` directories have the .subst suffix. This naming convention supports the files housing shell variables `${FOO}`. These variables will be computed to hardcoded values before deploying. Any variable in a .subst file should have a default value set in `scripts/lib.sh`

**Reading Comments** - Comments are structured as Markdown headers. Multi-line comments are indented. For readability, comments are not repeated with repeated code. In the YAML files, comment indentation matches relevant code:

```shell
# Top Level Comment
## Sub-Comment ...
##   ... rest of Sub-Comment
### Sub-Sub-Comment
```
**Gitignore**
Non .subst file counterparts are tracked in .gitignore to prevent accidental commits from local testing being published.

## Prerequisites

- Github account
- Publicly accessible Kubernetes cluster - the cluster must be _publicly accessible_ to use free [Github Actions Hosted Runners](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners#about-github-hosted-runners). If you cannot use a publicly accessible cluster, see [Self-hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners)
- [pingctl](https://devops.pingidentity.com/get-started/pingctlUtil/) configured or the PING_IDENTITY_DEVOPS_USER/KEY values exported in your shell environment
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [gh](https://cli.github.com/) the Github CLI utility
- Understanding of [Helm](https://helm.sh/docs/intro/quickstart/) and consuming Helm Charts
### Recommended
- [k9s](https://k9scli.io/)

## Launch an Environment
Set up a repository from this template:
- Click **Use This Template** at the top of this page to create a new repository based on these contents in your account.
![Use This Template button](./img/useThisTemplate.png "create repository from template")
- Using git, clone the new repository to `~/projects/devops/pingidentity-devops-reference-pipeline`
 > IMPORTANT! The folder name must match. It is hardcoded in the scripts supporting the following commands.

Start by deploying with the default settings to get a simple environment running. Later in this guide, modifications from default will be discussed.

First, initialize your environment.  The following script will prepare your local and remote repositories. 

```
./scripts/initialize.sh
```

Next, deploy an environment.  To do so, create and push a new branch from a terminal or using the GitHub web console:

```
git checkout -b mydemo
git push origin mydemo
```

As the code is deployed, you can observe the pipeline actions in GitHub Actions logs. In addition, you can use **kubectl** to observe the pods and other objects being created and initializing in your Kubernetes namespace.  The **k9s** utility referenced above is ideal for watching real-time activity in a cluster.

## Description of the default environment deployment

The _initialize.sh_ script prepares your local and remote repositories for use:
1. Prep Baseline:
   1. git clone Ping Identity Server Profiles baseline folder
   2. copy to a `profiles` folder
   3. rename folders in `profiles` to match product names on pingidentity/ping-devops helm chart. 

## Cleanup

Once you

## Prepare Profiles

Server Profiles are used to deploy configuration to products. The pipeline uses the profiles directory for storing config.

### Use Ping Identity's Baseline Server Profiles
<!-- TODO CLEAN THIS UP-->
[Ping Identity's Baseline Server Profiles](https://github.com/pingidentity/pingidentity-server-profiles/tree/master/baseline) are maintained for demo and testing purposes. Eventually you will want to [bring your own profiles](#bring-your-own-profiles)

To test this environment quickly use the [baseline server-profile](https://github.com/pingidentity/pingidentity-server-profiles/tree/master/baseline).


### Bring Your Own Profiles

<!-- TODO -->


## Adjust Default Deployment

> Note: The defaults are aligned to Ping's Employee K8s Clusters, if you are using one of them there no need to adjust yet. 


The default deployment will deploy a number of software products with simple configurations and [ingresses](https://kubernetes.io/docs/concepts/services-networking/ingress/). Ingresses rely on the kubernetes cluster having an [ingress controller](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/) deployed. 


### Ingress

The default setup on [values.yaml.subst] will work for an nginx ingress controller with class "nginx-public". Update `global.ingress` on values.yaml to match your environment.

### Products

If you want to remove any products, change `<product>.enabled` to false. Over time, as you become more comfortable with the repo you can remove those pieces. 

Example for turning off pingdataconsole:

```
pingdataconsole:
  enabled: false
  envs:
    SERVER_PROFILE_PATH: profiles/pingdataconsole
    PDC_PROFILE_SHA: "${PINGDATACONSOLE_SHA}"
```


## 
**Create a branch** off the default branch. This deploys an up-to-date, isolated environment to build a new feature. 

**Follow ingress URLs** - once the environment has deployed. Features are developed through admin UIs, command line utilities, or api calls. Ingress URLs can be found with: 

```
kubectl get ingress -n <namespace>
```

**Thoroughly test** your new feature in your local environment. 

**Run generate-profile script** Once ready to bring code back for a commit and pull request. The generate-profile script uses your local git branch to identify which environment to build a profile from.

## Push to Prod

Merge to master as frequently as needed, when ready to push a change, tag the branch. Pushing tags leaves an easy to trace history and room for rollbacks. 