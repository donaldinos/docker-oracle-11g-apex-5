docker-oracle-11g-apex-5
============================

Oracle Express Edition 11g Release 2 on Ubuntu 14.04.1 LTS with APEX 5.1 and ORDS 3.0.9

#### Installation:

    docker pull donaldinos/oracle-11g-apex-5

#### Initial first run the container with custom PASSWORD:
    Initial process (create DB, install Apex, install ORDS and Tomcat) take 10-20 Minutes (Depends on hardware).

    docker run --env PASSWORD="<custom-password>" -v /my/oracle/data:/u01/app/oracle -v /my/tomcat/webapps:/tomcat/webapps -p 8080:8080 -p 1521:1521 donaldinos/oracle-11g-apex-5

    In another case defaul password for SYS & SYSTEM & Tomcat ADMIN & APEX ADMIN:

    secret

#### Run the container based on prebuilt image from docker with 8080, 1521 ports opened:

    docker run -d --name <own-container-name> -v /my/oracle/data:/u01/app/oracle -v /my/tomcat/webapps:/tomcat/webapps -p 8080:8080 -p 1521:1521 donaldinos/oracle-11g-apex-5    

#### 


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
