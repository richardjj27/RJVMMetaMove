# Temporary script to play around with additional tabs and text in an Excel file.
import-Module -Name ImportExcel

$XLOutputFile = ".\text.xlsx"
Remove-item $XLOutputFile

get-childitem "." | export-excel -path $XLOutputFile -WorksheetName "vmHostExport" -autosize -append


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

$exportXL = Export-Excel -Path $XLOutputFile -WorksheetName "vmHostExport" -FreezeTopRowFirstColumn -autofilter -titlebold -autosize -PassThru
$exportXL = Export-Excel -Path $XLOutputFile -WorksheetName "Notes" -FreezeTopRowFirstColumn -autofilter -titlebold -autosize -PassThru
$exportWS = $exportXL.vmHostExport
Set-Format $exportWS.workbook.worksheets['vmHostExport'].cells -WrapText
Close-ExcelPackage $exportXL