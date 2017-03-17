#!/bin/bash

cat /files/oracle-xe_11.2.0-1.0_amd64.deba* > /files/oracle-xe_11.2.0-1.0_amd64.deb
dpkg --install /files/oracle-xe_11.2.0-1.0_amd64.deb
mv /scripts/init.ora       /u01/app/oracle/product/11.2.0/xe/config/scripts
mv /scripts/initXETemp.ora /u01/app/oracle/product/11.2.0/xe/config/scripts

mv /u01/app/oracle/product /u01/app/oracle-product

rm -rf /files/oracle-xe*
