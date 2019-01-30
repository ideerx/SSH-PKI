# SSH-PKI
A bash script for generating and signing SSH certificates with CA.
## Usage
### Generate CA
First you must generate CA for user and host.  
./ssh-pki.sh -c ca_name  
The ca_name must has string "user" or "host" like "ssh_pki_user_ca".  

### Generate User Cert
./ssh-pki.sh -u user_name  

### Generate Host Cert
./ssh-pki.sh -h host_name  

### Sign Cert
./ssh-pki.sh -u/-h user_file/host_file -s ca_file -y years  
If file not exist, it will generate a new key.  
If ca_file not exist, it will find ca by config file.  
If years = 0, it's valid forever.  

### Install
It will make a installation package named date-time_name.install.  
You can copy it to you target device, and run it.  
You must run the host installation package by "root".  

## Usage suggested
./ssh-pki.sh -c XXX_ssh_user_ca  
./ssh-pki.sh -c XXX_ssh_host_ca  
./ssh-pki.sh -u user_name -s XXX_ssh_user_ca -y 1  
./ssh-pki.sh -h host_name -s XXX_ssh_user_ca -y 1  
