#Módulo para o powershell!


#Verifica se um assembly já foi carregado!
Function CheckAssembly {
	param($Name)
	
	if($Global:PowerZabbix_Loaded){
		return $true;
	}
	
	if( [appdomain]::currentdomain.getassemblies() | ? {$_ -match $Name}){
		$Global:PowerZabbix_Loaded = $true
		return $true;
	} else {
		return $false
	}
}

Function LoadJsonEngine {

	$Engine = "System.Web.Extensions"

	if(!(CheckAssembly Engine)){
		try {
			Add-Type -Assembly  $Engine
			$Global:PowerZabbix_Loaded = $true;
		} catch {
			throw "ERROR_LOADIING_WEB_EXTENSIONS: $_";
		}
	}

}

Function ConvertToJson($o) {
	LoadJsonEngine

	
	$jo=new-object system.web.script.serialization.javascriptSerializer
    return $jo.Serialize($o)
}

Function ConvertFromJson([string]$json) {
	LoadJsonEngine
	$jo=new-object system.web.script.serialization.javascriptSerializer
    return $jo.DeserializeObject($json)
}


#Faz uma chamada para a API do zabbix!
Function CallZabbixURL([object]$data = $null,$url = $null,$method = "POST", $contentType = "application/json-rpc"){
	$ErrorActionPreference="Stop";
	
	try {
		if($data -is [hashtable]){
			$data = ConvertToJson $data;
		}
		
		if($Global:PowerZabbix_ZabbixUrl -and !$url){
			$url = $Global:PowerZabbix_ZabbixUrl;
		}
		
		if($url -NotLike "*api_jsonrpc.php" ){
			if($url -NotLike "*/"){
				$url += "/"
			}
			
			$url += "api_jsonrpc.php"
		}
		

		write-verbose "CallZabbixURL: Creating WebRequest method... Url: $url. Method: $Method ContentType: $ContentType";
		$Web = [System.Net.WebRequest]::Create($url);
		$Web.Method = $method;
		$Web.ContentType = $contentType
		
		#Determina a quantidade de bytes...
		[Byte[]]$bytes = [byte[]][char[]]$data;
		
		#Escrevendo os dados
		$Web.ContentLength = $bytes.Length;
		write-verbose "CallZabbixURL: Bytes lengths: $($Web.ContentLength)"
		
		
		write-verbose "CallZabbixURL: Getting request stream...."
		$RequestStream = $Web.GetRequestStream();
		$RequestStream.Write($bytes, 0, $bytes.length);
		
		
		write-verbose "CallZabbixURL: Making http request... Waiting for the response..."
		$HttpResp = $Web.GetResponse();
		
		$responseString  = $null;
		
		if($HttpResp){
			write-verbose "CallZabbixURL: Getting response stream..."
			$ResponseStream  = $HttpResp.GetResponseStream();
			
			$IO = New-Object System.IO.StreamReader($ResponseStream);
			
			write-verbose "CallZabbixURL: Reading response stream...."
			$responseString = $IO.ReadToEnd();
		}
		
		return $responseString;
	} catch {
		throw "ERROR_CALLING_ZABBIX_URL: $_";
	} finally {
		if($IO){
			$IO.close()
		}
		
		if($ResponseStream){
			$ResponseStream.Close()
		}
		
		<#
		if($HttpResp){
			write-host "Finazling http request stream..."
			$HttpResp.finalize()
		}
		#>

	
		if($RequestStream){
			write-verbose "Finazling request stream..."
			$RequestStream.Close()
		}
	}
}


