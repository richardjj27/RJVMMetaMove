# Script to test the move-xvcvm function.  The 'function' side of this will move to the module.
# initially, do all the hard work here, later, put it all in a function with x parameters (VM, sourcevc object, destvc object, datastore and network attributes)

import-Module -Name vmware.powercli
import-Module .\export-vmmetadata.psm1

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

$VMtoMove = "TestVM"
$credential = Get-Credential

#### Get the metadata
# may also need disk and network??
$VMMetaDataItems = get-VMMetaData -VMName $VMtoMove

#### Migrate the VM
# maybe need to specify folders and other data.
# may need to create some logic of source and desintation networks/portgroups/datastores

# 2 to 4
$SourceVC = Connect-VIServer -Server "su-gbcp-vvcsa02.emea.wdpr.disney.com" -Credential $credential
$TargetVC = Connect-VIServer -Server "su-gbcp-vvcsa04.emea.wdpr.disney.com" -Credential $credential
$TargetVMHost = "su-gbeq-vxrail01.emea.wdpr.disney.com"
$TargetPortgroup = "PROD_DataCentre2-386"
$TargetVDSwitch = "VMware HCIA Distributed Switch GBEQ Ent Tech VxRail v7 1c4bfa"
$Targetdatastore = "VxRail-Virtual-SAN-Datastore-1c4bfaa4-60d6-4ddf-87df-419f47e931a6"

# 4 to 2
#$SourceVC = Connect-VIServer -Server "su-gbcp-vvcsa04.emea.wdpr.disney.com" -Credential $credential
#$TargetVC = Connect-VIServer -Server "su-gbcp-vvcsa02.emea.wdpr.disney.com" -Credential $credential
#$TargetVMHost = "su-gbeq-vxrail50.emea.wdpr.disney.com"
#$TargetPortgroup = "PROD_DataCentre2-386"
#$TargetVDSwitch = "VMware HCIA Distributed Switch GBEQ Ent Tech VxRail 82d1d4"
#$Targetdatastore = "VxRail-Virtual-SAN-Datastore-82d1d453-d153-4a50-8ec2-8fa5a819b4a9"

$VM = get-vm $VMtoMove
$networkAdapter = Get-NetworkAdapter -VM $vm -Server $SourceVC
$TargetPortGroup = Get-VDPortgroup -Name $TargetPortGroup -Server $TargetVC -vdswitch $TargetVDSwitch
Move-VM -VM $vm -VMotionPriority High -Destination (Get-VMhost -Server $TargetVC -Name $TargetVMHost) -Datastore (Get-Datastore -Server $targetVC -Name $TargetDatastore) -NetworkAdapter $networkAdapter -PortGroup $TargetPortGroup

############

#### Write the metadata

$VMMetaDataItems = get-VMMetaData -VMName $VMtoMove
# This section below will become the 'put-VMMetaData' function.
foreach ($VMMetaDataItem in $VMMetaDataItems){
    #write-host $VMMetaDataItem |fl
    if ($VMMetaDataItem.AttributeName){
        $VM | Set-Annotation -CustomAttribute $VMMetaDataItem.AttributeName -Value "xyz"
    }

    if ($VMMetaDataItem.Tag){
        #server will change to 'destination' when live.
        $VM | New-TagAssignment -Tag "Development" -Server $SourceVC # $VMMetaDataItem.Tag
    }
    
}

Disconnect-VIServer -Server * -Confirm:$false

