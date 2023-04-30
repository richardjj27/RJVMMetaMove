# Script to Export all the VM Hosts in multiple vCenter Servers to a native Excel file.

import-Module -Name vmware.powercli
import-Module -Name ImportExcel
remove-module RJVMMetaMove
import-Module .\RJVMMetaMove.psm1

$XLOutputFile = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\Richard\vCenterExport\Exports\vmHostExport [$runtype] $(get-date -Format "yyyy-MM-dd_HH.mm").xlsx"
$VCenterList = "C:\Users\rjohnson\Documents\VSCode Projects\X\VCList.csv"

$AdminCredentials = Get-Credential
$VCenters = Import-CSV -Path $VCenterList

ForEach($VCenter in $Vcenters){
    if($VCenter.Server.SubString(0,1) -ne "#") {
        $VC = Connect-VIServer -Server $VCenter.Server -Credential $AdminCredentials | Out-Null
        $VMHosts += get-VMHost -server $VC
        # $VMGuests += Get-VM -server $VC
    }
}

$VMHosts = $VMHosts | sort-object -property name

$ProgressCount = 0
foreach ($VMHost in $VMHosts){
    $completed = [math]::Round((($ProgressCount/$VMHosts.count) * 100), 2)
    Get-RJVMHostData -VMHost $VMHost | select-object -ExcludeProperty DatastoreName,DatastoreType,DatastoreCapacityGB,Network,NetworkSwitch `
    -Property `
        Name, `
        State, `
        vCenter, `
        Cluster, `
        LocationCode, `
        Vendor, `
        Model, `
        SerialNumber, `
        PSNT, `
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
        @{N='Network';E={ if ($_.Network) { $_.Network -join("`r")}}}, `
        @{N='NetworkSwitch';E={ if ($_.NetworkSwitch) { $_.NetworkSwitch -join("`r")}}} `
        | export-excel -path $XLOutputFile -WorksheetName "vmHostExport" -autosize -append

    Write-Progress -Activity "Scan Progress:" -Status "$completed% completed." -PercentComplete $completed
    $ProgressCount++
}

$exportXL = Export-Excel -Path $XLOutputFile -WorksheetName "vmHostExport" -FreezeTopRowFirstColumn -autofilter -titlebold -autosize -PassThru
$exportWS = $exportXL.vmHostExport
set-format $exportWS.workbook.worksheets['vmHostExport'].cells -WrapText
Close-ExcelPackage $exportXL

Disconnect-VIServer -Server * -Confirm:$false
