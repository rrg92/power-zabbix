![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/powerzabbix)
![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/powerzabbix)

# PowerZabbix

* [english](/docs/en-US/START-README.md)

O PowerZabbix é um módulo powershell que encapsula as chamadas da API do Zabbix, permitindo você invocar diretamente do Powershell, usando os recursos do powershell, como pipeline, etc.  

Com alguns poucos comandos, você pode automatizar a criação de hosts, hosts grups, itens, etc.  

**IMPORTANTE: Este projeto ficou parado por algum tempo, e agora resolvi atualizá-lo novamente. Ainda existem muitos endpoints e documentação. Estou ciente das issues que foram abertas. Se você sabe powershell e quiser contribuir, estou aceitando ajudas para me ajudar a manter esse projeto atualizado!**

PowerZabbix allows query zabbix data via the zabbix api and access frontend using powershell code!
In addition to the cmdlets that represent API calls, this tool adds some other cmdlets and parameters to enhance de user experience with zabbix API.

It is easy start managing zabbix, gathering data to generate custom reports, download maps, etc. with this tool! Check examples section to ideas.


## Instalação  


A forma mais simples de instalar o powerzabbix é usando o comando `Install-Module powerzabbix`:

```powershell 
Install-Module powerzabbix
```  


Caso voce tenha problemas, pode fazer um clone desse repositório e importá-lo:

```powershell
cd C:\temp
git clone https://github.com/rrg92/power-zabbix
cd power-zabbix 
import-module .\powerzabbix 
```

**IMPORTANTE: Você pode precisar habilitar a execução de scripts no seu ambiente, com Set-ExecutionPolicy**
	
	
## Uso básico

Antes de usar este módulo, é importante ter o seguinte em mãos:

- A URL zabbix (certifique-se que é acessível a partir do seu computador. Ex.: teste a autenticação no navegador antes)
- Usuário/Senha ou uma API Token

Então, a primeira coisa a se fazer é autenticar:

```powershell
import-module powerzabbix # obviamente, deve importar o modulo na sessão!

# Utilize o comando Connect-Zabbix para autenticar!
Connect-Zabbix 'http://IpOrDNS'

# As credenciais serão solicitadas!
# Apos autenticar, voce pode usar os comandos, como por exemplo:
Get-ZabbixHost # listar os hosts!

```

O comando Connect-Zabbix é o ponto de partida para autenticação.  
Você pode especificar vários formatos de URL e até uma API Token. Saiba mais sobre usando `get-help Connect-Zabbix`.  

### Várias sessões 

Você pode criar várias conexões, com diferentes servidores zabbixes, ou com o mesmo servidor usando usuaros diferentes.
Porém, somente uma destas sessões estão ativas por vez (isso pode mudar em breve):

```powershell

# Cria duas sessoes 
$s1 = Connect-Zabbix -URL 'https://ZabbixHost1/zabbix';
$s2 = Connect-Zabbix -URL 'https://ZabbixHost2/zabbix';

# Define a sessao retornada em $2 como default:
$s2 | Set-DefaultZabbixSession

#verifica a default!
Get-DefaultZabbixSession
```

### Exemplo: Listando e atualizando hosts

O comando `Get-ZabbixHost` é o principal para obter a lista de hosts.  
Ele é equivalente ao método host.get da API. Muitos parâmetros já foram adicionados, e, os demais serão adicionados:

```powershell

# Obter um host com um id específico
Get-ZabbixHost -Id 10084


# Obter todos os hosts do grupo "DATABASE"
Get-ZabbixHost -Groups 'TEST'

# Obter todos os hosts que estão no grupo MSSQL ou POSTGRES
Get-ZabbixHost -Groups 'MSSQL','POSTGRES'

# Todos os hosts do grupo LINUX, retornando apenas as propriedades hostid, hostname and visible name.
Get-ZabbixHost -Groups 'LINUX'  -output 'hostid','host','name'

# O próximo exemplo é um pouco mais complexo se você não está acosumtado com powershell
# Primeiro, nós armazenamos todos os hosts do grupo WINDOWS em uma variável.
# Isso é útil se você precisar acessar esses dados várias vezes 
# Ao invés de ficar consultando isso no zabbix toda hora, você salva isso na sua sessão do powershell!
# Graças ao parâmetro -output, nós retornamos apenas poucos dados da api.
$AllHosts = Get-ZabbixHost -Groups 'WINDOWS' -output 'hostid','host'

# Suponha que voce queria atualizar todos os nomes de host do WINDOWS group. 
# Por exemplo, voce quer adicionar o prefix "WIN-" no início. ]
# Isso seria simples para fazer em 10 hosts. Mas em 1000, as coisas podem complicar um pouco...
# Vamos supor que o resultado do comando anterior contenha essa lista. Entao, primeiro, adicionamos o prefixo com um simples comanod foreach (%), do powershell:
$AllHosts | %{  $_.host = "WIN-"+$_.host };

# O comando acima é apenas powershell, nada em especial. Ele itera sobre o array de hosts em $Allhosts, e para cada um, altera a proprioedade host.

#Até aqui, atualizamos somente na memória da nossa sessão!
# Para efetivar isso no abbix, precisamos usar o comando Update-ZabbixHost
# Podemos usar o pipe para passar os valores.
# E, antes de atualizar, o parâmetro -WhatIf pode ser usado para apenas simular o que aconteceria:
$AllHosts | Update-ZabbixHost -WhatIf

#e, uma vez que voce confirmou, basta executar!
$AllHosts | Update-ZabbixHost;


# Para mostrar mais algumas facilidades do PowerZabbix, considere este exemplo:
#	Nós queremos adicionar um monte de hosts para um hostgroup
#	A API não define um jeito de adicionar grupos ao um host. Ela espera uma lista completa que sobrescreverá a lista anterior.
#	For exemplo, imagine que um host A pertence aos grupos 1,13,40,20,59 e um host B pertence ao grupo 1 e 2. Você quer adicionar esses hosts no grupo 100.
# Para fazer isso, voce teria que fazer o seguinte usando a API:
#	Obter a lista atual
#	Adicionar o novo id 
#	invocar o metodo host.update coma  lista atualizada.
#
# O cmdlet Update-ZabbixHost simplifica isso, graças ao parâmetro -Append
$LotOfHosts = Get-ZabbixHost -output @('hostid')

# Adiciona ao grupo MY_NEW_GROUP
$LotOfHosts | Update-ZabbixHost -Groups 'MY_NEW_GROUP' -append

#To show you the enhacements and facilites provided to PowerZabbix, consider this example.
# We want add a lot of hosts to a hostgroup!
# The API dont define a way to append hosts groups to the hosts.
# The API expects that you inform all groups ids when updating a hostgroup for a host.
# For example, supposed the host A belongs to groupsids 1,13,40,20,59 and host B belongs to group 1 and 2. You want add this host to the group 100.
# By default, the api expects you specify new groups ids, that will replace current groups ids.
# In order to complete this task using just api, for each host, you must do this:
#		1) Get the current groups ids
#		2) Add new groups ids
#		3) Call host.update method passing the complete list (older + new groups)
# The Update-ZabbixHost simplifie this actions with -Append parameter. Just specify the groups in the -Groups paraemter and the magic happens!

# Here we get all hosts. Is not important the groups...
# note that specify the unique property 'hostid'. This is because we not need any property to do this...
# The @('hostid') is need due to fact we specify a unique value and the API expects this as array. With this, we ask to powershell to treat this values as array, not a string...


# Dica ao usar comandos Update-*
# A maioria destes comandos espera o retorno do cmdlet respectivo Get-*
# Use o parâmetro -output do comando Get-*, para trazer somente o que você precisa atualizar. Isso reduz o tráfego desnecessário e ajuda aliviar seu zabbix e banco.
```

## Nomenclatura

