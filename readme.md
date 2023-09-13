# GitLab local Runner

To run this GitLab architecture consisting of a GitLab runner for CI/CD and a deployment server as a target for CI/CD you need to do the following:

1. Download and run `docker compose up`.
2. Register the GitLab Runner.
3. Setup the Deployment server to work with the GitLab Instance.

## The docker-compose.yml file

``` yaml
version: '3.7'

networks:
  gitlab-network:


services:
  gitlab-runner:
    image: gitlab/gitlab-runner:alpine
    container_name: gitlab-runner
    depends_on:
      - deployment-server
    volumes:
      - './gitlab-runner:/etc/gitlab-runner'
      - '/var/run/docker.sock:/var/run/docker.sock'
    networks:
      - gitlab-network

  deployment-server:
    build: .
    container_name: hatch.deployment.com
    ports:
      - '22:23'
    networks:
      - gitlab-network
```

This has 2 key sections. The first defines a network called `gitlab-network`. This is the network that docker will create and that all of our services are attached to. This network allows us to define how the different services within the network are able to communicate and how services outside of the network will communicate with services inside (if at all).

The second section is the services and we have 2 defined - `gitlab-runner` and `deployment-server`.

For the `gitlab-runner` service we have used the official `gitlab-runner` image as a basis for the service. The container is called `gitlab-runner` to enable access by name within the network and make it look like a server on the internet. We set `depends_on` so that the runner has to wait for the `deployment-server` service before it is run.  finally we add it to the `gitlab-network`.

For the `deployment-server` service we have use the Dockerfile mode as a basis of creating an image for the service. We have stated that it should always restart (as long as this is on your computer and the docker daemon running it will start when you boot up your computer). The container is called `hatch.deployment.com` to enable access by name within the network. We have also defined a port so the service can be accessed via ssh (from inside and outside of the gitlab-network). Finally we add it to the `gitlab-network`.

The `deployment-server` Docker file looks like this:

``` Dockerfile
FROM ubuntu:latest

RUN apt update && apt install  openssh-server sudo -y

RUN useradd -rm -d /home/ubuntu -s /bin/bash -g root -G sudo -u 1000 deploymentagent 

RUN  echo 'deploymentagent:testpass123' | chpasswd

RUN service ssh start

CMD ["/usr/sbin/sshd","-D"]
```

With the Ubuntu image we create a linux computing instance. Then we update the package library on this instance and install the Openssh server to enable access to the remote server over the network. we then add a new user with a password so we can access without using the root user and start the ssh service.

To run the 2 containers defined here we use the `docker compose up` command, this will pull/build any images and then run them as containers. From a terminal running the `docker ps` command should now show us the containers.

``` bash
CONTAINER ID   IMAGE                          COMMAND                  CREATED      STATUS                 PORTS                                                                                                             NAMES
a4fbc554a0b9   gitlab/gitlab-runner:alpine    "/usr/bin/dumb-init …"   2 days ago   Up 4 hours                                                                                                                               gitlab-runner
215c31a60d45   gitlabrunner-deployment-server "/usr/sbin/sshd -D"      2 days ago   Up 4 hours             0.0.0.0:22->23/tcp, :::22->23/tcp                                                                                 hatch.deployment.com
```

We are now ready to start setting up and using our GitLab service installation.

## After Docker Compose Up

## Registering the GitLab Runner

To be able to do CI/CD on our GitLab instance we will need to set up our gitlab runner. These are computing instances that act as the CI/CD environment. To register one follow the procedure on GitLab.

You will typically asked to run a command on your gitlab-runner instance suach as:

``` bash
gitlab-runner register  --url https://gitlab.com  --token WhatEv3rYu0rT0ken1s
```

2. You should see something like this (remember to enter the correct data when asked if the command is running interactively):

``` bash
Runtime platform                                    arch=amd64 os=linux pid=455 revision=436955cb version=15.11.0
Running in system-mode.                            
                                                   
Enter the GitLab instance URL (for example, https://gitlab.com/):
[https://hatch.gitlab.com]: 
Enter a name for the runner:
[dwWr8yBLZ_RaiB-Zziyd]: hatch-runner
Enter an executor for the runner: virtualbox, customer, docker-ssh, shell, ssh, etc...
docker
Enter the default docker image (for example, ruby:2.7):
alpine:latest
Verifying runner... is valid                        runner=dwWr8yBL       
Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded!
 
Configuration (with the authentication token) was saved in "/etc/gitlab-runner/config.toml" 
```

You should be able to now see the file `config.toml` in the gitlab-runner folder with the runners setup as registered. You may not be able to access this because of a lack of permissions. If you want to look just change the permissions.

## The Deployment Server

## Running a CI/CD pipeline for deployment

The reason to have a GitLab runner is so that we can run CI/CD pipelines as part of a DevOps cycle. When you intially try to run your registered gitlab runner for deployment you may find the pipeline throws up errors such as:

