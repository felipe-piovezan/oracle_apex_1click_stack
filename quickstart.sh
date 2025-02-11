#!/usr/bin/env bash

##### Getting args #####
CONTAINER_NAME=$1
PIN=$2
VERSION=$3

APEX_ADMIN_EMAIL=apex@apex.com

##### Functions #####
function generate_password() {
    # SC => special characters allowed
    SC="_"
    while
        _password=$(openssl rand -base64 $(($RANDOM % 6 + 15)) | tr '[:punct:]' $SC)
        [[
            $(echo $_password | grep -o '['$SC']' | wc -l) -lt 2
            || $(echo $_password | grep -o '[0-9]' | wc -l) -lt 2
            || $(echo $_password | grep -o '[A-Z]' | wc -l) -lt 2
            || $(echo $_password | grep -o '[a-z]' | wc -l) -lt 2
        ]]
    do true; done

    echo $_password
}

sp="/-\|"
sc=0
spin() {
   printf "\b${sp:sc++:1}"
   ((sc==${#sp})) && sc=0
}
endspin() {
   printf "\r%s\n" "$@"
}

##### Prompt for required variables #####
if [ -z "$PIN" ]
then
    while
        echo -n "PIN (required): "
        read PIN
        [[ -z $PIN ]]
    do true; done
fi

if [ -z "$CONTAINER_NAME" ]
then
    while
        echo -n "Base name (required): "
        read CONTAINER_NAME
        [[ -z $CONTAINER_NAME ]]
    do true; done
fi

#if [ -z "$APEX_ADMIN_EMAIL" ]
#then
#    while
#        echo -n "Enter an email address for your APEX administrator (required): "
#        read APEX_ADMIN_EMAIL
#        [[ -z $APEX_ADMIN_EMAIL ]]
#    do true; done
#fi

if [ -z "$VERSION" ]
then
    while
        echo -n "Enter the database version [free:23.6.0.0 , enterprise:19.3.0.0, enterprise:19.19.0.0 (arm) ]: "
        read VERSION
        [[ -z $VERSION ]]
    do true; done
fi

##### Creating directories #####
mkdir -p $CONTAINER_NAME && cd $CONTAINER_NAME && mkdir -p data startup setup secrets ords_config custom_scripts && cd .. && chmod -R 777 $CONTAINER_NAME && cd $CONTAINER_NAME

##### Creating password #####
if [ -e "$PWD/secrets/secret.txt" ]
then
    ORACLE_PWD=$(cat "$PWD/secrets/secret.txt" | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$PIN)
    echo "PASSWORD RECOVERY: $ORACLE_PWD"
else
    ORACLE_PWD=$(generate_password)
    echo $ORACLE_PWD | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 100000 -salt -pass pass:$PIN > "$PWD/secrets/secret.txt"
fi

##### Print out Oracle password #####
echo "############################## Important Information ##############################"
echo "Database version: ${VERSION}"
echo "Your database container name is: ${CONTAINER_NAME}-db"
echo "Your ords container name is: ${CONTAINER_NAME}-ords"
echo "Your password for the database and APEX internal workspace is: $ORACLE_PWD"
echo ""


while
    echo "We are now ready to run the your containers."
    echo -n "Type \"Y|y\" to continue or CTRL-C to exit: "
    read CONTINUE
    [[ ! $CONTINUE =~ (Y|y) ]]
do true; done

##### Defining oracle version ####
if [ $VERSION = "free:23.6.0.0" ]
then
  DEFAULT_PDB="FREEPDB1";
  DEFAULT_SID="FREE";
else
  DEFAULT_PDB="ORCLPDB1";
  DEFAULT_SID="ORCLCDB";
fi

##### Create Pos-script #####
cat << EOF > "$PWD/custom_scripts/01_set_apex_pass.sh"
#!/bin/bash
export ORACLE_SID=${DEFAULT_SID}

sqlplus / as sysdba << EOF2

alter session set container = ${DEFAULT_PDB};
BEGIN
    ORDS_ADMIN.ENABLE_SCHEMA(p_schema => 'PDBADMIN');

    apex_util.set_workspace(p_workspace => 'internal');
    BEGIN
        apex_util.remove_user(p_user_name => 'ADMIN');
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    apex_util.create_user(
            p_user_name => 'ADMIN'
        , p_email_address => '${APEX_ADMIN_EMAIL}'
        , p_web_password => '${ORACLE_PWD}'
        , p_developer_privs => 'ADMIN:CREATE:DATA_LOADER:EDIT:HELP:MONITOR:SQL'
        , p_change_password_on_first_use => 'N'
        );
    COMMIT;
END;
/
EOF2
EOF


cat << EOF1 > "$PWD/setup/02_make_wallet.sh"
#!/bin/bash

export WALLET_BASE_PATH=\$ORACLE_BASE/oradata/dbconfig/${DEFAULT_PDB}/wallets
export BUNDLE_FILE=/etc/pki/tls/cert.pem
export WALLET_PATH=\$WALLET_BASE_PATH/tls_wallet
export WALLET_PWD=$ORACLE_PWD
export WALLET_PWD_CONFIRM=\$WALLET_PWD

if [ ! -d \$WALLET_BASE_PATH ]; then
  mkdir -p \$WALLET_BASE_PATH
fi

TMPDIR=/tmp/owbutil

if [ -z "\$BUNDLE_FILE" ]; then
  echo -n "Bundle file: "
  read  BUNDLE_FILE
fi

if [ ! -f "\${BUNDLE_FILE}" ];
then
  echo Please specify a valid file.
  exit -1
fi

if [ -z "\$WALLET_PATH" ]; then
  echo -n "Wallet path: "
  read WALLET_PATH
fi

if [ -d "\${WALLET_PATH}" ];
then
  echo "Wallet path exists"
  exit -1
fi

if [ -z "\$WALLET_PWD" ]; then
  echo -n "Enter an Oracle Wallet password: "
  read -s WALLET_PWD
fi

if [ -z "\$WALLET_PWD_CONFIRM" ]; then
  echo -e
  echo -n "Enter the password again: "
  read -s WALLET_PWD_CONFIRM
fi

if [ -z "\${WALLET_PWD}" ];
then
  echo Password required.
  exit -1
fi

if [ \$WALLET_PWD != \$WALLET_PWD_CONFIRM ];
then
  echo Passwords do not match.
  exit -1
fi

if [ ! -d \${TMPDIR} ];
then
  mkdir -p \${TMPDIR}
fi;

csplit -f \${TMPDIR}/cert- -b %02d.pem \${BUNDLE_FILE} \\
  '/-----END CERTIFICATE-----/1' '{*}'

orapki wallet create -wallet \${WALLET_PATH} -pwd \${WALLET_PWD}

for file in \`ls \${TMPDIR}/*.pem\`
do
  if grep -Pzoq -e "-----BEGIN CERTIFICATE-----(.|\\\\s)*-----END CERTIFICATE-----" \$file
  then
    orapki wallet add -wallet \${WALLET_PATH} -trusted_cert \\
      -pwd \${WALLET_PWD} -cert \$file
  else
    echo Skipping file \$file
  fi
done

rm -rf \${TMPDIR}

echo "Setup APEX Wallet"
EOF1

cat << EOF1 > "$PWD/custom_scripts/03_set_apex_wallet.sh"
#!/bin/bash

export ORACLE_SID=${DEFAULT_SID}
export WALLET_BASE_PATH=\$ORACLE_BASE/oradata/dbconfig/\$ORACLE_SID/wallets
export WALLET_PATH=\$WALLET_BASE_PATH/tls_wallet
export WALLET_PWD=$ORACLE_PWD

sqlplus / as sysdba << EOF
  alter session set container = ${DEFAULT_PDB};

  -- Network ACL
  prompt Setup Network ACL
  begin
    for c1 in (
      select schema
      from sys.dba_registry
      where comp_id = 'APEX'
    ) loop
      sys.dbms_network_acl_admin.append_host_ace(
        host => '*'
        , ace => xs\\\$ace_type(
            privilege_list => xs\\\$name_list('connect', 'resolve')
            , principal_name => c1.schema
            , principal_type => xs_acl.ptype_db
        )
      );
    end loop;
    

    apex_instance_admin.set_parameter(
      p_parameter => 'WALLET_PATH'
      , p_value => 'file:\${WALLET_PATH}'
    );

    apex_instance_admin.set_parameter(
      p_parameter => 'WALLET_PWD'
      , p_value => '\${WALLET_PWD}'
    );

    commit;
  end;
  /
EOF
EOF1

##### Create compose file #####
cat << EOF1 > "$PWD/compose.yaml"
---
services:
  oracle-db:
    container_name: ${CONTAINER_NAME}-db
    image: container-registry.oracle.com/database/${VERSION}
    volumes:
      - ./data:/opt/oracle/oradata
      - ./startup:/opt/oracle/scripts/startup
      - ./setup:/opt/oracle/scripts/setup
      - ./custom_scripts/:/opt/oracle/scripts/custom
    ports:
      - 1521:1521
    environment:
      - ORACLE_PWD=${ORACLE_PWD}
      - ORACLE_CHARACTERSET=AL32UTF8
    healthcheck:
      interval: 10s
      timeout: 10s
      retries: 60
    restart: unless-stopped

  oracle-ords:
    container_name: ${CONTAINER_NAME}-ords
    image: container-registry.oracle.com/database/ords-developer:latest
    volumes:
      - ./secrets/:/opt/oracle/variables
      - ./ords_config/:/etc/ords/config/
      - ./custom_scripts/:/ords-entrypoint.d/
    ports:
      - 8181:8181
    depends_on:
      oracle-db:
        condition: service_healthy
    restart: unless-stopped
EOF1

chmod +x $PWD/custom_scripts/01_set_apex_pass.sh
chmod +x $PWD/custom_scripts/03_set_apex_wallet.sh

echo "##### Creating container ${CONTAINER_NAME}-db #####"
echo "You can check the logs by running the command below in a new terminal window: docker logs -f ${CONTAINER_NAME}-db"
echo "#####"
echo ""

##### Deploy ORDS and install APEX #####
echo ""
echo "##### Creating container ${CONTAINER_NAME}-ords #####"

CONN_STRING="CONN_STRING=sys/${ORACLE_PWD}@${CONTAINER_NAME}-db:1521/${DEFAULT_PDB}"
echo ${CONN_STRING} > secrets/conn_string.txt

docker compose up -d --force-recreate --remove-orphans

echo ""
echo "#####"
echo "You can check the logs by running the command below in a new terminal window: docker exec -it ${CONTAINER_NAME}-ords tail -f /tmp/install_container.log"
echo "#####"
echo ""

until false
do
    spin
    if curl -s --head --request GET http://localhost:8181/ords | grep -E "302 Found|301 Moved Permanently" > /dev/null; then
        break
    fi
    sleep 1;
done;
endspin

##### Executing pos-scripts #####
echo "##### Creating APEX User"
docker exec -t ${CONTAINER_NAME}-db bash /opt/oracle/scripts/custom/01_set_apex_pass.sh
#echo "##### Making Wallet"
#docker exec -t ${CONTAINER_NAME}-db bash /opt/oracle/scripts/custom/02_make_wallet.sh
echo "##### Setting APEX Wallet"
docker exec -t ${CONTAINER_NAME}-db bash /opt/oracle/scripts/custom/03_set_apex_wallet.sh

##### Cleaning pos-scripts #####
echo "##### Cleaning Pos Install Scripts"
##rm -f $PWD/custom_scripts/01_set_apex_pass.sh

echo ""
echo ""
echo "##################################################"
echo "You now can accesss APEX admin workspace:"
echo "http://localhost:8181/ords"
echo "- Workspace: internal"
echo "- User:      ADMIN"
echo "- Password:  ${ORACLE_PWD}"
echo ""
echo "SQL Developer WEB:"
echo "http://localhost:8181/ords/sql-developer"
echo "- User:      PDBADMIN"
echo "- Password:  ${ORACLE_PWD}"
echo ""
echo "Oracle Connection:"
echo "- host:         localhost"
echo "- port:         1521"
echo "- service name: ${DEFAULT_PDB}"
echo "##################################################"
echo ""
echo ""