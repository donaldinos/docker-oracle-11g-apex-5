#!/bin/bash

# Prevent owner issues on mounted folders
chown -R oracle:dba /u01/app/oracle
rm -f /u01/app/oracle/product
ln -s /u01/app/oracle-product /u01/app/oracle/product
# Update hostname
sed -i -E "s/HOST = [^)]+/HOST = $HOSTNAME/g" /u01/app/oracle/product/11.2.0/xe/network/admin/listener.ora
sed -i -E "s/PORT = [^)]+/PORT = 1521/g" /u01/app/oracle/product/11.2.0/xe/network/admin/listener.ora
echo "export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe" > /etc/profile.d/oracle-xe.sh
echo "export PATH=\$ORACLE_HOME/bin:\$PATH" >> /etc/profile.d/oracle-xe.sh
echo "export ORACLE_SID=XE" >> /etc/profile.d/oracle-xe.sh
echo 'export JAVA_HOME=/usr/local/java' >> /etc/profile.d/java.sh
echo 'export PATH=$PATH:$HOME/bin:$JAVA_HOME/bin' >> /etc/profile.d/java.sh
. /etc/profile

impdp () {
	DUMP_FILE=$(basename "$1")
	DUMP_NAME=${DUMP_FILE%.dmp} 
	cat > /tmp/impdp.sql << EOL
-- Impdp User
CREATE USER IMPDP IDENTIFIED BY IMPDP;
ALTER USER IMPDP ACCOUNT UNLOCK;
GRANT dba TO IMPDP WITH ADMIN OPTION;
-- New Scheme User
create or replace directory IMPDP as '/docker-entrypoint-initdb.d';
create tablespace $DUMP_NAME datafile '$ORACLE_HOME/$DUMP_NAME.dbf' size 1000M autoextend on next 100M maxsize unlimited;
create user $DUMP_NAME identified by $DUMP_NAME default tablespace $DUMP_NAME;
alter user $DUMP_NAME quota unlimited on $DUMP_NAME;
alter user $DUMP_NAME default role all;
grant connect, resource to $DUMP_NAME;
exit;
EOL

	su oracle -c "NLS_LANG=.$CHARACTER_SET $ORACLE_HOME/bin/sqlplus -S / as sysdba @/tmp/impdp.sql"
	su oracle -c "NLS_LANG=.$CHARACTER_SET $ORACLE_HOME/bin/impdp IMPDP/IMPDP directory=IMPDP dumpfile=$DUMP_FILE nologfile=y"
	#Disable IMPDP user
	echo -e 'ALTER USER IMPDP ACCOUNT LOCK;\nexit;' | su oracle -c "NLS_LANG=.$CHARACTER_SET $ORACLE_HOME/bin/sqlplus -S / as sysdba"
}

