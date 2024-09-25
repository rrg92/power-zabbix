<#
	.DESCRIPTION 
		Converte cmdlets para documentação!
#>
param(
	$lang = "pt-BR"
	
	#Fitlrar comandos!
	,$CommandFilter = $null
	
	,[switch]$Update
)

$ErrorActionPreference = "Stop";
. (Join-Path "$PsScriptRoot" UtilLib.ps1)
$Info = GetProjectVars

$DebugInfo = @{
	files = @()
	
}

$OutputDir = JoinPath -Resolve docs $lang cmdlets

import-module -force PlatyPs;

$ModDir = $Info.ModuleDir;
$m = import-module "./$ModDir" -force -passthru;

$ModCommands = Get-Command -mo $ModDir -CommandType Function

$CommonParams = GetCommonParamsNames

		
$ParamYmlMapping = @{
	'ParamSet' 			= 'Parameter Set'
	'ValidValues' 		= 'Accepted Values'
	'Default' 			= 'Default Value'
	'AcceptPipeline' 	= 'Accept pipeline input'
	'AcceptWildCard'	= 'Accept wildcard characters' 
}
		
$HEADERS = GetHeaderShorts
$INVERSE_HEADERS = @{}
@($HEADERS.keys) | %{ 
	$ShortName 	= $_;
	$HeaderText = $HEADERS[$ShortName];
	$INVERSE_HEADERS[$HeaderText] = "## $HeaderText <!--!= @#$ShortName !-->" 
}

function GetHeaderShort {
	param($text)
	
	$text = $text.toUpper();
	
	$NewHeader = $INVERSE_HEADERS[$text];
	
	if(!$NewHeader){
		throw "INVALID_HEADER: $text";
	}
	
	return $NewHeader;
}
		
foreach($Cmd in $ModCommands){
	

	
	$Parsed = ParseCommandHelp $Cmd;
	
	
	$PlatyMd = @(
		"---"
		"external help file: $($Info.ProjectName)-help.xml"
		"schema: 2.0.0"
		"---"
		""
		"# $($Cmd.name)"
		""
		(GetHeaderShort SYNOPSIS)
		$Parsed.Synopsis
	)
	
	if($Parsed.description){
		$PlatyMd += @(
			""
			(GetHeaderShort DESCRIPTION)
			$Parsed.description
		)
	}


	$PlatyMd += @(
		""
		(GetHeaderShort SYNTAX)
	)
	
	if($Parsed.Syntax.__AllParameterSets){
		$PlatyMd += @(
				''
				'```'
				$Parsed.Syntax.__AllParameterSets
				'```'
			)
	} else {
		@($Parsed.Syntax.keys) | %{
			$PlatyMd += @(
				""
				"### "+$_
				'```'
				$Parsed.Syntax[$_]
				'```'
			)
		}
	}
	
	
	if($Parsed.examples){
		$PlatyMd += @(
			""
			(GetHeaderShort EXAMPLES)
		)
		
		$Parsed.examples | %{
			$PlatyMd += @(
				""
				"### " + $_.title
				'```powershell'
				$_.code
				'```'
				$_.remarks
			)
		}
	}
	
	$PlatyMd += @(
		""
		(GetHeaderShort PARAMETERS)
	)
	
	if($Parsed.parameters){
		foreach($Param in $Parsed.parameters){
			
			$ParamYaml = @()
			
			
			$Param.psobject.properties | %{
				
				if($_.name -in 'name','description' -or $_.name -Like '_*'){
					return;
				}
				
				$ParamMetaName = $ParamYmlMapping[$_.name];
				$ParamValue = $_.value;
				
				if(!$ParamMetaName){
					$ParamMetaName = $_.name;
				}
				
				if($_.name -eq "ParamSet" -and $ParamValue -eq '__AllParameterSets'){
					$ParamValue = '(All)'
				}
				
				if($ParamValue -is [array]){
					$ParamValue = $ParamValue -Join ","
				}

				$ParamYaml += "$($ParamMetaName): $ParamValue"
			}
			
			
			$PlatyMd += @(
				""
				"### -" + $Param.name
				$Param.description
				""
				'```yml'
				$ParamYaml
				'```'
			)
		}
		
	}
	
	
	$OutputFile = JoinPath $OutputDir "$($Cmd.Name).md"
	
	if($Update){
		write-host "Writing to $OutputFile";
		WriteFileBom $OutputFile $PlatyMd;
	}
}

write-warning "Check local FileData var to details"

if(!$Update){
	write-host "Nothing updated. Use -Updated to generate files (or overwrite existing)"
}