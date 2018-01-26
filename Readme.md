# Teamcity Build Agent (common)

*Version: 2017.2.1*, *Last update date: 2018-01-23*

This image provides teamcity build agent which might be connected to teamcity server instance. Because of Teamcity architecture actual build process will be performed by build agent which means that in case of dockerized environment build scripts will be launched **inside** container. 

__NOTE__: It is highly recommended to keep Teamcity Server and agent versions in sync. While it is possible to use __older__ version of agent with newer version of Teamcity this setup is not recommended as it will cause agent update on each new agent container provisioning.

## Contents

Along with agent itself this image contains a few set of software widely used in typical build chains. Table below contains the main packages and theirs versions:

| Package                              | Version  | Description                              |
| ------------------------------------ | -------- | ---------------------------------------- |
| Teamcity Build Agent                 | 2017.2.1 | Build agent itself                       |
| [NodeJS](https://nodejs.org/)        | 8.9.4    | Node.js is a JavaScript runtime built on Chrome's V8 JavaScript engine. Includes NPM - the default package manager. |
| [Grunt](https://gruntjs.com/)        | latest   | JavaScript task runner, a tool used to automatically perform frequent tasks such as minification, compilation, unit testing, and linting. |
| [Gulp](https://gulpjs.com/)          | latest   | Streaming build system for front-end web development |
| Karma                                | latest   |                                          |
| [Yarn](https://yarnpkg.com/)         | latest   | Fast, reliable, and secure dependency management for NodeJS. |
| [Maven](https://maven.apache.org/)   | 3.5.2    | Maven is a build automation tool used primarily for Java projects. |
| Docker                               | latest   |                                          |
| docker-compose                       | latest   |                                          |
| [JQ](https://stedolan.github.io/jq/) | latest   | Very high-level functional programming language with support for backtracking and managing streams of JSON data. Something like **sed** for JSON. |
| awscli                               | latest   |                                          |
| subversion                           | latest   |                                          |
| git                                  | latest   |                                          |

\* __latest__ version means the recent stable version in repositories available on the moment of image build.

## Interfaces

### Exposed Ports

| Port | Description                              |
| ---- | ---------------------------------------- |
| 9090 | The port used for communication between TeamCity server and Agent. It is required to make sure that Teamcity could establish network connection with agent on this port. |

## Exposed Volumes

| Path                     | Description                              |
| ------------------------ | ---------------------------------------- |
| /srv/teamcity-agent/conf | The directory contains Teamcity agent configuration files. You might consider mapping this volume in case you need to tweak configuration manually. |

## Usage

Below is basic configuration for deploying teamcity server and agent on the same machine:

```yaml
teamcity:
  image: logicify/teamcity:latest
agent1:
  image: logicify/teamcityagent-common:latest
  links:
    - teamcity
  environment:
    AGENT_NAME: agent1    
```

For real setup you might need to specify `TEAMCITY_SERVER_URL` and make sure that server and agent are able to maintain network link.

Below is a full list of supported environment variables:

| Variable            | Default value | Description                              |
| ------------------- | ------------- | ---------------------------------------- |
| TEAMCITY_SERVER_URL | teamcity      | url pointing teamcity server installation |
| AGENT_PORT          | 9090          | Agent own port number to be occupied by agent |
| AGENT_NAME          | default-agent | Agent name to be used for agent identification. It will be visible in teamcity control panel. |

### Configuring for building docker images

Nowadays it is pretty common to build docker images as a part of continuous integration process. However from the technological standpoint it might be tricky as you need to use docker from the inside of docker container. It is impossible to run docker server inside docker container, however you can leverage docker's client-server architecture and point docker client from this agent container to the external docker server instance. 

In order to configure this setup you need to set `DOCKER_HOST` environment variable to point docker server accessible from the container. There are multiple options how to achieve this. We describe a few below, however you should be careful in your choices and **consider security implications** before implementation.

#### Option 1. Share docker server from  your host.

You can simply grand access to the docker server of the machine you use to run this container with build agent. This is the easiest configuration possible **BUT it is also the most dangerous one**! It means that your agent will have FULL access on the containers running on the machine including own container and also other containers on the same machine. **Please think twice before doing this and ensure you understand the risks**. In general this might be a good option if you do not run anything critical on the same machine with your agent and you are not able to setup more complicated configuration.

1. Make sure you docker daemon on host machine is configured to expose tcp interface. Please refer official docker documents for details. Below is an example of `daemon.conf` which enables socket interface along with tcp for docker network only:

   ```json
   {
     "hosts": ["tcp://172.17.0.1:2375", "unix:///var/run/docker.sock"]
   }
   ```

2. Configure agent to use DOCKER_HOST:

   ```yaml
   agent1:
     image: logicify/teamcityagent-common:latest
     links:
       - teamcity
     environment:
       AGENT_NAME: agent1
       DOCKER_HOST: 172.17.0.1
   ```

Alternatively you can mount unix socket as a volume, but in this case you should ensure the user running docker agent has write permissions on that file. 

#### Option 2. Setup another docker daemon instance on the host

An  idea is very similar to the previous one but it allows to __address some__ of the security risks - your build agent will not be able to kill or brake another containers (own neighbors).

Just configure you host machine to run 2 docker daemons and use the first one for running containers and the second one exclusively for building images.  

Note there is still a non addressed security risk - your build agent along with building, pushing and pulling images might also **run** new containers and generally do whatever is possible with docker daemon (full access).

#### Option 3. Setup separate docker daemon with http interface behind proxy

An idea is the similar to the prev. one but we add http proxy (e.g. nginx) to limit allowed api calls to `BUILD`, `PULL`, `PUSH`, `TAG`, `AUTH`. Below is simple nginx config which might do the trick:

```nginx
upstream docker-backend {
    server 127.0.0.1:2375;
}

server {
    listen 9180;
    server_name dockerbuilder;

    location ~* /(v[\\.\d]+/)?(images|build|auth)/?.* {
      proxy_pass http://127.0.0.1:2375;
    }

    location / {
      deny all;
    }
}

server {
    listen 9443 ssl;
    server_name dockerbuilder;
    include ssl.conf;
    include proxy.conf;

    location ~* /(v[\\.\d]+/)?(images|build|auth)/?.* {
      proxy_pass http://docker-backend;
    }

    location / {
      deny all;
    }
}
```

Keep in mind that `DOCKER_HOST` variable passed to the container should point nginx port, not original docker. In this example it should be `9180` or `9443` for ssl.

## Credits

This image was originally built by Dmitry Berezovsky (Logicify). The list of maintainers is below:

* Dmitry Berezovsky (d@logicify.com)
* Kirill Vyborny (kirill.vyborny@logicify.com)

## Contribution

This image is connected to the [Docker Cloud](https://cloud.docker.com) automated builds and configured to rebuild images on each push to the repository. It should **automatically** pick changes from **any** repository tag. In that case it will build from repository tag, assign the same docker image tag and change `latest` to point the recent build. In order to build image from the `mater` branch it is required to trigger build manually via [Docker Cloud Console](https://cloud.docker.com/app/logicify/repository/). 