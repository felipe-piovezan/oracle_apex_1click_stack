#!/usr/bin/env bash
CONTAINER_NAME=$1
PIN=$2
VERSION=$3
APEX_VERSION=$4

if [ -z "$VERSION" ]
then
    while
        echo -n "Enter the database version [free:23.6.0.0 , enterprise:19.3.0.0, enterprise:19.19.0.0 (arm) ]: "
        read VERSION
        [[ -z $VERSION ]]
    do true; done
fi

if [ -z "$APEX_VERSION" ]
then
    while
        echo -n "Enter the Oracle APEX version to be installed [23.2 , 24.1, 24.2 ]: "
        read APEX_VERSION
        [[ -z $APEX_VERSION ]]
    do true; done
fi

cd ${CONTAINER_NAME}

ORACLE_PWD=$(cat "$PWD/secrets/secret.txt" | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$PIN)
echo "PASSWORD RECOVERY: $ORACLE_PWD"


##### Defining oracle version ####
if [ $VERSION = "free:23.6.0.0" ]
then
# replace "." with "" to get the version number
  PDB_NAME="FREEPDB$(echo $APEX_VERSION | tr -d '.')";
  DEFAULT_SID="FREE";
else
  PDB_NAME="ORCLPDB${APEX_VERSION}";
  DEFAULT_SID="ORCLCDB";
fi

APEX_POOL_NAME="apex$(echo $APEX_VERSION | tr -d '.')";

##### Downloading APEX #####
rm -rf "$PWD/custom_scripts/apex_${APEX_VERSION}.zip"
rm -rf "$PWD/custom_scripts/apex"
rm -rf "$PWD/custom_scripts/META-INF"
wget https://download.oracle.com/otn_software/apex/apex_${APEX_VERSION}.zip -O $PWD/custom_scripts/apex_${APEX_VERSION}.zip

##### Create Upgrade Script #####
rm -rf "$PWD/custom_scripts/98_install_new_APEX_version.sh"

cat << EOF > "$PWD/custom_scripts/98_install_new_APEX_version.sh"
#!/bin/bash
export ORACLE_SID=${DEFAULT_SID}

cd /opt/oracle/oradata/ && mkdir -p ${PDB_NAME}
cd /opt/oracle/scripts/custom
unzip apex_${APEX_VERSION}.zip
cd apex


sqlplus / as sysdba << EOF2
WHENEVER SQLERROR EXIT SQL.SQLCODE

 -- check if PDB exists and you want to destroy, uncomment the following lines
 -- alter pluggable database ${PDB_NAME} close immediate;
 -- drop pluggable database ${PDB_NAME} including datafiles;

alter system set db_create_file_dest='/opt/oracle/oradata/${PDB_NAME}';
CREATE PLUGGABLE DATABASE ${PDB_NAME} ADMIN USER pdb_adm IDENTIFIED BY "${ORACLE_PWD}";
alter pluggable database ${PDB_NAME} open;
alter pluggable database all save state;

alter session set container=${PDB_NAME};
@apexins.sql SYSAUX SYSAUX TEMP /i/

BEGIN
    APEX_UTIL.set_security_group_id( 10 );
    
    APEX_UTIL.create_user(
        p_user_name       => 'ADMIN',
        p_email_address   => 'me@example.com',
        p_web_password    => 'OrclAPEX1999!',
        p_developer_privs => 'ADMIN' );
        
    APEX_UTIL.set_security_group_id( null );
    COMMIT;
END;
/

@apex_rest_config.sql
ALTER USER APEX_PUBLIC_USER ACCOUNT UNLOCK;

begin
    for c1 in (select version_no from APEX_RELEASE)
    loop
        APEX_INSTANCE_ADMIN.set_parameter(
            p_parameter => 'IMAGE_PREFIX',
            p_value => 'https://static.oracle.com/cdn/apex/' ||
                            c1.version_no || '/');
    end loop;

    commit;
end;
/
EOF2
EOF

docker exec -t ${CONTAINER_NAME}-db bash /opt/oracle/scripts/custom/98_install_new_APEX_version.sh


rm -rf "$PWD/custom_scripts/99_install_new_APEX_version.sh"

cat << EOF > "$PWD/custom_scripts/99_install_new_APEX_version.sh"
#!/bin/bash

cat > password.txt << EOF2
${ORACLE_PWD}
${ORACLE_PWD}
EOF2

ords --config /etc/ords/config install --db-pool ${APEX_POOL_NAME} --admin-user SYS --proxy-user --db-hostname ${CONTAINER_NAME}-db --db-port 1521 --db-servicename ${PDB_NAME} --feature-sdw true --log-folder /etc/ords/config/logs --password-stdin < password.txt

EOF

docker exec -t ${CONTAINER_NAME}-ords bash /ords-entrypoint.d/99_install_new_APEX_version.sh
docker container restart ${CONTAINER_NAME}-ords