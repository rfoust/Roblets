<#
.SYNOPSIS
Adds syntax highlighting to string data, such as log files and csv's.

.DESCRIPTION
The Format-RColor cmdlet adds color to generic boring strings such as
log files and csv's.

.PARAMETER StringData
The string to colorize.

.PARAMETER Delimeter
The regex pattern to split the string for formatting. The default should
be acceptable 99.99% of the time but feel free to experiment here if
the output doesn't look right.
Default value: "([ ,;\=\{\}\[\]\(\)])"

.PARAMETER NoNewLine
Suppress newlines. Useful for string building.

.EXAMPLE
PS /var/log> cat ./monthly.out | Format-RColor

.EXAMPLE
PS /var/log> tail -f ./system.log | Format-RColor

.EXAMPLE
PS C:\> "f79f8150-e8a8-4a64-8610-15b0cc10434d [1/1/2019 00:00:00] 0xff {foo} [bar] nobody@example.com error info server http://example.com" | Format-RColor
#>
function Format-RColor {
	[CmdletBinding(DefaultParameterSetName = "StringData")]
	param (
		[Parameter(ParameterSetName = "StringData", Position = 0, ValueFromPipeline = $true)]
		[string]$StringData,

		[Parameter(ParameterSetName = "StringData", Position = 1)]
		[string]$Delimiter = "([ ,;\=\{\}\[\]\(\)])",

		[Parameter(ParameterSetName = "StringData")]
		[switch]$NoNewLine
	)

	begin {
		# test colors like this: "f79f8150-e8a8-4a64-8610-15b0cc10434d [1/1/2019 00:00:00] 0xff {foo} [bar] nobody@example.com error info server http://example.com" | Format-DUColor
		# Most of the regex strings and inspiration was borrowed from here: https://github.com/IBM-Cloud/vscode-log-output-colorizer/blob/master/src/syntaxes/log.tmLanguage

		$patterns = [ordered]@{
			# email address
			email       = "\S+@\S+\.\S+"
			# exception
			exception   = "\b(?i:((\.)*[a-z]|[0-9])*(Exception|Error|Failure|Fail))\b"
			# Date MM/DD/(YY)YY
			date        = "\b(((0|1)?[0-9][1-2]?)|(Jan(uary)?|Feb(ruary)?|Mar(ch)?|Apr(il)?|May|Jun(e)?|Jul(y)?|Aug(ust)?|Sept(ember)?|Oct(ober)?|Nov(ember)?|Dec(ember)?))[/|\-|\.| ]([0-2]?[0-9]|[3][0-1])[/|\-|\.| ]((19|20)?[0-9]{2})\b"
			# Date (YY)YY/DD/MM
			date2       = "\b((19|20)?[0-9]{2}[/|\-|\.| ](((0|1)?[0-9][1-2]?)|(Jan(uary)?|Feb(ruary)?|Mar(ch)?|Apr(il)?|May|Jun(e)?|Jul(y)?|Aug(ust)?|Sept(ember)?|Oct(ober)?|Nov(ember)?|Dec(ember)?))[/|\-|\.| ]([0-2]?[0-9]|[3][0-1]))\b"
			# Date DD/MM/(YY)YY
			date3       = "\b([0-2]?[0-9]|[3][0-1])[/|\-|\.| ](((0|1)?[0-9][1-2]?)|(Jan(uary)?|Feb(ruary)?|Mar(ch)?|Apr(il)?|May|Jun(e)?|Jul(y)?|Aug(ust)?|Sept(ember)?|Oct(ober)?|Nov(ember)?|Dec(ember)?))[/|\-|\.| ]((19|20)?[0-9]{2})\b"
			# Time HH:MM(:SS)? AM? timezone?
			time        = "\b([0|1]?[0-9]|2[0-3])\:[0-5][0-9](\:[0-5][0-9])?( ?(?i:(a|p)m?))?( ?[+-]?[0-9]*)?\b"
			# Numeric
			numeric     = "\b\d+\.?\d*?\b"
			# Quoted strings with "
			doublequote = '"[^}]*"'
			# Quoted strings with '
			singlequote = "'[^}]*'"
			# Bracket strings with []
			bracket     = "\[[^}]*\]"
			# Numeric (hex)
			hex         = "\b(?i:(0?x)?[0-9a-f][0-9a-f]+)\b"
			# guid
			guid        = "\b(?i:([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}))\b"
			# namespace
			namespace   = "\b(?i:(([a-z]|[0-9]|[_|-])*(\.([a-z]|[0-9]|[_|-])*)+))\b"
			# ??
			down        = "\b(?i:(Down|Error|Failure|Fail|Fatal|false))(\:|\b)"
			# keyword
			keyword     = "\b(?i:(hint|info|information|true|log))(\:|\b)"
			# warning
			warning     = "\b(?i:(warning|warn|test|debug|null|undefined|NaN))(\:|\b)"
			# url
			url         = "\b(?i:([a-z]|[0-9])+\:((\/\/)|((\/\/)?(\S)))+)"
		}

		$colorMap = @{
			exception   = "Red"
			date        = "DarkGray"
			date2       = "DarkGray"
			date3       = "DarkGray"
			time        = "DarkGray"
			numeric     = "Cyan"
			doublequote = "Yellow"
			singlequote = "Yellow"
			hex         = "Cyan"
			email       = "Green"
			guid        = "Cyan"
			bracket     = "White"
			namespace   = "Red"
			down        = "Red"
			keyword     = "Green"
			warning     = "Yellow"
			url         = "Magenta"
		}
	}

	process {
		foreach ($str in $StringData) {
			$strArr = [regex]::split($str, $Delimiter)

			for ($i = 0; $i -lt $strArr.count; $i++) {
				$matchFound = $false

				foreach ($pattern in $patterns.GetEnumerator()) {
					if ($strArr[$i] -match $pattern.Value) {
						$matchFound = $true
						Write-Host $strArr[$i] -ForegroundColor $colorMap[$pattern.Key] -NoNewline
					}

					if ($matchFound) {
						break
					}
				}

				# default/no regex matches
				if (!$matchFound) {
					Write-Host $strArr[$i] -ForegroundColor Gray -NoNewline
				}

				# end of the line, so add newline
				if (($i + 1 -ge $strArr.count) -and !$NoNewLine) {
					Write-Host
				}
			}
		}
	}

	end { }
}