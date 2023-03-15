# Script to test the export-vmmmetadata function by exporting all VMs.

import-Module -Name vmware.powercli
import-Module -Name ImportExcel
import-Module .\RJVMMetaMove.psm1

#Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

$output = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\Richard\vCenterExport\vCenterExport.xlsx"

# Silently delete old file
remove-item $output -force -ErrorAction SilentlyContinue

# Connect to the vCenter Server
$credential = Get-Credential
$VC1 = Connect-VIServer -Server "su-gbcp-vvcsa02.emea.wdpr.disney.com" -Credential $credential
$VC2 = Connect-VIServer -Server "su-gbcp-vvcsa03.emea.wdpr.disney.com" -Credential $credential
$VC3 = Connect-VIServer -Server "su-gbcp-vvcsa04.emea.wdpr.disney.com" -Credential $credential

$VirtualMachines = get-VM -server $VC1 #| where-object NumCpu -ge 18
$VirtualMachines += get-VM -server $VC2
$VirtualMachines += get-VM -server $VC3

# create an empty XLSX document with all the headings
$CustomObject = New-Object -TypeName PSObject
$CustomObject | Add-Member -Name "VMName" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "VMCreated" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "VMVersion" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "AttributeKey" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "AttributeName" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "AttributeValue" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "Tag" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "DiskName" -MemberType NoteProperty -value $null
#$CustomObject | Add-Member -Name "DiskEncryptionStatus" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "DiskLayout" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "DiskSizeGB" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "DiskDatastore" -MemberType NoteProperty -value $null
#$CustomObject | Add-Member -Name "DiskDatastoreEncryptionStatus" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "NetworkAdapter" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "vCenter" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "Host" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "HostVersion" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "HostBuild" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "Datacenter" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "Cluster" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "ResourcePool" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "MemoryGB" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "CPU" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "ToolsVersion" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "Notes" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "Powerstate" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "GuestOS" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "Snapshot" -MemberType NoteProperty -value $null
$CustomObject | export-excel $output -append -freezetoprow -autofilter -autosize

$count = 0
foreach ($VirtualMachine in $VirtualMachines){
    $completed = [math]::Round((($count/$VirtualMachines.count) * 100), 2)
    get-RJVMMetaData -VMName $VirtualMachine.Name | export-excel $output -append -freezetoprow -autofilter -autosize
    get-RJVMCoreData -VMName $VirtualMachine.Name | export-excel $output -append -freezetoprow -autofilter -autosize
    Write-Progress -Activity "Scan Progress:" -Status "$completed% completed." -PercentComplete $completed
    $count++
}

Disconnect-VIServer -Server * -Confirm:$false