``` bash
$ ping hatch.deployment.com -c 2
ping: hatch.deployment.com: Name or service not known
Cleaning up project directory and file based variables
```

or

``` bash
Running with gitlab-runner 15.11.0 (436955cb)
  on docker-runner BxW-HWyW, system ID: r_9hmSrpFx4qVD
Preparing the "docker" executor
00:02
Using Docker executor with image python:latest ...
Pulling docker image python:latest ...
Using docker image sha256:815c8c75dfc08272d817d6bbcd0ac034c3bd718ba566bfe6e3f47f06f932a3ec for python:latest with digest python@sha256:b9683fa80e22970150741c974f45bf1d25856bd76443ea561df4e6fc00c2bc17 ...
Preparing environment
00:00
ERROR: Container "d6f8731313ec1652ec0cbf9b421403a6925bef537d4440c737076ff907180e97" not found or removed. Will retry...
ERROR: Job failed (system failure): prepare environment: Error response from daemon: network gitlab-network not found (exec.go:78:0s). Check https://docs.gitlab.com/runner/shells/index.html#shell-profile-loading for more information
```

Take note of the error relating to the network. It is saying that it cannot find the gitlab-network that is defined in the docker-compose.yml file for this gitlab distribution.

Take a look at the networks running in Docker with:

``` bash
ssnowden:GitLab$ docker network ls
NETWORK ID     NAME                           DRIVER    SCOPE
411d8f7893fe   bridge                         bridge    local
532cb0d69e53   gitalabrunner_gitlab-network   bridge    local
c867781a3318   host                           host      local
5965bc944a74   none                           null      local
```

Does your config.toml have a `network_mode` appended to it? If not, then add one in the runners.docker section. So from:

``` toml
[[runners]]
  name = "hatch-runner"
  url = "<https://gitlab.com>"
  id = 24823096
  token = "glrt-FRegtnskEiZwLzqhGyef"
  token_obtained_at = 2023-06-30T09:49:44Z
  token_expires_at = 0001-01-01T00:00:00Z
  executor = "docker"
  [runners.cache]
    MaxUploadedArchiveSize = 0
  [runners.docker]
    tls_verify = false
    image = "alpine:latest"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 0
```

to

``` toml
[[runners]]
  name = "hatch-runner"
  url = "<https://gitlab.com>"
  id = 24823096
  token = "glrt-FRegtnskEiZwLzqhGyef"
  token_obtained_at = 2023-06-30T09:49:44Z
  token_expires_at = 0001-01-01T00:00:00Z
  executor = "docker"
  [runners.cache]
    MaxUploadedArchiveSize = 0
  [runners.docker]
    tls_verify = false
    image = "alpine:latest"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/var/run/docker.sock:/var/run/docker.sock", "/cache"]
    network_mode = "gitalabrunner_gitlab-network"
    shm_size = 0
```

When the containers were spun up from the docker-compose.yml file the network had the project directory appended to it. Is the network mode in the gitlab-runner config.toml the same as the name in the list? If not make sure that it is. Then Docker down and Docker up again.

Once you have got used to running build and test CI/CD routines you are gong to want to deploy code to a server. This requires that your server and GitLab Instance know one another. This requires that we setup some form of certification between them. Here we will describe using ssh as the primary tool for deploying.

### Adding a ssh key for automatic access to the deployment server

1. On the gitlab-runner instance, generate a ssh key pair with `ssh-keygen -t rsa -b 4096` and fill in requested data. No need for a passphrase.
2. Copy your id with `ssh-copy-id -i ~/.ssh/your_key -p 22 deploymentagent@hatch.deployment.com`. The output will be something like that shown below. Note that it will ask for the password for the deploymentagent user.

``` bash
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 3 key(s) remain to be installed -- if you are prompted now it is to install the new keys
deploymentagent@localhost's password: 

Number of key(s) added: 3

Now try logging into the machine, with:   "ssh 'deploymentagent@localhost'"
and check to make sure that only the key(s) you wanted were added.
```

3. you should then be able to login with `ssh -i ~/.ssh/your_key deploymentagent@hatch.deployment.com`.
4. The will look something like (note the change in the command line prompt from bash-5.1# - local - to deploymentagent@xxxxxxxxx:~$ - the server.):

``` bash
bash-5.1# ssh -p '22' 'deploymentagent@localhost'
Welcome to Ubuntu 22.04.2 LTS (GNU/Linux 5.19.0-41-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

This system has been minimized by removing packages and content that are
not required on a system that users do not log into.

To restore this content, you can run the 'unminimize' command.
To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

deploymentagent@499c0d6b7f13:~$
```

5. You can then use scp to copy files to the deployment server with `scp /afile.txt deploymentagent@hatch.deployment.com:/app` to allow copying of files.
6. You can also sftp to the deployment server with `sftp -P 23 deploymentagent@hatch.deployment.com` to allow copying of files.
