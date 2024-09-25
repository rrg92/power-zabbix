param($ResetStorage = $false)

#M�dulo para o powershell!
$ErrorActionPreference= "Stop";

## Global Var storing important values!
if($Global:PowerZabbix_Storage -eq $null -or $ResetStorage){
	$Global:PowerZabbix_Storage = @{
			SESSIONS = @()
			DEFAULT_SESSION = $null	
			SESSION_NAME = @{}
		}
}


. "$PSSCriptRoot/lib/util.ps1"
Set-Alias PowerZabbixHttp InvokeHttp




#Make calls to a zabbix server url api.
Function CallZabbixURL {
	param(
		[object]$data 	= $null
		,$url 			= $null
		,$method 		= "POST"
		,$contentType 	= "application/json-rpc"
	)
	
	verbose "CallZabbixURL: URL param is: $Url";
	if(!$URL){
		$DefaultSession = Get-DefaultZabbixSession
		$URL = $DefaultSession.URL;
	}
	
	if($url -NotLike "*api_jsonrpc.php" ){
		if($url -NotLike "*/"){
			$url += "/"
		}
		
		$url += "api_jsonrpc.php"
	}
	

	
	if($Global:PowerZabbix_ZabbixUrl -and !$url){
		$url = $Global:PowerZabbix_ZabbixUrl;
	}
	
	$ReqParams = @{
		method 		= $method 
		contentType = $contentType
		url 		= $url 
		data 		= $data 
	}
	
	$resp = Invoke-Http @ReqParams
	return $resp.text;
}

	
#Gets file for backing connections
Function GetPowerZabbixBackingFile {
	$DirPath = $PsHome+'\power-zabbix'
	
	if( ![IO.Directory]::Exists($Pshome) ){
		$F = mkdir -force $DirPath;
	}
	
	$File = $DirPath+'\backing.xml';
	
	return $File;
}
	
	
#Handle the zabbix server answers.
#If the repsonse represents a error, a exception will be thrown. Otherwise, a object containing the response will be returned.
Function TranslateZabbixJson {
	param($ZabbixResponse)
	
	
	#Converts the response to a object.
	$ZabbixResponseO = ConvertFromJson $ZabbixResponse;
	
	#If the "error" property is set, then a error is build.
	#https://www.zabbix.com/documentation/3.0/manual/api
	if($ZabbixResponseO.error){
		$ZabbixError = $ZabbixResponseO.error;
		$MessageException = "[$($ZabbixError.code)]: $($ZabbixError.data). Details: $($ZabbixError.data)";
		$Exception = New-Object System.Exception($MessageException)
		$Exception.Source = "ZabbixAPI"
		throw $Exception;
		return;
	}
	
	
	#If not error, then return response result.
	return $ZabbixResponseO.result;
}

#Generate a id for be used in each request to the API.
Function  GetNewZabbixApiId {
	return [System.Guid]::NewGuid().Guid.ToString()
}

	
#Gets a authentication token to be used in calls to API.
#Cmdlets that implements api methods must calls this in order to get a valid token.
Function GetZabbixApiAuthToken {
	param([switch]$FrontEnd = $false)
	
	verbose "Getting token from the default Zabbix Session..."
	$DefaultSession = Get-DefaultZabbixSession;

	if(!$DefaultSession){
		throw "POWER_ZABBIX_NODEFAULTSESSION!";
	}

	if($FrontEnd){
		return $DefaultSession.FrontendSession;
	} else{
		return $DefaultSession.SessionID;
	}
}

	
#This is a generic API builder. This builds a hashtable with all common information to call api methods.
Function New-ZabbixApiParams {
	<#
		.DESCRIPTION 
			Cria um novo objeto que representa parâmetros da API.
	#>
	param(
		 $method
		,[switch]$NoAuth
	)
	
	if(!$NoAuth){
		[string]$token = GetZabbixApiAuthToken;
	}
	
	
	[string]$NewId = GetNewZabbixApiId;
	
	
	$APIParams =  @{
					jsonrpc = "2.0"
					id 		= $NewId
					method	= $method
					params 	=  @{}
				}
				
	if($token){
		$APIParams["auth"] = $token;
	}
				
	return $APIParams
}
Set-Alias ZabbixAPI_NewParams New-ZabbixApiParams
	
	
#This functions builds all commons *.get API methods parameters.
#You can use this to generate some basic structure for a get operation of any object type.
Function ZabbixAPI_Get {
	param(
		[hashtable]$Options
		,$APIParams = @{}
	)
	
	$Options.params.add("filter",@{});
	
	#Determinando searchByAny
	if($APIParams.common.searchByAny){
		$Options.params.add("searchByAny", $true);
	}
	
	if($APIParams.common.startSearch){
		$Options.params.add("startSearch", $true);
	}
	
	
	if($APIParams.common.limit){
		$Options.params.add("limit", $APIParams.common.limit);
	}
	
	
	if($APIParams.common.output){
		$Options.params.add("output", $APIParams.common.output);
	}
	
				
	#Determinando se iremos usar search ou filter pra buscar...
	if($APIParams.common.search){
		$Options.params.add("searchWildcardsEnabled",$true);
		$Options.params.add("search",$APIPArams.props);
	} 
	elseif($APIParams.props.name) {
		$Options.params.filter["name"] = $APIParams.props.name
	}
	
	return;
}

	
#Convert a datetime object to a unix time representation.
Function Datetime2Unix {
	param([datetime]$Datetime)
	
	return $Datetime.toUniversalTime().Subtract([datetime]'1970-01-01').totalSeconds;
}

#Converts a unixtime representation to a datetime in local time.
Function UnixTime2LocalTime {
	param([uint32]$unixts)
	
	return ([datetime]'1970-01-01').toUniversalTime().addSeconds($unixts).toLocalTime();
}
	
#Returns a value formatted to the zabbix datetime
function MakeZabbixDatetime {
	param($datetime)
	
	[string]$TimeFilter = "";
	if($datetime -is [int]){
		$TimeFilter = $datetime;
	} else {
		$TimeFilter = Datetime2Unix $datetime;
	}
	return $TimeFilter
}
		
		
#Get a list of names and converts it to ids.
#This is a auxliary function that contains common steps to convert a name of some object (hosts, hostgroups, etc.) to the respective id.
#It handles names not founds, etc.
#You must supply the original names and a scriptblock used to cast the name to the id.
Function ZabbixAPI_List2Ids {
	param(
		#This is the names list!
		$SourceList
		
		,[scriptblock]$NamesToId
		
		,[switch]$NoValidate = $false	
	)

	$Ids = @();
	$Names = @();
	
	$SourceList | %{
		if($_ -as [int]){
			$Ids += @{id=$_;name=$null};
		} else {
			$Names += $_.toString()
		}
	}
	
	if($Names){
		#NameToId must return a array of objects, where each object contains id of entity and the associated name in name property.
		$Founded += & $NamesToId $Names;
		
		if(!$NoValidate){
			#Gera um array com a lista de nomes encontrados...
			$NamesFound = @($Founded | %{$_.name});
			
			#Obt�m os nomes que n�o foram encontrados...
			$NamesNotFound  = @();
			$NamesNotFound = $SourceList | ? {  $NamesFound  -NotContains $_  } | %{$_};
			
			if($NamesNotFound){
				throw "NAMES_NOT_FOUND: $NamesNotFound"
			}
		}
		
		$Ids += $Founded;
		
		
	}
	
	return $Ids;
}
	
	
		
############# DEBUGGING CMDLETS.
##### This cmdlets are provided to allows externals calls debug of the module. To be used by module developers only.
#Debugging purposes
	Function Get-NewZabbixParams {
		param($method)
		
		return ZabbixAPI_NewParams $method
	}

	Function Invoke-ZabbixURL {
		[CmdLetBinding()]
		param($APIParams, [switch]$Translate)
		
		
		write-host "Converting APIParams to JSON..."
		$APIString = ConvertToJson $APIParams;
		write-host "JSON:`r`n" $APIString
		
		$resp = CallZabbixURL -data $APIString;
		
		if($Translate){
			$resultado = TranslateZabbixJson $resp;
			
			if($resultado -is [object[]]){
				$ResultsObjects = @();
				if($resultado){
					$resultado | %{
						$ResultsObjects += NEw-Object PSObject -Prop $_;	
					}
				}
			}

		}
		
		return @{RawResponse=$resp;RawTranslate=$Resultado;ResultObjects=$ResultsObjects};
	}
	
	
	
