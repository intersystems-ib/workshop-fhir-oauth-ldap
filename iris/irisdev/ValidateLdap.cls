Include (%syLDAP, %syLDAPFunc, %sySite)

/// The %OAuth2.Server.Validate class is the default ValidateUserClass which is included with the server.
/// The default class will use the user database of the Cache instance where the authorization server
/// is located to validate the user.  The supported properties will be
/// issuer (Issuer), roles and sub (Username).<br>
/// The ValidateUserClass is specified in the Authorization Server Configuration.
/// It must contain a ValidateUser method which will validate a username/password combination
/// and return a set of properties associated with this user.
/// 
Class demo.ValidateLdap Extends %RegisteredObject
{

/// LDAP User to Scan/Read the Directory
Parameter AdminDN = "cn=admin,dc=devcom,dc=com";

/// Credentials for the LDAP Read user
Parameter AdminPassword = "StrongAdminPassw0rd";

/// LDAP Server, We only check against one server
Parameter LDAPServer1 = "ldap.devcom.com";

/// Secondary LDAP Server. No yet used
Parameter LDAPServer2 = "server2.to.use";

/// The BaseDN for Searches
Parameter BaseDN = "DC=devcom,DC=com";

/// The Filter for Search
/// If ActiveDirectory use sAMAccountname. If OpenLDAP use uid
Parameter FILTER = "uid";

/// The Certificate file for SSL/TLS: ###TODO (not Yet Implemented)
Parameter UnixCertificateFile;

/// Your custom ValidateUser method must return true (1) only if the username and password refer to a valid user
/// based on whatever criteria you choose to implement.  It must return false in other cases. <p>
/// If password="", then the user is already logged into an existing session and the password
/// does not need to be validated.<p>
/// In addition, this method receives the properties array and can further modify it;
/// this correspond to the Properties property of %OAuth2.Server.Token. 
/// The authorization server will always add the "iss" (URL of authorization server),
/// "sub" (client_id), and "exp" (expiration time in seconds since December 31st, 1840)
/// to ClaimValues and "client_id" (client_id of the requesting client) to CusotmProperties 
/// after return from ValidateUser if they have not already been added.<p>
/// This sample ValidateUser method validates the user based on the Cache users for this instance.
ClassMethod ValidateUser(username As %String, password As %String, scope As %ArrayOfDataTypes, properties As %OAuth2.Server.Properties, Output sc As %Status) As %Boolean
{
	#DIM tValidUser as %Boolean
	#DIM tSC as %Status=$$$OK
	#DIM tLDAPErr as %Integer   //An LDAPError Code o $$$LDAPSUCCESS
	#DIM tLDAPMsg as %String 
	#DIM errObj as %Exception.AbstractException
	#DIM LD   //LDAP Handle
	#DIM tFilter,tAttributes,tTimeout,tSizeLimit
	#DIM SearchResult, tNumEntries, tCurrentEntry
	#DIM tUserDN
	try {
		///0- Not a Valid User
		set tValidUser=0
		
		///0.1- Empty Password: User already validated? Then Nothing to do...
		
		///1- Bind against LDAP Server 1 
		set LD=##class(%SYS.LDAP).Init(..#LDAPServer1)
		if (LD="") {
			set tLDAPErr=##class(%SYS.LDAP).GetLastError()
			set tLDAPMsg="ldap Init - "_##Class(%SYS.LDAP).Err2String(tLDAPErr)
			$$$ThrowStatus($$$ERROR($$$GeneralError,tLDAPMsg))
		}
		///2- Turn on TLS Now. ###TODO (Not Yet Tested, Don't have the URI of the Certificates files)
		if (..#UnixCertificateFile'="") {
			set tLDAPErr=##Class(%SYS.LDAP).SetOption(LD,$$$LDAPOPTXTLSCACERTFILE,..#UnixCertificateFile) 
   			if tLDAPErr'=$$$LDAPSUCCESS { 
   				set tLDAPMsg="ldap_setoption(Certificate) - "_##Class(%SYS.LDAP).Err2String(tLDAPErr)
				$$$ThrowStatus($$$ERROR($$$GeneralError,tLDAPMsg)) 
   			} 
			#;Turn on TLS. This forms the connection, and exchanges the certificate, and makes this a 
			#;Error -11 or -12 most likely means that the certificate has a problem, or possibly
			#;the value for LDAPServer is not correct or the right format in the LDAP_Init call. If you have 
			#;problems getting this to work, you can run the server in debug mode as described above, and 
			#;watch the debug messages on the server as the certificates exchange between the machines.
			
			Set tLDAPErr=##Class(%SYS.LDAP).StartTLSs(LD)
			if tLDAPErr'=$$$LDAPSUCCESS {
				set tLDAPMsg="ldap_setoption(Certificate) - "_##Class(%SYS.LDAP).Err2String(tLDAPErr)
				$$$ThrowStatus($$$ERROR($$$GeneralError,tLDAPMsg)) 
 			}
		}
		
		///3- Bind as Admin, to get the UserDN for this username
	 	set tLDAPErr=##Class(%SYS.LDAP).SimpleBinds(LD,..#AdminDN,..#AdminPassword)
		if (tLDAPErr'=$$$LDAPSUCCESS) {
			set tLDAPMsg="ldap_Binds(AdminDN) - "_##Class(%SYS.LDAP).Err2String(tLDAPErr)
			$$$ThrowStatus($$$ERROR($$$GeneralError,tLDAPMsg)) 
		}
		///3.1- Get the UserDN, and Some Attributes...	
 		set tFilter=..#FILTER_"="_username
 		set tAttributes=$lb("givenName","businessCategory")
 		set tTimeout=10,tSizeLimit=1
 		set tLDAPErr=##class(%SYS.LDAP).SearchExts(LD,..#BaseDN,$$$LDAPSCOPESUBTREE,tFilter,tAttributes,0,"","",tTimeout,tSizeLimit,.SearchResult)
 		if (tLDAPErr'=$$$LDAPSUCCESS) {
	 		set tLDAPMsg="ldap_SearchExt - "_##Class(%SYS.LDAP).Err2String(tLDAPErr)
	 		$$$ThrowStatus($$$ERROR($$$GeneralError,tLDAPMsg))
 		}
 		#;See how many entries were returned by the search.
 		set tNumEntries=##Class(%SYS.LDAP).CountEntries(LD,SearchResult)
 		if tNumEntries=-1 {
	 		set tLDAPErr=##Class(%SYS.LDAP).GetError(LD)
	 		set tLDAPMsg="ldap_Count_Entries - "_##Class(%SYS.LDAP).Err2String(tLDAPErr)
	 		$$$ThrowStatus($$$ERROR($$$GeneralError,tLDAPMsg))
 		}
		#;If NumEntries=0, then either there is no LDAP user for the username 
		#;in the database, or the BaseDN parameter needs to be set higher in the tree.
 		i tNumEntries=0 {
	 		$$$ThrowStatus($$$ERROR($$$GeneralError,"User "_username_" does not exist"))

 		}
		#;If the search returned too many items, then the Filter is probably wrong. 
 		i tNumEntries>1 {
	 		$$$ThrowStatus($$$ERROR($$$GeneralError,"LDAP Filter is not unique"))
 		}
		#;Now get the pointer to the first (and only) entry in the returned search list.
 		set tCurrentEntry=##Class(%SYS.LDAP).FirstEntry(LD,SearchResult)
 		if tCurrentEntry=0 {
	 		set tLDAPErr=##Class(%SYS.LDAP).GetError(LD)
	 		set tLDAPMsg="ldap_FirstEntry - "_##Class(%SYS.LDAP).Err2String(tLDAPErr)
	 		$$$ThrowStatus($$$ERROR($$$GeneralError,tLDAPMsg))
 		}
		#;Retrieve the DN for the user we found so we can bind on it.
		set tUserDN=##Class(%SYS.LDAP).GetDN(LD,tCurrentEntry)
		#;Make sure the password is not null. A null password will actually bind "anonymously"
		#;and return success even though it does not match the user's password
		if password="" {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"ldap_Simple_Bind("_tUserDN_") -password cannot be null"))
		}
		//4- Now authenticate the user based on their DN
		set tLDAPErr=##Class(%SYS.LDAP).SimpleBinds(LD,tUserDN,password)
		i tLDAPErr'=$$$LDAPSUCCESS {
	 		set tLDAPMsg="ldap_Simple_Bind("_tUserDN_") - "_##Class(%SYS.LDAP).Err2String(tLDAPErr)
	 		$$$ThrowStatus($$$ERROR($$$GeneralError,tLDAPMsg))
 		}else {
		//5 - Authenticated! Authorization (scope) check based on some attributes 
			set tAttrName=##Class(%SYS.LDAP).FirstAttribute(LD,tCurrentEntry,.Ptr)
			
			while (tAttrName'="") {
				set tAttrValues=##Class(%SYS.LDAP).GetValues(LD,tCurrentEntry,tAttrName)
				quit:tAttrName="businessCategory"
				set tAttrName=##Class(%SYS.LDAP).NextAttribute(LD,tCurrentEntry,.Ptr)
			}
			//set ^zRdPLog($I(^zRdPLog))=$zdt($h,3)_"tAttrName: "_tAttrName_"| "_"tAttrValues: "_tAttrValues_"|"

			set tScope=properties.RequestProperties.GetAt("scope")
			set tCount=$LENGTH(tScope," ")
			set isValid=1

			for i=1:1:tCount{
				set tValScope=$PIECE(tScope," ",i)
				quit:'isValid
				continue:((tValScope="openid")||(tValScope["launch/"))
                
				set:(tAttrValues'[tValScope) isValid=0
				if ('isValid) $$$ThrowStatus($$$ERROR($$$GeneralError,"scope validation failed"))
			}
			
			
	 		////OK; we're Logged in!
	 		set tValidUser=1
 		}
 	}catch (errObj) {
	 	set ^zRdPOAuthLog($I(^zRdPOAuthLog))=$zdt($h,3)_"|"_username_"|"_errObj.DisplayString()
		set tSC=errObj.AsStatus()
	}
	///5- Finally, cleanup
	#;We must free the search buffer here otherwise future LDAP calls may core 
	#;or memory leak.
 	i $d(SearchResult) d ##Class(%SYS.LDAP).MsgFree(SearchResult)
	#;Close the connection and free the LDAP in memory structures.
 	i $d(LD) d ##Class(%SYS.LDAP).UnBinds(LD)
 	//6- return the Login Result
	quit tValidUser
}

/// The ValidateClient method returns true (1), if the client_id and client_secret refer to a
/// client computer which may use the client credentials grant type based on whatever criteria
/// the method chooses to implement.  This client will already have been verified to be registered 
/// to this authorization server and thus will usually be accepted.
/// ValidateClient populates the properties array argument with any properties needed to generate the access token.
/// This correspond to the Properties arguments of OAuth2.Server.Token.
/// The authorization server will always add the "iss" (URL of authorization server),
/// "sub" (client_id), and "exp" (expiration time in seconds since December 31st, 1840)
/// to ClaimValues and "client_id" (client_id of the requesting client) to CusotmProperties 
/// after return from ValidateUser if they have not already been added.<br>
/// If not valid then false is returned.<br>
/// This default ValidateClient accepts all clients and adds no properties.
ClassMethod ValidateClient(clientId As %String, clientSecret As %String, scope As %ArrayOfDataTypes, Output properties As %OAuth2.Server.Properties, Output sc As %Status) As %Boolean
{
	Set sc=$$$OK
	Quit 1
}

/// The SupportedClaims method returns a $list of claims that are supported
/// by this authorization server based on customizations.  The SupportedClaims method is in the
/// ValidateUserClass since this is where additional claims are usually added.
/// The returned list is added to the list of claims defined by OpenID Connect Core and
/// should include JWT, IDToken, userinfo endpoint and introspection endpoint claims.
ClassMethod SupportedClaims() As %List
{
	// This is the list that corresponds to the above code.
	// This list should be adjusted based on the specific customizations of this server.
	// Quit $lb("preferred_username","email","email_verified","name","phone_number","phone_number_verified")
	quit ""
}

}
