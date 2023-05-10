# Script to Export all VM Guests on multiple vCenter Servers to an Excel file.

Import-Module -Name vmware.powercli
Import-Module -Name ImportExcel
Remove-Module RJVMMetaMove
Import-Module .\RJVMMetaMove.psm1

$XLOutputFile = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\Richard\RJVMMetaMove\Exports\vmGuestExport $(Get-date -Format "yyyy-MM-dd_HH.mm").xlsx"
$VCenterList = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\Richard\RJVMMetaMove\VCList.csv"
$VMGuests = $Null

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

$VMGuests = $VMGuests | Get-Random -Count 4 # Limit results to a small number of servers for testing.
write-host "Processing"$VMGuests.count"VM Guests."
$VMGuests = $VMGuests | Sort-Object -property VMHost, Name

$XLFormats = Import-CSV -Path ".\ExcelFormat.csv"
$XLFormats = $XLFormats | sort-object -Property { [int]$_.Column }
$ObjectOrder = @()
ForEach ($XLFormat in $XLFormats) {
    
    if ($XLFormat.target -eq "1" -and $XLFormat.Column) {
        $ObjectOrder += $XLFormat.Field
        $ObjectFormat += $XLFormat.Format
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
    

    # @{N = 'AttributeName'; E = { if ($_.AttributeName) { $_.AttributeName -join ("`r") } } }, #22
    # @{N = 'AttributeValue'; E = { if ($_.AttributeValue) { $_.AttributeValue -join ("`r") } } }, #23
    # @{N = 'AttributeTag'; E = { if ($_.AttributeTag) { $_.AttributeTag -join ("`r") } } }, #24
    # @{N = 'Network'; E = { if ($_.NetworkAdapter) { $_.NetworkAdapter -join ("`r") } } }, #25
    # @{N = 'DiskName'; E = { if ($_.DiskName) { $_.DiskName -join ("`r") } } }, #26
    # @{N = 'DiskID'; E = { if ($_.DiskID) { $_.DiskID -join ("`r") } } }, #27
    # @{N = 'DiskFileName'; E = { if ($_.DiskFileName) { $_.DiskFileName -join ("`r") } } }, #28
    # @{N = 'DiskStoragePolicy'; E = { if ($_.DiskStoragePolicy) { $_.DiskStoragePolicy -join ("`r") } } }, #29
    # @{N = 'DiskLayoutStorageFormat'; E = { if ($_.DiskLayoutStorageFormat) { $_.DiskLayoutStorageFormat -join ("`r") } } }, #30
    # @{N = 'DiskLayoutPersistence'; E = { $_.DiskLayoutPersistence -join ("`r") } }, #31
    # @{N = 'DiskLayoutDiskType'; E = { if ($_.DiskLayoutDiskType) { $_.DiskLayoutDiskType -join ("`r") } } }, #32
    # @{N = 'DiskSizeGB'; E = { if ($_.DiskSizeGB) { $_.DiskSizeGB -join ("`r") } } }, #33 R
    # TotalDiskSizeGB, #34 N
    # @{N = 'LocalHardDisksPath'; E = { if ($_.LocalHardDisksPath) { $_.LocalHardDisksPath -join ("`r") } } }, #35
    # @{N = 'LocalHardDisksCapacityGB'; E = { if ($_.LocalHardDisksCapacityGB) { $_.LocalHardDisksCapacityGB -join ("`r") } } }, #36 R
    # @{N = 'LocalHardDisksFreespaceGB'; E = { if ($_.LocalHardDisksFreespaceGB) { $_.LocalHardDisksFreespaceGB -join ("`r") } } }, #37 R
    # LocalHardDiskTotalGB, #38 N
    # @{N = 'DiskDatastore'; E = { if ($_.DiskDatastore) { $_.DiskDatastore -join ("`r") } } }, #39
    # @{N = 'Snapshot'; E = { if ($_.Snapshot) { $_.Snapshot -join ("`r") } } } ` #40
    
    
    $Output | export-excel -path $XLOutputFile -WorksheetName "vmGuestExport" -autosize -append

    Write-Progress -Activity $Completed"%" -Status $VMGuest -PercentComplete $Completed
    $ProgressCount++
}

#$XLFormats = Import-CSV -Path ".\ExcelFormat.csv"
ForEach ($XLFormat in $XLFormats) {
    if ($XLFormat.target -eq "1") {
        $OutputObject = New-Object -TypeName PSObject
        $OutputObject | Add-Member -Name "Field" -MemberType NoteProperty -value $XLFormat.field
        $OutputObject | Add-Member -Name "Description" -MemberType NoteProperty -value $XLFormat.description
        $OutputObject | Add-Member -Name "Datatype" -MemberType NoteProperty -value $XLFormat.datatype
        $OutputObject | Add-Member -Name "Origin" -MemberType NoteProperty -value $XLFormat.origin
        $OutputObject | Add-Member -Name "Notes" -MemberType NoteProperty -value $XLFormat.notes
        $OutputObject | Add-Member -Name "Code" -MemberType NoteProperty -value $XLFormat.Code
        $OutputObject | Add-Member -Name "Todo" -MemberType NoteProperty -value $XLFormat.Todo
        $OutputObject | export-excel -path $XLOutputFile -WorksheetName "Notes" -autosize -append
    }
}

$ExportXL = Open-ExcelPackage -path $XLOutputFile
ForEach ($XLFormat in $XLFormats) {
    if ($XLFormat.target -eq "1") {
        # write-host $XLFormat.Format.toupper()

        # Need to get the column index.
        If ($XLFormat.Format.ToUpper().contains("R")) {Set-ExcelColumn -Worksheet $exportXL.workbook.worksheets['vmGuestExport'] -Column $XLFormat.Column -HorizontalAlignment "Right"} # Format / Right
        If ($XLFormat.Format.ToUpper().contains("L")) {Set-ExcelColumn -Worksheet $exportXL.workbook.worksheets['vmGuestExport'] -Column $XLFormat.Column -HorizontalAlignment "Left"} # Format / } # Format / Left
        If ($XLFormat.Format.ToUpper().contains("D")) {Set-ExcelColumn -worksheet $exportXL.Workbook.Worksheets['vmGuestExport'] -Column $XLFormat.Column -NumberFormat 'Short Date'} # Format / Date
        If ($XLFormat.Format.ToUpper().contains("T")) {Set-ExcelColumn -Worksheet $exportXL.workbook.worksheets['vmGuestExport'] -Column $XLFormat.Column -NumberFormat "#,###.00"} # Format / 2 digit number
        If ($XLFormat.Format.ToUpper().contains("I")) {Set-ExcelColumn -Worksheet $exportXL.workbook.worksheets['vmGuestExport'] -Column $XLFormat.Column -NumberFormat "#,###"} # Format / Integer
    }
}

Close-ExcelPackage -excelpackage $ExportXL

$ExportXL = Export-Excel -Path $XLOutputFile -WorksheetName "vmGuestExport" -FreezeTopRowFirstColumn -autofilter -titlebold -autosize -PassThru
Close-ExcelPackage $exportXL

$ExportXL = Export-Excel -Path $XLOutputFile -WorksheetName "Notes" -FreezeTopRowFirstColumn -autofilter -titlebold -autosize -PassThru
Close-ExcelPackage $exportXL

$ExportXL = Open-ExcelPackage -path $XLOutputFile
Set-Format $ExportXL.workbook.worksheets['vmGuestExport'].cells -WrapText
Close-ExcelPackage -excelpackage $ExportXL




# $ExportXL = Export-Excel -Path $XLOutputFile -WorksheetName "vmGuestExport" -FreezeTopRowFirstColumn -autofilter -titlebold -autosize -PassThru
# $exportWS = $exportXL.vmGuestExport
# Set-Format $exportWS.workbook.worksheets['vmGuestExport'].cells -WrapText
# 8..9 | Set-ExcelColumn -Worksheet $exportWS.workbook.worksheets['vmGuestExport'] -NumberFormat "#,###.00"
# 34 | Set-ExcelColumn -Worksheet $exportWS.workbook.worksheets['vmGuestExport'] -NumberFormat "#,###.00"
# 38 | Set-ExcelColumn -Worksheet $exportWS.workbook.worksheets['vmGuestExport'] -NumberFormat "#,###.00"
# 12 | Set-ExcelColumn -Worksheet $exportWS.workbook.worksheets['vmGuestExport'] -NumberFormat "Short Date"
# 33 | Set-ExcelColumn -Worksheet $exportWS.workbook.worksheets['vmGuestExport'] -HorizontalAlignment "Right"
# 36..37 | Set-ExcelColumn -Worksheet $exportWS.workbook.worksheets['vmGuestExport'] -HorizontalAlignment "Right"
# Close-ExcelPackage $exportXL
# $exportXL = Export-Excel -Path $XLOutputFile -WorksheetName "Notes" -FreezeTopRowFirstColumn -autofilter -titlebold -autosize -PassThru
# Close-ExcelPackage $exportXL




Write-Progress -Activity "Export Progress:" -Status "Ready" -Completed

Disconnect-VIServer -Server * -Confirm:$false
