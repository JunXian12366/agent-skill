param(
    [Parameter(Mandatory = $true)][string]$Left,
    [Parameter(Mandatory = $true)][string]$Right,
    [string]$Sheet,
    [string]$Delimiter = "`t",
    [switch]$IgnoreCase,
    [switch]$TrimWhitespace,
    [switch]$IgnoreBlankLines,
    [double]$NumericTolerance = 0,
    [int]$MaxDiffs = 200
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Read-ZipEntryXml($zip, $name) {
    $entry = $zip.GetEntry($name)
    if ($null -eq $entry) { return $null }
    $reader = New-Object System.IO.StreamReader($entry.Open())
    try { $doc = New-Object System.Xml.XmlDocument; $doc.LoadXml($reader.ReadToEnd()); return $doc }
    finally { $reader.Dispose() }
}

function ConvertTo-ColumnIndex([string]$letters) {
    $n = 0
    foreach ($c in $letters.ToCharArray()) { $n = $n * 26 + ([int][char]$c - [int][char]'A' + 1) }
    return $n
}

function Read-XlsxSheets([string]$path) {
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $path).Path)
    try {
        $shared = New-Object System.Collections.Generic.List[string]
        $ssDoc = Read-ZipEntryXml $zip 'xl/sharedStrings.xml'
        if ($ssDoc) {
            foreach ($si in $ssDoc.GetElementsByTagName('si')) {
                $sb = New-Object System.Text.StringBuilder
                foreach ($t in $si.GetElementsByTagName('t')) { [void]$sb.Append($t.InnerText) }
                $shared.Add($sb.ToString())
            }
        }
        $wb = Read-ZipEntryXml $zip 'xl/workbook.xml'
        $rels = Read-ZipEntryXml $zip 'xl/_rels/workbook.xml.rels'
        $relMap = @{}
        foreach ($r in $rels.GetElementsByTagName('Relationship')) { $relMap[$r.GetAttribute('Id')] = $r.GetAttribute('Target') }
        $result = [ordered]@{}
        foreach ($s in $wb.GetElementsByTagName('sheet')) {
            $name = $s.GetAttribute('name')
            $rid = $s.GetAttribute('id', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
            $target = $relMap[$rid].TrimStart('/')
            if (-not $target.StartsWith('xl/')) { $target = "xl/$target" }
            $doc = Read-ZipEntryXml $zip $target
            $cells = @{}
            foreach ($c in $doc.GetElementsByTagName('c')) {
                $ref = $c.GetAttribute('r')
                $type = $c.GetAttribute('t')
                $vNode = $c.GetElementsByTagName('v') | Select-Object -First 1
                $value = $null
                if ($type -eq 'inlineStr') {
                    $value = -join ($c.GetElementsByTagName('t') | ForEach-Object { $_.InnerText })
                }
                elseif ($vNode) {
                    $value = $vNode.InnerText
                    if ($type -eq 's') { $value = $shared[[int]$value] }
                }
                if ($null -ne $value -and $value -ne '') { $cells[$ref] = $value }
            }
            $result[$name] = $cells
        }
        return $result
    }
    finally { $zip.Dispose() }
}

function Format-Value($v) {
    if ($null -eq $v) { return '' }
    $s = [string]$v
    if ($TrimWhitespace) { $s = $s.Trim() }
    if ($IgnoreCase) { $s = $s.ToLowerInvariant() }
    return $s
}

function Test-ValueEqual($a, $b) {
    $x = Format-Value $a
    $y = Format-Value $b
    if ($x -ceq $y) { return $true }
    $dx = 0.0; $dy = 0.0
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    if ([double]::TryParse($x, 'Float', $inv, [ref]$dx) -and [double]::TryParse($y, 'Float', $inv, [ref]$dy)) {
        return [math]::Abs($dx - $dy) -le $NumericTolerance
    }
    return $false
}

function Split-CellRef([string]$ref) {
    if ($ref -match '^([A-Z]+)(\d+)$') { return @{ Col = (ConvertTo-ColumnIndex $Matches[1]); Row = [int]$Matches[2] } }
    return @{ Col = 0; Row = 0 }
}

function ConvertTo-Rows($cells) {
    $rows = @{}
    foreach ($k in $cells.Keys) {
        $p = Split-CellRef $k
        if (-not $rows.ContainsKey($p.Row)) { $rows[$p.Row] = @{} }
        $rows[$p.Row][$p.Col] = $cells[$k]
    }
    $lines = New-Object System.Collections.Generic.List[string]
    if ($rows.Count -eq 0) { return , $lines }
    $maxRow = ($rows.Keys | Measure-Object -Maximum).Maximum
    for ($r = 1; $r -le $maxRow; $r++) {
        if (-not $rows.ContainsKey($r)) { $lines.Add(''); continue }
        $maxCol = ($rows[$r].Keys | Measure-Object -Maximum).Maximum
        $parts = for ($c = 1; $c -le $maxCol; $c++) { [string]$rows[$r][$c] }
        $lines.Add(($parts -join $Delimiter))
    }
    return , $lines
}

function Read-TextLines([string]$path) {
    $text = [System.IO.File]::ReadAllText((Resolve-Path $path).Path)
    $text = $text.TrimStart([char]0xFEFF)
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($l in ($text -split "`r`n|`n|`r")) { $lines.Add($l) }
    if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') { $lines.RemoveAt($lines.Count - 1) }
    return , $lines
}