############# NON-API Cmdlets
######This cmdlets are provided to allwos use supply or get information that module needs to talk with api, like usernames, urls, etc.

	#Auths a user on the zabbix server.
	#The authentication information (like auth token generated by the server) is saved on credential cache and marked as last used URL.
	#THus, every call that needs a authentication token, will be get from cache.
	Function Connect-Zabbix {
		<#
			.SYNOPSIS  
				Conecta com um Zabbix e cria uma nova sessão para invocar os demais comandos 
				
			.DESCRIPTION 
				Este é o ponto de partida para começar a usar o power zabbix.  
				Este comando faz a autenticação com o servidor zabbix especificado e, se a autenticação for feita com sucesso, cria uma sessão.  
				Uma sessão é um objeto na memória do power-zabbix que contém tudo o que é necessário para invocar as demais APIs.  É onde fica o token de autenticação.  
				Você pode se autenticar usando uma API token, basta informar a mesma no campo "Password"
				
		#>
		[CmdLetBinding(DefaultParameterSetName = "UserPass")]
		param(
				 #A URL do zabbix!
				 #Pode ser servidor:porta (assume http por padrao)
				 #pode ser https://servidor:porta 
				 #Formato: [http[s]://]host[:porta][/path]
				 [Parameter(Position=0)]
				 $URL 		= $null

				,#Nome do usuário (Criado no zabbix)
					[Parameter(ParameterSetName="UserPass")]
					$User = $null
				
				,#Senha do usuáro 
					[Parameter(ParameterSetName="UserPass")]
					$Password = $null
				
				,#Autentica usando uma API Token
					[Parameter(ParameterSetName="Apitoken")]
					[switch]$UseApiToken
				
				,#Especifica a api token direto como parâmetro.
				 #Especificar este, implicitamente, habilita -UseApiToken
					[Parameter(ParameterSetName="Apitoken")]
					$ApiToken = $null
				
				,[switch]$Frontend = $false
				,#Nome único que identifica esta conexão 
					$Name = $null
					
				,#Forçar recriar a conexão mesmo que já exista uma em aberto 
					[switch]$Force = $False
			)

		#Gets a reference for the cache!
		$AllSessions 		= $Global:PowerZabbix_Storage.SESSIONS;
		$SessionNameIndex 	= $Global:PowerZabbix_Storage.SESSION_NAME;
		
		$URI = [Uri]$URL;
		
		if($URI.scheme -notin 'http','https'){
			$URL = 'http://' + $URL;
		}
		
		#Check if api is accessbile!
		try {
			$APIVersion = Get-ZabbixApiInfoVersion -URL $URL
		} catch {
			verbose "$($MyInvocation.InvocationName): Error testing access to the $URL"
			if($Force){
				verbose "$($MyInvocation.InvocationName): 	Ignoring due to -Force!"
			} else {
				verbose "$($MyInvocation.InvocationName): 	Use -Force to try any way!"
				throw "URL_NOT_ACESSIBLE: $URL. Error: $_";
			}
		}
		
	
		#Find a session with same name and url!
		if($Name){
			$Session = $SessionNameIndex[$Name]
		}
		
		if($ApiToken){
			$UseApiToken = $true;
		}

		if(!$Session){		
		
			if($UseApiToken ){
				if(!$ApiToken){
					$Creds = Get-Credential "API TOKEN";
					$ApiToken = $Creds.GetNetworkCredential().Password
				}
			} else {
				#Promtps for credentials!
				if($User -and $password){
					$PassSecure	= ConvertTo-SecureString $Password -AsPlainText -Force;
					$Creds		= New-Object Management.Automation.PSCredential($User, $PassSecure)
				}
				else {
					$Creds 		= Get-Credential
					$User		= $Creds.GetNetworkCredential().UserName
					$Password 	= $Creds.GetNetworkCredential().Password
				}
				
				$Session = $AllSessions | ? {  $_.Url -eq $Url -and $_.User -eq $User };
			}

		}
		
		
		#Pending!
		$PendingAuth = @();
		if(!$Session.SessionID -or $Force){
			$PendingAuth += "API"
		}

		if($FrontEnd -and (!$Session.FrontendSession -or $Force)){
			$PendingAuth += "Frontend"
		}

		if(!$PendingAuth){
			verbose "Getting from cache!"
			return $Session;
		}

		if(!$Session) {
			verbose "Session object dont exist. Create new!"
			$Session = [PsCustomObject]@{
					Url 				= $Url
					User 				= $User
					SessionID			= $null
					FrontendSession		= $null
					AuthTime			= $null
					FrontEndAuthTime	= $null
					Name				= $null
				}

			$Session | Add-Member -Type ScriptMethod -Name ToString -Force -Value {
				$SessionInfo = @()

				if($this.Name){
					$SessionInfo += "NAME=$($this.Name)";
				}
				
				$SessionString += @(
					"URL=$($this.Url)"
					"USER=$($this.User)";	
				)

				return $SessionString -Join " ";
			}

			$IsNewSession = $true;
		}


		if($Name){
			$Session.Name = $Name;
			$SessionNameIndex[$Name] = $Session;
		}
		
		
		#Authenticates on API URL!
		if($PendingAuth -Contains "API"){
			verbose "Auth on API"
			
			$v5 = [Version]"5.0.0"
			$ApiParams = New-ZabbixApiParams -NoAuth;
			
			if($UseApiToken){
				verbose "Using Api Token Auth"
				
				$ApiParams.method = "user.checkAuthentication"
				$ApiParams.params = @{
					token  = $ApiToken
				}
				
				verbose "Testing token..."
				$resp 				= CallZabbixURL -data $ApiParams -url $URL;
				$Result 			= TranslateZabbixJson $resp;
				
				if(!$Result.userid){
					throw "POWERZABBIX_AUTH_TOKEN_FAIL: Auth failed. Check credentials! (UserId = $($Result.userid))";
				}
				
				$AuthToken = $ApiToken;
			} else {
				verbose "Using user/pass auth flow..."
				$Params = @{
					password = [string]$password
				}	
				
				if($APIVersion -le $v5){
					$Params.user = [string]$User;
				} else {
					$Params.username = [string]$User;
				}

				$ApiParams.params 	= $Params;
				$ApiParams.method	= "user.login"

				#Chama a Url
				verbose "Checking user/pass..."
				$resp 				= CallZabbixURL -data $ApiParams -url $URL;
				$AuthToken 			= TranslateZabbixJson $resp;
			}
			
			if(!$AuthToken){
				throw "POWERZABBIX_NO_AUTHTOKEN: Authentication failed. No auth token returned!"
			}
			
			$Session.SessionID 	= $AuthToken;
			$Session.AuthTime 	= Get-Date
		}


		#If users wants login in frontend, then do this.
		#This is useful for invoking some method that api dont support, like graphics.
		if($PendingAuth -Contains "Frontend"){
			verbose "$($MyInvocation.InvocationName): Auth on Frontend"
			$AuthPage = $URL;
			
			if($AuthPage -NotLike '*/'){
				$AuthPage = $AuthPage + '/'
			}
			
			verbose "Login into frontend. Ivoking the the page $AuthPage...";
			$LoginPage = InvokeHttp -URL $AuthPage;
			
			#At this point, we can setup all information need to send to zabbix login page.
			$LoginData = @{
				name = $User
				password = $Password
				enter = 'Sign in'
				autologin = 1
			}
			
			#Just call using our function to invoke http request...
			$LoginResult = InvokeHttp -URL $AuthPage -data $LoginData -Headers @{"Authorization" = "Bearer "}
			
			#If the login result was a 302, means sucessfully login.
			#This is because when login is sucessfully, zabbix frontend redirects the user to another page.
			#HTTP CODE 302 means redirections.
			if($LoginResult.httpResponse.statusCode -eq 302){
				$Session.FrontendSession = $LoginResult.session;
				$Session.FrontEndAuthTime = Get-Date;
			} else {
				
				#If return code was another thant 302, then somehting wrong occured.
				#We must try find in html response possible error messages expected...
				
				$AllErrorMsgs = @();
				
				if($LoginResult.html){
					$AllErrorMsgs += $LoginResult.html.DocumentNode.SelectNodes('//div[@class="article"]//div[@class="red"]/text()') | %{$_.InnerText};
				}
				
				
				if($AllErrorMsgs){
					throw "AUTH_FRONTEND_ERROR: $($AllErrorMsgs -Join '`r`n')"
					return;
				}

				throw "AUTH_FRONTEND_UNKOWN! StatusCode: $([int]$LoginResult.httpResponse.statusCode)"
			}
			
		}

		if($IsNewSession){
			verbose "Inserting on sessions cache"
			$Global:PowerZabbix_Storage.SESSIONS += $Session;
		}

		return $Session;
	}
	Set-Alias Auth-Zabbix Connect-Zabbix;
	Set-Alias ZabbixLogin Connect-Zabbix;

	Function Remove-ZabbixSession {
		[CmdLetBinding()]
		param(
			
			[Parameter(Mandatory=$True, ValueFromPipeline=$true)]
			$Session
			
			,[switch]$NoLogout = $false
		)
		
		begin {
			$Sessions2Remove = @()
		}
		process {
			$Sessions2Remove += $Session;
		}
		end {
			$Default = $Global:PowerZabbix_Storage.DEFAULT_SESSION
			$Sessions2Remove | %{
				$Sess2Remove = $_;
				verbose "$($MyInvocation.InvocationName): Removing $Sess2Remove";
				

				#If is default, removes!
				if($Default -and $Default.Equals($Sess2Remove)){
					verbose "$($MyInvocation.InvocationName): 	Removing from default!";
					$Global:PowerZabbix_Storage.DEFAULT_SESSION = $null;
					$Default = $null;
				}

				if($Sess2Remove.Name){
					verbose "$($MyInvocation.InvocationName): 	Removing from index";
					$Global:PowerZabbix_Storage.SESSION_NAME.Remove($Sess2Remove.Name);
				}
				
				#Unathenticte!
				if(!$NoLogout){
					try {
						verbose "$($MyInvocation.InvocationName): 	Invokking logout api...";
						$out = Invoke-LogoutUser -token $Sess2Remove.SessionID;
					} catch {
						verbose "$($MyInvocation.InvocationName): 	Error in logout user: $_";
					}
				}

				
				
				verbose "$($MyInvocation.InvocationName): 	Removing from SESSIONS list...";
				if($Global:PowerZabbix_Storage.SESSIONS){
					$Global:PowerZabbix_Storage.SESSIONS  = @($Global:PowerZabbix_Storage.SESSIONS | ?{
							$_.Equals($Sess2Remove)
						})
				}
			}
		}
		
	}

	Function Set-DefaultZabbixSession {
		[CmdLetBinding()]
		param(
			
			[Parameter(Mandatory=$True, ValueFromPipeline=$true)]
			$Session
		)
		
		begin {}
		process {}
		end {
			$Global:PowerZabbix_Storage.DEFAULT_SESSION = $Session;
		}
		
	}
	
	Function Get-DefaultZabbixSession {
		
		if(@($Global:PowerZabbix_Storage.SESSIONS).count -eq 1){
			return @($Global:PowerZabbix_Storage.SESSIONS)[0];
		} else {
			return $Global:PowerZabbix_Storage.DEFAULT_SESSION
		}
		
	}

	Function Get-DefaultZabbixSessionId {
		$d = Get-DefaultZabbixSession;
		
		if($d){return $d.SessionID};
	}

	Function Get-ZabbixSessions {
		param($Name)

		if($Name){
			return $Global:PowerZabbix_Storage.SESSION_NAME[$Name];
		} else {
			return $Global:PowerZabbix_Storage.SESSIONS
		}

		
	}

	#Returns a hashtable with a host interface to be used with cmdlet Create-Zabbixhost
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/hostinterface/object
	Function Get-InterfaceConfig {
		param(
			#Pode ser um nome DNS ou IP. O que vai determinar o tipo � a presen�a ou n�o do par�metro -IsIP
			$Address = $null
			
			,#Porta da interface. 
				[int]$Port = 10050
				
			,#Indica que a interface n�o � a padr�o!
			 #Neste caso, a propriedade main ser� marcada como 0.
				[switch]$NoMain 	= $false

			,#Indica se o valor em Address � um IP. Se sim, a interface ser� configurada como IP.
				[switch]$IsIP		= $False
			
			
			,#Tipo da interface. Pode se usar o nome ou id. Verifique o link para os ids!
				[ValidateSet("Agent","SNMP","IPMI","JMX",1,2,3,4)]
				$Type = "Agent"
		)
		
		$Config = @{dns="";ip="";main=1;port=$Port;type=[int]$null;useip=1};
		
		#Transforma o tipo em n�mero!
		if($Type -is [string]){
			$i = 1;
			$Type = @("Agent","SNMP","IPMI","JMX") |  ? { if($Type -eq $_){return $true} else {$i++;return $false} } | %{$i};
		}
		
		$Config.type = $Type;
		
		
		if($IsIP){
			$Config.ip = [string]$Address;
		} else {
			$Config.dns = [string]$Address;
			$Config.useip = 0;
		}
		
		if($NoMain){
			$Config.main = 0;
		}
		
		
		return $Config;
		
	}

	
	#Converts a lot of host names to respectiv ids!
	#The returned object is a array of hashtable containing the hostid key.
	Function ConvertHostNames2Ids {
		param($Names, [switch]$ReturnNames = $false)
		
		verbose "ConvertHostNames2Ids: Castings groups to groups ids..."
		$HostIds = ZabbixAPI_List2Ids $Names { 
													param($HostNames) 
													
													$Found = @();
													
													$Found = Get-ZabbixHost -Name $HostNames -Output @('hostid','name') | %{
														New-Object PSObject -Prop @{id=$_.hostid;name=$_.name};
													}
													
													return $Found;
												};			
		
		$NewGroups = @();
		if($HostIds){
			 $HostIds | %{
				$NewId = @{hostid = [int]$_.id};
				
				if($ReturnNames){
					$NewId['name'] = $_.name;
				}
				
				$NewGroups += $NewId;
			 }
		} else {
			throw "GROUPS_NOT_FOUND: $Names";
		}	
		
		verbose "ConvertHostNames2Ids: Hosts add casted sucessfully!";
		return $NewGroups;
	}
	
	
	#Converts a lot of groups names to respectiv ids!
	#The returned object is a array of hashtable containing the groupid key.
	Function ConvertGroupNames2Ids {
		param($Names, [switch]$ReturnNames = $false)
		
		verbose "ConvertGroupNames2Ids: Castings groups to groups ids..."
		$GroupIds = ZabbixAPI_List2Ids $Names { 
													param($GroupNames) 
													
													$Found = @();
													
													$Found = Get-ZabbixHostGroup -Name $GroupNames -Output @('groupid','name') | %{
														New-Object PSObject -Prop @{id=$_.groupid;name=$_.name};
													}
													
													return $Found;
												};			
		
		$NewGroups = @();
		if($GroupIDs){
			 $GroupIDs | %{
				$NewId = @{groupid = [int]$_.id};
				
				if($ReturnNames){
					$NewId['name'] = $_.name;
				}
				
				$NewGroups += $NewId;
			 }
		} else {
			throw "GROUPS_NOT_FOUND: $Names";
		}	
		
		verbose "ConvertGroupNames2Ids: Groups add casted sucessfully!";
		return $NewGroups;
	}
	
	#Converts a lot of map names to respective ids!
	#The returned object is a array of hashtable containing the groupid key.
	Function ConvertMapNames2Ids {
		param($Names, [switch]$ReturnNames = $false)
		
		verbose "ConvertMapNames2Ids: Castings maps to groups ids..."
		$MapIds = ZabbixAPI_List2Ids $Names { 
													param($MapNames) 
													
													$Found = @();
													
													$Found = Get-ZabbixMap -Name $MapNames -output @('sysmapid','name') | %{
														New-Object PSObject -Prop @{id=$_.sysmapid;name=$_.name};
													}
													
													return $Found;
												};			
		
		$NewMaps = @();
		if($MapIds){
			 $MapIds | %{
				$NewID = @{sysmapid = [int]$_.id};
				if($ReturnNames){
					$NewID['name'] = $_.name;
				}
				$NewMaps += $NewID;
			 }
		} else {
			throw "MAPS_NOT_FOUND: $Names";
		}	
		
		verbose "ConvertGroupNames2Ids: Groups add casted sucessfully!";
		return $NewMaps;
	}
	
	
	#Generate a copy of object with just properties specified in hashtable and values.
	#This is useful for generating a object ready to be updated and discard other properties.
	Function Get-ObjectForUpdate {
		param(
			$Object
			
			,$ObjectType
			
			,[Alias("Props","Prop")]
			[string[]]$Properties = @()
		)
		
		#ID properties!
		[string[]]$IDProperty = @{
			host 			= 'hostid'
			template		= 'templateid'
			hostgroup		= 'groupid'
			hostinterface	= 'interfaceid'
			hostinventory	= @()
		}[$ObjectType]
		
		#Creates a new empty object!
		$Changed = $Object.psobject.copy();
		
		#For properties must be changed, and news one, add it.
		$Object.psobject.Properties | ? { -not ( $Properties+@($IDProperty)  -Contains $_.Name) } | %{
			$Changed.psobject.properties.remove($_.Name);
		}
		
		
		return $Changed;
	}

