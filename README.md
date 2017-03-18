docker-oracle-apex-ords
============================

Oracle Express Edition 11g Release 2 on Ubuntu 14.04.1 LTS with APEX 5.1 and ORDS 3.0.9
# Option 1. Own docker image, with custom password

#### Get the image code from github:

    git clone --depth=1 https://github.com/donaldinos/docker-oracle-11g-apex-5.git <own-image-name>
    cd <own-image-name>

#### Building your own image, with custom password:

    docker build -t <own-image-name> --build-arg PASSWORD=<custom-password> .

#### Run the container based on your own image with 8080, 1521, 22 ports opened:

    docker run -d --name <own-container-name>  -v /my/oracle/data:/u01/app/oracle -v /my/tomcat/webapps:/tomcat/webapps -p 8080:8080 -p 1521:1521 <own-image-name>

# Option 2. Get the prebuilt image from docker hub

#### Installation:

    docker pull donaldinos/oracle-11g-apex-5

#### Run the container based on prebuilt image from docker with 8080, 1521, 22 ports opened:

    docker run -d --name <own-container-name> -v /my/oracle/data:/u01/app/oracle -v /my/tomcat/webapps:/tomcat/webapps -p 8080:8080 -p 1521:1521 donaldinos/oracle-11g-apex-5    

#### Password for SYS & SYSTEM & Tomcat ADMIN & APEX ADMIN:

    secret


# Connect to server in container (Option 1. / Option 2.)


##### Connect database with following setting:

    hostname: localhost
    port: 1521
    sid: xe
    username: system
    password: <custom-password> / secret


##### Connect to Tomcat Manager with following settings:

    http://localhost:8080/manager
    user: ADMIN
    password: <custom-password> / secret

##### Connect to Oracle Application Express web management console via ORDS with following settings:

    http://localhost:8080/ords/apex
    workspace: INTERNAL
    user: ADMIN
    password: <custom-password> / secret
