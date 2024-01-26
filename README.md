# workshop-fhir-oauth-ldap
Using a FHIR repository, OAuth2 framework and LDAP integration with InterSystems IRIS for Health.

This is the base setup for using InterSystems IRIS for Health Community Edition as a FHIR Server. 
It will create the following containers:
* Webserver (apache)
* InterSystems IRIS for Health (FHIR Server + Authentication Server)
* OpenLDAP (LDAP Server)
* phpLDAPAdmin (LDAP UI)

## Prerequisites
Make sure you have [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git), [Docker desktop](https://www.docker.com/products/docker-desktop) and [postman] (https://www.postman.com/) installed.

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

## OAuth2 Configuration
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

Adding Web Application
To ensure a correct access and handle to this configuration endpoint we need to create a web application to this URL path - https://webserver/authserver/oauth2

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
