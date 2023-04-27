# Script to test the move-xvcvm function.  The 'function' side of this will eventually move to this module.
# initially, do all the hard work here, later, put it all in a function with x parameters (VM, sourcevc object, destvc object, datastore and network attributes)

import-Module -Name vmware.powercli
remove-module RJVMMetaMove
import-Module .\RJVMMetaMove.psm1

#Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

$logfile = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\richard\vCenterExport\Logs\VM Migration Log $(get-date -Format "yyyy-MM-dd_HH.mm").txt"
$VMListFile = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\richard\vCenterExport\VMList.txt"
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

Connect-VIServer -Server "su-gbcp-vvcsa02.emea.wdpr.disney.com" -Credential $credential | Out-Null
Connect-VIServer -Server "su-gbcp-vvcsa03.emea.wdpr.disney.com" -Credential $credential | Out-Null
Connect-VIServer -Server "su-gbcp-vvcsa04.emea.wdpr.disney.com" -Credential $credential | Out-Null

# 2 to 4
$TargetVMHost = "su-gbeq-vxrail01.emea.wdpr.disney.com"
$TargetNetwork = "OnAir-GBEQ-86"
$TargetDatastore = "VxRail-Virtual-SAN-Datastore-1c4bfaa4-60d6-4ddf-87df-419f47e931a6"

# # 4 to 2
# $TargetVMHost = "su-gbeq-vxrail50.emea.wdpr.disney.com"
# $TargetNetwork = "PROD_DataCentre2-386"
# $TargetDatastore = "VxRail-Virtual-SAN-Datastore-82d1d453-d153-4a50-8ec2-8fa5a819b4a9"

# # ILTA Move
# $TargetVMHost = "su-ilta-vxrail01.emea.wdpr.disney.com"
# $TargetNetwork = "PROD_ILTA_VLAN5"
# $TargetDatastore = "VxRail-Virtual-SAN-Datastore-ILTA"

# # TRZE Move
# $TargetVMHost = "su-trze-vxrail01.emea.wdpr.disney.com"
# $TargetNetwork = "Production_45"
# $TargetDatastore = "VxRail-Virtual-SAN-Datastore-a86fa29d-0e1d-4b08-9bf1-633d0064c41d"

$MovingVMs = Get-Content ($VMListFile)

ForEach($MovingVM in $MovingVMs) {

    #### Get the metadata
    $SourceVM = Get-VM -Name $MovingVM #-server $SourceVC
    Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Collect data for $SourceVM."
    $VMMetaData = get-RJVMMetaData -VMName $SourceVM

    #### Move the VM and convert target to thin (remove the switch if this is undesired)
    #### Todo: a pre-move compatbility check (processor stepping level etc) or make this a 'try/catch' command.
    $TargetPortGroup = Get-VirtualPortGroup -VMHost $TargetVMHost -Name $TargetNetwork
    Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Start VM migration for $SourceVM to $TargetVMHost."
    Move-VM -VM $SourceVM -VMotionPriority High -Destination (Get-VMhost -Name $TargetVMHost) -Datastore (Get-Datastore -Name $TargetDatastore) -DiskStorageFormat Thin -PortGroup $TargetPortGroup | Out-Null

    #### Write the metadata
    $TargetVM = get-vm -Name $SourceVM #-Server $TargetVC
    $TargetVC = (get-vm -name $SourceVM).Uid.Split(":")[0].Split("@")[1]

    $VMTargetMetaData = get-RJVMMetaData -VMName $SourceVM

    if ($VMMetaData.Host -eq $VMTargetMetaData.Host) {
        Write-RJLog -LogFile $Logfile -Severity 2 -LogText "Migration of $SourceVM failed."
    }
    else {
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Migration of $SourceVM succeeded."
        Set-RJVMCustomAttributes -TargetVM $TargetVM -VMMetaData $VMMetaData -TargetVC $TargetVC 
        $VMTargetMetaData = get-RJVMMetaData -VMName $SourceVM
        if ((Compare-Object -ReferenceObject @($VMMetaData.AttributeName | Select-Object) -DifferenceObject @($VMTargetMetaData.AttributeName | Select-Object)).count -eq 0)
            {Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Migration of attribute names for $SourceVM succeeded."} 
            else
            {Write-RJLog -LogFile $Logfile -Severity 2 -LogText "Migration of attribute names for $SourceVM failed."}
        if ((Compare-Object -ReferenceObject @($VMMetaData.AttributeValue | Select-Object) -DifferenceObject @($VMTargetMetaData.AttributeValue | Select-Object)).count -eq 0)
            {Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Migration of attribute values for $SourceVM succeeded."}
            else
            {Write-RJLog -LogFile $Logfile -Severity 2 -LogText "Migration of attribute values for $SourceVM failed."}
        if ((Compare-Object -ReferenceObject @($VMMetaData.AttributeTag | Select-Object) -DifferenceObject @($VMTargetMetaData.AttributeTag | Select-Object)).count -eq 0)
            {Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Migration of tags for $SourceVM succeeded."}
            else
            {Write-RJLog -LogFile $Logfile -Severity 2 -LogText "Migration of tags for $SourceVM failed."}
    }

    Write-RJLog -LogFile $LogFile 
}


Disconnect-VIServer -Server * -Confirm:$false



