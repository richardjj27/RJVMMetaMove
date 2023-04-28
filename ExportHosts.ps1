# Script to Export all the VM Hosts in multiple vCenter Servers to a native Excel file.

import-Module -Name vmware.powercli
import-Module -Name ImportExcel
remove-module RJVMMetaMove
import-Module .\RJVMMetaMove.psm1

# P = Just one vCenter (for testing)
# E = Just Europe
# G = Global
$runtype = "G"

$output = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\Richard\vCenterExport\Exports\vmHostExport [$runtype] $(get-date -Format "yyyy-MM-dd_HH.mm").xlsx"

$credential = Get-Credential

$VC1 = Connect-VIServer -Server "su-gbcp-vvcsa02.emea.wdpr.disney.com" -Credential $credential
if($runtype -ne "P"){
    $VC2 = Connect-VIServer -Server "su-gbcp-vvcsa03.emea.wdpr.disney.com" -Credential $credential
    $VC3 = Connect-VIServer -Server "su-gbcp-vvcsa04.emea.wdpr.disney.com" -Credential $credential
    if($runtype -eq "G"){
        $VC4 = Connect-VIServer -Server "su-cnts-vcsa01.apac.wdpr.disney.com" -Credential $credential
        $VC5 = Connect-VIServer -Server "su-cnts-vvcsa02.apac.wdpr.disney.com" -Credential $credential
        $VC6 = Connect-VIServer -Server "su-arba-vc01.ltam.wdpr.disney.com" -Credential $credential
    }
}

$VMHosts = get-VMHost -server $VC1

if($runtype -ne "P"){
    $VMHosts += get-VMHost -server $VC2
    $VMHosts += get-VMHost -server $VC3
    if($runtype -eq "G"){
        $VMHosts += get-VMHost -server $VC4
        $VMHosts += get-VMHost -server $VC5
        $VMHosts += get-VMHost -server $VC6
    }
}

$VMHosts = $VMHosts | sort-object -property name

$count = 0
foreach ($VMHost in $VMHosts){
    $completed = [math]::Round((($count/$VMHosts.count) * 100), 2)
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
        | export-excel -path $output -WorksheetName "vmHostExport" -autosize -append

    Write-Progress -Activity "Scan Progress:" -Status "$completed% completed." -PercentComplete $completed
    $count++
}

$exportXL = Export-Excel -Path $output -WorksheetName "vmHostExport" -FreezeTopRowFirstColumn -autofilter -titlebold -autosize -PassThru
$exportWS = $exportXL.vmHostExport
set-format $exportWS.workbook.worksheets['vmHostExport'].cells -WrapText
Close-ExcelPackage $exportXL

Disconnect-VIServer -Server * -Confirm:$false