############# API cmdlets ###############
#######API implementations. Starting at this point, API implementation################

######### API INFO

	Function Get-ZabbixApiInfoVersion {
		[CmdLetBinding()]
		param(
			#Manually inform a URL. This is useful if you want test access to the URl before, for example, prompting credentials!
			$URL = $null
		)
		
		#Determinando searchByAny
		$APIParams = ZabbixAPI_NewParams "apiinfo.version" -NoAuth;
	
		#Builds the JSON string!
		verbose "Generating JSON"
		$APIString = ConvertToJson $APIParams;
		verbose "JSON: $APIString"
						
		#Chama a Url
		$resp = CallZabbixURL -data $APIString -Url $URL;
		$resultado = TranslateZabbixJson $resp;
		return [Version]$resultado;
	}

######### HOST
	
	#Get a host object, that represent a host!
	#Based on: https://www.zabbix.com/documentation/3.4/manual/api/reference/host/object#host
	Function Get-ZabbixHostObject {
		[CmdLetBinding()]
		param()
		
		return New-Object PsObject -Prop @{
			hostid = [string]$null
			host = [string]$null
			name = [string]$null
			status = [int]$null
		}
		
	}
 
	
	Function Get-ZabbixHost {
		<#
			.SYNOPSIS
				Obtém os hosts do zabbix
			
			.DESCRIPTION 
				Equivalente a API
				https://www.zabbix.com/documentation/3.4/manual/api/reference/host/get
		#>
		[CmdLetBinding()]
		param(
			 #Id do host. Pode ser 1 ou mais ids separados por vírgula.
				[int[]]$Id = @()
				
			,# Filtra pelo nome de exibição (Visible Name). Pode especificar vários separado por vírgula.
				[string[]]$Name = @()
				
			,# Filtr por hostname, pode especificar vários separado por vírgula
				[string[]]$Host = @()
				
			,# Filtrar por host group. Pode especificar vários separados por vírgula 
				[string[]]$Groups 		= @()
				
			,#Ativa o parâmetro common search 
				[switch]$Search 	   = $false
				
			,#Ativa o parâmetro searchByAny da api 
				[switch]$SearchByAny  = $false
				
			,#ATiva o parâmetro common StartSearch 
				[switch]$StartSearch  = $false
				
			,#Parâemtro common output 
				$output				= $null
				
			,#Query para selecionar host groups. Parãmetro selectGroups da api.
				$SelectGroups 			= $null
				
			,#Query para selecionar interfaces. Parãmetro selectInterfaces da API 
				$SelectInterfaces		= $null
				
			,#Query para selecionar inventory. Parãmetro selectInventory da API 
				$SelectInventory		= $null
				
			,$HostStatus			= $null
		)

				
		#Determinando searchByAny
		$APIParams = ZabbixAPI_NewParams "host.get"
		
		$propsFilter = @{};
		
		if($host){
			$filterHost=@();
			$host | %{
				$filterHost += [string]$_;
			}
			$propsFilter['host'] = $filterHost;
		} else {
			$filterName=@();
			$name | %{
				$filterName += [string]$_;
			}
			$propsFilter['name']=$filterName
		}
		
		ZabbixAPI_Get $APIParams -APIParams @{
					common = @{
							search 		= $Search 
							searchByAny = $SearchByAny
							startSearch = $StartSearch
							output		= $output
							"filter"	= $filter
						}
						
					props = $propsFilter
				}
				
		if($Host -and !$Search){
			$APIParams.params.filter["host"] = $Host;
			$APIParams.params.filter.remove("name");
		}

		if($Id){
			$APIParams.params.add("hostids", $Id)
		}
				
		if($SelectGroups){
			$APIParams.params.add("selectGroups", $SelectGroups)
		}
		
		if($SelectInterfaces){
			$APIParams.params.add("selectInterfaces", $SelectInterfaces)
		}
		
		if($SelectInventory){
			$APIParams.params.add("selectInventory", $SelectInventory)
		}
		
		if($HostStatus -ne $null){
			$APIParams.params.filter.add("status", ([int]$HostStatus) )
		}
		
		#If groups was specified, convert it to group names...
		if($Groups){
			verbose "Get-ZabbixHost: About to convert group names to ids"
			[hashtable[]]$GroupsID = ConvertGroupNames2Ids $Groups;
			[int[]]$groupsids = @($GroupsID | %{$_.groupid});
			$APIParams.params.add("groupids", $groupsids )
		}
				
		#Builds the JSON string!
		$APIString = ConvertToJson $APIParams;
						
		#Chama a Url
		$resp = CallZabbixURL -data $APIString;
		$resultado = TranslateZabbixJson $resp;
		
		
		$ResultsObjects = @();
		if($resultado){
			foreach($item in @($resultado)){
				$ResultsObjects += $item;	
			}
		}

		return $ResultsObjects;
	}


	#Equivalente ao m�todo da API host.create
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/hostgroup/create
	Function New-ZabbixHost {
		[CmdLetBinding()]
		param(
			$HostName
			,$VisibleName = $null
			,$Interfaces
			,$Groups = $null
			,$Templates = $null
		)

		
		$APIPArams = ZabbixAPI_NewParams "host.create";
		
		$APIPArams.params.add("host",$HostName);
		
		if($VisibleName){
			$APIPArams.params.add("name",$VisibleName);
		}
		
		$APIParams.params.add("interfaces",$interfaces);
		
		$AllGroups = @();
		if($Groups)	{
			$Groups | %{
				$AllGroups += @{groupid=$_.groupid};
			}
			$APIParams.params.add("groups", $AllGroups );
		}

		
		$AllTemplates = @();
		if($Templates){
			$Templates | %{
				$AllTemplates += @{templateid=$_.templateid};
			}
			$APIParams.params.add("templates", $AllTemplates );
		}
		
		
		$APIString = ConvertToJson $APIParams;
							
		#Chama a Url
		$resp = CallZabbixURL -data $APIString;
		$resultado = TranslateZabbixJson $resp;
		return $resultado
	}
	Set-Alias Create-ZabbixHost New-ZabbixHost

	#Equivalent to the method host.update.
	#In addition, added the option "Append". This option not exist in original API and is just a facility provided by this module.
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/host/update
	#You must pipe this from result of Get-ZabbixHost in order to use them.
	Function Update-ZabbixHost {
		[CmdLetBinding(SupportsShouldProcess=$True)]
		param(
			$Groups = $null
			
			,$Templates = $null
			
			,#If specified, the cmdlet will get existent groups and add to the list informed!
				[switch]$Append = $false

				
			,#If piped with Get-Zabibx host, get the returned object from it!
			 #Note that this cmdlet expects a object returned by Get-Zabbixhost cmdlet!
				[Parameter(ValueFromPipeline=$true, Mandatory=$true)]
				$ZabbixHost
		)

		begin {
			$AllHosts = @{};
			[hashtable[]]$NewsGroup = @();
			[hashtable[]]$NewTemplates = @();
			
			#If groups was specified, convert it to group names...
			if($Groups){
				verbose "Update-ZabbixHost: About to convert group names to ids"
				[hashtable[]]$NewsGroup = ConvertGroupNames2Ids $Groups;
				verbose "Update-ZabbixHost: Converted Groups: $($NewsGroup.values)"
			}
		
			if($Templates){
				$NewTemplates = $Templates | % { @{templateid=$_.templateid} }
			}
		
		}
		
		process {
		
			if($ZabbixHost){
				
				$ZabbixHost | %{
					$CurrentHost = $_;
					
					#Converts the object to a hashtable in order to avoid circular reference problem...
					$ObjectHashTable = @{};
					$CurrentHost.psobject.properties | %{ $ObjectHashTable.add($_.Name,$CurrentHost.psobject.properties[$_.Name].Value)  };
					
					#Add the groupids property if exists...
					if($NewsGroup){
						$ObjectHashTable.add("groups",$NewsGroup)
					}
					
					if($Templates){
						$ObjectHashTable.add("templates", $NewTemplates);
					}
					
					$AllHosts.add($CurrentHost.hostid, $ObjectHashTable);
				}
				
			} else {
				throw "INVALID_ZABBIX_HOST"
			}
		}
		
		end {
		
			#If appends specified, gets the groups for the hosts...
			if($Append){
				#Gets the groups for each host id!
				$Ids = $AllHosts.Values | %{$_.hostid};
				verbose "Update-ZabbixHost: Getting host info for append"
				$HostInfo = Get-ZabbixHost -SelectGroups @("groupid") -Id $Ids -Output @("hostid");
				
				if(!$HostInfo){
					throw "NO_HOSTS_FOUND: Getting groups for appending not returned any host object. Ids: $Ids"
				}
				
				verbose "Update-ZabbixHost: Hosts objects: $HostInfo"
				#Adds groups for each host!
				$HostInfo | %{
					$CurrentHost = $AllHosts[$_.hostid];
					$CurrentGroups = $_.groups;
					
					
					$CurrentHost.groups += @( $CurrentGroups | %{ @{groupid=$_.groupid}  }  )
				}
				
			}
		
			
		
			$APIParams = ZabbixAPI_NewParams "host.update";
			$APIParams.params = @($AllHosts.Values);
			
			verbose "Update-ZabbixHost: APIParams, before convert $APIParams"
			$APIString = ConvertToJson $APIParams;
			verbose "Update-ZabbixHost: APIString, before convert $APISTring"
			
			#Chama a Url
			$ConfirmMsg = @(
				"Hosts to be updated: $($AllHosts.count)"
				"JSON: "+(ConvertToJson @($AllHosts.Values))
			) -Join "`r`n"

			
			
			
			if($PSCmdLet.ShouldProcess($ConfirmMsg)){
				$resp = CallZabbixURL -data $APIString;
				$resultado = TranslateZabbixJson $resp;
			}
			

			return $resultado;
		}
	
	
	}

	#Equivalente ao m�todo da API host.massremove
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/host/massremove
	Function Remove-ZabbixHostMass {
		[CmdLetBinding(SupportsShouldProcess=$True)]
		param(
			$Groups = $null
			
			,#If piped with Get-Zabibx host, get the returned object from it!
			 #Note that this cmdlet expects a object returned by Get-Zabbixhost cmdlet!
				[Parameter(ValueFromPipeline=$true, Mandatory=$true)]
				$ZabbixHost
		)
		
		begin {
			$FUN = $MyInvocation.InvocationName;
		
		
			[int[]]$AllHosts = @();
			[int[]]$GroupsRemoveFrom = @();
			
			#If groups was specified, convert it to group names...
			if($Groups){
				verbose "$($FUN): About to convert group names to ids"
				[hashtable[]]$ConvertedGroups = ConvertGroupNames2Ids $Groups;
				verbose "$($FUN): Converted Groups: $($ConvertedGroups.values)"
				
				if($ConvertedGroups.count){
					$GroupsRemoveFrom = @($ConvertedGroups.Values)
				}
			}
		}
		
		process {
		
			if($ZabbixHost){
				
				$ZabbixHost | %{
					if(!$_.hostid){
						throw "INVALID_HOSTOBJECT_NOHOSTID";
					}
					
					$AllHosts += [int]$_.hostid;
				}
			} else {
				throw "INVALID_ZABBIX_HOST"
			}
		}
		
		end {

			$APIParams = ZabbixAPI_NewParams "host.massremove";
			$APIParams.params = @{
					hostids = $AllHosts
				}
				
			if($GroupsRemoveFrom){
				$APIParams.add("groupids",$GroupsRemoveFrom);
			}
			
			verbose "$($FUN): APIParams, before convert $APIParams"
			$APIString = ConvertToJson $APIParams;
			verbose "$($FUN): APIString, before convert $APISTring"
			
			#Chama a Url
			$ConfirmMsg = @(
				"Hosts to be updated: $($AllHosts.count)"
				"JSON: "+(ConvertToJson @($AllHosts))
			)

			if($APIParams.groupids){
				$ConfirmMsg += "Group Ids To remove: "+(ConvertToJson @($GroupsRemoveFrom))
			}
			
			$ConfirmMsg = $ConfirmMsg -Join "`r`n";
			
			if($PSCmdLet.ShouldProcess($ConfirmMsg)){
				$resp = CallZabbixURL -data $APIString;
				$resultado = TranslateZabbixJson $resp;
			}

			return $resultado;
		}
	
		
		
	}
 
	
