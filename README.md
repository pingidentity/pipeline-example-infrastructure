Usage Guidelines
===

> DISCLAIMER: This is a template repository implementation of a **sample** CI/CD pipeline. This should not be considered production worthy, instead this repository should be used to demo and learn how to use Ping Identity Containerized Software in a GitOps Model. If you have just cloned it, start with [admin docs](./ADMIN-README.md)

Welcome, Developer! Principles for interacting with this repo are defined here.


**Table of Contents**
- [Usage Guidelines](#usage-guidelines)
  - [General Information](#general-information)
    - [Variables](#variables)
  - [Developer Prerequisites](#developer-prerequisites)
  - [Add a Feature](#add-a-feature)
  - [Push to Prod](#push-to-prod)


## General Information

**Development Model** - Interaction follows a development model similar to [Github Flow](https://docs.github.com/en/get-started/quickstart/github-flow) or trunk-based. 

**Deployment architecture** - A Single Region implementation based on guidelines in devops.pingidentity.com.

**Default Branch** - main

**Reading Comments** - Comments are structured like Github headers. Multi-line comments are indented. For Readability, comments are not repeated with repeated code. On YAML, comment indentation matches relevant code

```shell
# Top Level Comment
## Sub-Comment ...
##   ... rest of Sub-Comment
### Sub-Sub-Comment
```

**Gitignore**
non .subst file counterparts are tracked in .gitignore to prevent accidental commits from local testing

### Variables

Files in `helm` and `manifest` have the .subst prefix. This allows the files to hold shell variables `${FOO}`. These variables will be computed to hardcoded values before deploying. Any variable on a .subst file should be identified in `scripts/lib.sh`

## Developer Prerequisites

- Access to the Kubernetes cluster
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- git

_If running locally_:

- helm
- envsubst

## Add a Feature

**Create a branch** off the default branch. This deploys an up-to-date, isolated environment to build a new feature. 

**Follow ingress URLs** - once the environment has deployed. Features are developed through admin UIs, command line utilities, or api calls. Ingress URLs can be found with: 
kubectl get ingress -n <namespace>

**Thoroughly test** your new feature in your local environment. 

**Run generate-profile script** Once ready to bring code back for a commit and pull request. The generate-profile script uses your local git branch to identify which environment to build a profile from.

## Push to Prod

Merge to master as frequently as needed, when ready to push a change, tag the branch. Pushing tags leaves an easy to trace history and room for rollbacks. 