case "$1" in
	'')
		#Check for mounted database files
		if [ "$(ls -A /u01/app/oracle/oradata/XE)" ]; then
			echo "found files in /u01/app/oracle/oradata/XE Using them instead of initial database"
			echo "XE:$ORACLE_HOME:N" >> /etc/oratab
			chown oracle:dba /etc/oratab
			chown 664 /etc/oratab
			printf "ORACLE_DBENABLED=false\nLISTENER_PORT=1521\nHTTP_PORT=8080\nCONFIGURE_RUN=true\n" > /etc/default/oracle-xe
			rm -rf /u01/app/oracle-product/11.2.0/xe/dbs
			ln -s /u01/app/oracle/dbs /u01/app/oracle-product/11.2.0/xe/dbs

			echo "Activate ords..."
			cd /u01/ords
			sed -i -E 's:secret:'$PASSWORD':g' /scripts/ords_params.properties
			cp -rf /scripts/ords_params.properties /u01/ords/params

			java -jar ords.war configdir /u01
			java -jar ords.war install simple
			echo "ORDS activated."
		else
			echo "Database not initialized. Initializing database."

			export IMPORT_FROM_VOLUME=true

			if [ -z "$CHARACTER_SET" ]; then
				export CHARACTER_SET="AL32UTF8"
			fi

			printf "Setting up:\nprocesses=$processes\nsessions=$sessions\ntransactions=$transactions\n"
			echo "If you want to use different parameters set processes, sessions, transactions env variables and consider this formula:"
			printf "processes=x\nsessions=x*1.1+5\ntransactions=sessions*1.1\n"

			mv /u01/app/oracle-product/11.2.0/xe/dbs /u01/app/oracle/dbs
			ln -s /u01/app/oracle/dbs /u01/app/oracle-product/11.2.0/xe/dbs

			#Setting up processes, sessions, transactions.
			sed -i -E "s/processes=[^)]+/processes=$processes/g" /u01/app/oracle/product/11.2.0/xe/config/scripts/init.ora
			sed -i -E "s/processes=[^)]+/processes=$processes/g" /u01/app/oracle/product/11.2.0/xe/config/scripts/initXETemp.ora
			
			sed -i -E "s/sessions=[^)]+/sessions=$sessions/g" /u01/app/oracle/product/11.2.0/xe/config/scripts/init.ora
			sed -i -E "s/sessions=[^)]+/sessions=$sessions/g" /u01/app/oracle/product/11.2.0/xe/config/scripts/initXETemp.ora

			sed -i -E "s/transactions=[^)]+/transactions=$transactions/g" /u01/app/oracle/product/11.2.0/xe/config/scripts/init.ora
			sed -i -E "s/transactions=[^)]+/transactions=$transactions/g" /u01/app/oracle/product/11.2.0/xe/config/scripts/initXETemp.ora

			printf 8888\\n1521\\n$PASSWORD\\n$PASSWORD\\ny\\n | /etc/init.d/oracle-xe configure

			echo "Database initialized."
			echo "==================================================================================================================="
			echo "Apex not initialized. Initializing apex."

			
			SQLPLUS=$ORACLE_HOME/bin/sqlplus
			SQLPLUS_ARGS="/ as sysdba"

			verify_connection(){
				echo "exit" | su oracle -c "${SQLPLUS} -L $SQLPLUS_ARGS" | grep Connected > /dev/null
				if [ $? -eq 0 ];
				then
					echo "Database Connetion is OK"
				else
					echo -e "Database Connection Failed. Connection failed with:\n $SQLPLUS -L $SQLPLUS_ARGS\n `$SQLPLUS -L $SQLPLUS_ARGS` < /dev/null"
					exit 1
				fi

				if [ "$(ls -A /u01/app/oracle)" ]; then
					echo "Check Database files folder: OK"
				else
					echo -e "Failed to find database files"
					exit 1
				fi
			}

			disable_http(){
				echo "Turning off DBMS_XDB HTTP port"
				echo "EXEC DBMS_XDB.SETHTTPPORT(0);\n exit" | su oracle -c "$SQLPLUS -S $SQLPLUS_ARGS"
			}

			enable_http(){
				echo "Turning on DBMS_XDB HTTP port"
				echo "EXEC DBMS_XDB.SETHTTPPORT(8080);\n exit" | su oracle -c "$SQLPLUS -S $SQLPLUS_ARGS"
			}

			get_oracle_home(){
				echo "Getting ORACLE_HOME Path"
				ORACLE_HOME=`echo -e "var ORACLEHOME varchar2(200);\n EXEC dbms_system.get_env('ORACLE_HOME', :ORACLEHOME);\n PRINT ORACLEHOME;\n exit" | su oracle -c "$SQLPLUS -S $SQLPLUS_ARGS" | grep "/.*/"`
				echo "ORACLE_HOME found: $ORACLE_HOME"
			}

			apex_epg_config(){
				cd $ORACLE_HOME/apex
				#get_oracle_home
				echo "Setting up EPG for Apex by running: @apex_epg_config $ORACLE_HOME"				
				su oracle -c "$SQLPLUS -S $SQLPLUS_ARGS @apex_epg_config $ORACLE_HOME < /dev/null"
			}

			apex_upgrade(){
				cd $ORACLE_HOME/apex
				echo "Upgrading apex..."
				su oracle -c "$SQLPLUS -S $SQLPLUS_ARGS @apexins SYSAUX SYSAUX TEMP /i/ < /dev/null"
				echo "Updating apex images"
				su oracle -c "$SQLPLUS -S $SQLPLUS_ARGS @apxldimg.sql $ORACLE_HOME < /dev/null"
			}

			conf_rest(){
				cd $ORACLE_HOME/apex
				echo "Installing rest..."
				su oracle -c "$SQLPLUS -S $SQLPLUS_ARGS @apex_rest_config.sql $PASSWORD $PASSWORD < /dev/null"
			}
			
			install_ords(){
				cd /u01/ords
				echo "Installing ords..."
				sed -i -E 's:secret:'$PASSWORD':g' /scripts/ords_unlock_account.sql
				su oracle -c "$SQLPLUS -S $SQLPLUS_ARGS @/scripts/ords_unlock_account.sql"
				
				sed -i -E 's:secret:'$PASSWORD':g' /scripts/ords_params.properties
				cp -rf /scripts/ords_params.properties /u01/ords/params

				java -jar ords.war configdir /u01
				java -jar ords.war install simple				
			}

			verify_connection
			disable_http
			apex_upgrade
			apex_epg_config
			enable_http
			conf_rest
			install_ords
		fi

		#Check for mounted database files
		if [ "$(ls -A /tomcat/webapps)" ]; then
			echo "Tomcat already initilized .. existing data in /tomcat/webapps"
			echo "Activate Tomcat.."
			sed -i -e 's/password="secret"/password="'$PASSWORD'"/g' /scripts/tomcat-users.xml
			mv /scripts/tomcat-users.xml /tomcat/conf
			echo "Tomcat activated."
		else
			echo "Tomcat not initialized. Initializing tomcat."
			
			sed -i -e 's/password="secret"/password="'$PASSWORD'"/g' /scripts/tomcat-users.xml
			mv /scripts/tomcat-users.xml /tomcat/conf
			mv /tomcat/webapps-init /tomcat/webapps
			cp -rf /u01/ords/ords.war /tomcat/webapps/
			cp -rf $ORACLE_HOME/apex/images /tomcat/webapps/i			

			echo "Tomcat initialized."
		fi

		# solution for the problem with timezone
		#dpkg-reconfigure tzdata
		echo "Europe/Prague" > /etc/timezone
		dpkg-reconfigure -f noninteractive tzdata

		/etc/init.d/oracle-xe start
		/etc/init.d/tomcat start

		if [ $IMPORT_FROM_VOLUME ]; then
			echo "Starting import from '/docker-entrypoint-initdb.d':"

			for f in /docker-entrypoint-initdb.d/*; do
				echo "found file /docker-entrypoint-initdb.d/$f"
				case "$f" in
					*.sh)     echo "[IMPORT] $0: running $f"; . "$f" ;;
					*.sql)    echo "[IMPORT] $0: running $f"; echo "exit" | su oracle -c "NLS_LANG=.$CHARACTER_SET $ORACLE_HOME/bin/sqlplus -S / as sysdba @$f"; echo ;;
					*.dmp)    echo "[IMPORT] $0: running $f"; impdp $f ;;
					*)        echo "[IMPORT] $0: ignoring $f" ;;
				esac
				echo
			done

			echo "Import finished"
			echo
		else
			echo "[IMPORT] Not a first start, SKIPPING Import from Volume '/docker-entrypoint-initdb.d'"
			echo "[IMPORT] If you want to enable import at any state - add 'IMPORT_FROM_VOLUME=true' variable"
			echo
		fi

		echo "Database ready to use. Enjoy! ;)"

		##
		## Workaround for graceful shutdown. ....ing oracle... ‿( ́ ̵ _-`)‿
		##
		while [ "$END" == '' ]; do
			sleep 1
			trap "/etc/init.d/oracle-xe stop && END=1" INT TERM
		done
		;;

	*)
		echo "Database is not configured. Please run /etc/init.d/oracle-xe configure if needed."
		exec "$@"
		;;
esac
