function Get-RADUser {
	[CmdletBinding(DefaultParameterSetName = "All")]
	param (
		[Parameter(ParameterSetName = "Identity", Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
		[string]$Identity,

		[Parameter(ParameterSetName = "LdapFilter", Mandatory = $true)]
		[string]$LdapFilter,

		[Parameter(ParameterSetName = "All")]
		[Parameter(ParameterSetName = "Identity")]
		[Parameter(ParameterSetName = "LdapFilter")]
		[string]$Server,

		[Parameter(ParameterSetName = "All")]
		[Parameter(ParameterSetName = "Identity")]
		[Parameter(ParameterSetName = "LdapFilter")]
		[Alias("Properties")]
		[string[]]$Attributes = @(
			"distinguishedName"
			"givenName"
			"displayName"
			"objectClass"
			"objectGuid"
			"sAMAccountName"
			"objectSid"
			"sn"
			"userPrincipalName"
		),

		[Parameter(ParameterSetName = "All")]
		[Parameter(ParameterSetName = "Identity")]
		[Parameter(ParameterSetName = "LdapFilter")]
		[string]$BaseDN,

		[Parameter(ParameterSetName = "All")]
		[Parameter(ParameterSetName = "Identity")]
		[Parameter(ParameterSetName = "LdapFilter")]
		[PSCredential]$Credential,

		[Parameter(ParameterSetName = "All")]
		[Parameter(ParameterSetName = "Identity")]
		[Parameter(ParameterSetName = "LdapFilter")]
		[Int32]$ResultSetSize = 0,	# 0 = unlimited

		[Parameter(ParameterSetName = "All")]
		[Parameter(ParameterSetName = "Identity")]
		[Parameter(ParameterSetName = "LdapFilter")]
		[Int32]$ResultPageSize = 256,

		[Parameter(ParameterSetName = "All")]
		[Parameter(ParameterSetName = "Identity")]
		[Parameter(ParameterSetName = "LdapFilter")]
		[switch]$NoSSL,

		[Parameter(ParameterSetName = "All")]
		[Parameter(ParameterSetName = "Identity")]
		[Parameter(ParameterSetName = "LdapFilter")]
		[switch]$RawOutput
	)

	begin {
		if ($IsMacOS -eq $false -and $IsLinux -eq $false) {
			throw "This cmdlet is only supported on Mac/Linux. Use Get-ADUser instead."
		}

		if ($PSCmdlet.ParameterSetName -eq "All" -or $PSCmdlet.ParameterSetName -eq "LdapFilter") {
			$Identity = "*"
		}

		foreach ($param in $PSCmdlet.MyInvocation.BoundParameters.GetEnumerator()) {
			Write-Verbose "[Get-RADUser] param: $param"
		}

		# null credential was passed in
		if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("Credential") -and !$PSCmdlet.MyInvocation.BoundParameters["Credential"]) {
			$noCred = $true
			$localADCredential = "NoCred"
		}
		else {
			$localADCredential = $Credential
		}

		if (!$localADCredential) {
			$localADCredential = Get-Credential -Message "Enter Active Directory credentials."
		}

		if (!$noCred -and $localADCredential) {
			$authStr1 = "-D $($localADCredential.UserName)"
			$authStr2 = "-w $($localADCredential.GetNetworkCredential().Password)"
		}

		if (!$Server) {
			$ldapSearchTarget = ($localADCredential.Username -split "@")[-1]
		}
		else {
			$ldapSearchTarget = $Server
		}

		if (!$BaseDN -and $noCred) {
			$BaseDN = "dc=example,dc=com"
		}
		elseif (!$BaseDN) {
			$BaseDN = "dc=" + ($ldapSearchTarget -replace "\.", ",dc=")
		}

		if ($NoSSL) {
			$ldapStr = "ldap://"
		}
		else {
			$ldapStr = "ldaps://"
		}

		if ($ResultSetSize -ne 0 -and $ResultPageSize -le $ResultSetSize) {
			$ResultPageSize = $ResultSetSize + 1
			Write-Verbose "[Get-RADUser] Increasing PageSize to $ResultPageSize"

			$resultSetSizeStr = "-z $ResultSetSize"
		}

		Write-Verbose "[Get-RADUser] localADCredential: $localADCredential"
		Write-Verbose "[Get-RADUser] server: $server"
		Write-Verbose "[Get-RADUser] BaseDN: $BaseDN"
		Write-Verbose "[Get-RADUser] ldapSearchTarget: $ldapSearchTarget"

		if ($VerbosePreference -eq "continue") {
			$verboseParam = "-v"
		}

		if ($DebugPreference -eq "continue") {
			$debugParam = "-d 1"
		}
	}

	process {
		foreach ($id in $Identity) {
			if (!$id) {
				continue
			}

			if ($PSCmdlet.ParameterSetName -eq "LdapFilter") {
				$ldapSearchStr = $LdapFilter
			}
			else {
				$ldapSearchStr = "(&(|(objectClass=User)(objectClass=inetOrgPerson))(|(sAMAccountName=$id)(userPrincipalName=$id)(mail=$id)(employeeNumber=$id)))"
			}

			if ($IsMacOS -or $IsLinux) {
				Write-Verbose "[Get-RADUser] Calling ldapsearch"
				Write-Verbose "[Get-RADUser] Attributes: $attributes"

				$expressionClean = "ldapsearch $verboseParam $debugParam -LLL -P 3 -E pr=$ResultPageSize/noprompt $resultSetSizeStr -H $($ldapStr + $ldapSearchTarget) -x $authStr1 [pw redacted] -b $baseDN $ldapSearchStr $attributes"
				$expression = "ldapsearch $verboseParam $debugParam -LLL -P 3 -E pr=$ResultPageSize/noprompt $resultSetSizeStr -H $($ldapStr + $ldapSearchTarget) -x $authStr1 $authStr2 -b $baseDN $ldapSearchStr $attributes"

				Write-Verbose "[Get-RADUser] expression: $expressionClean"

				$results = Invoke-Expression $expression

				if ($RawOutput) {
					$results
				}
				else {
					ConvertFrom-RLDIF $results
				}
			}

		}
	}

	end {
		$authStr = $null
	}
}