A mairia dos comandos são wrappers para a API do zabbix, com a possiblidade opcções adicionais para facilitar o uso.  
Sabendo disso, fica mais fácil encontrar um comando para sua necessidade:

### Comandos que implementa a API diretamente  

Existe um grupo de comandos que implementam as funcionalidades diretas da API.
Eles possuem parâmetros e um comportamento muito próximo ao do método respectivo da API. 
O formato é:

	Verbo + -Zabbix + ObjectCamelCaseName
	
	
* Verbo  
A ação. Geralmente é a segunda parte. Por exemplo, host.get, será Get-ZabbixHost.  
Nem toda ação tem um verbo aprovado direto no powershell, então, o verbo aprovado mais próximo será usado.  
Por exemplo, host.create não fica Create-ZabbixHost, e sim New-ZabbixHost, porque o nonme Create não é aprovado como um verbo powershell.  
Porém, para que seja intuitivo, alias podem ser criados.

* -Zabbix = É uma string fixa. Todo comando exportado do módulo powerzabbix deve ter essa string no nome.  

* ObjectCamelCaseName  
Este é padrão camel case do objeto respectivo em que a api faz efeito.  Por exemplo, hostgroup.get fica Get-ZabbixHostGroup. 


Alguns exemplos:

* Get-ZabbixHost => host.get
* Update-Zabbixhost => host.update 
* New-ZabbixHostGroup => hostgroup.create
* Confirm-ZabbixEvent => event.acknowledge
* Remove-ZabbixItem => item.delete

### FRONTEND

Algumas funcionalidades do zabbix não são fornecidas pela API, e sim pelo frontend.  
Por exemplo, o donwload das imagens dos mapas não é possível pela API. É uma feature do frontend.  
Por se rque, em uma determinada versão, se tenha suporte.  

Porém, para prover o máximo de experiência no powerzabbix, usamos alguns hacks para conseguir trazer a funcionalidade de frontend pra linha de comando.  
É importante saber que, devido a essa natureza, dependendo da versão do seu zabbix, se atualizar, por exemplo, essas implementações podem falhar.  
Se for este o seu caso, abra issues para que possamos rapidamente avaliar alternarivas e correções.  

Para manter separadamente da implementação da API oficial, os comandos do frontend seguem esse padrão de formato:

	Verbo + -ZabbixFrontEnd + ObjectCamelCaseName
	
Examplos:

* Add-ZabbixFrontendMapImage => Adiciona os bytes do mapa retornado por Get-ZabbixMap.

```powershell
# obtém um obejto mapa!
$MyMap = Get-ZabbixMap -Name "topologia da minha rede"

# gera a iomagem do mapa com severidade 3, e adicioa os bytes da imagem no objeto!
$MyMap | Add-ZabbixFrontendMapImage -Minseverity 3

# Agora, é so escrever em um arquivo!
[Io.File]::WriteAllBytes('C:\temp\maps.png', $MyMap.mapImage.bytes);
```

### cmdlets Auxiliares

Alguns cmdlets nao necessariamente interagem com a API, implementam algo da API, mas complemetam criando objetos ou facilitando a criação de estrutras complexas:


Examples:

* Get-ZabbixSessions	=> lista sessoes
* Get-InterfaceConfig	=> facilita a criacao de um objeto interface , para ser usado com New-ZabbixHost
	

## Explore

Use `Get-Command -Module powerzabbix`c para ver todos os comandos
Use `Get-Help -full NomeComando` para obter help sobre o comando!  
A cada nova versão, iremos melhorar mais ainda a documentação destes comandos com detalhes e exemplos.


## Contribua  

Você pode contriubuir com o powerzabbix de várias menrias:

- Pode ajudar sugerindo melhorias e complementos da documentação 
- Pode sugerir novas funcionalidades 
- pode enviar pull requests com correções 
- Pode ajudar sinalizando quando novos recursos das novas versões do zabbix forem lançadas 

Utilize as issues!












