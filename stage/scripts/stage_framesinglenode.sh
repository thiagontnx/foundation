#!/bin/bash

MY_CVM_IP=$(/sbin/ifconfig eth0 | grep 'inet ' | awk '{ print $2}')
array=(${MY_CVM_IP//./ })
MY_HPOC_SITE=${array[1]}
MY_HPOC_NUMBER=${array[2]}
MY_CVM_LAST_OCTET=${array[3]}
MY_SP_NAME='SP01'
MY_CONTAINER_NAME='Default'
MY_IMG_CONTAINER_NAME='Images'
PHX_DNS_IP='10.42.196.10'
MY_PRIMARY_NET_NAME='Infrastructure'
MY_PRIMARY_NET_VLAN='0'
MY_SECONDARY_NET_NAME='Desktop'
MY_SECONDARY_NET_VLAN="${MY_HPOC_NUMBER}1"
WIN10_IMG_SRC='http://10.42.194.11/workshop_staging/Windows10-1709.qcow2'
WIN2012R2_IMG_SRC='http://10.42.194.11/workshop_staging/Windows2012R2.qcow2'
FRAMEGA_ISO_SRC='http://10.42.194.11/workshop_staging/FrameGuestAgentInstaller_1.0.2.2_7930.iso'
FRAMECCA_ISO_SRC='http://10.42.194.11/workshop_staging/FrameCCA-2.1.0.iso'
MY_PC_SRC_URL='http://10.42.194.11/workshop_staging/euphrates-5.11-stable-prism_central.tar'
MY_PC_META_URL='http://10.42.194.11/workshop_staging/euphrates-5.11-stable-prism_central-metadata.json'
VIRTIO_ISO_SRC='http://download.nutanix.com/mobility/1.1.4/Nutanix-VirtIO-1.1.4.iso'
PC_VERSION='5.11'

source /etc/profile.d/nutanix_env.sh
# Logging function
function my_log {
    #echo `$MY_LOG_DATE`" $1"
    echo $(date "+%Y-%m-%d %H:%M:%S") $1
}

#Set networking variables based on Node position
if [[ ${MY_CVM_LAST_OCTET} == '29' ]]; then
  my_log 'Setting variables for Node A, CVM IP: '${MY_CVM_IP}
  CLUSTER_NAME="POC${MY_HPOC_NUMBER}-NodeA"
  MY_CLUSTER_IP="10.${MY_HPOC_SITE}.${MY_HPOC_NUMBER}.17"
  MY_ISCSI_IP="10.${MY_HPOC_SITE}.${MY_HPOC_NUMBER}.21"
  MY_PC_IP="10.${MY_HPOC_SITE}.${MY_HPOC_NUMBER}.39"
  MY_PRIMARY_NET_START_IP='45'
  MY_PRIMARY_NET_END_IP='64'
  MY_SECONDARY_NET_START_IP='130'
  MY_SECONDARY_NET_END_IP='159'
elif [[ ${MY_CVM_LAST_OCTET} == '30' ]]; then
  my_log 'Setting variables for Node A, CVM IP: '${MY_CVM_IP}
  CLUSTER_NAME="POC${MY_HPOC_NUMBER}-NodeB"
  MY_CLUSTER_IP="10.${MY_HPOC_SITE}.${MY_HPOC_NUMBER}.18"
  MY_ISCSI_IP="10.${MY_HPOC_SITE}.${MY_HPOC_NUMBER}.22"
  MY_PC_IP="10.${MY_HPOC_SITE}.${MY_HPOC_NUMBER}.40"
  MY_PRIMARY_NET_START_IP='65'
  MY_PRIMARY_NET_END_IP='84'
  MY_SECONDARY_NET_START_IP='160'
  MY_SECONDARY_NET_END_IP='189'
elif [[ ${MY_CVM_LAST_OCTET} == '31' ]]; then
  my_log 'Setting variables for Node A, CVM IP: '${MY_CVM_IP}
  CLUSTER_NAME="POC${MY_HPOC_NUMBER}-NodeC"
  MY_CLUSTER_IP="10.${MY_HPOC_SITE}.${MY_HPOC_NUMBER}.19"
  MY_ISCSI_IP="10.${MY_HPOC_SITE}.${MY_HPOC_NUMBER}.23"
  MY_PC_IP="10.${MY_HPOC_SITE}.${MY_HPOC_NUMBER}.41"
  MY_PRIMARY_NET_START_IP='85'
  MY_PRIMARY_NET_END_IP='104'
  MY_SECONDARY_NET_START_IP='190'
  MY_SECONDARY_NET_END_IP='219'
elif [[ ${MY_CVM_LAST_OCTET} == '32' ]]; then
  my_log 'Setting variables for Node A, CVM IP: '${MY_CVM_IP}
  CLUSTER_NAME="POC${MY_HPOC_NUMBER}-NodeD"
  MY_CLUSTER_IP="10.${MY_HPOC_SITE}.${MY_HPOC_NUMBER}.20"
  MY_ISCSI_IP="10.${MY_HPOC_SITE}.${MY_HPOC_NUMBER}.24"
  MY_PC_IP="10.${MY_HPOC_SITE}.${MY_HPOC_NUMBER}.42"
  MY_PRIMARY_NET_START_IP='105'
  MY_PRIMARY_NET_END_IP='124'
  MY_SECONDARY_NET_START_IP='220'
  MY_SECONDARY_NET_END_IP='249'
else
  my_log 'Invalid HPOC CVM IP'
  exit
fi

# Check if we got a password from environment or from the settings above, otherwise exit before doing anything
if [[ -z ${MY_PE_PASSWORD+x} ]]; then
    my_log "No password provided, exiting"
    exit -1
fi

my_log "My PID is $$"
#my_log "Installing sshpass"
#sudo rpm -ivh https://fr2.rpmfind.net/linux/epel/7/x86_64/Packages/s/sshpass-1.06-1.el7.x86_64.rpm

my_log "Creating single node cluster"
yes | cluster --cluster_name=${CLUSTER_NAME} --dns_servers=${PHX_DNS_IP} --ntp_server=${PHX_DNS_IP} --svm_ips=${MY_CVM_IP} create
my_log "Setting PE password"
ncli user reset-password user-name="admin" password="${MY_PE_PASSWORD}"

# Configure SMTP
my_log "Configure SMTP"
ncli cluster set-smtp-server address=nutanix-com.mail.protection.outlook.com from-email-address=cluster@nutanix.com port=25
# Configure NTP
my_log "Configure NTP"
ncli cluster add-to-ntp-servers servers=0.us.pool.ntp.org,1.us.pool.ntp.org,2.us.pool.ntp.org,3.us.pool.ntp.org
# Rename default storage container to MY_CONTAINER_NAME
my_log "Rename default container to ${MY_CONTAINER_NAME}"
default_container=$(ncli container ls | grep -P '^(?!.*VStore Name).*Name' | cut -d ':' -f 2 | sed s/' '//g | grep '^default-container-')
ncli container edit name="${default_container}" new-name="${MY_CONTAINER_NAME}"
# Rename default storage pool to MY_SP_NAME
my_log "Rename default storage pool to ${MY_SP_NAME}"
default_sp=$(ncli storagepool ls | grep 'Name' | cut -d ':' -f 2 | sed s/' '//g)
ncli sp edit name="${default_sp}" new-name="${MY_SP_NAME}"
# Check if there is a container named MY_IMG_CONTAINER_NAME, if not create one
my_log "Check if there is a container named ${MY_IMG_CONTAINER_NAME}, if not create one"
(ncli container ls | grep -P '^(?!.*VStore Name).*Name' | cut -d ':' -f 2 | sed s/' '//g | grep "^${MY_IMG_CONTAINER_NAME}" 2>&1 > /dev/null) \
    && echo "Container ${MY_IMG_CONTAINER_NAME} already exists" \
    || ncli container create name="${MY_IMG_CONTAINER_NAME}" sp-name="${MY_SP_NAME}"
# Set external IP address:
#ncli cluster edit-params external-ip-address=10.21.${MY_HPOC_NUMBER}.37
# Set Data Services IP address:
my_log "Set Data Services IP address to ${MY_ISCSI_IP}"
ncli cluster edit-params external-data-services-ip-address=${MY_ISCSI_IP}

my_log "Set Cluster IP address to ${MY_CLUSTER_IP}"
ncli cluster edit-params external-ip-address=${MY_CLUSTER_IP}
# Importing images
my_log "Importing Windows 10 image"
acli image.create Windows10 container="${MY_IMG_CONTAINER_NAME}" image_type=kDiskImage source_url=${WIN10_IMG_SRC} wait=true
my_log "Importing Windows 2012R2 image"
acli image.create Windows2012R2 container="${MY_IMG_CONTAINER_NAME}" image_type=kDiskImage source_url=${WIN2012R2_IMG_SRC} wait=true
my_log "Importing Frame Guest Agent image"
acli image.create FrameGuestAgent_1.0.1.7_77120.iso container="${MY_IMG_CONTAINER_NAME}" image_type=kIsoImage source_url=${FRAMEGA_ISO_SRC} wait=true
my_log "Importing Frame CCA"
acli image.create FrameCCA-2.0.0.iso container="${MY_IMG_CONTAINER_NAME}" image_type=kIsoImage source_url=${FRAMECCA_ISO_SRC} wait=true
my_log "Importing VirtIO ISO"
acli image.create VirtIO-1.1.4.iso container="${MY_IMG_CONTAINER_NAME}" image_type=kIsoImage source_url=${VIRTIO_ISO_SRC} wait=true
# Remove existing VMs, if any
my_log "Removing \"Windows 2012\" VM if it exists"
acli -y vm.delete Windows\ 2012\ VM delete_snapshots=true
my_log "Removing \"Windows 10\" VM if it exists"
acli -y vm.delete Windows\ 10\ VM delete_snapshots=true
my_log "Removing \"CentOS\" VM if it exists"
acli -y vm.delete CentOS\ VM delete_snapshots=true
# Remove Rx-Automation-Network network
my_log "Removing \"Rx-Automation-Network\" Network if it exists"
acli -y net.delete Rx-Automation-Network

# Create primary network
my_log "Create primary network"
acli net.create ${MY_PRIMARY_NET_NAME} vlan=${MY_PRIMARY_NET_VLAN} ip_config=10.${MY_HPOC_SITE}.${MY_HPOC_NUMBER}.1/25
acli net.update_dhcp_dns ${MY_PRIMARY_NET_NAME} servers=${PHX_DNS_IP}
acli net.add_dhcp_pool ${MY_PRIMARY_NET_NAME} start=10.${MY_HPOC_SITE}.${MY_HPOC_NUMBER}.${MY_PRIMARY_NET_START_IP} end=10.${MY_HPOC_SITE}.${MY_HPOC_NUMBER}.${MY_PRIMARY_NET_END_IP}
# Create secondary network
my_log "Create secondary network"
acli net.create ${MY_SECONDARY_NET_NAME} vlan=${MY_SECONDARY_NET_VLAN} ip_config=10.${MY_HPOC_SITE}.${MY_HPOC_NUMBER}.129/25
acli net.update_dhcp_dns ${MY_SECONDARY_NET_NAME} servers=${PHX_DNS_IP}
acli net.add_dhcp_pool ${MY_SECONDARY_NET_NAME} start=10.${MY_HPOC_SITE}.${MY_HPOC_NUMBER}.${MY_SECONDARY_NET_START_IP} end=10.${MY_HPOC_SITE}.${MY_HPOC_NUMBER}.${MY_SECONDARY_NET_END_IP}

my_log "Validate EULA on PE"
curl -u admin:${MY_PE_PASSWORD} -k -H 'Content-Type: application/json' -X POST \
  https://127.0.0.1:9440/PrismGateway/services/rest/v1/eulas/accept \
  -d '{
    "username": "SE",
    "companyName": "NTNX",
    "jobTitle": "SE"
}'
# Disable Pulse in PE
my_log "Disable Pulse in PE"
curl -u admin:${MY_PE_PASSWORD} -k -H 'Content-Type: application/json' -X PUT \
  https://127.0.0.1:9440/PrismGateway/services/rest/v1/pulse \
  -d '{
    "defaultNutanixEmail": null,
    "emailContactList": null,
    "enable": false,
    "enableDefaultNutanixEmail": false,
    "isPulsePromptNeeded": false,
    "nosVersion": null,
    "remindLater": null,
    "verbosityType": null
}'

my_log "Downloading PC package"
wget -nv ${MY_PC_SRC_URL}
wget -nv ${MY_PC_META_URL}
my_log "NCLI PC package upload"
ncli software upload file-path=/home/nutanix/${MY_PC_SRC_URL##*/} meta-file-path=/home/nutanix/${MY_PC_META_URL##*/} software-type=PRISM_CENTRAL_DEPLOY
my_log "Cleaning up unneeded PC binaries"
rm ${MY_PC_SRC_URL##*/} ${MY_PC_META_URL##*/}

my_log "Get UUIDs needed to deploy PC"
MY_NET_UUID=$(acli net.get ${MY_PRIMARY_NET_NAME} | grep "uuid" | cut -f 2 -d ':' | xargs)
MY_CONTAINER_UUID=$(ncli container ls name=${MY_CONTAINER_NAME} | grep Uuid | grep -v Pool | cut -f 2 -d ':' | xargs)

MY_DEPLOY_BODY=$(cat <<EOF
{
  "resources": {
      "should_auto_register":true,
      "version":"${PC_VERSION}",
      "pc_vm_list":[{
          "data_disk_size_bytes":536870912000,
          "nic_list":[{
              "network_configuration":{
                  "subnet_mask":"255.255.255.128",
                  "network_uuid":"${MY_NET_UUID}",
                  "default_gateway":"10.${MY_HPOC_SITE}.${MY_HPOC_NUMBER}.1"
              },
              "ip_list":["${MY_PC_IP}"]
          }],
          "dns_server_ip_list":["${PHX_DNS_IP}"],
          "container_uuid":"${MY_CONTAINER_UUID}",
          "num_sockets":4,
          "memory_size_bytes":17179869184,
          "vm_name":"PC"
      }]
  }
}
EOF
)
curl -u admin:${MY_PE_PASSWORD} -k -H 'Content-Type: application/json' -X POST https://127.0.0.1:9440/api/nutanix/v3/prism_central -d "${MY_DEPLOY_BODY}"
