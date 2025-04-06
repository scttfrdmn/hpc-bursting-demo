#!/bin/bash
# LDAP server setup
set -e

# Install 389 Directory Server packages
echo "Installing 389 Directory Server packages..."
sudo dnf install -y 389-ds-base

# Set up the 389 Directory Server instance
echo "Creating 389-ds setup configuration..."
cat << DSSETUP > dssetup.inf
[general]
config_version = 2

[slapd]
root_password = ldapadminpassword
instance_name = demo
serverid = 1

[backend-userroot]
suffix = dc=demo,dc=local
sample_entries = yes
DSSETUP

# Create the 389-ds instance
echo "Creating 389-ds instance..."
sudo dscreate from-file dssetup.inf

# Wait for the server to start
sleep 5

# Create a test user
echo "Creating test user LDIF..."
cat << LDIFFILE > testuser.ldif
dn: uid=testuser,ou=People,dc=demo,dc=local
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: Test User
sn: User
uid: testuser
uidNumber: 10000
gidNumber: 10000
homeDirectory: /home/testuser
loginShell: /bin/bash
userPassword: {SSHA}aaQRtbKGXEAWRAm+HS8UtV9a4tBZcbq0TvLgVg==

dn: cn=hpcusers,ou=Groups,dc=demo,dc=local
objectClass: top
objectClass: posixGroup
cn: hpcusers
gidNumber: 10000
memberUid: testuser
LDIFFILE

# Add test user to the directory
echo "Adding test user to LDAP..."
sudo ldapadd -x -D "cn=Directory Manager" -w ldapadminpassword -f testuser.ldif

# Install SSSD and required packages
echo "Installing SSSD packages..."
sudo dnf install -y sssd sssd-ldap oddjob-mkhomedir

# Configure SSSD
echo "Configuring SSSD..."
cat << 'SSSDCONF' | sudo tee /etc/sssd/sssd.conf
[sssd]
domains = demo.local
config_file_version = 2
services = nss, pam

[domain/demo.local]
id_provider = ldap
auth_provider = ldap
ldap_uri = ldap://ldap.hpc-demo.internal
ldap_search_base = dc=demo,dc=local
ldap_user_search_base = ou=People,dc=demo,dc=local
ldap_group_search_base = ou=Groups,dc=demo,dc=local
ldap_default_bind_dn = cn=Directory Manager
ldap_default_authtok = ldapadminpassword
ldap_id_use_start_tls = False
ldap_tls_reqcert = never
enumerate = True
cache_credentials = True

# Schema mappings
ldap_user_object_class = posixAccount
ldap_user_name = uid
ldap_user_uid_number = uidNumber
ldap_user_gid_number = gidNumber
ldap_user_home_directory = homeDirectory
ldap_user_shell = loginShell

ldap_group_object_class = posixGroup
ldap_group_name = cn
ldap_group_gid_number = gidNumber
ldap_group_member = memberUid
SSSDCONF

# Set appropriate permissions
sudo chmod 600 /etc/sssd/sssd.conf

# Configure system authentication
echo "Configuring system authentication..."
sudo authselect select sssd with-mkhomedir --force

# Create home directory for testuser
echo "Creating home directory for testuser..."
sudo mkdir -p /export/home/testuser
sudo chown 10000:10000 /export/home/testuser

# Clear SSSD cache and restart the service
echo "Starting SSSD service..."
sudo rm -rf /var/lib/sss/db/*
sudo systemctl enable --now sssd

# Add entry to /etc/hosts for LDAP
echo "10.0.0.1 ldap.hpc-demo.internal" | sudo tee -a /etc/hosts

# Verify SSSD is working
echo "Verifying SSSD configuration..."
getent passwd testuser
getent group hpcusers

echo "LDAP server and SSSD setup completed."
