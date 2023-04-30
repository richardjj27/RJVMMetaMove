# RJVMMetaMove

The project contains three scripts and one module containing four functions.

## *ExportHosts.ps1*
Create a report in Excel for all VM hosts from multiple vCenter servers as listed in VCList.csv.

- XLOutputFile - Name and location of output file.
- VCenterList - List of vCenter servers to be processed.

## *ExportVMs.ps1*
Create a report in Excel for all VM guests from multiple vCenter servers as listed in VCList.csv.

- XLOutputFile - Name and location of output file.
- VCenterList - List of vCenter servers to be processed.

## *MigrateVMs.ps1*
Migrate a list of VMs from one cluster to another (including cross vCenter) preserving tags and custom attributes.

- LogFile - Output log file.
- VCenterList - List of vCenter servers to be processed.
1. Servers

- VMListFile - CSV list of VMs to be moved .
1. SourceVM
2. TargetVMHost
3. TargetNetwork
4. TargetDatastore

## *RJVMMetaDataMove.psm1*
### Get-RJVMMetaData
Get multiple useful attributes and settings for the specified VM.
- An explanation for each attribute is included in the notes tab of the output of ExportVMs.ps1 - todo

### *Get-RJVMHostData*
Get multiple useful attributes and settings for the specified VM host.
- An explanation for each attribute is included in the notes tab of the output of ExportHosts.ps1 - todo.

### *Set-RJVMCustomAttributes*
Set custom attributes for a specific VM derived from previous Get-RJVMMetaData.

### Write-RJLog
Write timed, formated log text to a specified log file.
