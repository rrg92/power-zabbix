# Simple verbose logging function
Function verbose {
	$ParentName = (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Name;
	write-verbose ( $ParentName +':'+ ($Args -Join ' '))
}

#Converts objets to JSON and vice versa,
Function ConvertToJson($o) {
	return $o | ConvertTo-Json -Depth 10
}

Function ConvertFromJson([string]$json) {
	$json | ConvertFrom-Json;
}

function JoinPath {
	$Args -Join [IO.Path]::DirectorySeparatorChar
}


# LOW LEVEL HTTP Functions
. (JoinPath $PSSCriptRoot "http.ps1")