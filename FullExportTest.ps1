# Script to test the export-vmmmetadata function by exporting all VMs.

import-Module -Name vmware.powercli
import-Module -Name ImportExcel
remove-module RJVMMetaMove
import-Module .\RJVMMetaMove.psm1

$output = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\Richard\vCenterExport\vmGuestExport [P] $(get-date -Format "yyyy-MM-dd_HH.mm").xlsx"

# Connect to the vCenter Server
$credential = Get-Credential
$VC1 = Connect-VIServer -Server "su-gbcp-vvcsa02.emea.wdpr.disney.com" -Credential $credential
$VC2 = Connect-VIServer -Server "su-gbcp-vvcsa03.emea.wdpr.disney.com" -Credential $credential
$VC3 = Connect-VIServer -Server "su-gbcp-vvcsa04.emea.wdpr.disney.com" -Credential $credential
$VC4 = Connect-VIServer -Server "su-cnts-vcsa01.apac.wdpr.disney.com" -Credential $credential
$VC5 = Connect-VIServer -Server "su-cnts-vvcsa02.apac.wdpr.disney.com" -Credential $credential
$VC6 = Connect-VIServer -Server "su-arba-vc01.ltam.wdpr.disney.com" -Credential $credential

$VirtualMachines = get-VM -server $VC1
$VirtualMachines += get-VM -server $VC2
$VirtualMachines += get-VM -server $VC3
$VirtualMachines += get-VM -server $VC4
$VirtualMachines += get-VM -server $VC5
$VirtualMachines += get-VM -server $VC6

$count = 0
foreach ($VirtualMachine in $VirtualMachines){
    $completed = [math]::Round((($count/$VirtualMachines.count) * 100), 2)
    $a = get-RJVMMetaData -VMName $VirtualMachine
    $a | select-object -ExcludeProperty AttributeName,AttributeValue,AttributeTag,NetworkAdaper,DiskName,DiskLayout,DiskSizeGB,DiskDatastore,Snapshot `
    -Property `
        VMName, `
        Powerstate, `
        VMVersion, `
        MemoryGB, `
        CPUCores, `
        ToolsVersion, `
        GuestOS, `
        VMCreated, `
        vCenter, `
        Host, `
        HostVersion, `
        HostBuild, `
        Datacenter, `
        Cluster, `
        ResourcePool, `
        Folder, `
        ClusterLocation, `
        Notes, `
        @{N='AttributeName';E={ if ($_.AttributeName) { $_.AttributeName -join("`r")}}}, `
        @{N='AttributeValue';E={ if ($_.AttributeValue) { $_.AttributeValue -join("`r")}}}, `
        @{N='AttributeTag';E={ if ($_.AttributeTag) { $_.AttributeTag -join("`r")}}}, `
        @{N='NetworkAdapter';E={ if ($_.NetworkAdapter) { $_.NetworkAdapter -join("`r")}}}, `
        @{N='DiskName';E={ if ($_.DiskName) { $_.DiskName -join("`r")}}}, `
        @{N='DiskLayout';E={ if ($_.DiskLayout) { $_.DiskLayout -join("`r")}}}, `
        @{N='DiskSizeGB';E={ if ($_.DiskSizeGB) { $_.DiskSizeGB -join("`r")}}}, `
        @{N='DiskDatastore';E={ if ($_.DiskDatastore) { $_.DiskDatastore -join("`r")}}}, `
        @{N='Snapshot';E={ if ($_.Snapshot) { $_.Snapshot -join("`r")}}} `
        | export-excel -path $output -WorksheetName "vmGuestExport" -autosize -append

    Write-Progress -Activity "Scan Progress:" -Status "$completed% completed." -PercentComplete $completed
    $count++

}

$exportXL = Export-Excel -Path $output -WorksheetName "vmGuestExport" -freezetoprow -autofilter -titlebold -autosize -PassThru
$exportWS = $exportXL.vmGuestExport
set-format $exportWS.workbook.worksheets['vmGuestExport'].cells -WrapText
Close-ExcelPackage $exportXL

Disconnect-VIServer -Server * -Confirm:$false
