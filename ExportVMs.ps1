# Script to Export all the VM Guests in multiple vCenter Servers to a native Excel file.

import-Module -Name vmware.powercli
import-Module -Name ImportExcel
remove-module RJVMMetaMove
import-Module .\RJVMMetaMove.psm1

# P = Just one vCenter (for testing)
# E = Just Europe
# G = Global
$runtype = "E"

$output = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\Richard\vCenterExport\Exports\vmGuestExport [$runtype] $(Get-date -Format "yyyy-MM-dd_HH.mm").xlsx"

$Credentials = Get-Credential

$VC1 = Connect-VIServer -Server "su-gbcp-vvcsa02.emea.wdpr.disney.com" -Credential $Credentials
if($runtype -ne "P"){
    $VC2 = Connect-VIServer -Server "su-gbcp-vvcsa03.emea.wdpr.disney.com" -Credential $Credentials
    $VC3 = Connect-VIServer -Server "su-gbcp-vvcsa04.emea.wdpr.disney.com" -Credential $Credentials
    if($runtype -eq "G"){
        $VC4 = Connect-VIServer -Server "su-cnts-vcsa01.apac.wdpr.disney.com" -Credential $Credentials
        $VC5 = Connect-VIServer -Server "su-cnts-vvcsa02.apac.wdpr.disney.com" -Credential $Credentials
        $VC6 = Connect-VIServer -Server "su-arba-vc01.ltam.wdpr.disney.com" -Credential $Credentials
    }
}

$VMGuests = Get-VM -server $VC1

if($runtype -ne "P"){
    $VMGuests += Get-VM -server $VC2
    $VMGuests += Get-VM -server $VC3
    if($runtype -eq "G"){   
        $VMGuests += Get-VM -server $VC4
        $VMGuests += Get-VM -server $VC5
        $VMGuests += Get-VM -server $VC6
    }
}

$VMGuests = $VMGuests | Sort-Object -property VMHost,Name

$count = 0
foreach ($VMGuest in $VMGuests){
    $completed = [math]::Round((($count/$VMGuests.count) * 100), 2)
    Get-RJVMMetaData -VMName $VMGuest | select-object -ExcludeProperty AttributeName,AttributeValue,AttributeTag,NetworkAdaper,DiskName,DiskStoragePolicy,DiskID,DiskFileName,DiskLayoutStorageFormat,DiskLayoutPersistence,DiskLayoutDiskType,DiskSizeGB,DiskDatastore,Snapshot `
    -Property `
        VMName, `
        VMID, `
        VMHostName, `
        Powerstate, `
        VMVersion, `
        MemoryGB, `
        CPUCores, `
        TotalDiskSizeGB, `
        UsedSpaceGB, `
        ProvisionedSpaceGB, `
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
        LocationCode, `
        Notes, `
        @{N='AttributeName';E={ if ($_.AttributeName) { $_.AttributeName -join("`r")}}}, `
        @{N='AttributeValue';E={ if ($_.AttributeValue) { $_.AttributeValue -join("`r")}}}, `
        @{N='AttributeTag';E={ if ($_.AttributeTag) { $_.AttributeTag -join("`r")}}}, `
        @{N='Network';E={ if ($_.NetworkAdapter) { $_.NetworkAdapter -join("`r")}}}, `
        @{N='DiskName';E={ if ($_.DiskName) { $_.DiskName -join("`r")}}}, `
        @{N='DiskID';E={ if ($_.DiskID) { $_.DiskID -join("`r")}}}, `
        @{N='DiskFileName';E={ if ($_.DiskFileName) { $_.DiskFileName -join("`r")}}}, `
        @{N='DiskStoragePolicy';E={ if ($_.DiskStoragePolicy) { $_.DiskStoragePolicy -join("`r")}}}, `
        @{N='DiskLayoutStorageFormat';E={ if ($_.DiskLayoutStorageFormat) { $_.DiskLayoutStorageFormat -join("`r")}}}, `
        @{N='DiskLayoutPersistence';E={ $_.DiskLayoutPersistence -join("`r")}}, `
        @{N='DiskLayoutDiskType';E={ if ($_.DiskLayoutDiskType) { $_.DiskLayoutDiskType -join("`r")}}}, `
        @{N='DiskSizeGB';E={ if ($_.DiskSizeGB) { $_.DiskSizeGB -join("`r")}}}, `
        @{N='DiskDatastore';E={ if ($_.DiskDatastore) { $_.DiskDatastore -join("`r")}}}, `
        @{N='Snapshot';E={ if ($_.Snapshot) { $_.Snapshot -join("`r")}}} `
        | export-excel -path $output -WorksheetName "vmGuestExport" -autosize -append

    Write-Progress -Activity "Scan Progress:" -Status "$completed% completed." -PercentComplete $completed
    $count++
}

$exportXL = Export-Excel -Path $output -WorksheetName "vmGuestExport" -FreezeTopRowFirstColumn -autofilter -titlebold -autosize -PassThru
$exportWS = $exportXL.vmGuestExport
set-format $exportWS.workbook.worksheets['vmGuestExport'].cells -WrapText
Close-ExcelPackage $exportXL

Disconnect-VIServer -Server * -Confirm:$false