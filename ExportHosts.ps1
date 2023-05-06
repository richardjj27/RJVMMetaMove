# Script to Export all VM Hosts on multiple vCenter Servers to an Excel file.

Import-Module -Name vmware.powercli
Import-Module -Name ImportExcel
Remove-Module RJVMMetaMove
Import-Module .\RJVMMetaMove.psm1

$XLOutputFile = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\Richard\RJVMMetaMove\Exports\vmHostExport $(get-date -Format "yyyy-MM-dd_HH.mm").xlsx"
$VCenterList = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\Richard\RJVMMetaMove\VCList.csv"
$VMHosts = $Null

# Only ask for credentials if they aren't already in memory.
if (!($AdminCredentials)) {
    $AdminCredentials = Get-Credential
}

$VCenters = Import-CSV -Path $VCenterList
ForEach ($VCenter in $VCenters) {
    if ($VCenter.Server.SubString(0, 1) -ne "#") {
        Connect-VIServer -Server $VCenter.Server -Credential $AdminCredentials | Out-Null
        $VMHosts += Get-VMHost -Server $VCenter.Server
        # $VMGuests += Get-VM -Server $VCenter.Server
    }
}

# $VMHosts = $VMHosts | Get-Random -Count 5 # Limit results to a small number of servers for testing.
Write-Host "Processing"$VMHosts.count"VM Hosts."
$VMHosts = $VMHosts | sort-object -property Name

$ProgressCount = 0
ForEach ($VMHost in $VMHosts) {
    $Completed = ('{0:d2}' -f [int]((($ProgressCount / $VMHosts.count) * 100)))
    Get-RJVMHostData -VMHost $VMHost | select-object -ExcludeProperty DatastoreName, DatastoreType, DatastoreCapacityGB, Network, NetworkSwitch `
        -Property `
        Name, `
        ConnectionState, `
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
    @{N = 'DatastoreName'; E = { if ($_.DatastoreName) { $_.DatastoreName -join ("`r") } } }, `
    @{N = 'DatastoreType'; E = { if ($_.DatastoreType) { $_.DatastoreType -join ("`r") } } }, `
    @{N = 'DatastoreCapacityGB'; E = { if ($_.DatastoreCapacityGB) { $_.DatastoreCapacityGB -join ("`r") } } }, `
    @{N = 'Network'; E = { if ($_.Network) { $_.Network -join ("`r") } } }, `
    @{N = 'NetworkSwitch'; E = { if ($_.NetworkSwitch) { $_.NetworkSwitch -join ("`r") } } } `
    | export-excel -path $XLOutputFile -WorksheetName "vmHostExport" -autosize -append

    Write-Progress -Activity $Completed"%" -Status $VMHost -PercentComplete $Completed
    $ProgressCount++
}

$XLNotes = Import-CSV -Path ".\notes.csv"
ForEach ($XLNote in $XLNotes) {
    if ($XLNote.target -eq "2") {
        $OutputObject = New-Object -TypeName PSObject
        $OutputObject | Add-Member -Name "Field" -MemberType NoteProperty -value $XLNote.field
        $OutputObject | Add-Member -Name "Description" -MemberType NoteProperty -value $XLNote.description
        $OutputObject | Add-Member -Name "Datatype" -MemberType NoteProperty -value $XLNote.datatype
        $OutputObject | Add-Member -Name "Origin" -MemberType NoteProperty -value $XLNote.origin
        $OutputObject | Add-Member -Name "Notes" -MemberType NoteProperty -value $XLNote.notes
        $OutputObject | Add-Member -Name "Code" -MemberType NoteProperty -value $XLNote.Code
        $OutputObject | Add-Member -Name "Todo" -MemberType NoteProperty -value $XLNote.Todo
        $OutputObject | export-excel -path $XLOutputFile -WorksheetName "Notes" -autosize -append
    }
}

$exportXL = Export-Excel -Path $XLOutputFile -WorksheetName "vmHostExport" -FreezeTopRowFirstColumn -autofilter -titlebold -autosize -PassThru
$exportWS = $exportXL.vmHostExport
Set-Format $exportWS.workbook.worksheets['vmHostExport'].cells -WrapText
21 | Set-ExcelColumn -Worksheet $exportWS.workbook.worksheets['vmHostExport'] -HorizontalAlignment "Right"
Close-ExcelPackage $exportXL

$exportXL = Export-Excel -Path $XLOutputFile -WorksheetName "Notes" -FreezeTopRowFirstColumn -autofilter -titlebold -autosize -PassThru
Close-ExcelPackage $exportXL

Write-Progress -Activity "Export Progress:" -Status "Ready" -Completed

Disconnect-VIServer -Server * -Confirm:$false
