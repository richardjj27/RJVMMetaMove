# Script to Export all VM Hosts on multiple vCenter Servers to an Excel file.

Import-Module -Name Vmware.PowerCli
Import-Module -Name ImportExcel
Remove-Module RJVMMetaMove
Import-Module .\RJVMMetaMove.psm1

$WorkingFolder = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\Richard\RJVMMetaMove"

$ExportFolder = $WorkingFolder + "\Exports"
$XLOutputFile = $ExportFolder + "\vmHostExport $(Get-Date -Format "yyyy-MM-dd_HH.mm").xlsx"
$VCenterList = $WorkingFolder + "\VCList.csv"
$XLOutputs = Import-CSV -Path ".\ExcelOutput.csv"
$XLOutputs = $XLOutputs | Sort-Object -Property { [int]$_.Column }
$VMHosts = $Null

If (!(Test-Path -Path $WorkingFolder)) {
    Write-Host "$WorkingFolder Does not exist. Terminating."
    exit
}

If (!(Test-Path -Path $ExportFolder)) {
    New-Item -Path $ExportFolder -ItemType Directory | Out-Null
}

# Only ask for credentials if they aren't already in memory.
If (!($AdminCredentials)) {
    $AdminCredentials = Get-Credential
}

$VCenters = Import-CSV -Path $VCenterList
ForEach ($VCenter in $VCenters) {
    If ($VCenter.Server.SubString(0, 1) -ne "#") {
        Connect-VIServer -Server $VCenter.Server -Credential $AdminCredentials | Out-Null
        $VMHosts += Get-VMHost -Server $VCenter.Server
        # $VMGuests += Get-VM -Server $VCenter.Server
    }
}

# $VMHosts = $VMHosts | Get-Random -Count 10 # Limit results to a small number of servers for testing.
Write-Host "Processing"$VMHosts.count"VM Hosts."
$VMHosts = $VMHosts | Sort-Object -Property Name

$ObjectOrder = @()
ForEach ($XLOutput in $XLOutputs) {
    
    If ($XLOutput.target -eq "2" -and $XLOutput.Column) {
        $ObjectOrder += $XLOutput.Field
        $ObjectFormat += $XLOutput.Format
    }
}

$ProgressCount = 0
ForEach ($VMHost in $VMHosts) {
    $Completed = ('{0:d2}' -f [int]((($ProgressCount / $VMHosts.Count) * 100)))
    $Output = Get-RJVMHostData -VMHost $VMHost | Select-Object -Property $ObjectOrder
    $Output.DatastoreName = $Output.DatastoreName -Join ("`r")
    $Output.DatastoreType = $Output.DatastoreType -Join ("`r")
    $Output.DatastoreCapacityGB = $Output.DatastoreCapacityGB -Join ("`r")
    $Output.NetworkAdapter = $Output.Network.Adapter -Join ("`r")
    $Output.NetworkSwitch = $Output.NetworkSwitch -Join ("`r")
    $Output | Export-Excel -Path $XLOutputFile -WorksheetName "vmHostExport" -Autosize -Append

    Write-Progress -Activity $Completed"%" -Status $VMHost -PercentComplete $Completed
    $ProgressCount++
}

ForEach ($XLOutput in $XLOutputs) {
    If ($XLOutput.target -eq "2") {
        $OutputObject = New-Object -TypeName PSObject
        $OutputObject | Add-Member -Name "Field" -MemberType NoteProperty -value $XLOutput.Field
        $OutputObject | Add-Member -Name "Description" -MemberType NoteProperty -value $XLOutput.Description
        $OutputObject | Add-Member -Name "Datatype" -MemberType NoteProperty -value $XLOutput.Datatype
        $OutputObject | Add-Member -Name "Origin" -MemberType NoteProperty -value $XLOutput.Origin
        $OutputObject | Add-Member -Name "Notes" -MemberType NoteProperty -value $XLOutput.Notes
        $OutputObject | Add-Member -Name "Code" -MemberType NoteProperty -value $XLOutput.Code
        $OutputObject | Add-Member -Name "Todo" -MemberType NoteProperty -value $XLOutput.Todo
        $OutputObject | Export-Excel -path $XLOutputFile -WorksheetName "Notes" -Autosize -Append
    }
}

$ExportXL = Open-ExcelPackage -path $XLOutputFile
ForEach ($XLOutput in $XLOutputs) {
    If ($XLOutput.target -eq "2") {
        If ($XLOutput.Format.ToUpper().contains("R")) {Set-ExcelColumn -Worksheet $exportXL.Workbook.Worksheets['vmHostExport'] -Column $XLOutput.Column -HorizontalAlignment "Right"} # Format / Right
        If ($XLOutput.Format.ToUpper().contains("L")) {Set-ExcelColumn -Worksheet $exportXL.Workbook.Worksheets['vmHostExport'] -Column $XLOutput.Column -HorizontalAlignment "Left"} # Format / } # Format / Left
        If ($XLOutput.Format.ToUpper().contains("D")) {Set-ExcelColumn -worksheet $exportXL.Workbook.Worksheets['vmHostExport'] -Column $XLOutput.Column -NumberFormat 'Short Date'} # Format / Date
        If ($XLOutput.Format.ToUpper().contains("T")) {Set-ExcelColumn -Worksheet $exportXL.Workbook.Worksheets['vmHostExport'] -Column $XLOutput.Column -NumberFormat "#,###.00"} # Format / 2 digit number
        If ($XLOutput.Format.ToUpper().contains("I")) {Set-ExcelColumn -Worksheet $exportXL.Workbook.Worksheets['vmHostExport'] -Column $XLOutput.Column -NumberFormat "#,###"} # Format / Integer
    }
}

Close-ExcelPackage -ExcelPackage $ExportXL

$ExportXL = Export-Excel -Path $XLOutputFile -WorksheetName "vmHostExport" -FreezeTopRowFirstColumn -Autofilter -Titlebold -Autosize -Passthru
Close-ExcelPackage $ExportXL

$ExportXL = Export-Excel -Path $XLOutputFile -WorksheetName "Notes" -FreezeTopRowFirstColumn -Autofilter -Titlebold -Autosize -Passthru
Close-ExcelPackage $ExportXL

$ExportXL = Open-ExcelPackage -path $XLOutputFile
Set-Format $exportXL.Workbook.Worksheets['vmHostExport'].Cells -WrapText
Close-ExcelPackage -ExcelPackage $ExportXL

Write-Progress -Activity "Export Progress:" -Status "Ready" -Completed

Disconnect-VIServer -Server * -Confirm:$False
