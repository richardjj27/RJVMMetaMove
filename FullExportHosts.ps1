# Script to test the export-vmmmetadata function by exporting all VMs.

import-Module -Name vmware.powercli
import-Module -Name ImportExcel
remove-module RJVMMetaMove
import-Module .\RJVMMetaMove.psm1

$output = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\Richard\vCenterExport\vmHostExport [F] $(get-date -Format "yyyy-MM-dd_HH.mm").xlsx"

# Connect to the vCenter Server
$credential = Get-Credential
$VC1 = Connect-VIServer -Server "su-gbcp-vvcsa02.emea.wdpr.disney.com" -Credential $credential
$VC2 = Connect-VIServer -Server "su-gbcp-vvcsa03.emea.wdpr.disney.com" -Credential $credential
$VC3 = Connect-VIServer -Server "su-gbcp-vvcsa04.emea.wdpr.disney.com" -Credential $credential

$allVMHosts = get-VMHost -server $VC1
$allVMHosts += get-VMHost -server $VC2
$allVMHosts += get-VMHost -server $VC3

$count = 0
foreach ($VMHost in $allVMHosts){
    $completed = [math]::Round((($count/$allVMHosts.count) * 100), 2)
    $a = Get-RJVMHostData -VMHost $VMHost
    $a | select-object -ExcludeProperty DatastoreName,DatastoreType,DatastoreCapacityGB,vdPortGroupName `
    -Property `
        Name, `
        State, `
        vCenter, `
        ParentCluster, `
        Vendor, `
        Model, `
        SerialNumber, `
        IPMIIP, `
        LicenseKey, `
        NumCPU, `
        CryptoState, `
        Version, `
        Build, `
        MemoryTotalGB, `
        MaxEVCMode, `
        ProcessorType, `
        @{N='DatastoreName';E={ if ($_.DatastoreName) { $_.DatastoreName -join("`r")}}}, `
        @{N='DatastoreType';E={ if ($_.DatastoreType) { $_.DatastoreType -join("`r")}}}, `
        @{N='DatastoreCapacityGB';E={ if ($_.DatastoreCapacityGB) { $_.DatastoreCapacityGB -join("`r")}}}, `
        @{N='vdPortGroupName';E={ if ($_.vdPortGroupName) { $_.vdPortGroupName -join("`r")}}} `
        | export-excel -path $output -WorksheetName "vmHostExport" -autosize -append

    Write-Progress -Activity "Scan Progress:" -Status "$completed% completed." -PercentComplete $completed
    $count++
}

$exportXL = Export-Excel -Path $output -WorksheetName "vmHostExport" -freezetoprow -autofilter -Titlebold -autosize -PassThru
$exportWS = $exportXL.vmHostExport
set-format $exportWS.workbook.worksheets['vmHostExport'].cells -WrapText
Close-ExcelPackage $exportXL

Disconnect-VIServer -Server * -Confirm:$false