#Trata a resposta enviada pela API do zabbix.
#Em caso de erros, uma expcetion será tratada. Caso contrário, um objeto contendo a resposta será retornado.
Function TranslateZabbixJson {
	param($ZabbixResponse)
	
	#Cria um objeto contendo os campos da resposta!
	$ZabbixResponseO = ConvertFromJson $ZabbixResponse;
	
	#Se o campo "error" estiver presente, significa que houve um erro!
	#https://www.zabbix.com/documentation/3.0/manual/api
	if($ZabbixResponseO.error){
		$ZabbixError = $ZabbixResponseO.error;
		$MessageException = "[$($ZabbixError.code)]: $($ZabbixError.data). Details: $($ZabbixError.data)";
		$Exception = New-Object System.Exception($MessageException)
		$Exception.Source = "ZabbixAPI"
		throw $Exception;
		return;
	}
	
	
	#Caso contrário, o resultado será enviado
	return $ZabbixResponseO.result;
}


#Guarda as informações de conexão com o Zabbix na memória da sessão para uso com os outros comandos!
Function Set-ZabbixConnection($url, $user, $password) {
	$Global:PowerZabbix_ZabbixUrl 		= $url
	$Global:PowerZabbix_ZabbixUser 		= $user
	$Global:PowerZabbix_ZabbixPassword 	= $password
}

#Gera um id para as requisições da api DO ZABBIX
Function  GetNewZabbixApiId {
	return [System.Guid]::NewGuid().Guid.ToString()
}

#Autentica no Zabbix. As informações de autenticação serão guardadas na sessao para autenticação posterior!
Function Auth-Zabbix {
	[CmdLetBinding()]
	param(
			 $User 		= $null
			,$Password	= $null
			,$URL 		= $null
		)

	
	#Se o usuário não foi informado, então tenta obter do cache!
	if(!$User){
		$User 		= $Global:PowerZabbix_ZabbixUser
		$Password 	= $Global:PowerZabbix_ZabbixPassword
		
		#Se ainda continuar sem usuário, pergunta para o usuário!
		if(!$User){
			$Creds = Get-Credential
			$NC = $Creds.GetNetworkCredential();
			$User = $NC.UserName
			$Password = $NC.Password;
		}
	}
		
		
	#Monta o objeto de autenticação
	[string]$NewId = GetNewZabbixApiId;
	$AuthString = ConvertToJson @{
							jsonrpc = "2.0"
							method	= "user.login"
							params =  @{
										user 		= $User
										password	= $Password
									}
							id = $NewId
							auth = $null
						}
						
	#Chama a Url
	$resp = CallZabbixURL -data $AuthString;
	$resultado = TranslateZabbixJson $resp;

	if($resultado){
		$Global:PowerZabbix_Auth = $resultado;
		return;
	}
}

#Obtém o token de autenticação se existe. Caso contrário, chama a função de auth!
Function GetZabbixApiAuthToken {
	if( $Global:PowerZabbix_Auth ){
		return $Global:PowerZabbix_Auth;
	} else {
		Auth-Zabbix;
		
		if(!$Global:PowerZabbix_Auth){
			throw 'INVALID_AUTH_TOKEN'
			return;
		}
		
		return $Global:PowerZabbix_Auth;
	}
}


#Retorna uma hashtable para ser usada na comunicação com a apu
Function ZabbixAPI_NewParams {
	param($method)
	
	[string]$token = GetZabbixApiAuthToken;
	[string]$NewId = GetNewZabbixApiId;
	
	
	$APIParams =  @{
					jsonrpc = "2.0"
					auth 	= $token
					id 		= $NewId
					method	= $method
					params 	=  @{}
				}
				
	return $APIParams
}


#Função genérica usada para chamar o método get de diversos elementos!
#Retorna uma hashtable contendo as informações baseadas no filtro!
#Assim, os usuários da mesma podem fazer alterações se necessário!!!
#APIParams @{common=@{};props=@{}}
Function ZabbixAPI_Get {
	param(
		[hashtable]$Options
		,$APIParams = @{}
	)
	
	#Determinando searchByAny
	if($APIParams.common.searchByAny){
		$Options.params.add("searchByAny", $true);
	}
	
	if($APIParams.common.startSearch){
		$Options.params.add("startSearch", $true);
	}
				
	#Determinando se iremos usar search ou filter pra buscar...
	if($APIParams.common.search){
		$Options.params.add("searchWildcardsEnabled",$true);
		$Options.params.add("search",@{
									name = $APIParams.props.name
							});
	} else {
		$Options.params.add("filter",@{
									name = $APIParams.props.name
							});
	}
	
	return;
}



