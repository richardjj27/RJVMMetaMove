# Script to Export all VM Guests on multiple vCenter Servers to an Excel file.

Import-Module -Name vmware.powercli
Import-Module -Name ImportExcel
Remove-Module RJVMMetaMove
Import-Module .\RJVMMetaMove.psm1

$XLOutputFile = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\Richard\vCenterExport\Exports\vmGuestExport $(Get-date -Format "yyyy-MM-dd_HH.mm").xlsx"
$VCenterList = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\Richard\vCenterExport\VCList.csv"

$AdminCredentials = Get-Credential

$VCenters = Import-CSV -Path $VCenterList
$VMGuests = $null
ForEach($VCenter in $Vcenters){
    if($VCenter.Server.SubString(0,1) -ne "#") {
        $VC = Connect-VIServer -Server $VCenter.Server -Credential $AdminCredentials | Out-Null
        # $VMHosts += get-VMHost -Server $VC
        $VMGuests += Get-VM -Server $VC 
    }
}

$VMGuests = $VMGuests | Get-Random -Count 10 # Limit results to a small number of servers for testing.
write-host "Processing"$VMGuests.count"VM Guests."
$VMGuests = $VMGuests | Sort-Object -property VMHost,Name

$ProgressCount = 0
foreach ($VMGuest in $VMGuests){
    $completed = [math]::Round((($ProgressCount/$VMGuests.count) * 100), 2)
    Get-RJVMMetaData -VMName $VMGuest | select-object -ExcludeProperty AttributeName,AttributeValue,AttributeTag,NetworkAdaper,DiskName,DiskStoragePolicy,DiskID,DiskFileName,DiskLayoutStorageFormat,DiskLayoutPersistence,DiskLayoutDiskType,DiskSizeGB,DiskDatastore,Snapshot `
    -Property `
        Name, `
        ID, `
        HostName, `
        Powerstate, `
        Version, `
        MemoryGB, `
        CPUCores, `
        TotalDiskSizeGB, `
        UsedSpaceGB, `
        ProvisionedSpaceGB, `
        ToolsVersion, `
        GuestFullName, `
        CreateDate, `
        vCenter, `
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
        | export-excel -path $XLOutputFile -WorksheetName "vmGuestExport" -autosize -append

    Write-Progress -Activity "Export Progress:" -Status "$completed% completed." -PercentComplete $completed
    $ProgressCount++
}

$XLNotes = Import-CSV -Path ".\notes.csv"
ForEach($XLNote in $XLNotes){
    if($XLNote.target -eq "1") {
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

$exportXL = Export-Excel -Path $XLOutputFile -WorksheetName "vmGuestExport" -FreezeTopRowFirstColumn -autofilter -titlebold -autosize -PassThru
$exportWS = $exportXL.vmGuestExport
Set-Format $exportWS.workbook.worksheets['vmGuestExport'].cells -WrapText
Close-ExcelPackage $exportXL

$exportXL = Export-Excel -Path $XLOutputFile -WorksheetName "Notes" -FreezeTopRowFirstColumn -autofilter -titlebold -autosize -PassThru
Close-ExcelPackage $exportXL

Write-Progress -Activity "Export Progress:" -Status "Ready" -Completed

Disconnect-VIServer -Server * -Confirm:$false
