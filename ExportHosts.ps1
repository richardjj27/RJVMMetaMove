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

$VMHosts = $VMHosts | Get-Random -Count 5 # Limit results to a small number of servers for testing.
Write-Host "Processing"$VMHosts.count"VM Hosts."
$VMHosts = $VMHosts | sort-object -property Name

# read notes file for properties to display
# if its an array, do the 'r thing.


$XLNotes = Import-CSV -Path ".\notes.csv"
$XLNotes = $XLNotes |sort-object -Property { [int]$_.Column }
$ObjectOrder = @()
ForEach ($XLNote in $XLNotes) {
    
    if ($XLNote.target -eq "2" -and $XLNote.Column) {
        $ObjectOrder += $XLNote.Field
        $ObjectFormat += $XLNote.Format
    }
}

#$ObjectOrder = $ObjectOrder -replace ".{2}$"

#write-host $ObjectOrder

$ProgressCount = 0
ForEach ($VMHost in $VMHosts) {
    $Completed = ('{0:d2}' -f [int]((($ProgressCount / $VMHosts.count) * 100)))
    $Output = Get-RJVMHostData -VMHost $VMHost | Select-Object -Property $ObjectOrder
    $Output.DatastoreName = $Output.DatastoreName -join ("`r")
    $Output.DatastoreType = $Output.DatastoreType -join ("`r")
    $Output.DatastoreCapacityGB = $Output.DatastoreCapacityGB -join ("`r")
    $Output.Network = $Output.Network -join ("`r")
    $Output.NetworkSwitch = $Output.NetworkSwitch -join ("`r")
    $Output | export-excel -path $XLOutputFile -WorksheetName "vmHostExport" -autosize -append

    Write-Progress -Activity $Completed"%" -Status $VMHost -PercentComplete $Completed
    $ProgressCount++
}

# This section needs a bit of a rewrite to include cell formatting logic too.

$XLNotes = Import-CSV -Path ".\Notes.csv"

exit

$ExportXL = Open-ExcelPackage -path $XLOutputFile

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

        write-host $xlnote.Format.toupper()

        # Need to get the column index.
        If ($XLNote.Format.ToUpper().contains("R")) {Set-ExcelColumn -Worksheet $exportXL.workbook.worksheets['vmHostExport'] -Column 1 -HorizontalAlignment "Right"} # Format / Right
        If ($XLNote.Format.ToUpper().contains("L")) {Set-ExcelColumn -Worksheet $exportXL.workbook.worksheets['vmHostExport'] -Column 1 -HorizontalAlignment "Left"} # Format / } # Format / Left
        If ($XLNote.Format.ToUpper().contains("D")) {Set-ExcelColumn -worksheet $exportXL.Workbook.Worksheets['vmHostExport'] -Column 1 -NumberFormat 'Short Date'} # Format / Date
        If ($XLNote.Format.ToUpper().contains("T")) {Set-ExcelColumn -Worksheet $exportXL.workbook.worksheets['vmHostExport'] -Column 1 -NumberFormat "#,###.00"} # Format / 2 digit number
        If ($XLNote.Format.ToUpper().contains("I")) {Set-ExcelColumn -Worksheet $exportXL.workbook.worksheets['vmHostExport'] -Column 1 -NumberFormat "#,###"} # Format / Integer
    }
}

Close-ExcelPackage -excelpackage $exportXL

$ExportXL = Open-ExcelPackage -path $XLOutputFile
Set-Format $exportXL.workbook.worksheets['vmHostExport'].cells -WrapText
Close-ExcelPackage -excelpackage $exportXL

$exportXL = Export-Excel -Path $XLOutputFile -WorksheetName "vmHostExport" -FreezeTopRowFirstColumn -autofilter -titlebold -autosize -PassThru
Close-ExcelPackage $exportXL

$exportXL = Export-Excel -Path $XLOutputFile -WorksheetName "Notes" -FreezeTopRowFirstColumn -autofilter -titlebold -autosize -PassThru
Close-ExcelPackage $exportXL


# Set-ExcelColumn -worksheet $exportXL.Workbook.Worksheets['vmHostExport'] -column 14 -numberformat 'Short Date'
# 1 | Set-ExcelColumn -Worksheet $exportXL.workbook.worksheets['vmHostExport'] -HorizontalAlignment "Right"


Write-Progress -Activity "Export Progress:" -Status "Ready" -Completed

Disconnect-VIServer -Server * -Confirm:$false
