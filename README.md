# oracle_apex_1click_stack
## Introduction
Script to start a docker based Oracle APEX stack. You will have a full functional developer enviroment, with HTTP wallet configured on Oracle APEX.

This will spin 2 containers
 - Oracle Database container, named <base-name>-db
 - ORDS Developer container, named <base-name>-ords

Do not use this configuration on production.

## Prerequisites
You need docker and docker compose installed.
If you want to use an enterprise database version, you need to login and accept Oracle terms on Oracle Container Registry website (https://container-registry.oracle.com/ords/f?p=113:10::::::) and do a docker login on the machine.

This method is tested on Linux based system (Arch x86)


## Usage

### Single step
For convenience, there is a one line option to install the default.
 - Container names:
   - apex-db
   - apex-ords
 - PIN 1234
 - Database version: free:23.6.0.0
 - PORT 8181
 
```bash
curl -fsSL https://raw.githubusercontent.com/felipe-piovezan/oracle_apex_1click_stack/refs/heads/main/quickstart_default.sh | bash
```


### Manual configuration
Download quickstart.sh script.
Make script executable:

```bash
chmod +x ./quickstart.sh
```

Execute the script passing:
 - base name for the folder with data and containers name;
 - Pin used to encrypt the password on ./<base_name>/secrets/secret.txt;
 - Database container version like free:23.6.0.0 , enterprise:19.3.0.0, enterprise:19.19.0.0;
 - ORDS Port to be mapped on host machine (Default: 8181);


Running the command:

```bash
./quickstart.sh apex 1234 free:23.6.0.0
```

Expected output on terminal:
```bash
############################## Important Information ##############################
Database version: free:23.6.0.0
Your database container name is: apex-db
Your ords container name is: apex-ords
Your password for the database and APEX internal workspace is: LmsQaV_T_QLlAwluPB8HJ8Z24g__

We are now ready to run the your containers.
Type "Y|y" to continue or CTRL-C to exit: y
##### Creating container apex-db #####
You can check the logs by running the command below in a new terminal window: docker logs -f apex-db
#####


##### Creating container apex-ords #####
[+] Running 2/2
 ✔ Container apex-ords  Started                                                                                            139.6s 
 ✔ Container apex-db    Healthy                                                                                            139.4s 

#####
You can check the logs by running the command below in a new terminal window: docker exec -it apex-ords tail -f /tmp/install_container.log
#####

-
##### Creating APEX User

SQL*Plus: Release 23.0.0.0.0 - Production on Tue Feb 11 18:37:03 2025
Version 23.6.0.24.10

Copyright (c) 1982, 2024, Oracle.  All rights reserved.


Connected to:
Oracle Database 23ai Free Release 23.0.0.0.0 - Develop, Learn, and Run for Free
Version 23.6.0.24.10

SQL> SQL> 
Session altered.

SQL>   2    3    4    5    6    7    8    9   10   11   12   13   14   15   16   17   18  
PL/SQL procedure successfully completed.

SQL> Disconnected from Oracle Database 23ai Free Release 23.0.0.0.0 - Develop, Learn, and Run for Free
Version 23.6.0.24.10
##### Setting APEX Wallet

SQL*Plus: Release 23.0.0.0.0 - Production on Tue Feb 11 18:37:03 2025
Version 23.6.0.24.10

Copyright (c) 1982, 2024, Oracle.  All rights reserved.


Connected to:
Oracle Database 23ai Free Release 23.0.0.0.0 - Develop, Learn, and Run for Free
Version 23.6.0.24.10

SQL> 
Session altered.

SQL> SQL> SQL> Setup Network ACL
SQL>   2    3    4    5    6    7    8    9   10   11   12   13   14   15   16   17   18   19   20   21   22   23   24   25   26   27   28   29   30  
PL/SQL procedure successfully completed.

SQL> Disconnected from Oracle Database 23ai Free Release 23.0.0.0.0 - Develop, Learn, and Run for Free
Version 23.6.0.24.10
##### Cleaning Pos Install Scripts


##################################################
You now can accesss APEX admin workspace:
http://localhost:8181/ords
- Workspace: internal
- User:      ADMIN
- Password:  LmsQaV_T_QLlAwluPB8HJ8Z24g__

Oracle Connection:
- host:         localhost
- port:         1521
- service name: FREEPDB1
##################################################
```