# RJVMMetaMove

The project contains three scripts and one module containing four functions.

## *ExportHosts.ps1*
Create a report in Excel for all VM hosts from multiple vCenter servers as listed in VCList.csv.

- `$XLOutputFile` - Name and location of output file.
- `$VCenterList` - List of vCenter servers to be processed.

## *ExportVMs.ps1*
Create a report in Excel for all VM guests from multiple vCenter servers as listed in VCList.csv.

- `$XLOutputFile` - Name and location of output file.
- `$VCenterList` - List of vCenter servers to be processed.

## *MigrateVMs.ps1*
Migrate a list of VMs from one cluster to another (including cross vCenter) preserving tags and custom attributes.

- `$LogFile` - Output log file.
- `$VCenterList` - List of vCenter servers to be processed. (Servers)
- `$VMListFile` - CSV list of VMs to be moved. (SourceVM,TargetVMHost,TargetNetwork,TargetDatastore)

## *RJVMMetaDataMove.psm1*
### *Get-RJVMMetaData*
Get multiple useful attributes and settings for the specified VM.
- An explanation for each attribute is included in the notes tab of the output of ExportVMs.ps1 - todo.

### *Get-RJVMHostData*
Get multiple useful attributes and settings for the specified VM host.
- An explanation for each attribute is included in the notes tab of the output of ExportHosts.ps1 - todo.

### *Set-RJVMCustomAttributes*
Set custom attributes for a specific VM derived from previous Get-RJVMMetaData.

### *Write-RJLog*
`LogFile, Severity, LogText`
Write timed, formatted log text to the file specified in $LogFile.
