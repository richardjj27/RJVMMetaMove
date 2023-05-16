# Script to Export all VM Guests on multiple vCenter Servers to an Excel file.

Import-Module -Name Vmware.PowerCli
Import-Module -Name ImportExcel
Remove-Module RJVMMetaMove
Import-Module .\RJVMMetaMove.psm1

$WorkingFolder = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\Richard\RJVMMetaMove"

$ExportFolder = $WorkingFolder + "\Exports"
$XLOutputFile = $ExportFolder + "\vmGuestExport $(Get-Date -Format "yyyy-MM-dd_HH.mm").xlsx"
$VCenterList = $WorkingFolder + "\VCList.csv"
$XLOutputs = Import-CSV -Path ".\ExcelOutput.csv"
$XLOutputs = $XLOutputs | Sort-Object -Property { [int]$_.Column }
$VMGuests = $Null

If (!(Test-Path -Path $WorkingFolder)) {
    Write-Host "$WorkingFolder Does not exist. Terminating."
    exit
}

If (!(Test-Path -Path $ExportFolder)) {
    New-Item -Path $ExportFolder -ItemType Directory | Out-Null
}

# Only ask for credentials if they aren't already in memory.
if (!($AdminCredentials)) {
    $AdminCredentials = Get-Credential
}

$VCenters = Import-CSV -Path $VCenterList
ForEach ($VCenter in $VCenters) {
    if ($VCenter.Server.SubString(0, 1) -ne "#") {
        Connect-VIServer -Server $VCenter.Server -Credential $AdminCredentials | Out-Null
        # $VMHosts += get-VMHost -Server $VCenter.Server
        $VMGuests += Get-VM -Server $VCenter.Server
    }
}

# $VMGuests = $VMGuests | Get-Random -Count 10 # Limit results to a small number of servers for testing.
Write-Host "Processing"$VMGuests.count"VM Guests."
$VMGuests = $VMGuests | Sort-Object -property VMHost, Name

$ObjectOrder = @()
ForEach ($XLOutput in $XLOutputs) {
    
    if ($XLOutput.target -eq "1" -and $XLOutput.Column) {
        $ObjectOrder += $XLOutput.Field
        $ObjectFormat += $XLOutput.Format
    }
}

$ProgressCount = 0
ForEach ($VMGuest in $VMGuests) {
    $Completed = ('{0:d2}' -f [int]((($ProgressCount / $VMGuests.count) * 100)))
    $Output = Get-RJVMMetaData -VMName $VMGuest | select-object -Property $ObjectOrder
    
    $Output.AttributeName = $Output.AttributeName -join ("`r")
    $Output.AttributeValue = $Output.AttributeValue -join ("`r")
    $Output.AttributeTag = $Output.AttributeTag -join ("`r")
    $Output.NetworkAdapter = $Output.NetworkAdapter -join ("`r")
    $Output.DiskName = $Output.DiskName -join ("`r")
    $Output.DiskID = $Output.DiskID -join ("`r")
    $Output.DiskFilename = $Output.DiskFilename -join ("`r")
    $Output.DiskStoragePolicy = $Output.DiskStoragePolicy -join ("`r")
    $Output.DiskLayoutStorageFormat = $Output.DiskLayoutStorageFormat -join ("`r")
    $Output.DiskLayoutPersistence = $Output.DiskLayoutPersistence -join ("`r")
    $Output.DiskLayoutDiskType = $Output.DiskLayoutDiskType -join ("`r")
    $Output.DiskSizeGB = $Output.DiskSizeGB -join ("`r")
    $Output.LocalHardDisksPath = $Output.LocalHardDisksPath -join ("`r")
    $Output.LocalHardDisksCapacityGB = $Output.LocalHardDisksCapacityGB -join ("`r")
    $Output.LocalHardDisksFreespaceGB = $Output.LocalHardDisksFreespaceGB -join ("`r")
    $Output.DiskDatastore = $Output.DiskDatastore -join ("`r")
    $Output.Snapshot = $Output.Snapshot -join ("`r")
    


    $Output | export-excel -path $XLOutputFile -WorksheetName "vmGuestExport" -autosize -append

    Write-Progress -Activity $Completed"%" -Status $VMGuest -PercentComplete $Completed
    $ProgressCount++
}

ForEach ($XLOutput in $XLOutputs) {
    if ($XLOutput.target -eq "1") {
        $OutputObject = New-Object -TypeName PSObject
        $OutputObject | Add-Member -Name "Field" -MemberType NoteProperty -value $XLOutput.field
        $OutputObject | Add-Member -Name "Description" -MemberType NoteProperty -value $XLOutput.description
        $OutputObject | Add-Member -Name "Datatype" -MemberType NoteProperty -value $XLOutput.datatype
        $OutputObject | Add-Member -Name "Origin" -MemberType NoteProperty -value $XLOutput.origin
        $OutputObject | Add-Member -Name "Notes" -MemberType NoteProperty -value $XLOutput.notes
        $OutputObject | Add-Member -Name "Code" -MemberType NoteProperty -value $XLOutput.Code
        $OutputObject | Add-Member -Name "Todo" -MemberType NoteProperty -value $XLOutput.Todo
        $OutputObject | export-excel -path $XLOutputFile -WorksheetName "Notes" -autosize -append
    }
}

$ExportXL = Open-ExcelPackage -path $XLOutputFile
ForEach ($XLOutput in $XLOutputs) {
    if ($XLOutput.target -eq "1") {
        If ($XLOutput.Format.ToUpper().contains("R")) {Set-ExcelColumn -Worksheet $exportXL.Workbook.Worksheets['vmGuestExport'] -Column $XLOutput.Column -HorizontalAlignment "Right"} # Format / Right
        If ($XLOutput.Format.ToUpper().contains("L")) {Set-ExcelColumn -Worksheet $exportXL.Workbook.Worksheets['vmGuestExport'] -Column $XLOutput.Column -HorizontalAlignment "Left"} # Format / } # Format / Left
        If ($XLOutput.Format.ToUpper().contains("D")) {Set-ExcelColumn -worksheet $exportXL.Workbook.Worksheets['vmGuestExport'] -Column $XLOutput.Column -NumberFormat 'Short Date'} # Format / Date
        If ($XLOutput.Format.ToUpper().contains("T")) {Set-ExcelColumn -Worksheet $exportXL.Workbook.Worksheets['vmGuestExport'] -Column $XLOutput.Column -NumberFormat "#,###.00"} # Format / 2 digit number
        If ($XLOutput.Format.ToUpper().contains("I")) {Set-ExcelColumn -Worksheet $exportXL.Workbook.Worksheets['vmGuestExport'] -Column $XLOutput.Column -NumberFormat "#,###"} # Format / Integer
    }
}

Close-ExcelPackage -excelpackage $ExportXL

$ExportXL = Export-Excel -Path $XLOutputFile -WorksheetName "vmGuestExport" -FreezeTopRowFirstColumn -autofilter -titlebold -autosize -PassThru
Close-ExcelPackage $exportXL

$ExportXL = Export-Excel -Path $XLOutputFile -WorksheetName "Notes" -FreezeTopRowFirstColumn -autofilter -titlebold -autosize -PassThru
Close-ExcelPackage $exportXL

$ExportXL = Open-ExcelPackage -path $XLOutputFile
Set-Format $ExportXL.Workbook.Worksheets['vmGuestExport'].cells -WrapText
Close-ExcelPackage -excelpackage $ExportXL

Write-Progress -Activity "Export Progress:" -Status "Ready" -Completed

Disconnect-VIServer -Server * -Confirm:$false
