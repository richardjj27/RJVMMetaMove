# Script to test the export-vmmmetadata function by exporting all VMs.

import-Module -Name vmware.powercli
import-Module -Name ImportExcel
remove-module RJVMMetaMove
import-Module .\RJVMMetaMove.psm1

# Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

$output = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\Richard\vCenterExport\vCenterExport [P] $(get-date -Format "yyyy-MM-dd_HH.mm").xlsx"

# Silently delete old file
#remove-item $output -force -ErrorAction SilentlyContinue

# Connect to the vCenter Server
$credential = Get-Credential
$VC1 = Connect-VIServer -Server "su-gbcp-vvcsa02.emea.wdpr.disney.com" -Credential $credential
#$VC2 = Connect-VIServer -Server "su-gbcp-vvcsa03.emea.wdpr.disney.com" -Credential $credential
#$VC3 = Connect-VIServer -Server "su-gbcp-vvcsa04.emea.wdpr.disney.com" -Credential $credential

$VirtualMachines = get-VM -server $VC1 | where-object NumCpu -ge 18
$virtualMachines += get-vm -server $VC1 | where-object Name -eq "SM-GBCP-VCXA105"  
#$VirtualMachines += get-VM -server $VC2
#$VirtualMachines += get-VM -server $VC3

# create an empty XLSX document with all the headings
# $CustomObject = New-Object -TypeName PSObject
# $CustomObject | Add-Member -Name "VMName" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "VMCreated" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "VMVersion" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "AttributeKey" -MemberType NoteProperty -value $null #
# $CustomObject | Add-Member -Name "AttributeName" -MemberType NoteProperty -value $null #
# $CustomObject | Add-Member -Name "AttributeValue" -MemberType NoteProperty -value $null #
# $CustomObject | Add-Member -Name "AttributeTag" -MemberType NoteProperty -value $null #
# $CustomObject | Add-Member -Name "DiskName" -MemberType NoteProperty -value $null
# #$CustomObject | Add-Member -Name "DiskEncryptionStatus" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "DiskLayout" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "DiskSizeGB" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "DiskDatastore" -MemberType NoteProperty -value $null
# #$CustomObject | Add-Member -Name "DiskDatastoreEncryptionStatus" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "NetworkAdapter" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "vCenter" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "Host" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "HostVersion" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "HostBuild" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "Folder" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "Datacenter" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "Cluster" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "ResourcePool" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "MemoryGB" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "CPUCores" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "ToolsVersion" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "Notes" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "Powerstate" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "GuestOS" -MemberType NoteProperty -value $null
# $CustomObject | Add-Member -Name "Snapshot" -MemberType NoteProperty -value $null
# $CustomObject | export-excel $output -append -freezetoprow -autofilter -autosize

$count = 0
foreach ($VirtualMachine in $VirtualMachines){
    $completed = [math]::Round((($count/$VirtualMachines.count) * 100), 2)
    $a = get-RJVMMetaData2 -VMName $VirtualMachine
    $a | select-object -ExcludeProperty AttributeKey,AttributeName,AttributeValue,AttributeTag,NetworkAdapers,DiskName,DiskLayout,DiskSizeGB,DiskDatastore,Snapshot `
    -Property `
        VMName, `
        VMCreated, `
        VMVersion, `
        vCenter, `
        Host, `
        HostVersion, `
        HostBuild, `
        Datacenter, `
        Cluster, `
        ResourcePool, `
        MemoryGB, `
        CPUCores, `
        ToolsVersion, `
        Folder, `
        Notes, `
        Powerstate, `
        GuestOS, `
        @{N='AttributeKey';E={ if ($_.AttributeKey) { $_.AttributeKey -join("`r`n")}}}, `
        @{N='AttributeName';E={ if ($_.AttributeName) { $_.AttributeName -join("`r`n")}}}, `
        @{N='AttributeValue';E={ if ($_.AttributeValue) { $_.AttributeValue -join("`r`n")}}}, `
        @{N='AttributeTag';E={ if ($_.AttributeTag) { $_.AttributeTag -join("`r`n")}}}, `
        @{N='NetworkAdapters';E={ if ($_.NetworkAdapters) { $_.NetworkAdapters -join("`r`n")}}}, `
        @{N='DiskName';E={ if ($_.DiskName) { $_.DiskName -join("`r`n")}}}, `
        @{N='DiskLayout';E={ if ($_.DiskLayout) { $_.DiskLayout -join("`r`n")}}}, `
        @{N='DiskSizeGB';E={ if ($_.DiskSizeGB) { $_.DiskSizeGB -join("`r`n")}}}, `
        @{N='DiskDatastore';E={ if ($_.DiskDatastore) { $_.DiskDatastore -join("`r`n")}}}, `
        @{N='Snapshots';E={ if ($_.Snapshots) { $_.Snapshots -join("`r`n")}}} `
        | export-excel -path $output -append -freezetoprow -autofilter -autosize

    #get-RJVMCoreData -VMName $VirtualMachine.Name | export-excel $output -append -freezetoprow -autofilter -autosize
    Write-Progress -Activity "Scan Progress:" -Status "$completed% completed." -PercentComplete $completed
    $count++
}

#Disconnect-VIServer -Server * -Confirm:$false
