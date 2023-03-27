# Script to test the move-xvcvm function.  The 'function' side of this will eventually move to this module.
# initially, do all the hard work here, later, put it all in a function with x parameters (VM, sourcevc object, destvc object, datastore and network attributes)

import-Module -Name vmware.powercli
remove-module RJVMMetaMove
import-Module .\RJVMMetaMove.psm1

#Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

$VMtoMove = "TestVM"
$credential = Get-Credential

#### Migrate the VM
# may need to specify folders and other data.
# may need to create some logic of source and desintation networks/portgroups/datastores

# code to find datastore, portgroup and VDSwitch
# Connect-VIServer -Server "su-gbcp-vvcsa02.emea.wdpr.disney.com" 
# $myvmhost = get-vmhost -name "su-gbcp-vxrail01.emea.wdpr.disney.com"
# get-datastore -vmhost $myvmhost | ft -autosize -property name,capacitygb
# get-virtualportgroup -vmhost $myvmhost | ft -autosize -property name
# get-vdswitch -VMHost $myvmhost | ft -autosize -property name

# # 2 to 4
# $SourceVC = Connect-VIServer -Server "su-gbcp-vvcsa02.emea.wdpr.disney.com" -Credential $credential
# $TargetVC = Connect-VIServer -Server "su-gbcp-vvcsa04.emea.wdpr.disney.com" -Credential $credential
# $TargetVMHost = "su-gbeq-vxrail01.emea.wdpr.disney.com"
# $TargetPortgroup = "PROD_DataCentre2-386"
# $TargetVDSwitch = "VMware HCIA Distributed Switch GBEQ Ent Tech VxRail v7 1c4bfa"
# $Targetdatastore = "VxRail-Virtual-SAN-Datastore-1c4bfaa4-60d6-4ddf-87df-419f47e931a6"

# 4 to 2
$SourceVC = Connect-VIServer -Server "su-gbcp-vvcsa04.emea.wdpr.disney.com" -Credential $credential
$TargetVC = Connect-VIServer -Server "su-gbcp-vvcsa02.emea.wdpr.disney.com" -Credential $credential
$TargetVMHost = "su-gbeq-vxrail50.emea.wdpr.disney.com"
$TargetPortgroup = "PROD_DataCentre2-386"
$TargetVDSwitch = "VMware HCIA Distributed Switch GBEQ Ent Tech VxRail 82d1d4"
$Targetdatastore = "VxRail-Virtual-SAN-Datastore-82d1d453-d153-4a50-8ec2-8fa5a819b4a9"

#### Get the metadata
$SourceVM = get-vm -Name $VMtoMove -server $SourceVC
$VMMetaData = get-RJVMMetaData -VMName $VMtoMove

#### Move the VM
#### Do a pre-move compatbility check (processor stepping level etc)
$networkAdapter = Get-NetworkAdapter -VM $SourceVM -Server $SourceVC
$TargetPortGroup = Get-VDPortgroup -Name $TargetPortGroup -Server $TargetVC -vdswitch $TargetVDSwitch
Move-VM -VM $SourceVM -VMotionPriority High -Destination (Get-VMhost -Server $TargetVC -Name $TargetVMHost) -Datastore (Get-Datastore -Server $targetVC -Name $TargetDatastore) -NetworkAdapter $networkAdapter -PortGroup $TargetPortGroup

#### Write the metadata
$TargetVM = get-vm -Name $VMtoMove -Server $TargetVC
Set-RJVMCustomAttributes -VMName $VMtoMove -TargetVM $TargetVM -TargetVC $TargetVC -VMMetaData $VMMetaData

Disconnect-VIServer -Server * -Confirm:$false