######### HOSTGROUP	
	#Equivalente ao m�todo da API hostgroup.get
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/hostgroup/get
	Function Get-ZabbixHostGroup {
		[CmdLetBinding()]
		param(
			[string[]]$Name = @()
			,[switch]$Search 	   = $false
			,[switch]$SearchByAny  = $false
			,[switch]$StartSearch  = $false
			,[object]$selectHosts  		 	= $null
			,$Output			   = $null
		)

				
		#Determinando searchByAny
		$APIParams = ZabbixAPI_NewParams "hostgroup.get"
		ZabbixAPI_Get $APIParams -APIParams @{
					common = @{
							search 		= $Search 
							searchByAny = $SearchByAny
							startSearch = $StartSearch
							output		= $output
						}
						
					props = @{
						name = $Name 
					}
				}
		
		if($selectHosts){
			$APIParams.params.add("selectHosts", $selectHosts);
		}
		
		verbose "Get-ZabbixHostGroup: APIParams, before convert $APIParams"
		$APIString = ConvertToJson $APIParams;
		verbose "Get-ZabbixHostGroup: APIString, before convert $APISTring"
							
		#Chama a Url
		verbose "Get-ZabbixHostGroup:  calling zabbix url function..."
		$resp = CallZabbixURL -data $APIString;
		verbose "Get-ZabbixHostGroup:  response received! Calling translate..."
		$resultado = TranslateZabbixJson $resp;
		verbose "Get-ZabbixHostGroup:  Translated!"

		verbose "Objects generated = $($resultado.count)"
		return $resultado;
	}

	#Equivalente ao m�todo da API hosgroup.create
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/hostgroup/create
	Function New-ZabbixHostGroup {
		[CmdLetBinding()]
		param(
			[string[]]$Name
		)

		
		$APIPArams = ZabbixAPI_NewParams "hostgroup.create";
		
		$AllHostGroups = @();
		
		$Name | %{
			$AllHostGroups += @{name = [string]$_};
		}
		
		$APIParams.params = $AllHostGroups;
		
		
		$APIString = ConvertToJson $APIParams;
		verbose "Create-ZabbixHostGroup: APIString: $APIString"
							
		#Chama a Url
		$resp = CallZabbixURL -data $APIString;
		$resultado = TranslateZabbixJson $resp;
		return $resultado
	}
	Set-Alias Create-ZabbixHostGroup  New-ZabbixHostGroup
	
	#Equivalente ao m�todo da API hostgroup.massremove
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/hostgroup/massremove
	Function Remove-ZabbixHostGroupMass {
		[CmdLetBinding(SupportsShouldProcess=$True)]
		param(
			$Groups = $null
			
			,#If piped with Get-Zabibx host, get the returned object from it!
			 #Note that this cmdlet expects a object returned by Get-Zabbixhost cmdlet!
				[Parameter(ValueFromPipeline=$true, Mandatory=$true)]
				$ZabbixHost
		)
		
		begin {
			$FUN = $MyInvocation.InvocationName;
		
		
			[int[]]$AllHosts = @();
			[int[]]$GroupsRemoveFrom = @();
			
			#If groups was specified, convert it to group names...
			if($Groups){
				verbose "$($FUN): About to convert group names to ids"
				[hashtable[]]$ConvertedGroups = ConvertGroupNames2Ids $Groups;
				verbose "$($FUN): Converted Groups: $($ConvertedGroups.values)"
				
				if($ConvertedGroups.count){
					$GroupsRemoveFrom = @($ConvertedGroups.Values)
				}
			}
		}
		
		process {
		
			if($ZabbixHost){
				
				$ZabbixHost | %{
					if(!$_.hostid){
						throw "INVALID_HOSTOBJECT_NOHOSTID";
					}
					
					$AllHosts += [int]$_.hostid;
				}
			} else {
				throw "INVALID_ZABBIX_HOST"
			}
		}
		
		end {

			$APIParams = ZabbixAPI_NewParams "hostgroup.massremove";
			$APIParams.params = @{
					groupids = $GroupsRemoveFrom
					hostids = $AllHosts
				}
			
			verbose "$($FUN): APIParams, before convert $APIParams"
			$APIString = ConvertToJson $APIParams;
			verbose "$($FUN): APIString, before convert $APISTring"
			
			#Chama a Url
			$ConfirmMsg = @(
				"Hosts to be updated: $($AllHosts.count)"
				"JSON: "+(ConvertToJson @($AllHosts))
				"Group ids: "+(ConvertToJson @($GroupsRemoveFrom))
			) -Join "`r`n"

			
			if($PSCmdLet.ShouldProcess($ConfirmMsg)){
				$resp = CallZabbixURL -data $APIString;
				$resultado = TranslateZabbixJson $resp;
			}

			return $resultado;
		}
	
		
		
	}
 
	
