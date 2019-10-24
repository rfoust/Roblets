<#
.SYNOPSIS
Converts LDIF formatted data into a PSCustomObject.

.DESCRIPTION
Converts LDIF formatted data into a PSCustomObject. Multivalued
attributes are grouped into arrays, and attributes that contain
a datatime value are converted.

.PARAMETER Data
Specifies the LDIF data to convert.

.EXAMPLE
PS C:\> $ldifData | ConvertFrom-RLDIF
#>
function ConvertFrom-RLDIF {
	[CmdletBinding(DefaultParameterSetName = "Data")]
	param(
		[Parameter(ParameterSetName = "Data", Position = 0)]
		[string[]]$Data
	)

	begin {
		$dateTimeAttributes = @(
			"pwdLastSet"
			"msDS-LastSuccessfulInteractiveLogonTime"
			"msDS-LastFailedInteractiveLogonTime"
			"lastLogonTimestamp"
		)
	}

	process {
		if (!$Data) {
			continue
		}

		$beginNewUser = $true

		for ($i = 0; $i -lt $Data.Count; $i++) {
			# skip comment line or continuation line that would have already been processed by a prior loop.
			if ($Data[$i] -match "^#|^\W." -or $Data[$i] -eq "") {
				continue
			}

			if ($beginNewUser) {
				$userHash = @{ }
				$beginNewUser = $false
			}

			$prop, $value = $Data[$i] -split ": "

			# some properties end with a double "::"
			$prop = $prop -replace ":", ""

			if ($prop -eq "dn") {
				Write-Verbose "[ConvertFrom-DULDIF] dn: $value"
			}

			# process line continuations
			$continuationCount = 1
			$moreData = $true

			do {
				if ($Data[$i + $continuationCount] -match "^\W.") {
					$value += $Data[$i + $continuationCount].TrimStart()
					$continuationCount++
				}

				if ($Data[$i + $continuationCount] -notmatch "^\W.") {
					$moreData = $false
				}
			} while ($moreData)

			# format guid or datetime if needed
			if ($prop -match "guid") {
				$value = ConvertFrom-Base64 $value -AsGuid
			}
			elseif ($value -and ($dateTimeAttributes -contains $prop)) {
				$value = [DateTime]::FromFileTimeUtc($value)
			}
			elseif ($value -match "\w*\.0Z\b") {
				$value = [DateTime]$value.insert(4, "-").insert(7, "-").insert(10, "T").insert(13, ":").insert(16, ":") -replace ".0Z", ""
			}

			# convert single hash entry to an array if attribute is multivalued
			if ($userHash.$prop) {
				$userHash.$prop = [array]$userHash.$prop + $value
			}
			else {
				$userHash[$prop] = $value
			}

			# blank line separates users
			# need to check the line that comes after any continuation lines
			if ($Data[$i + $continuationCount] -eq "") {
				$beginNewUser = $true

				$userObj = [PSCustomObject]$userHash
				$userObj | Add-Member ScriptMethod ToString { $this.dn } -Force
				$userObj
			}
		}
	}

	end { }
}
