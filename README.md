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
For convenience, there is a one line option to install with the defaults.
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
Make the script executable:

```bash
chmod +x ./quickstart.sh
```

Execute the script passing:
 - base name for the folder with data and containers name;
 - Pin used to encrypt the password on ./<base_name>/secrets/secret.txt;
 - Database container version like free:23.6.0.0 , enterprise:19.3.0.0, enterprise:19.19.0.0;
 - ORDS Port to be mapped on host machine (Default: 8181);


Example:

```bash
./quickstart.sh apex 1234 free:23.6.0.0
```

Expected output on terminal:
```bash
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