######### TEMPLATE
	#Equivalente ao m�todo da API template.get
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/template/get
	Function Get-ZabbixTemplate {
		[CmdLetBinding()]
		param(
			$Name = @()
			,[switch]$Search 	   = $false
			,[switch]$SearchByAny  = $false
			,[switch]$StartSearch  = $false
		)

				
		#Determinando searchByAny
		$APIParams = ZabbixAPI_NewParams "template.get"
		ZabbixAPI_Get $APIParams -APIParams @{
					common = @{
							search 		= $Search 
							searchByAny = $SearchByAny
							startSearch = $StartSearch
						}
						
					props = @{
						name = $Name 
					}
				}		
		$APIString = ConvertToJson $APIParams;
							
		#Chama a Url
		$resp = CallZabbixURL -data $APIString;
		$resultado = TranslateZabbixJson $resp;
		
		return $resultado;
	}


######### EVENT
	#Equivalente ao m�todo da API event.get
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/event/get
	Function Get-ZabbixEvent {
		[CmdLetBinding()]
		param(
			 [int[]]$Id	= @()
			,[string[]]$Hosts 	= @()		
			,[string[]]$Groups  	= @()
			,[string[]]$ObjectId	= @()	
			,$TimeFrom 	= $null
			,$TimeTill	= $null
			
			,
				[ValidateSet("trigger","discovered host","discovered service","auto-registered host","item","LLD rule",0,1,2,3,4,5)]
				$Object				= $null
				
			,$Value					= '1' #PROBLEM
			,$selectHosts 			= $null
			,$selectRelatedObject	= $null
			,	
				[Alias("selectAcks")]
				$selectAcknowledges	= $null
				
			,$limit					= $null
			,$acknowledged			= $null
			
			,#Specify api params manually. It overrides any other defined here.
				$ManualParams			= @{}
			
			,#Try gets correlated event with this one.
			 #A correlated event is the event the OK or PROBLEM event associated with this.
			 #If passed object is a PROBLEM, the correlated is a OK.
			 #If passed object is a OK, the correlated is a PROBLEM. This always must exists (if not deleted by zabbix internal)
			 #YOu must pass a object or array of objects returned by this cmdlet.
			 #The cmdlet will add the property "correlated" to each object.
			 #This parameter is not provided by Zabbix API, and just it a enchament provided by this cmdlet.
			 #Note that for each object passed in this parameter, the cmdlet will make a call to zabbix. The number of calls to zabbix will be equals to number of objects.
			 #This can be slow.
				$Correlate = $null
		)

		
	
		#Determinando searchByAny
		[hashtable]$APIParams = ZabbixAPI_NewParams "event.get"
		ZabbixAPI_Get $APIParams -APIParams @{
					common = @{
							search 		= $false 
							searchByAny = $false
							startSearch = $false
							limit		= $limit
						}
				}
					
		if($Correlate){
			
			$Correlate  | %{
				if($_.value -eq 1) {
					#finds the OK. It must be a clock after this clock.
					$C = Get-ZabbixEvent -ObjectId $_.objectid -TimeFrom ([int]$_.clock + 1) -Value 0 -Limit 1
				} else {
					#finds the PROBLEM, It must be a clock current.
					$C = Get-ZabbixEvent -ObjectId $_.objectid -TimeTill ([int]$_.clock - 1) -Value 1 -Limit 1
				}
				
				$_ | Add-Member -Type Noteproperty -Name "correlated" -Value $C -force;
			
			}
			
			return;
		}
		else {
			
		
			if($Id){
				$APIParams.params.add("eventids", $Id ); 
			}
			
			if($ObjectId){
				$APIParams.params.add('objectids', $ObjectId);
			}
					
			if($TimeFrom){
				[string]$TimeFromFilter = "";
				if($TimeFrom -is [int]){
					$TimeFromFilter = $TimeFrom;
				} else {
					$TimeFromFilter = Datetime2Unix $TimeFrom;
				}
			
				$APIParams.params.add("time_from", $TimeFromFilter); 
			}
			
			if($TimeTill){
				[string]$TimeTillFilter = "";
				if($TimeTill -is [int]){
					$TimeTillFilter = $TimeTill;
				} else {
					$TimeTillFilter = Datetime2Unix $TimeTill;
				}
				
				$APIParams.params.add("time_till", $TimeTillFilter ); 
			}
			
			if($Value){
				$APIParams.params.add('value', $Value);
			}
			
			if($Hosts){
				verbose "Get-ZabbixEvent: Castings hosts to groups ids..."
				[hashtable[]]$HostsIds = ConvertHostNames2Ids $Hosts;
				[int[]]$hostids = @($HostsIds | %{$_.hostid});
				$APIParams.params.add("hostids", $hostids )
				verbose "Get-ZabbixEvent: Groups add casted sucessfully!"
			}
			
			if($Groups){
				verbose "Get-ZabbixEvent: Castings groups to groups ids..."
				[hashtable[]]$GroupsID = ConvertGroupNames2Ids $Groups;
				[int[]]$groupsids = @($GroupsID | %{$_.groupid});
				$APIParams.params.add("groupids", $groupsids )
				verbose "Get-ZabbixEvent: Groups add casted sucessfully!"
			}
			
			if($selectAcknowledges){
				$APIParams.params.add("select_acknowledges", $selectAcknowledges);
			}
			
			if($acknowledged -ne $null){
				$APIParams.params.add("acknowledged", [bool]$acknowledged);
			}
			
			if($Object){
				if($Object -is [string]){
					$i = 0;
					
					$Object = 'trigger','discovered host','discovered service','auto-registered host','item','LLD rule' | ?{
						if($_ -eq $Object){
							return $true;
						} else {
							$i++;return $false;
						}
					} | %{$i}
				}
			
				$APIParams.params.add("object", $object )
			}
			
			if($selectHosts){
				$APIParams.params.add("selectHosts", $selectHosts);
			}
			
			if($selectRelatedObject){
				$APIParams.params.add("selectRelatedObject", $selectRelatedObject);
			}
				

		}
		
		if($ManualParams){
			$ManualParams.GetEnumerator() | %{
				$APIParams.params[$_.Key] = $_.Value;
			}
			
		}
			
			
		verbose "Get-ZabbixEvent: About to generate json from apiparams!"
		$APIString = ConvertToJson $APIParams;
		verbose "JSON is: $APIString";
		
		#Chama a Url
		$resp = CallZabbixURL -data $APIString;
		$resultado = TranslateZabbixJson $resp;
		
		
		$ResultsObjects = @();
		if($resultado){
			$resultado | %{
				$r = $_
				
				#Adiciona o datetime local...
				if($r | gm "clock"){
					$r | Add-Member -Type Noteproperty -Name "datetime" -Value (UnixTime2LocalTime $r.clock)
				}
				
				#Adiciona as informa��es da trigger...
				if($r.object -eq 0 -and $r.relatedObject.description){
					$r | Add-Member -Type Noteproperty -Name "TriggerName" -Value $r.relatedObject.description
				}
				
				#Adiciona as informa��es da trigger...
				if($r.object -eq 0 -and $r.relatedObject.priority){
					$r | Add-Member -Type Noteproperty -Name "TriggerSeverity" -Value $r.relatedObject.priority
				}
				
				#Adiciona as informa��es do host...
				if($r.object -eq 0 -and $r.hosts.count -ge 1){
					if($r.hosts[0].name){
						$r | Add-Member -Type Noteproperty -Name "HostName" -Value $r.hosts[0].name
					}
					
				}
				
				$ResultsObjects += $r;
			}
		}

		return $ResultsObjects;
	}


	Function Confirm-ZabbixEvent {
		<#
			.SYNOPSIS 
				Equivalente ao método da API event.acknowledge
				
			.DESCRIPTION 
				https://www.zabbix.com/documentation/3.4/manual/api/reference/event/get
		#>
		[CmdLetBinding(SupportsShouldProcess=$True)]
		param(
			[parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
			[int]$EventId
			,[string]$Message
		)
		
		begin  {
			[int[]]$EventsIds = @();
		}
		
		process {
			$EventsIds += $EventId;
		}
		
		end {
			[hashtable]$AckParams = @{eventids=$EventsIds;message=$Message};
			[hashtable]$APIParams = ZabbixAPI_NewParams "event.acknowledge"
			$APIParams.params = $AckParams;
			$APIString = ConvertToJson $APIParams;
			verbose "Ack-ZabbixEvent: APIString: $APIString";
			
			
			#Chama a Url
			
			if($PSCmdLet.ShouldProcess("Events[$($EventsIds.count)]:$EventsIds")){
				verbose 'Ack-ZabbixEvent: Calling url...'
				$resp = CallZabbixURL -data $APIString;
				$resultado = TranslateZabbixJson $resp;
				verbose 'Ack-ZabbixEvent: Translatio finished...'
			}

			
			return $resultado;
		}
		
	}
	Set-Alias Ack-ZabbixEvent Confirm-ZabbixEvent 

######### TRIGGER

	Function Get-ZabbixTrigger {
		<#
			.SYNOPSIS 
				Equivalente ao método da API trigger.get
				
			.DESCRIPTION 
				https://www.zabbix.com/documentation/3.2/manual/api/reference/trigger/get
		#>
		[CmdLetBinding()]
		param(
			 [int[]]$Id	= @()
			,[string[]]$Hosts 	= @()		
			,[string[]]$Groups = @()	
			,[string[]]$Name = @()
			,[switch]$Search 	   = $false
			,[switch]$SearchByAny  = $false
			,[switch]$StartSearch  = $false
			,$limit = $null
			,$output				= $null
			,[switch]$Trigged		= $false
			,[switch]$NoExpand		= $false
		)

		
	
		#Determinando searchByAny
		[hashtable]$APIParams = ZabbixAPI_NewParams "trigger.get"
		ZabbixAPI_Get $APIParams -APIParams @{
					common = @{
							search 		= $Search 
							searchByAny = $SearchByAny
							startSearch = $StartSearch
							limit		= $limit
							output		= $output
						}
					
					props = @{
						description = $Name 
					}
				}

		if($Id){
			$APIParams.params.add("triggerids", $Id ); 
		}

		#If groups was specified, convert it to group names...
		if($Hosts){
			verbose "Get-ZabbixTrigger: About to convert host names to ids"
			[hashtable[]]$HostIDsObject = ConvertHostNames2Ids $Hosts;
			[int[]]$hostsids = @($HostIDsObject | %{$_.hostid});
			$APIParams.params.add("hostids", $hostsids )
		}

		#If groups was specified, convert it to group names...
		if($Groups){
			verbose "Get-ZabbixTrigger: About to convert group names to ids"
			[hashtable[]]$GroupsID = ConvertGroupNames2Ids $Groups;
			[int[]]$groupsids = @($GroupsID | %{$_.groupid});
			$APIParams.params.add("groupids", $groupsids )
		}
		
		if($Trigged){
			$APIParams.params.add('only_true',$true);
		}
		
		if(!$NoExpand){
			$APIParams.params.add('expandDescription',$false);
		}
		

		verbose "Get-ZabbixTrigger: About to generate json from apiparams!"
		$APIString = ConvertToJson $APIParams;
		verbose "JSON is: $APIString";

		#Chama a Url
		$resp = CallZabbixURL -data $APIString;
		TranslateZabbixJson $resp;
	}

	
	Function Update-ZabbixTrigger {
		<#
			.SYNOPSIS 
				Equivalente ao método trigger.update.
				
			.DESCRIPTION
				https://www.zabbix.com/documentation/3.2/manual/api/reference/trigger/update
				Utilize com Get-ZabbixTrigger:
				$MinhaTrigger = Get-ZabbixTrigger
				$MinhaTrigger.prop = newval
				$MinhaTrigger | Update-ZabbixTrigger
		#>

		[CmdLetBinding(SupportsShouldProcess=$True)]
		param(
			
			#If piped with Get-ZabbixTrigger, get the returned object from it!
			 #Note that this cmdlet expects a object returned by Get-ZabbixTrigger cmdlet!
				[Parameter(ValueFromPipeline=$true, Mandatory=$true)]
				$ZabbixTrigger
		)

		begin {
			$AllTriggers = @{};
		}
		
		process {
		
			if($ZabbixTrigger){
				
				$ZabbixTrigger | %{
					$CurrentTrigger = $_;
					
					#Converts the object to a hashtable in order to avoid circular reference problem...
					$ObjectHashTable = @{};
					$CurrentTrigger.psobject.properties | %{ $ObjectHashTable.add($_.Name,$CurrentTrigger.psobject.properties[$_.Name].Value)  };
					
					$AllTriggers.add($CurrentTrigger.triggerid, $ObjectHashTable);
				}
				
			} else {
				throw "INVALID_ZABBIX_TRIGGER"
			}
		}
		
		end {

			$APIParams = ZabbixAPI_NewParams "trigger.update";
			$APIParams.params = @($AllTriggers.Values);
			
			verbose "APIParams, before convert $APIParams"
			$APIString = ConvertToJson $APIParams;
			verbose "APIString, before convert $APISTring"
			
			#Chama a Url
			$ConfirmMsg = @(
				"Triggers to be updated: $($AllTriggers.count)"
				"JSON: "+(ConvertToJson @($AllTriggers.Values))
			) -Join "`r`n"

			if($PSCmdLet.ShouldProcess($ConfirmMsg)){
				$resp = CallZabbixURL -data $APIString;
				$resultado = TranslateZabbixJson $resp;
				return $resultado;
			}
		}
	
	
	}

	
######### MAP

	Function Get-ZabbixMap {
		<#
			.SYNOPSIS 
				Método map.get 
				
			.DESCRIPTION 
				https://www.zabbix.com/documentation/current/en/manual/api/reference/map/get
		#>
		param(
			 [int[]]$Id		 = @()
			,[string[]]$Name = @()
			,[switch]$Search 	   = $false
			,[switch]$SearchByAny  = $false
			,[switch]$StartSearch  = $false
			,$Output			   = $null
		)

				
		#Determinando searchByAny
		$APIParams = ZabbixAPI_NewParams "map.get"
		ZabbixAPI_Get $APIParams -APIParams @{
					common = @{
							search 		= $Search 
							searchByAny = $SearchByAny
							startSearch = $StartSearch
							output		= $output
						}
						
					props = @{
						name = $Name 
					}
				}
				
		if($Id){
			$APIParams.params.add('sysmapids', $Id);
		}
		
		verbose "APIParams, before convert $APIParams"
		$APIString = ConvertToJson $APIParams;
		verbose "APIString, before convert $APISTring"
							
		#Chama a Url
		verbose "Get-ZabbixMap:  calling zabbix url function..."
		$resp = CallZabbixURL -data $APIString;
		verbose "Get-ZabbixMap:  response received! Calling translate..."
		TranslateZabbixJson $resp;
	}

######### ALERT	

	Function Get-ZabbixAlert {
		<#
			.SYNOPSIS 
				Método alert.get
			
			.DESCRIPTION 
				https://www.zabbix.com/documentation/3.4/manual/api/reference/alert/get
			
		#>
		[CmdLetBinding()]
		param(
			 $name = $null
			,[int[]]$Id				= @()
			,$Hosts 				= @()		
			,$Groups  				= @()
			,$selectHosts 			= $null
			,$selectMediaTypes		= $null
			,$selectUsers			= $null
			,$limit					= $null
			,$timeFrom				= $null
			,$timeTill				= $null
			,$eventSource			= $null
			,$eventObject			= $null
			,[switch]$Search 	   = $false
			,[switch]$SearchByAny  = $false
			,[switch]$StartSearch  = $false
			,$output				= $null
			,[switch]$GetActionName	
		)

		
	
		#Determinando searchByAny
		[hashtable]$APIParams = ZabbixAPI_NewParams "alert.get"
		ZabbixAPI_Get $APIParams -APIParams @{
					common = @{
							search 		= $Search 
							searchByAny = $SearchByAny
							startSearch = $StartSearch
							limit		= $limit
							output		= $output
						}
				}

		if($Id){
			$APIParams.params.add("alertids", $Id ); 
		}
		
		if($Hosts){
			$NamesToConvert = @();
			[int[]]$hostids =  $Hosts | %{
				if($_.hostid){
					return $_.hostid;
				} else {
					if ($_ -is [string]){
						$NamesToConvert += $_;
					} else {
						return [int]$_;
					}
				}
			}
			
			if($NamesToConvert){
				verbose "Get-ZabbixItem: Castings hosts to groups ids..."
				[hashtable[]]$ConvertedHosts = ConvertHostNames2Ids $NamesToConvert;
				$hostids += @($ConvertedHosts | %{$_.hostid});
			}
		
			$APIParams.params.add("hostids", $hostids )
			verbose "Get-ZabbixItem: Groups add casted sucessfully!"
		}
		
		if($Groups){
			$NamesToConvert = @();
			[int[]]$groupsids =  $Groups | %{
				if($_.groupid){
					return $_.groupid;
				} else {
					if ($_ -is [string]){
						$NamesToConvert += $_;
					} else {
						return [int]$_;
					}
				}
			}
			
			if($NamesToConvert){
				verbose "Get-ZabbixItem: Castings hosts to groups ids..."
				[hashtable[]]$ConvertedGroups = ConvertGroupNames2Ids $NamesToConvert;
				$groupsids += @($ConvertedGroups | %{$_.groupid});
			}
		
			$APIParams.params.add("groupids", $groupsids )
			verbose "Get-ZabbixItem: Groups add casted sucessfully!"
		}

		
		if($selectHosts){
			$APIParams.params.add("selectHosts", $selectHosts);
		}
		
		if($selectMediaTypes){
			$APIParams.params.add("selectMediaTypes", $selectMediaTypes);
		}
				
		if($selectUsers){
			$APIParams.params.add("selectUsers", $selectUsers);
		}
		
		if($timeFrom){
			$APIPArams.params.add("time_from", (MakeZabbixDatetime $timeFrom))
		}
		
		if($timeTill){
			$APIPArams.params.add("time_till", (MakeZabbixDatetime $timeTill))
		}
		
		if($eventSource -ne $null){
			$APIPArams.params.add("eventsource", $eventSource)
		}
			
		if($eventobject -ne $null){
			$APIPArams.params.add("eventobject", $eventobject)
		}
		
		verbose "Get-ZabbixAlert: About to generate json from apiparams!"
		$APIString = ConvertToJson $APIParams;
		verbose "JSON is: $APIString";
		
		#Chama a Url
		$resp = CallZabbixURL -data $APIString;
		$resultado = TranslateZabbixJson $resp;
		
		
		$ResultsObjects = @();
		if($resultado){
			$Actions = @{}
			if($GetActionName){
				$AllActions = $resultado | %{$_.actionid}
				Get-ZabbixAction -Id $AllActions -output 'id','name' | % {
					$Actions[$_.actionid] = $_;
				}
			}
		
			$resultado | %{
				$r = $_;
				
				if($GetActionName){
					$r | Add-Member -Type Noteproperty -Name "ActionName" -Value $Actions[$_.actionid].name	
				}
				
				if($r | gm "clock"){
					$r | Add-Member -Type Noteproperty -Name "datetime" -Value (UnixTime2LocalTime $r.clock)
				}
				
				#Adiciona as informa��es do host...
				if($r.hosts.count -ge 1){
					if($r.hosts[0].name){
						$r | Add-Member -Type Noteproperty -Name "HostName" -Value $r.hosts[0].name
					}
					
				}
				
				$ResultsObjects += $r;
			}
		}
		

		return $ResultsObjects;
	}

	
######### ACTION	

	Function Get-ZabbixAction {
		<#
			.SYNOPSIS 
				Método action.get
			
			.DESCRIPTION
				https://www.zabbix.com/documentation/current/en/manual/api/reference/action/get
		#>
		[CmdLetBinding()]
		param(
			 [int[]]$Id				= @()
			,$Hosts 				= @()		
			,$Groups  				= @()
			,$selectFilter 					= $null
			,$selectOperations				= $null
			,$selectRecoveryOperations		= $null
			,$selectAcknowledgeOperations	= $null
			,$limit					= $null
			,[switch]$Search 	   = $false
			,[switch]$SearchByAny  = $false
			,[switch]$StartSearch  = $false
			,$output				= $null
		)

		
	
		#Determinando searchByAny
		[hashtable]$APIParams = ZabbixAPI_NewParams "action.get"
		ZabbixAPI_Get $APIParams -APIParams @{
					common = @{
							search 		= $Search 
							searchByAny = $SearchByAny
							startSearch = $StartSearch
							limit		= $limit
							output		= $output
						}
				}

		if($Id){
			$APIParams.params.add("actionids", $Id ); 
		}
		
		if($Hosts){
			$NamesToConvert = @();
			[int[]]$hostids =  $Hosts | %{
				if($_.hostid){
					return $_.hostid;
				} else {
					if ($_ -is [string]){
						$NamesToConvert += $_;
					} else {
						return [int]$_;
					}
				}
			}
			
			if($NamesToConvert){
				verbose "Get-ZabbixItem: Castings hosts to groups ids..."
				[hashtable[]]$ConvertedHosts = ConvertHostNames2Ids $NamesToConvert;
				$hostids += @($ConvertedHosts | %{$_.hostid});
			}
		
			$APIParams.params.add("hostids", $hostids )
			verbose "Get-ZabbixItem: Groups add casted sucessfully!"
		}
		
		if($Groups){
			$NamesToConvert = @();
			[int[]]$groupsids =  $Groups | %{
				if($_.groupid){
					return $_.groupid;
				} else {
					if ($_ -is [string]){
						$NamesToConvert += $_;
					} else {
						return [int]$_;
					}
				}
			}
			
			if($NamesToConvert){
				verbose "Get-ZabbixItem: Castings hosts to groups ids..."
				[hashtable[]]$ConvertedGroups = ConvertGroupNames2Ids $NamesToConvert;
				$groupsids += @($ConvertedGroups | %{$_.groupid});
			}
		
			$APIParams.params.add("groupids", $groupsids )
			verbose "Get-ZabbixItem: Groups add casted sucessfully!"
		}

		
		if($selectFilter){
			$APIParams.params.add("selectFilter", $selectFilter);
		}
		
		if($selectOperations){
			$APIParams.params.add("selectOperations", $selectOperations);
		}
				
		if($selectRecoveryOperations){
			$APIParams.params.add("selectRecoveryOperations", $selectRecoveryOperations);
		}
		
		if($selectAcknowledgeOperations){
			$APIParams.params.add("selectAcknowledgeOperations", $selectAcknowledgeOperations);
		}
		
		verbose "Get-ZabbixAction: About to generate json from apiparams!"
		$APIString = ConvertToJson $APIParams;
		verbose "JSON is: $APIString";
		
		#Chama a Url
		$resp = CallZabbixURL -data $APIString;
		TranslateZabbixJson $resp;
	}

	
######### ITEM	

	Function Get-ZabbixItem {
		<#
			.SYNOPSIS 
				Equivalente ao método da API item.get
				
			.DESCRIPTION 
				https://www.zabbix.com/documentation/current/en/manual/api/reference/item/get
		#>
		[CmdLetBinding()]
		param(
			 $name = $null
			,[int[]]$Id				= @()
			,$Hosts 				= @()		
			,$Groups  				= @()
			,$selectHosts 			= $null
			,$selectTriggers		= $null
			,$limit					= $null
			,[switch]$Search 	   = $false
			,[switch]$SearchByAny  = $false
			,[switch]$StartSearch  = $false
			,$output				= $null
		)

		
	
		#Determinando searchByAny
		[hashtable]$APIParams = ZabbixAPI_NewParams "item.get"
		ZabbixAPI_Get $APIParams -APIParams @{
					common = @{
							search 		= $Search 
							searchByAny = $SearchByAny
							startSearch = $StartSearch
							limit		= $limit
							output		= $output
						}
						
						
					props = @{
						name = $Name 
					}
				}

			
		
		if($Id){
			$APIParams.params.add("itemids", $Id ); 
		}
		
		if($Hosts){
			$NamesToConvert = @();
			[int[]]$hostids =  $Hosts | %{
				if($_.hostid){
					return $_.hostid;
				} else {
					if ($_ -is [string]){
						$NamesToConvert += $_;
					} else {
						return [int]$_;
					}
				}
			}
			
			if($NamesToConvert){
				verbose "Get-ZabbixItem: Castings hosts to groups ids..."
				[hashtable[]]$ConvertedHosts = ConvertHostNames2Ids $NamesToConvert;
				$hostids += @($ConvertedHosts | %{$_.hostid});
			}
		
			$APIParams.params.add("hostids", $hostids )
			verbose "Get-ZabbixItem: Groups add casted sucessfully!"
		}
		
		if($Groups){
			$NamesToConvert = @();
			[int[]]$groupsids =  $Groups | %{
				if($_.groupid){
					return $_.groupid;
				} else {
					if ($_ -is [string]){
						$NamesToConvert += $_;
					} else {
						return [int]$_;
					}
				}
			}
			
			if($NamesToConvert){
				verbose "Get-ZabbixItem: Castings hosts to groups ids..."
				[hashtable[]]$ConvertedGroups = ConvertGroupNames2Ids $NamesToConvert;
				$groupsids += @($ConvertedGroups | %{$_.groupid});
			}
		
			$APIParams.params.add("groupids", $groupsids )
			verbose "Get-ZabbixItem: Groups add casted sucessfully!"
		}

		
		if($selectHosts){
			$APIParams.params.add("selectHosts", $selectHosts);
		}
		
		if($selectTriggers){
			$APIParams.params.add("selectTriggers", $selectTriggers);
		}
				

			
		verbose "Get-ZabbixItem: About to generate json from apiparams!"
		$APIString = ConvertToJson $APIParams;
		verbose "JSON is: $APIString";
		
		#Chama a Url
		$resp = CallZabbixURL -data $APIString;
		TranslateZabbixJson $resp;
	}


	Function New-ZabbixItem {
		<#
			.SYNOPSIS 
				Equivalente ao método da API item.create 
				
			.DESCRIPTION 
				https://www.zabbix.com/documentation/current/en/manual/api/reference/item/create
				Propriedades: 
					https://www.zabbix.com/documentation/current/en/manual/api/reference/item/object
		#>
		[CmdLetBinding(SupportsShouldProcess=$true)]
		param(
			$HostName
			,$Name = $null
			,$Key
			,#The type.
				[ValidateSet("Agent","SNMPv1","Trapper","Simple","SNMPv1","Internal","SNMPv3","Active","Aggregate"
							,"Web","External","Database","IPMI","SSH","Telnet","Calculated","JMX","SNMPTrap","Dependent"
							,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
				)]
				$Type
			,[ValidateSet("Float","Char","Log","Unsigned","Text",0,1,2,3,4)]
				$ValueType
			,#The params
			 [Alias("Formula")]
			 [string]$Params = $null

			,[string]
			[Alias("UpdateInterval")]
				$Delay
				
			,$ManualParams = $null
		)


		#Parsing type...
		if($Type -is [string]){
			$i = 0;
			$Type = @("Agent","SNMPv1","Trapper","Simple","SNMPv1","Internal","SNMPv3","Active","Aggregate"
			,"Web","External","Database","IPMI","SSH","Telnet"
			,"Calculated","JMX","SNMPTrap","Dependent") | ? { if($Type -eq $_){return $true} else {$i++;return $false} } | %{$i};
		}

		#Parsing value type...
		if($ValueType -is [string]){
			$i = 0;
			$ValueType = @("Float","Char","Log","Unsigned","Text") | ? { if($ValueType -eq $_){return $true} else {$i++;return $false} } | %{$i};
		}
		
		$APIPArams = ZabbixAPI_NewParams "item.create";
		
		$APIPArams.params.add("name",$Name);
		$APIPArams.params.add("key_",$Key);
		$APIPArams.params.add("type",$Type);
		$APIPArams.params.add("value_type",$ValueType);

		
		if($HostName -is [string]){
			verbose "$($MyInvocation.InvocationName): Castings host to ids..."
			[hashtable[]]$ConvertedHosts = ConvertHostNames2Ids $HostName;
			verbose "$($MyInvocation.InvocationName): Groups add casted sucessfully!"
			$APIParams.params.add("hostid", $ConvertedHosts[0].hostid);
		} else {
			$APIParams.params.add("hostid", [int]$HostName);
		}


		if($Params){
			$APIPArams.params.add("params",$Params);
		}

		$Suffix2SecondMultiplier = @{
			"s" = 1
			"m"	= 60
			"h"	= 3600
			"d"	= 86400
			"w"	= 604800
		}

		if($Delay){

			#If contains a unit, convert to seconds!
			if( $Delay -match "(\d+)([smhdw])" ){
				$DelayNumber 	= [int]$matches[1];
				$Multiplier  	= [int]$Suffix2SecondMultiplier[$matches[2]]
				$DelaySeconds 	= $DelayNumber * $Multiplier;
			} else {
				$DelaySeconds = [int]$Delay;
			}

			$APIPArams.params.add("delay",$DelaySeconds);
		}

		if($ManualParams){
			$ManualParams.GetEnumerator() | %{
				$APIParams.params[$_.Key] = $_.Value;
			}
			
		}
		
		verbose "$($MyInvocation.InvocationName): About to generate json from apiparams!"
		$APIString = ConvertToJson $APIParams;
		verbose "$($MyInvocation.InvocationName): Generated!"
	
							
		#Chama a Url
		$ConfirmMsg = @(
			"Item to be created: $($AllHosts.count)"+(ConvertToJson @($APIParams.params))
		) -Join "`r`n";

		if($PSCmdLet.ShouldProcess($ConfirmMsg)){
			$resp = CallZabbixURL -data $APIString;
			$resultado = TranslateZabbixJson $resp;
			return $resultado;
		}
	}
	Set-Alias Create-ZabbixItem  New-ZabbixItem 
	
	#
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/item/create
	#Properties: https://www.zabbix.com/documentation/3.4/manual/api/reference/item/object#host
	Function Remove-ZabbixItem {
		<#
			.SYNOPSIS 
				Equivalente ao método da API item.delete
				
			.DESCRIPTION 
				https://www.zabbix.com/documentation/current/en/manual/api/reference/item/delete
		#>
		[CmdLetBinding(SupportsShouldProcess=$true)]
		param(
			[Parameter(ValueFromPipeline=$true, Mandatory=$true)]
			$ZabbixItem
			,[switch]$Force = $false
		)
		
		begin {
			$AllItems = @()
		}
		
		process {
			$AllItems += [int]$ZabbixItem.itemid;
		}
		
		end {
			$APIPArams = ZabbixAPI_NewParams "item.delete";
			$APIPArams.params = $AllItems;
			
			verbose "$($MyInvocation.InvocationName): About to generate json from apiparams!"
			$APIString = ConvertToJson $APIParams;
			verbose "$($MyInvocation.InvocationName): Generated!"
		
							
			#Chama a Url
			$ConfirmMsg = @(
				"Items to be deleted: $($AllItems.count)"+(ConvertToJson @($APIParams.params))
				"ZABBIX JSON: $APIString"
			) -Join "`r`n";

			if($PSCmdLet.ShouldProcess($ConfirmMsg) -and $Force){
				$resp = CallZabbixURL -data $APIString;
				$resultado = TranslateZabbixJson $resp;
				return $resultado;
			}
		}
	}
	Set-Alias Delete-ZabbixItem Remove-ZabbixItem
	
######### HISTORY	
	#
	#https://www.zabbix.com/documentation/2.0/manual/appendix/api/history/get
	Function Get-ZabbixHistory {
		<#
			.SYNOPSIS 
				Equivalente ao método da API history.get
				
			.DESCRIPTION 
				https://www.zabbix.com/documentation/current/en/manual/api/reference/history/get
		#>
		[CmdLetBinding()]
		param(
			 [int]$history 	= $null
			,$Hosts 	= @()		
			,$Items		= @()
			,$TimeFrom 	= $null
			,$TimeTill	= $null
			,$limit		= $null
		)

		
		#Determinando searchByAny
		[hashtable]$APIParams = ZabbixAPI_NewParams "history.get"
		ZabbixAPI_Get $APIParams -APIParams @{
					common = @{
							search 		= $false 
							searchByAny = $false
							startSearch = $false
							limit		= $limit
						}
				}
					
		if($TimeFrom){
			[string]$TimeFromFilter = "";
			if($TimeFrom -is [int]){
				$TimeFromFilter = $TimeFrom;
			} else {
				$TimeFromFilter = Datetime2Unix $TimeFrom;
			}
		
			$APIParams.params.add("time_from", $TimeFromFilter); 
		}
		
		if($TimeTill){
			[string]$TimeTillFilter = "";
			if($TimeTill -is [int]){
				$TimeTillFilter = $TimeTill;
			} else {
				$TimeTillFilter = Datetime2Unix $TimeTill;
			}
			
			$APIParams.params.add("time_till", $TimeTillFilter ); 
		}

		if($Hosts){
			$NamesToConvert = @();
			[int[]]$hostids =  $Hosts | %{
				if($_.hostid){
					return $_.hostid;
				} else {
					if ($_ -is [string]){
						$NamesToConvert += $_;
					} else {
						return [int]$_;
					}
				}
			}
			
			if($NamesToConvert){
				verbose "Get-ZabbixHistory: Castings hosts to groups ids..."
				[hashtable[]]$ConvertedHosts = ConvertHostNames2Ids $NamesToConvert;
				$hostids += @($ConvertedHosts | %{$_.hostid});
			}
		
			$APIParams.params.add("hostids", $hostids )
			verbose "Get-ZabbixHistory: Groups add casted sucessfully!"
		}
		
		if($Items){
			[int[]]$itemids = @();
			
			$Items | %{
				if($_.itemid){
					$itemids += $_.itemid
				} else {	
					$itemids += [int]$_;
				}
			}
			
			$APIParams.params.add("itemids", $itemids )
		}
		
		if($history){
			$APIParams.params.add("history", $history )
		}

		verbose "Get-ZabbixHistory: About to generate json from apiparams!"
		$APIString = ConvertToJson $APIParams;
		verbose "JSON is: $APIString";
		
		#Chama a Url
		$resp = CallZabbixURL -data $APIString;
		TranslateZabbixJson $resp;
	}

	
######### SCRIPT	

	Function Get-ZabbixScript {
		<#
			.SYNOPSIS 
				Equivqles the API script.get
				
			.DESCRIPTION 
				https://www.zabbix.com/documentation/current/en/manual/api/reference/script/get
		#>
		[CmdLetBinding()]
		param(
			 [int[]]$Id	= @()
			,$Hosts 	= @()		
			,$Groups  	= @()
			,$limit		= $null
			,$output	= $null
			,$ManualParams = $null
		)

		
		#Determinando searchByAny
		[hashtable]$APIParams = ZabbixAPI_NewParams "script.get"
		ZabbixAPI_Get $APIParams -APIParams @{
					common = @{
							search 		= $false 
							searchByAny = $false
							startSearch = $false
							limit		= $limit
							output		= $output
						}
				}
					
		if($Id){
			$APIParams.params.add("scriptids", $Id); 
		}

		if($Hosts){
			$NamesToConvert = @();
			[int[]]$hostids =  $Hosts | %{
				if($_.hostid){
					return $_.hostid;
				} else {
					if ($_ -is [string]){
						$NamesToConvert += $_;
					} else {
						return [int]$_;
					}
				}
			}
			
			if($NamesToConvert){
				verbose "$($MyInvocation.InvocationName): Castings hosts to groups ids..."
				[hashtable[]]$ConvertedHosts = ConvertHostNames2Ids $NamesToConvert;
				$hostids += @($ConvertedHosts | %{$_.hostid});
			}
		
			$APIParams.params.add("hostids", $hostids )
			verbose "$($MyInvocation.InvocationName): Groups add casted sucessfully!"
		}
		
		if($Groups){
			$NamesToConvert = @();
			[int[]]$groupsids =  $Groups | %{
				if($_.groupid){
					return $_.groupid;
				} else {
					if ($_ -is [string]){
						$NamesToConvert += $_;
					} else {
						return [int]$_;
					}
				}
			}
			
			if($NamesToConvert){
				verbose "$($MyInvocation.InvocationName): Castings hosts to groups ids..."
				[hashtable[]]$ConvertedGroups = ConvertGroupNames2Ids $NamesToConvert;
				$groupsids += @($ConvertedGroups | %{$_.groupid});
			}
		
			$APIParams.params.add("groupids", $groupsids )
			verbose "$($MyInvocation.InvocationName): Groups add casted sucessfully!"
		}

		#Applymanual params!
		if($ManualParams){
			$ManualParams.GetEnumerator() | %{
				$APIParams.params[$_.Key] = $_.Value;
			}
		}

		verbose "$($MyInvocation.InvocationName): About to generate json from apiparams!"
		$APIString = ConvertToJson $APIParams;
		verbose "JSON is: $APIString";
		
		#Chama a Url
		$resp = CallZabbixURL -data $APIString;
		TranslateZabbixJson $resp;
	}

	Function Invoke-ZabbixScript {
		<#
			.SYNOPSIS 
				Equivale a API script.execute
				
			.DESCRIPTION 
				https://www.zabbix.com/documentation/current/en/manual/api/reference/script/execute
		#>	


		[CmdLetBinding(SupportsShouldProcess=$True)]
		param(
			 [parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
			 [Alias("Id")]
				 [int]$ScriptID
			
			,[Alias("Host")]
				[string]$ZabbixHost
			
			,$ManualParams = $null
		)

		#Determinando searchByAny
		[hashtable]$APIParams = ZabbixAPI_NewParams "script.execute"
				

		if($ScriptID){
			$APIParams.params.add("scriptids", $ScriptID); 
		}

		if($ZabbixHost){
			$NamesToConvert = @();
			[int[]]$hostids =  $ZabbixHost | %{
				if($_.hostid){
					return $_.hostid;
				} else {
					if ($_ -is [string]){
						$NamesToConvert += $_;
					} else {
						return [int]$_;
					}
				}
			}
			
			if($NamesToConvert){
				verbose "$($MyInvocation.InvocationName): Castings hosts to groups ids..."
				[hashtable[]]$ConvertedHosts = ConvertHostNames2Ids $NamesToConvert;
				$hostids += @($ConvertedHosts | %{$_.hostid});
			}
		
			$APIParams.params.add("hostid", $hostids )
			verbose "$($MyInvocation.InvocationName): Hosts add casted sucessfully!"
		}

		#Applymanual params!
		if($ManualParams){
			$ManualParams.GetEnumerator() | %{
				$APIParams.params[$_.Key] = $_.Value;
			}
		}

		verbose "$($MyInvocation.InvocationName): About to generate json from apiparams!"
		$APIString = ConvertToJson $APIParams;
		verbose "JSON is: $APIString";
		
		#Chama a Url
		if($PSCmdLet.ShouldProcess("Run script $ScriptID on $ZabbixHost")){
			verbose "$($MyInvocation.InvocationName): Calling url..."
			$resp = CallZabbixURL -data $APIString;
			$resultado = TranslateZabbixJson $resp;
			verbose "$($MyInvocation.InvocationName): Translation finished..."
		}
		
		
		$ResultsObjects = @();
		if($resultado){
			$resultado | %{
				$r = New-Object PSObject -Prop $_;
				$ResultsObjects += $r;
			}
		}

		return $ResultsObjects;
	}

	
######### User

	#Logouts current session!
	Function Disconnect-Zabbix {
		[CmdLetBinding()]
		param(
			#Explicity token to be unathenticated! If not specified, uses the default!
			$token = $null
		)
		
		$APIParams = ZabbixAPI_NewParams "user.logout";
		
		if($token){
			verbose "$($MyInvocation.InvocationName): Changing the logout session from $($APIParams.auth) to $token";
			$APIParams.auth = $token
		}
		
		#Builds the JSON string!
		verbose "$($MyInvocation.InvocationName): Generating JSON"
		$APIString = ConvertToJson $APIParams;
		verbose "$($MyInvocation.InvocationName): JSON: $APIString"
						
		#Chama a Url
		$resp = CallZabbixURL -data $APIString -Url $URL;
		$resultado = TranslateZabbixJson $resp;
		
		if($resultado -eq $true){
			return;
		} else {
			throw "LOGOUT_ERROR: logout result not expected!";
		}
	}
	Set-Alias Invoke-LogoutUser Disconnect-Zabbix
	
	
############# FRONTEND cmdlets ###############
#######Starting at this point, some calls to frontend to workaround some functionality that API dont support.################

######### MAP

	#This allows get a map.
	#The cmdlet must be used in conjuction with the Get-ZabbixMap cmdlet.
	#It will add the property 'mapImage' to the object returned from this cmdlet.
	#This property will contains the following properties:
	#
	#	bytes (the bytes of map. Just write to a file)
	#	errro (possible errors ocurred when getting map from zabbix)
	Function Add-ZabbixFrontendMapImage {
		[CmdLetBinding()]
		param(
		
			#Must return this object with Get-ZabbixMap cmdlet
			#The return objects must include at least sysmapid propertie.
			[parameter(Mandatory=$true,ValueFromPipeline=$true)]
			[object]$Map
			
			,$MinSeverity 	= 5

			,$File			= $null
		)
		
		begin {
			#Get last authentication of frontned!
			$DefaultSession 	= Get-DefaultZabbixSession;
			$FrontendSession 	= $DefaultSession.FrontendSession;
			$LastURL			= $DefaultSession.Url;
			#Full URL to the map!
			$AccessURL = "$LastURL/map.php?sysmapid={0}&severity_min=$MinSeverity";
		}
		
		process  {
			if(!$Map){
				return;
			}
		
			$MapURL = $AccessURL -f $_.sysmapid;
			$MapImage = New-Object PSObject;
			$MapImage | Add-Member -Name bytes -Type Noteproperty -Value $null
			$MapImage | Add-Member -Name error -Type Noteproperty -Value $null
			$Map | Add-Member -Name mapImage -Type Noteproperty -Value $MapImage;
			
			if(!$Map.sysmapid){
				$MapImage.error = 'sysmapid property not found!';
				return;
			}
		
			
			verbose "Accessing the map $($_.name) on url $MapURL";
			$HttpResp = InvokeHttp -URL $MapURL -Session $FrontendSession;
			
			try {
				if($HttpResp.httpResponse.statusCode -eq 200){
					$MapImage.bytes = $HttpResp.raw;
				} else {
					$MapImage.error = "HTTP ERROR: StatusCode:$($HttpResp.httpResponse.statusCode)";
				}
			} catch {
				$MapImage.error = $_;
			}

			if($MapImage.bytes -and $File){
				verbose "$($MyInvocation.InvocationName): Writing bytes to file $File";
				[Io.File]::WriteAllBytes($File, $MapImage.bytes);
			}
		}
		
		end {
			verbose "Done";
		}
	}
	Set-Alias -Name Add-ZabbixMapImage -Value Add-ZabbixFrontendMapImage;



Export-ModuleMember -Function *-* -Alias *