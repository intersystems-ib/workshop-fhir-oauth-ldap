# workshop-fhir-oauth-ldap
Using a FHIR repository, OAuth2 framework and LDAP integration with InterSystems IRIS for Health.

This is the base setup for using InterSystems IRIS for Health Community Edition as a FHIR Server. 
It will create the following containers:
* Webserver (apache)
* InterSystems IRIS for Health (FHIR Server + Authentication Server)
* OpenLDAP (LDAP Server)
* phpLDAPAdmin (LDAP UI)

## Prerequisites
Make sure you have [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git), [Docker desktop](https://www.docker.com/products/docker-desktop) and [postman](https://www.postman.com/) installed.

## Installation 

Clone/git pull the repo into any local directory

```
$ git clone https://github.com/
```

Open the terminal in this directory and run:

```
$ docker-compose up -d
```

## Patient data
The template goes with 6 preloaded patents in [/data/fhir](https://github.com/) folder which are being loaded during build process.
Should you need/want to generate more patients refer to the [following project](https://github.com/intersystems-community/irisdemo-base-synthea)

## SSL Configuration
Webserver instance is properly secured using a set of certificate/key. You'll find a SSL/TLS Configuration alerady available on InterSystems IRIS for Health. You don't need to create any other configuration. 

## Testing FHIR R4 API

Open URL https://localhost/fhir/r4/metadata
you should see the output of fhir resources on this server

## Testing Postman calls
Get fhir resources metadata
GET call for http://localhost/fhir/r4/metadata
<img src="img/W24 - FHIR Metadata.png" width="400px">


Open Postman and make a GET call for the preloaded Patients:
https://localhost/fhir/r4/Patient
<img src="img/W24 - Get All Patients.png" width="400px">


## Testing InterSystems IRIS for Health to LDAP Server connection
Go to System Administration -> Security -> System Security -> LDAP/Kerberos Configurations 
Select Create New LDAP/Kerberos configuration 
User the following data:
*   Login Domain Name: devcom.com
*   LDAP configuration: check
*   LDAP host names: ldap.devcom.com 
*   LDAP search username DN: cn=admin
*   LDAP username password (Enter new password): StrongAdminPassw0rd
*   LDAP Base DN to use for Username searches: DC=devcom,DC=com
*   LDAP Base DN to use for Nested Groups searches: DC=devcom,DC=com
*   LDAP Unique search attribute: uid

Once finished you can test connection.
Go to Go to System Administration -> Security -> System Security -> LDAP/Kerberos Configurations 
Select Test LDAP Authentication
User the following data:
*   Username: cuser01@devcom.com
*   Password: 12345
As result you should see somewhere along the output: "User cuser01 authenticated".
<img src="img/W24 - LDAP Conn Test.jpg" width="400px">

# OAuth2 Configuration #

## OAuth2 Server ##
Go to Management Portal -> System Administration -> Security -> OAuth 2.0 -> Server.
Let's start with Settings in General tab:
*   Issuer endpoint - Host name: webserver
*   Issuer endpoint - Prefix:	authserver
*   Supported grant types:	we'll only use “Authorization Code”. Let's also add other “Grant Types”: "Client credentials" and “JWT authorization”
*   SSL/TLS configuration:	webserver
<img src="img/W24 - OAuth Server General.png" width="400px">

Let's move on with Settings in Scopes tab:
Create a simple example:
*   scope: user/*.*	
*   description: user access to all scope
*   Allow unsupported scope 
<img src="img/W24 - OAuth Server Scopes.png" width="400px">

Let's keep the default Settings in the Intervals tab.
In the JWT Settings tab, let’s use “RS512” as the signature algorithm.
<img src="img/W24 - OAuth Server JWT.png" width="400px">

For the Personalization tab, let's change the Generate Token Class specification to %OAuth2.Server.JWT.
<img src="img/W24 - OAuth Server Personalization.png" width="400px">

Click Save button to save the configuration.
We're almost there! Let’s finish configuration and try accessing it from Postman to check if we can get an access token!
Let's add a client description
We need to add the information of Postman to be accessed as an OAuth2 client. OAuth2 client registration may be added through dynamic registration - let's use it. 
Click - Client Description - on the server configuration page.
<img src="img/W24 - OAuth Server Client DynReg.png" width="400px">
Let's - Create Client Description - to add an entry. Start with Settings in the General tab:	
*   Name: postman
*   Client Type: Confidential
*   Redirect URLs - Click on the Add URL button: https://webserver/authserver/csp/sys/oauth2/OAuth2.Response.cls
*   Supported grant types: Specify the same as configured for the OAuth2 authorization server settings. Authorization Code, JWT authorization and Client Credentials
*   Authenticated Signing Algorithm: RS512
<img src="img/W24 - OAuth Server Postman Client.png" width="400px">
Click the Save button to save the client description.
Click on - Client Credentials tab - to see the client ID and secret. You will need this information when testing from postman.
<img src="img/W24 - postman credentials.png" width="600px">

## Adding Web Application ##
To ensure a correct access and handle to this configuration endpoint we need to create a web application to this URL path - https://webserver/authserver/oauth2

Go to System Administration -> Security -> Applications -> Web Applications, and click “Create a new web application”.

To avoid misconfiguration you should use the provided template. First, select "/oauth2" in the "Copy from" dropdown. Then, do the following:

**“Edit Web Application” settings**	
Copy From	“/oauth2” : Always select this one first from the pull-down.
Name	/authserver/oauth2
Enable	Check the “REST” radio button.

<img src="img/W24 - WebbApp for OAuth Conf.png" width="600px">

After entering each value, save it. 

# Configure/Get Access Token from postman
We'll use postman. Should you rather use other framework, feel free to do so. You can import provided postman collection available on /misc. Let's assume a postman configuration from scratch. 

The detailed explanation of postman is beyond the scope of this workshop. Please note that SSL certificate verification should be changed to OFF in postman Settings.

After creating a new request in postman, let's say - retrieve all patients  https://webserver/fhir/r4/Patient - select “OAuth 2. 0” in the TYPE of Authorization tab and configure a new token:
Parameter       |   Value
----------------|-----------------------------------
Token Name	    |   You can enter any name you want
Grant Type	    |   Authorization Code
Callback URL	|   https://webserver/authserver/csp/sys/oauth2/OAuth2.Response.cls
Auth URL	    |   https://localhost/authserver/oauth2/authorize
Auth Token URL	|   https://localhost/authserver/oauth2/token
Client ID	    |   Enter the client ID displayed in the Client Credentials tab 
Client Secret	|   Enter the client’s private key, displayed in the Client Credentials tab
Scope	        |   user/*.read (at the moment, it doesn't matter)
State	        |   It is not explicitly used but cannot be left blank, so we enter an arbitrary string.

Click “Get New Access Token”.
When requesting a New Access Token you'll be requested login to the Authentication Server, as shown below:

<img src="img/W24 - Auth Server Login.png" width="600px">

IRIS for Health also comply with OpenID Connect authentication processing. To do so you'll have to add "openid” to the requested scopes. You'll get and extra token - **id_token**.  

## Specifying OAuth Client Name for the FHIR Repository ##
 You already have a FHIR Repository properly configured. Nontheless, you'll have to specify a OAuth Client Name for it. To do so, go to  Health -> FHIR Configuration -> Server Configuration, select /fhir/r4 endpoint and edit the configuration. Do the following:

Parameter           |   Value
--------------------|-----------------------------------
OAuth Client Name	    |   FHIRResourceServer 

Save it.

## OAuth Client Configuration ##
In the previous setp we gave it a name but we didn't create it. Let's do so.
Go to System Administration -> Security -> OAuth2.0 in the Management Portal and select “Client” instead of “Server”, unlike before.

On the next screen, click on “Create Server Description” to create the configuration for connecting to the OAuth2 authorization server. USe the following values:

Parameter               |   Value
------------------------|--------------------------------------  
Issuer endpoint	        |   https://webserver/authserver/oauth2 
SSL/TLS condiguration   |   webserver

<img src="img/W24 - OAuth Server Description.png" width="600px">

Run “Discover and Save” to get the information from the OAuth2 authorization server. If the access is successful, the information obtained will be displayed, as shown below.

<img src="img/W24 - Cient Auth Discovery.png" width="600px">

## Add client configuration to OAuth2 client ##
In this step we'll add the client configuration (information about the specific Application - FHIR Repository - that we want to connect to the OAuth2 authorization server as an OAuth2 client) to the OAuth2 client configuration we've just created (with information about which OAuth2 authorization server to connect to).

On the OAuth2 Client page click “Create Client Configuration” to display the following screen and set the necessary parameters.

Parameter               |   Value
------------------------|--------------------------------------  
Application Name        |   FHIRResourceServer 
Client Name             |   FHIRResourceServerClient
Description             |   Description for this Client
Type of client          |   Resource Server
SSL/TLS configuration   |   webserver

Click on the “Dynamic Registration and Save” button to save and register the file to the server.
When the button changes from “Dynamic Registration and Save” to “Get Update Metadata and Save”, the registration has been successful.

Let’s confirm the configuration on the Authorization Server side and check if it is registered.

On the Management Portal -> System Administration -> Security Management -> OAuth2.0→Server page, click on “Client Description”, and you will see that it is registered as shown below

<img src="img/W24 - OAuth Server Clients.png" width="600px">

## Accessing the FHIR repository from postman ##
We need to get an access token adding an audience parameter to indicate where the access token can be used. To do so, change the following postman parameter: 

<img src="img/W24 - postman Aud.png" width="600px">


# LDAP Configuration #
This kind of configuration is out of the scope of this workshop. We'll simply load/use a very simple configuration - for demonstration purposes. This configuration does not comply with best practices nor should be seen as a possible configuration for a real system. 

To set up oepnLDAP we'll use phpLDAPadmin. To do so, go to: https://localhost:10443/, login using the following data:
Parameter           |   Value
--------------------|-----------------------------------
Login DN    	    |   cn=admin,dc=devcom,dc=com
Password            |   StrongAdminPassw0rd

Once loggedin you cal load testing configuration. You can do it by importing the content of ldap-init.ldif file located in /misc. Your phpLDAPadmin should look like this:

<img src="img/W24 - phpLDAPadmin.png" width="600px">

## Delegate OAuth2 Authorization and Authentication to openLDAP Server ##

Load the [ValidateLDAP.cls](http://XXX) file to your IRIS for Health (acting as OAuth2 Server). To do so, open VSCode, connect to the server/namespace (FHIRSERVER) and compile this class. Once you've done so, you can change the OAuth2 Server Customization to:
Parameter               |   Value
------------------------|--------------------------------
Validate user class     |   demo.ValidateLdap
Customization namespace |   FHIRSERVER          
Customization roles     |   add %DB_FHIRSERVER

You should see a configuration just like this:

<img src="img/W24 - OAuth2+LDAP Personsalization.png" width="600px">

You should be all set!

## Troubleshooting
**ERROR #5001: Error -28 Creating Directory /usr/irissys/mgr/FHIRSERVER/**
If you see this error it probably means that you ran out of space in docker.
you can clean up it with the following command:
```
docker system prune -f
```
And then start rebuilding image without using cache:
```
docker-compose build --no-cache
```
and start the container with:
```
docker-compose up -d
```