function Compare-Lines($a, $b) {
    if ($IgnoreBlankLines) {
        $a = [System.Collections.Generic.List[string]]@($a | Where-Object { $_.Trim() -ne '' })
        $b = [System.Collections.Generic.List[string]]@($b | Where-Object { $_.Trim() -ne '' })
    }
    $diffs = New-Object System.Collections.Generic.List[string]
    $max = [math]::Max($a.Count, $b.Count)
    for ($i = 0; $i -lt $max; $i++) {
        $l = if ($i -lt $a.Count) { $a[$i] } else { $null }
        $r = if ($i -lt $b.Count) { $b[$i] } else { $null }
        if ($null -eq $l) { $diffs.Add("行 $($i + 1): 左侧缺失 | 右侧=[$r]"); continue }
        if ($null -eq $r) { $diffs.Add("行 $($i + 1): 右侧缺失 | 左侧=[$l]"); continue }
        if (-not (Test-ValueEqual $l $r)) { $diffs.Add("行 $($i + 1): 左=[$l] 右=[$r]") }
    }
    return @{ Diffs = $diffs; LeftCount = $a.Count; RightCount = $b.Count }
}

function Get-Kind([string]$path) {
    switch -Regex ([System.IO.Path]::GetExtension($path).ToLowerInvariant()) {
        '^\.(xlsx|xlsm)$' { return 'excel' }
        '^\.(txt|csv|tsv|log|md)$' { return 'text' }
        default { throw "不支持的文件类型: $path（仅支持 xlsx/xlsm 与文本文件；旧版 xls 请先另存为 xlsx）" }
    }
}

function Select-Sheets($sheets) {
    if ($Sheet) {
        if (-not $sheets.Contains($Sheet)) { throw "未找到工作表 '$Sheet'，可用: $($sheets.Keys -join ', ')" }
        return [ordered]@{ $Sheet = $sheets[$Sheet] }
    }
    return $sheets
}

$kindL = Get-Kind $Left
$kindR = Get-Kind $Right
$total = 0
$report = New-Object System.Collections.Generic.List[string]

if ($kindL -eq 'excel' -and $kindR -eq 'excel') {
    $sl = Select-Sheets (Read-XlsxSheets $Left)
    $sr = Select-Sheets (Read-XlsxSheets $Right)
    $report.Add("工作表(左): $($sl.Keys -join ', ')")
    $report.Add("工作表(右): $($sr.Keys -join ', ')")
    foreach ($n in $sl.Keys) { if (-not $sr.Contains($n)) { $report.Add("工作表仅存在于左侧: $n"); $total++ } }
    foreach ($n in $sr.Keys) { if (-not $sl.Contains($n)) { $report.Add("工作表仅存在于右侧: $n"); $total++ } }
    foreach ($n in $sl.Keys) {
        if (-not $sr.Contains($n)) { continue }
        $keys = @($sl[$n].Keys) + @($sr[$n].Keys) | Sort-Object -Unique { (Split-CellRef $_).Row * 100000 + (Split-CellRef $_).Col }
        $count = 0
        foreach ($k in $keys) {
            if (-not (Test-ValueEqual $sl[$n][$k] $sr[$n][$k])) {
                $count++; $total++
                if ($total -le $MaxDiffs) { $report.Add("[$n] $k : 左=[$($sl[$n][$k])] 右=[$($sr[$n][$k])]") }
            }
        }
        $report.Add("工作表 '$n' 差异单元格数: $count（已比较单元格 $($keys.Count)）")
    }
}
elseif ($kindL -eq 'text' -and $kindR -eq 'text') {
    $res = Compare-Lines (Read-TextLines $Left) (Read-TextLines $Right)
    $report.Add("行数: 左=$($res.LeftCount) 右=$($res.RightCount)")
    $total = $res.Diffs.Count
    $res.Diffs | Select-Object -First $MaxDiffs | ForEach-Object { $report.Add($_) }
}
else {
    $excelPath = if ($kindL -eq 'excel') { $Left } else { $Right }
    $textPath = if ($kindL -eq 'text') { $Left } else { $Right }
    $sheets = Select-Sheets (Read-XlsxSheets $excelPath)
    if ($sheets.Count -ne 1) { throw "Excel 与 txt 对比必须用 -Sheet 指定唯一工作表，可用: $($sheets.Keys -join ', ')" }
    $name = @($sheets.Keys)[0]
    $excelLines = ConvertTo-Rows $sheets[$name]
    $textLines = Read-TextLines $textPath
    $res = if ($kindL -eq 'excel') { Compare-Lines $excelLines $textLines } else { Compare-Lines $textLines $excelLines }
    $report.Add("工作表 '$name' 按分隔符转为文本行后比较；行数: 左=$($res.LeftCount) 右=$($res.RightCount)")
    $total = $res.Diffs.Count
    $res.Diffs | Select-Object -First $MaxDiffs | ForEach-Object { $report.Add($_) }
}

$report | ForEach-Object { Write-Output $_ }
if ($total -gt $MaxDiffs) { Write-Output "（仅显示前 $MaxDiffs 条，共 $total 处差异）" }
if ($total -eq 0) { Write-Output "结果: 相同（按当前比较口径）"; exit 0 }
Write-Output "结果: 不同，共 $total 处差异"
exit 1