############# Aux cmdlets ###############
#######Cmdlets auxiliares que podem ser usados para facilitar a interação com a API, mas que não são implementações da mesma!################
	
	#Retorna uma hashtable com as configurações para a interface a ser usada com o cmdlet Create-ZabbixHost
	#Para mais informações verifique o link https://www.zabbix.com/documentation/3.4/manual/api/reference/hostinterface/object
	Function Get-InterfaceConfig {
		param(
			#Pode ser um nome DNS ou IP. O que vai determinar o tipo é a presença ou não do parâmetro -IsIP
			$Address = $null
			
			,#Porta da interface. 
				$Port = 10050
				
			,#Indica que a interface não é a padrão!
			 #Neste caso, a propriedade main será marcada como 0.
				[switch]$NoMain 	= $false

			,#Indica se o valor em Address é um IP. Se sim, a interface será configurada como IP.
				[switch]$IsIP		= $False
			
			
			,#Tipo da interface. Pode se usar o nome ou id. Verifique o link para os ids!
				[ValidateSet("Agent","SNMP","IPMI","JMX",1,2,3,4)]
				$Type = "Agent"
		)
		
		$Config = @{dns="";ip="";main=1;port=$Port;type=$null;useip=1};
		
		#Transforma o tipo em número!
		if($Type -is [string]){
			$i = 1;
			$Type = @("Agent","SNMP","IPMI","JMX") |  ? { if($Type -eq $_){return $true} else {$i++;return $false} } | %{$i};
		}
		
		$Config.type = $Type;
		
		
		if($IsIP){
			$Config.ip = $Address;
		} else {
			$Config.dns = $Address;
			$Config.useip = 0;
		}
		
		if($NoMain){
			$Config.main = 0;
		}
		
		
		return $Config;
		
	}


############# API cmdlets ###############
#######API implementations. A partir daqui, segue as implementações da API################

######### HOST
	#Equivalente ao método da API host.get
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/host/get
	Function Get-ZabbixHost {
		[CmdLetBinding()]
		param(
			$Name = @()
			,[switch]$Search 	   = $false
			,[switch]$SearchByAny  = $false
			,[switch]$StartSearch  = $false
		)

				
		#Determinando searchByAny
		$APIParams = ZabbixAPI_NewParams "host.get"
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
		
		
		$ResultsObjects = @();
		if($resultado){
			$resultado | %{
				$ResultsObjects += NEw-Object PSObject -Prop $_;	
			}
		}

		return $ResultsObjects;
	}


	#Equivalente ao método da API host.create
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/hostgroup/get
	Function Create-ZabbixHost {
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
		
		
		$ResultsObjects = @();
		if($resultado){
			$resultado | %{
				$ResultsObjects += NEw-Object PSObject -Prop $_;	
			}
		}

		return $ResultsObjects;
	}


######### HOSTGROUP
	#Equivalente ao método da API hostgroup.get
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/hostgroup/get
	Function Get-ZabbixHostGroup {
		[CmdLetBinding()]
		param(
			$Name = @()
			,[switch]$Search 	   = $false
			,[switch]$SearchByAny  = $false
			,[switch]$StartSearch  = $false
		)

				
		#Determinando searchByAny
		$APIParams = ZabbixAPI_NewParams "hostgroup.get"
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
		
		
		$ResultsObjects = @();
		if($resultado){
			$resultado | %{
				$ResultsObjects += NEw-Object PSObject -Prop $_;	
			}
		}

		return $ResultsObjects;
	}

	
######### TEMPLATE
	#Equivalente ao método da API template.get
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
		
		
		$ResultsObjects = @();
		if($resultado){
			$resultado | %{
				$ResultsObjects += NEw-Object PSObject -Prop $_;	
			}
		}

		return $ResultsObjects;
	}


	
	
	