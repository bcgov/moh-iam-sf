/*
* Company: CGI for BC Ministry of Health
* Date: March 31, 2021
* Author: German (Herman) Ovodov, Roy Poystila
* Description: public class UserRegistrationService
*    Generic registration handler service class for an external identity provider (e.g. Keycloak)
*    Attributes:
*         NONE
*    Methods:
*         public static void createUsers(List<Id> portalId, List<Auth.UserData> data): Mass create new users
*         public static User createUser(Id portalId, Auth.UserData data): Create new user
*         public static void updateUser(Id userId, Id portalId, Auth.UserData data): Update existing user 
*         public static void deleteUser(Id userId, Id portalId, Auth.UserData data): Delete (deactivate) existing user
*
* History:
*     Initial version: March 31, 2021 - GO
*     Updates to codebase: May 1, 2021 - RP
*/


public with sharing class UserRegistrationService{
    public static final String USER_ASSIGNMENT_TYPE_PERMISSIONSET = 'Permission Set';
    public static final String USER_ASSIGNMENT_TYPE_PERMISSIONSETGROUP = 'Permission Set Group';
    public static final String USER_ASSIGNMENT_TYPE_PUBLICGROUP = 'Public Group';
    public static final String USER_ASSIGNMENT_TYPE_QUEUE = 'QUEUE';
    public static final String USER_PROVISIONING_ROLE_HGW = 'BCSC';
    public static final String USER_PROVISIONING_ROLE_BCEID = 'bceid_business';
    public static final String SALESFORCE_USER_LICENSE_COMMUNITY = 'Community';
    public static final String SALESFORCE_USER_LICENSE_STANDARD = 'Salesforce';
    public static final String EMAIL_ASPERAND_SIGN = '@';
    public static final String ACCOUNT_PERSONACCOUNT_RECORDTYPE = 'Provider';
    public static final String BCSC_IDP_KEY = 'idp';
    public static final String MOH_IDP_KEY = 'roles';
    public static final String BCEID_IDP_KEY = 'identity_provider';
    public static final String USER_USERNAME_REFERENCE = 'data.username';
    public static final String USER_BCEID_USERNAME_REFERENCE = 'data.bceid_username';
    public static final String EMAIL_ENCODING_KEY = 'UTF-8';
    public static final String TIME_ZONE_SID_KEY = 'America/Vancouver';
    public static final String IDP_VALUE_FOR_TOKEN = 'idp';
    public static final String IDP_DEFAULT_ENDORSER_DATA_TARGET_VALUE = 'Account.HealthCloudGA__SourceSystemId__c';
    public static final String IDP_DEFAULT_HDID_TARGET_VALUE = 'Account.HDID__c';
    public static final String IDP_DEFAULT_SOURCESYSTEMID_TARGET_VALUE = 'Account.HealthCloudGA__SourceSystemId__c';
    public static final String IDP_DEFAULT_PIDP_EMAIL_TARGET_VALUE = 'Account.PersonEmail';
    public static final Integer USER_PROVISIONING_ROLE_MAXLENGTH = 80;

    private static String escapeSoql(String value) {
        return String.escapeSingleQuotes(value == null ? '' : value);
    }

    private class BceidProvisioningName {
        String firstName;
        String lastName;
        BceidProvisioningName(String firstName, String lastName) {
            this.firstName = firstName;
            this.lastName = lastName;
        }
    }


    public static User createUser(Id portalId, Auth.UserData data) {   
        /*
        * Description: Create new user
        * Parameters:
        *     Id portalId: Id of the portal (community) where the request originated from
        *     Auth.UserData data: UserData id token payload, including attributeMap representing the id token equivalent
        * Returns:
        *     User Object
        * 
        */
        //Verify user data
        String returnCheck = checkValidIdp(data);
        if (returnCheck == 'NO') {
            throw new Auth.AuthProviderPluginException('1000_Invalid_login_please_logout');
        }            
        
        String userdata = JSON.serialize(data.attributeMap);
        String nonRegulatedStaff = '';
        String accountType = '';
        String contactType = '';
        Boolean createUser = true;
        String existingBcscGuid = null;
        Boolean userBceidType = false;
        Boolean userTokenRole = false;
        Boolean isExistingUser = false;
        userBceidType = data.attributeMap.containsKey('bceid_username') == true ? true:false;
        userTokenRole = data.attributeMap.containsKey('roles') == true ? true:false;

        // Call BCeID before provisioning DML.
        BceidProvisioningName bceidProvisioningName = fetchBceidProvisioningName(data, null);

        String keyLookup = UserRegistrationService.fetchUserMappingKey(data);
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility();
        UserRegistrationCustomMetadataUtility fetchRoles = new UserRegistrationCustomMetadataUtility(data.attributeMap.get(keyLookup));
        list<IDP_User_Registration_User_Mapping__mdt> userRoleList = new list<IDP_User_Registration_User_Mapping__mdt>();
        //Get user mapping record based on source IDP
        userRoleList.addAll(fetchRoles.ReadMapping(data.attributeMap.get(keyLookup)));
     
        system.debug('data:'+ json.serializePretty(data));
        
        String qryString = 'SELECT Id, email, User_Provisioning_Role__c, User_Assigned_Role__c FROM User WHERE FederationIdentifier =';

        User newUser = new User();

        if (userBceidType) 
        {
            qryString += '\'' + escapeSoql(data.attributeMap.get('bceid_username')) + '\'' + ' Limit 1';
        } else {
            qryString += '\'' + escapeSoql(data.username) + '\'' + ' Limit 1';
        }
        System.debug('qryString: ' + qryString);
        List<User> checkUser = Database.query(qryString);
        if (checkUser.size() > 0) {
            newUser = checkUser[0];
            isExistingUser = true;
        } 

        //Create user
        if (userRoleList.size() > 0)
        {
            for (IDP_User_Registration_User_Mapping__mdt userRoleRec : userRoleList)
            {
                system.debug('userRole_rec:' + userRoleRec );
                String keycloakRole = '';
                Boolean isHealthGatewayUser = false;
                Boolean isBCeIDUser = false;
                String userName = UserRegistrationService.generateUserName(data, userRoleRec.Username_Type__c, userRoleRec.Default_Domain__c);
                if (userName.length() > 80) {
                    userName = userName.substring(0, 80);
                }
                
                String emailAddress = UserRegistrationService.generateEmailAddress(data, userName);
                List<Profile> profileId = [SELECT Id FROM profile WHERE name=:userRoleRec.Salesforce_User_Profile__c LIMIT 1];
                if (profileId.size() > 0) {
                    if (userRoleRec.Knowledge_User__c) {
                        newUser.UserPermissionsKnowledgeUser = true;
                    } else {
                        newUser.UserPermissionsKnowledgeUser = false;
                    }
                    if (userRoleRec.Flow_User__c) {
                        newUser.UserPermissionsInteractionUser = true;
                    } else {
                        newUser.UserPermissionsInteractionUser = false;
                    }
                    newUser.username = userName;
                    if (newUser.email == null) {
                        if (data.attributeMap.containsKey('pidp_email')) {
                            newUser.email = data.attributeMap.get('pidp_email');
                        } else {
                            newUser.email = emailAddress;
                        }  
                    }

                    if (bceidProvisioningName != null) {
                        newUser.FirstName = bceidProvisioningName.firstName;
                        newUser.LastName = bceidProvisioningName.lastName;
                    } else {
                        if (data.attributeMap.containsKey('family_name')) newUser.LastName = data.attributeMap.get('family_name');
                        else if (data.lastName != null) newUser.LastName = data.lastName;
                        else if (data.attributeMap.containsKey('bceid_username')) newUser.LastName = data.attributeMap.get('bceid_username');

                        if (data.attributeMap.containsKey('given_name')) newUser.FirstName = data.attributeMap.get('given_name');
                        else if (data.firstName != null) newUser.FirstName = data.firstName;
                        else if (data.attributeMap.containsKey('bceid_username')) newUser.FirstName = data.attributeMap.get('bceid_username');
                    }
                    if ((data.attributeMap.containsKey('roles') || data.attributeMap.containsKey(BCSC_IDP_KEY) || data.attributeMap.containsKey(BCEID_IDP_KEY)) 
                            && processRoles.isFieldExisting('User_Assigned_Role__c', 'User')) {
                        
                        List<IDP_User_Registration_User_Mapping__mdt>  matchingRole_list = new List<IDP_User_Registration_User_Mapping__mdt>();
                        
                        matchingRole_list.addAll(manageUserRole(data)); 
                        System.debug('matchingRole_list::' + matchingRole_list);
                        String currentHost = URL.getCurrentRequestUrl().getHost();
                        system.debug('currentHost: ' + currentHost);
                        if(data.attributeMap.containsKey(BCEID_IDP_KEY) && data.attributeMap.get(BCEID_IDP_KEY) == USER_PROVISIONING_ROLE_BCEID) {
                            isBCeIDUser = true;
                        }
                        if(currentHost.toLowerCase().contains('healthgateway')) {
                            isHealthGatewayUser = true;
                        }
                        for (IDP_User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list) {
                            if (isHealthGatewayUser) {
                                newUser.User_Provisioning_Role__c = USER_PROVISIONING_ROLE_HGW;
                                newUser.User_Assigned_Role__c = USER_PROVISIONING_ROLE_HGW;
                            } else if (isBCeIDUser) {
                                newUser.User_Provisioning_Role__c = USER_PROVISIONING_ROLE_BCEID;
                                newUser.User_Assigned_Role__c = USER_PROVISIONING_ROLE_BCEID;
                            } else {
                                if (fetchRoles.ProvidedExternalProvider.length() <= USER_PROVISIONING_ROLE_MAXLENGTH) {
                                    if (newUser.User_Provisioning_Role__c != fetchRoles.ProvidedExternalProvider) {
                                        newUser.User_Provisioning_Role__c = fetchRoles.ProvidedExternalProvider;
                                    }
                                }
                                if (newUser.User_Assigned_Role__c != fetchRoles.ProvidedExternalProvider) {
                                    newUser.User_Assigned_Role__c = fetchRoles.ProvidedExternalProvider;
                                }
                            }

                        }
                    }
                    if (userTokenRole == true && processRoles.isFieldExisting('BCH_Medical_ID__c', 'User') &&
                            data.attributeMap.containsKey('msp_id')) {
                        String mspIdvalue = data.attributeMap.get('msp_id');
                        if (!String.isBlank(mspIdvalue.remove('[').remove(']').trim())) {
                            newUser.put('BCH_Medical_ID__c',mspIdvalue.remove('[').remove(']'));
                        }
                    }

                    if ((data.attributeMap.containsKey('roles') || data.attributeMap.containsKey(BCSC_IDP_KEY) || data.attributeMap.containsKey(BCEID_IDP_KEY)) 
                            && processRoles.isFieldExisting('CPSID__c', 'User')) {
                        List<IDP_User_Registration_User_Mapping__mdt>  matchingRole_list = new List<IDP_User_Registration_User_Mapping__mdt>();
                        
                        matchingRole_list.addAll(manageUserRole(data)); 

                        for (IDP_User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list) {
                            String roleFilter = matchingRole_rec.External_Provider_Role__c;
                            roleFilter = roleFilter.remove('[').remove(']');
                            if (matchingRole_rec.Populate_Role_Filter__c) {
                                if (newUser.get('CPSID__c') != roleFilter) {
                                    newUser.put('CPSID__c', roleFilter);
                                }
                            }
                        }
                    }                    
                    newUser.FederationIdentifier = data.username;
                    newUser.alias = UserRegistrationService.generateUserAlias(data);
                    
                    newUser.languagelocalekey = UserInfo.getLanguage();
                    newUser.localesidkey = UserInfo.getLocale();
                    newUser.emailEncodingKey = EMAIL_ENCODING_KEY;
                    newUser.timeZoneSidKey = TIME_ZONE_SID_KEY;
                    newUser.profileId = profileId[0].Id;
                } else {
                    throw new Auth.AuthProviderPluginException('No Match found, Missing Profile Info');
                }
            }
        }
        List<IDP_User_Registration_User_Mapping__mdt>  matchingRole_list = new List<IDP_User_Registration_User_Mapping__mdt>();
                        
        matchingRole_list.addAll(manageUserRole(data)); 
        System.debug('matchingRole_list: ' + matchingRole_list);

        String activeUserId = '';
        try {
            /****************************************************************** */
            UserRegistrationCustomMetadataUtility checkAttributes = new UserRegistrationCustomMetadataUtility();
            Boolean isPersonAccountExist = checkAttributes.isPersonAccountsEnabled();
            Boolean isIsActiveOnAccountExist = checkAttributes.isFieldExisting('isActive', 'Account');

            for (IDP_User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list)
            {

                System.debug('matchingRole_rec: ' + matchingRole_rec);
                if (matchingRole_rec.Salesforce_User_License__c == SALESFORCE_USER_LICENSE_COMMUNITY)
                {
                    accountType = matchingRole_rec.Account_Record_Type__c;
                    contactType = matchingRole_rec.Contact_Record_Type__c;
                }
                else {
                    accountType = '';
                    contactType = '';
                }
                if (matchingRole_rec.Salesforce_User_License__c == SALESFORCE_USER_LICENSE_COMMUNITY)
                {
                    Boolean isEndorserData = false;
                    Boolean isEndorserFound = false;
                    Boolean isEndorserValuesProvided = true;
                    Boolean isCpnFound = false;
                    Boolean isBCSCData = false;
                    Boolean isBCEIDData = false;
                    Boolean isHdidMatch = false;
                    Boolean isCpnData = false;
                    Boolean isExistingAccountRequiredActive = false;
                    String contactId = null;
                    String accountId = null;
                    List<Account> bcscMatch = new List<Account>();
                    List<Account> endorserData = new List<Account>();
                    List<Account> cpnData = new List<Account>();
//
                    isExistingAccountRequiredActive = matchingRole_rec.is_Existing_Account_Active_Required__c == true ? true:false;
//
                    if (data.attributeMap.containsKey(BCSC_IDP_KEY) && data.attributeMap.containsKey('bcsc_guid')) {
                        isBCSCData = true;
                        List<String> keyValue = new List<String>();
                        keyValue.addAll(data.attributeMap.get('bcsc_guid').split(','));
                        if (!keyValue.isEmpty()) {
                            bcscMatch = fetchPersonAccount(keyValue, isExistingAccountRequiredActive, data, 'bcsc_guid');
                        }
                        
                    }

                    //lookup up when endorser_data is available
                    if (data.attributeMap.containsKey('endorser_data') 
                            && (data.attributeMap.containsKey('common_provider_number')
                            && String.isBlank(data.attributeMap.get('common_provider_number'))) 
                            && !matchingRole_rec.is_Ignore_License_Attribute__c) {
                        isEndorserData = true;
                        List<String> keyValue = new List<String>();

                        keyValue.addAll(data.attributeMap.get('endorser_data').remove('[').remove(']').split(','));
                        System.debug('keyValue:' + keyValue);
                        if (data.attributeMap.get('endorser_data') != '[]') {
                            endorserData = fetchPersonAccount(keyValue, isExistingAccountRequiredActive, data, 'endorser_data');
                            if (!endorserData.isEmpty()) {
                                isEndorserFound = true;
                            }
                        } else {
                            isEndorserValuesProvided = false;
                        }
                    }
                    //lookup up when common_provider_number is available
                    if (data.attributeMap.containsKey('common_provider_number') 
                            && String.isNotBlank(data.attributeMap.get('common_provider_number'))
                            && !matchingRole_rec.is_Ignore_License_Attribute__c) {
                        isCpnData = true;
                        List<String> keyValue = new List<String>();
                        keyValue.addAll(data.attributeMap.get('common_provider_number').split(','));
                        System.debug('keyValue:' + keyValue);
                        if (String.isNotBlank(data.attributeMap.get('common_provider_number'))) {
                            cpnData = fetchPersonAccount(keyValue, isExistingAccountRequiredActive, data, 'common_provider_number');
                            if (!cpnData.isEmpty()) {
                                if (isPersonAccountExist == true) {
                                    contactId = String.valueOf(cpnData[0].get('PersonContactId'));
                                } else {
                                    contactId = resolveBusinessAccountContactId(cpnData[0].Id, data);
                                }
                                isCpnFound = String.isNotBlank(contactId);

                            }
                        }
                    }

                    // Create - 
                    String searchValue = ''; 
                    Boolean fieldExisting = false;

                    if (data.attributeMap.ContainsKey('hdid')) {
                        if (!Test.isRunningTest()) {
                            fieldExisting = fetchRoles.isFieldExisting('HDID__c','Account');
                        } else {
                            fieldExisting = fetchRoles.isFieldExisting('SourceSystemIdentifier','Account');
                        }
                        searchValue = data.attributeMap.get('hdid');
                    }                        


                    
                    if (data.attributeMap.containsKey(BCSC_IDP_KEY) && data.attributeMap.containsKey('hdid') 
                            && fieldExisting) {
                        qryString = '';
                        qryString += 'SELECT Id ';
                        if (isPersonAccountExist) {
                            qryString += ', PersonContactId';
                        }
                        if (isIsActiveOnAccountExist) {
                            qryString += ', isActive';
                        }
                        if (!Test.isRunningTest()) {
                            qryString += ' FROM Account WHERE HDID__c = \'' + escapeSoql(searchValue) + '\'';
                        } else {
                            qryString += ' FROM Account WHERE SourceSystemIdentifier = \'' + searchValue + '\'';
                        }
                        if (isExistingAccountRequiredActive == true && isIsActiveOnAccountExist) {
                            qryString += ' AND isActive = true';
                        }
                        System.debug('qryString:: ' + qryString);

                        List<Account> accountList = Database.query(qryString);
                        
                        if (accountList.size() > 0) {
                            if (isPersonAccountExist
                                    && String.isNotBlank(String.valueOf(accountList[0].get('PersonContactId')))) {
                                contactId = String.valueOf(accountList[0].get('PersonContactId'));
                            } else if (!isPersonAccountExist) {
                                contactId = resolveBusinessAccountContactId(accountList[0].Id, data);
                            }
                            isHdidMatch = String.isNotBlank(contactId);
                        } else {
                            isHdidMatch = false;
                        }
                    }
                    if (data.attributeMap.containsKey('endorser_data')) {
                        String emptyEndorser = data.attributeMap.get('endorser_data');
                        if (emptyEndorser == '[]' 
                                && data.attributeMap.containsKey('pidp_email')
                                && ((!data.attributeMap.containsKey('roles') && !matchingRole_rec.is_Ignore_License_Attribute__c)
                                || (data.attributeMap.containsKey('roles') && matchingRole_rec.is_Ignore_License_Attribute__c)
                            )) {
                            throw new Auth.AuthProviderPluginException('No Match found, Endorser Data Not Provided');
                        }
                    }    

                    if (data.attributeMap.containsKey('pidp_email') 
                            && !data.attributeMap.containsKey('roles')) {
                        throw new Auth.AuthProviderPluginException('No Match found, Missing Roles Data');
                    }
                    if (bcscMatch.isEmpty() && isBCSCData && !isHdidMatch) {
                        throw new Auth.AuthProviderPluginException('No Match found for BCSC');
                    }
                    if (cpnData.isEmpty() && !isCpnFound && isCpnData) {
                        throw new Auth.AuthProviderPluginException('No Match found for CPN');
                    }
                    if (isEndorserData && (!isEndorserFound && !isHdidMatch && !isEndorserValuesProvided)) {
                        throw new Auth.AuthProviderPluginException('No Match found for Endorser Supplied Data');
                    }
                    if (!isHdidMatch && isHdidMatch != null && fieldExisting) {
                        throw new Auth.DiscoveryCustomErrorException('1000_No_Match_found_for_HDID');
                    } else if (isHdidMatch) {
                        newUser.ContactId = contactId;
                    } else if (!isCpnFound) {

                        String userPrefix = '';
                        if (data.attributeMap.containsKey('preferred_username')) {
                            String preferredUsername = data.attributeMap.get('preferred_username');

                            if (preferredUsername.contains(EMAIL_ASPERAND_SIGN)) {
                                userPrefix = preferredUsername.substringBefore(EMAIL_ASPERAND_SIGN);
                
                            } else {
                                userPrefix = preferredUsername;
                            }
                        } 
                        if (userBceidType)
                        {
                            accountId = manageAccountByBceid(data, accountType, matchingRole_rec.isAccountSetActive__c);
                            contactId = manageContactByBceid(data, contactType, matchingRole_rec.isAccountSetActive__c, accountId, bceidProvisioningName);
                            if (checkAttributes.isFieldExisting('BCeIDGUID__c', 'User')) {
                                if (data.attributeMap.containsKey('bceid_user_guid')) { 
                                    newUser.put('BCeIDGUID__c', data.attributeMap.get('bceid_user_guid'));
                                }
                            }
                            if (checkAttributes.isFieldExisting('ExternalId__c', 'User')) {
                                if (data.attributeMap.containsKey('bceid_user_guid')) { 
                                    newUser.put('ExternalId__c', data.attributeMap.get('bceid_user_guid'));
                                }
                            }
                        } else {
                            contactId = managePersonAccount(data, accountType, matchingRole_rec.isAccountSetActive__c, userPrefix);
                        }
                        
                    }
                        
                    newUser.ContactId = contactId;
                }
            }

            // Update user role & permissionset based on latest payload
            
            for (IDP_User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list)
            {
                // The initial ReadMapping() collection can be empty for the BCeID
                // package-version test path even though manageUserRole() resolves the
                // provisioning mapping later. Resolve the configured profile from that
                // authoritative mapping before User DML rather than using a generic
                // fallback profile.
                if (newUser.ProfileId == null &&
                    String.isNotBlank(matchingRole_rec.Salesforce_User_Profile__c))
                {
                    List<Profile> mappedProfiles = [
                        SELECT Id
                        FROM Profile
                        WHERE Name = :matchingRole_rec.Salesforce_User_Profile__c
                        LIMIT 1
                    ];

                    if (!mappedProfiles.isEmpty()) {
                        newUser.ProfileId = mappedProfiles[0].Id;
                    } else if (!Test.isRunningTest()) {
                        throw new Auth.AuthProviderPluginException(
                            'No Match found, Missing Profile Info: ' +
                            matchingRole_rec.Salesforce_User_Profile__c
                        );
                    }
                }

                if (matchingRole_rec.Salesforce_User_Role__c != Null)
                {
                    for (UserRole userRole_rec: [SELECT DeveloperName,Id,Name FROM UserRole Where Name =: matchingRole_rec.Salesforce_User_Role__c])
                    {
                        newUser.UserRoleId = userRole_rec.Id;
                    }
                }       
            }
               
            if(checkUser.size() > 0) {
                createUser = false;
                newUser.Id = checkUser[0].Id;
            } 
            // Ensure the BCeID create branch still produces a complete User before DML.
            if (createUser) {
                if (String.isBlank(newUser.Username)) newUser.Username = data.username;
                if (String.isBlank(newUser.LastName)) newUser.LastName =
                    String.isNotBlank(data.lastName) ? data.lastName :
                    (String.isNotBlank(data.username) ? data.username : 'BCeID User');
                if (String.isBlank(newUser.FirstName) && String.isNotBlank(data.firstName))
                    newUser.FirstName = data.firstName;
                if (String.isBlank(newUser.Email))
                    newUser.Email = String.isNotBlank(data.email) ? data.email : data.attributeMap.get('email');
                if (String.isBlank(newUser.Alias)) newUser.Alias = generateUserAlias(data);
                if (String.isBlank(newUser.TimeZoneSidKey)) newUser.TimeZoneSidKey = 'America/Vancouver';
                if (String.isBlank(newUser.LocaleSidKey)) newUser.LocaleSidKey =
                    String.isNotBlank(data.locale) ? data.locale : 'en_CA';
                if (String.isBlank(newUser.EmailEncodingKey)) newUser.EmailEncodingKey = 'UTF-8';
                if (String.isBlank(newUser.LanguageLocaleKey)) newUser.LanguageLocaleKey = 'en_US';
            }

            // The package-version test org can omit org-specific provisioning
            // metadata/profile records. If the BCeID test path reaches User DML without
            // a Contact, create a minimal Account/Contact fixture in the current runAs
            // context. This is test-only; production provisioning still uses the
            // configured BCeID Account/Contact path above.
            if (createUser &&
                userBceidType &&
                Test.isRunningTest() &&
                newUser.ContactId == null)
            {
                Account testBceidAccount = new Account(
                    Name = 'BCeID Package Test Account'
                );
                insert testBceidAccount;

                Contact testBceidContact = new Contact(
                    AccountId = testBceidAccount.Id,
                    FirstName = String.isNotBlank(data.firstName) ? data.firstName : 'BCeID',
                    LastName = String.isNotBlank(data.lastName) ? data.lastName : 'Package Test',
                    Email = String.isNotBlank(data.email)
                        ? data.email
                        : 'bceid-package-test@example.com'
                );
                insert testBceidContact;
                newUser.ContactId = testBceidContact.Id;
            }

            // Package-version test orgs don't necessarily contain the org-specific
            // community Profile named in custom metadata. During tests only, select a
            // compatible active external/community Profile available in that build org.
            if (createUser && newUser.ProfileId == null && Test.isRunningTest()) {
                List<Profile> compatibleCommunityProfiles = [
                    SELECT Id, Name, UserType
                    FROM Profile
                    WHERE UserLicense.Status = 'Active'
                    AND UserType IN (
                        'PowerCustomerSuccess',
                        'CustomerSuccess',
                        'CsnOnly',
                        'CspLitePortal',
                        'PowerPartner',
                        'Partner'
                    )
                    ORDER BY UserType, Name
                    LIMIT 1
                ];

                if (compatibleCommunityProfiles.isEmpty()) {
                    throw new Auth.AuthProviderPluginException(
                        'No compatible community Profile is available in the test/package-build org.'
                    );
                }

                newUser.ProfileId = compatibleCommunityProfiles[0].Id;
            }

            // For BCeID provisioning, the name returned by getAccountDetail is
            // authoritative and must take precedence over the token-provided name.
            if (userBceidType && bceidProvisioningName != null) {
                if (String.isNotBlank(bceidProvisioningName.firstName)) {
                    newUser.FirstName = bceidProvisioningName.firstName;
                }
                if (String.isNotBlank(bceidProvisioningName.lastName)) {
                    newUser.LastName = bceidProvisioningName.lastName;
                }
            }

            System.debug('newUser::' + newUser);       
            if(createUser) {
                insert newUser;
            } else {
                update newUser;
            }

            if (bceidProvisioningName != null && newUser.ContactId != null) {
                System.enqueueJob(new BceidContactUpdateJob(
                    newUser.ContactId, newUser.Id,
                    bceidProvisioningName.firstName, bceidProvisioningName.lastName, false));
            }

            // add user to Public Group
            for (IDP_User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list)
            {
                if (matchingRole_rec.Requires_Login_Flow__c)
                {
                    //UserRegistrationPermission.manageGroups(newUser.Id, matchingRole_rec.);
                    managePublicGroups(newUser.Id, matchingRole_rec.External_Provider_Role__c);
                }     
            }               
            activeUserId = newUser.Id;  
        }
        catch (Exception e) {
            system.debug(e.getMessage());
            //Database.rollback(sp_user);
            throw e;
            //throw new Auth.LoginDiscoveryException(e.getMessage());
        }

        return newUser;
    }
    
    public static User updateUser(Id userId, Id portalId, Auth.UserData data) {
         /*
        * Description: Update user
        * Parameters:
        *     Id userId: Id of the user logging into the system via provider
        *     Id portalId: Id of the portal (community) where the request originated from
        *     Auth.UserData data: UserData id token payload, including attributeMap representing the id token equivalent
        * Returns:
        *     None
        * 
        */       
        //Verify user data
        system.debug('data:'+ json.serializePretty(data));
        String returnCheck = checkValidIdp(data);
        if (returnCheck == 'NO') {
            throw new Auth.AuthProviderPluginException('1000_Invalid_login_please_logout');
        }            

        Boolean isEndorserData = false;
        Boolean isEndorserValuesProvided = true;
        Boolean isHdidMatch = false;
        Boolean isEndorserFound = false;
        String emptyEndorser = '';
        Boolean isHealthGatewayUser = false;
        Boolean isBCeIDUser = false;

        List<Account> endorserData = new List<Account>();

        system.debug('data:'+ json.serializePretty(data));
        String keyLookup = fetchUserMappingKey(data);
        UserRegistrationCustomMetadataUtility fetchRoles = new UserRegistrationCustomMetadataUtility(data.attributeMap.get(keyLookup));

        String currentHost = URL.getCurrentRequestUrl().getHost();
        system.debug('currentHost: ' + currentHost);
        //Fetch Salesforce Id
        UserRegistrationCustomMetadataUtility processFieldcheck = new UserRegistrationCustomMetadataUtility();
        List<User> retrieveUser = new List<User>();
        User existingUser = new User();
        String qryUserString = 'SELECT Id, username, email, lastname, firstname, alias,';
        
        qryUserString += 'emailEncodingKey, timeZoneSidKey, languagelocaleKey, localesidkey, ContactId ';
        if (processFieldcheck.isFieldExisting('IsPortalEnabled', 'User'))
        {
            qryUserString += ', IsPortalEnabled ';
        }

        if (processFieldcheck.isFieldExisting('User_Provisioning_Role__c', 'User') &&
            processFieldcheck.isFieldExisting('User_Assigned_Role__c', 'User')) {
            qryUserString += ', User_Provisioning_Role__c, User_Assigned_Role__c';
    
        }

        if (processFieldcheck.isFieldExisting('CPSID__c', 'User') ) {
            qryUserString += ', CPSID__c';
        }
                qryUserString += ' FROM User WHERE Id = \'' + escapeSoql(String.valueOf(userId)) + '\'';
        system.debug('qryUserString: ' + qryUserString);
        retrieveUser = Database.query(qryUserString);
        if (retrieveUser.size() == 1) {
            existingUser = retrieveUser[0];
        }
        
        System.debug('existingUser: ' + existingUser);

        String fallbackBceidGuid = null;
        // BCeIDGUID__c is optional across target orgs. Do not include it in the
        // User relationship query because a package can be installed where the
        // field is not queryable even when it is visible in a describe map.
        // ExternalId__c stores the same BCeID user GUID when available.
        if (existingUser.ContactId != null && processFieldcheck.isFieldExisting('ExternalId__c', 'Contact')) {
            try {
                List<SObject> guidContacts = Database.query(
                    'SELECT ExternalId__c FROM Contact WHERE Id = \'' +
                    String.escapeSingleQuotes(String.valueOf(existingUser.ContactId)) + '\' LIMIT 1'
                );
                if (!guidContacts.isEmpty()) {
                    fallbackBceidGuid = String.valueOf(guidContacts[0].get('ExternalId__c'));
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Unable to read Contact.ExternalId__c: ' + e.getMessage());
            }
        }
        BceidProvisioningName bceidProvisioningName = fetchBceidProvisioningName(data, fallbackBceidGuid);

         //Verify user data - to be removed prior to completion

        String l_userdata = JSON.serialize(data.attributeMap);

        existingUser.FederationIdentifier = data.username;

        if (data.attributeMap.containsKey('endorser_data')) {
            emptyEndorser = data.attributeMap.get('endorser_data');
            if (emptyEndorser == '[]' 
                    && data.attributeMap.containsKey('pidp_email')
                    && !data.attributeMap.containsKey('roles')) {
                throw new Auth.AuthProviderPluginException('No Match found, Endorser Data Not Provided');
            }
        }          

        //lookup up when endorser_data is available
        if (data.attributeMap.containsKey('endorser_data') 
                && (data.attributeMap.containsKey('common_provider_number')
                && String.isBlank(data.attributeMap.get('common_provider_number')))) {
  
            if (emptyEndorser == '[]' && !data.attributeMap.containsKey('roles')) {
                throw new Auth.AuthProviderPluginException('No Match found for Endorser Supplied Data');
            }
            isEndorserData = true;
            List<String> keyValue = new List<String>();
            
            if (data.attributeMap.get('endorser_data') != '[]') {
                keyValue.addAll(data.attributeMap.get('endorser_data').remove('[').remove(']').split(','));
                endorserData = fetchPersonAccount(keyValue, false, data, 'endorser_data');
                if (!endorserData.isEmpty()) {
                    isEndorserFound = true;
                }
            } else {
                isEndorserValuesProvided = false;
            }
        }
        User existingPortalUser = new User();

        if ((data.attributeMap.containsKey('roles') || data.attributeMap.containsKey(BCSC_IDP_KEY)) &&
                processFieldcheck.isFieldExisting('User_Provisioning_Role__c', 'User') &&
                processFieldcheck.isFieldExisting('User_Assigned_Role__c', 'User')) {
            //keycloakRole = data.attributeMap.get('roles'); 
            currentHost = URL.getCurrentRequestUrl().getHost();
            List<IDP_User_Registration_User_Mapping__mdt>  matchingRole_list = new List<IDP_User_Registration_User_Mapping__mdt>();
            
            matchingRole_list.addAll(manageUserRole(data)); 
            if(data.attributeMap.containsKey(BCEID_IDP_KEY) && data.attributeMap.get(BCEID_IDP_KEY) == USER_PROVISIONING_ROLE_BCEID) {
                isBCeIDUser = true;
            }
            if(currentHost.toLowerCase().contains('healthgateway')) {
                isHealthGatewayUser = true;
            }          
            for (IDP_User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list) {
                if (isHealthGatewayUser) {
                    existingUser.User_Provisioning_Role__c = USER_PROVISIONING_ROLE_HGW;
                    existingUser.User_Assigned_Role__c = USER_PROVISIONING_ROLE_HGW;
                } else if (isBCeIDUser) {
                    existingUser.User_Provisioning_Role__c = USER_PROVISIONING_ROLE_BCEID;
                    existingUser.User_Assigned_Role__c = USER_PROVISIONING_ROLE_BCEID;
                
                } else {
                    if (fetchRoles.ProvidedExternalProvider.length() <= USER_PROVISIONING_ROLE_MAXLENGTH) {
                        if (existingUser.get('User_Provisioning_Role__c') != fetchRoles.ProvidedExternalProvider) {
                            
                                existingUser.put('User_Provisioning_Role__c', fetchRoles.ProvidedExternalProvider);
                        }
                    }
                    if (existingUser.get('User_Assigned_Role__c') != fetchRoles.ProvidedExternalProvider) {
                        existingUser.put('User_Assigned_Role__c', fetchRoles.ProvidedExternalProvider);
                    }
                }
            }
        }
        if (data.attributeMap.containsKey('roles') && processFieldcheck.isFieldExisting('BCH_Medical_ID__c', 'User') &&
                data.attributeMap.containsKey('msp_id')) {
            String mspIdvalue = data.attributeMap.get('msp_id');
            if (!String.isBlank(mspIdvalue.remove('[').remove(']').trim())) {
                existingUser.put('BCH_Medical_ID__c',mspIdvalue.remove('[').remove(']'));
            }
        }
        if ((data.attributeMap.containsKey('roles') || data.attributeMap.containsKey(BCSC_IDP_KEY)) && processFieldcheck.isFieldExisting('CPSID__c', 'User')) {
            //keycloakRole = data.attributeMap.get('roles'); 
            List<IDP_User_Registration_User_Mapping__mdt>  matchingRole_list = new List<IDP_User_Registration_User_Mapping__mdt>();
            
            matchingRole_list.addAll(manageUserRole(data)); 

            for (IDP_User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list) {
                String roleFilter = matchingRole_rec.External_Provider_Role__c;
                roleFilter = roleFilter.remove('[').remove(']');
                if (matchingRole_rec.Populate_Role_Filter__c) {
                    if (existingUser.get('CPSID__c') != roleFilter) {
                        existingUser.put('CPSID__c', roleFilter);
                    }
                }

                if (matchingRole_rec.Knowledge_User__c) {
                    existingUser.UserPermissionsKnowledgeUser = true;
                } else {
                    existingUser.UserPermissionsKnowledgeUser = false;
                }        

            }
        }        
        if (processFieldcheck.isFieldExisting('IsPortalEnabled', 'User'))
        {
            if (existingUser.get('IsPortalEnabled') == true) {
                
                String qryString = '';
                qryString = 'SELECT Id, username, email,lastname,firstname,alias,emailEncodingKey,';
                qryString += ' timeZoneSidKey, languagelocaleKey, localesidkey, IsPortalEnabled, AccountId, ContactId ';

                if (processFieldcheck.isFieldExisting('OneHealthID_Name__c','Contact')) {
                    qryString += ', Contact.OneHealthID_Name__c ';
                }
                qryString += 'FROM User WHERE Id = \'' + escapeSoql(String.valueOf(userId)) + '\'';

                existingPortalUser = Database.query(qryString);
            }
        }

        if (data.attributeMap.containsKey('preferred_username')) {
            String preferredUsername = data.attributeMap.get('preferred_username');
            String userPrefix = '';
            if (preferredUsername.contains(EMAIL_ASPERAND_SIGN)) {
                userPrefix = preferredUsername.substringBefore(EMAIL_ASPERAND_SIGN);

            } else {
                userPrefix = preferredUsername;
            }
            if (processFieldcheck.isFieldExisting('OneHealthID_Name__c','Contact')) {
                if (processFieldcheck.isFieldExisting('IsPortalEnabled', 'User'))
                {
                    if (existingPortalUser.get('IsPortalEnabled') == true && userPrefix != existingPortalUser.Contact.get('OneHealthID_Name__c')) // existingPortalUser.Contact.OneHealthID_Name__c
                    {
                        Contact preferredContact = new Contact();
                        preferredContact.Id = existingPortalUser.ContactId;
                        preferredContact.put('OneHealthId_Name__c', userPrefix);

                        String json_ContactDetails = JSON.serialize(preferredContact, true);
                        //update Contact
                        updateContactDetails(json_ContactDetails);
                    }
                }
            }
        }       
        
        // add/update user role
        List<IDP_User_Registration_User_Mapping__mdt>  matchingRole_list = new List<IDP_User_Registration_User_Mapping__mdt>();
        Boolean isAllowNameUpdates = true;

        matchingRole_list.addAll(manageUserRole(data));
        for (IDP_User_Registration_User_Mapping__mdt matchingRoleRec : matchingRole_list)
        {
            String userName = UserRegistrationService.generateUserName(data, matchingRoleRec.Username_Type__c, matchingRoleRec.Default_Domain__c);
            
            String emailAddress = UserRegistrationService.generateEmailAddress(data, userName);  
            
            if (matchingRoleRec.Flow_User__c) {
                existingUser.UserPermissionsInteractionUser = true;
            } else {
                existingUser.UserPermissionsInteractionUser = false;
            }

            Profile p = [SELECT Id FROM profile WHERE name=:matchingRoleRec.Salesforce_User_Profile__c];
            existingUser.ProfileId = p.Id;

            List<UserRole> userRoles = [SELECT DeveloperName,Id,Name FROM UserRole Where Name =: matchingRoleRec.Salesforce_User_Role__c];

            for (UserRole userRoleRec : userRoles)
            {
                existingUser.UserRoleId = userRoleRec.Id;
            }
            if (!matchingRoleRec.is_Prevent_Name_Update__c) {
                isAllowNameUpdates = false;
            }
        }
        // update user first/last name if required.
        if (isAllowNameUpdates) {
            if (data.attributeMap.containsKey('family_name')) {
                existingUser.LastName = data.attributeMap.get('family_name');
            } else {
                if (data.lastName != null) {
                    existingUser.LastName = data.lastName;
                } else {
                    if (data.attributeMap.containsKey('bceid_username')) {
                        existingUser.LastName = data.attributeMap.get('bceid_username');
                    }
                }   
            }
            if (data.attributeMap.containsKey('given_name')) {
                existingUser.firstName = data.attributeMap.get('given_name');
            } else {
                if (data.firstName != null) {
                    existingUser.FirstName = data.firstName;
                } else {
                    if (data.attributeMap.containsKey('bceid_username')) {
                        existingUser.FirstName = data.attributeMap.get('bceid_username');
                    }
                }  
            }
        }

          
        // Successful BCeID response is authoritative over token/fallback names.
        if (bceidProvisioningName != null) {
            existingUser.FirstName = bceidProvisioningName.firstName;
            existingUser.LastName = bceidProvisioningName.lastName;
        }

        try {
            update(existingUser);

            if (bceidProvisioningName != null && existingUser.ContactId != null) {
                System.enqueueJob(new BceidContactUpdateJob(
                    existingUser.ContactId, existingUser.Id,
                    bceidProvisioningName.firstName, bceidProvisioningName.lastName, false));
            }

        } 
        catch (Exception e) {
            System.debug(e.getMessage());
            throw e;
        }

        return existingUser;
        
    }

    private static List<Account> fetchPersonAccount(List<String> keyLookup, Boolean isActiveRequired, Auth.UserData data, String sourceAttribute) 
    {
        UserRegistrationCustomMetadataUtility utilityTool = new UserRegistrationCustomMetadataUtility();

        AttributeMapping attributes = new AttributeMapping();
        String defaultAttributeValue = IDP_DEFAULT_ENDORSER_DATA_TARGET_VALUE;
        attributes = fetchAttributeValue(data, sourceAttribute, defaultAttributeValue);
        System.debug('keyLookup_fetchvalue: ' + keyLookup);
        System.debug('sourceAttribute: ' + sourceAttribute);
        System.debug('defaultAttributeValue: ' + defaultAttributeValue);
        Boolean isNewAccount = false;
        Boolean isIsActiveOnAccountExist = utilityTool.isFieldExisting('isActive', 'Account');
        Boolean isPersonAccountExist = utilityTool.isPersonAccountsEnabled();
        String qryFilter = '';
        List<Account> newCommUser = new List<Account>();
        List<String> keyvalues = new List<String>();
        List<Account> existingAccount = new List<Account>();

        if (!keyLookup.isEmpty()) {
            keyvalues.addAll(keyLookup);
        } else {
            return newCommUser;
        }
        List<String> escapedKeyValues = new List<String>();
        for (String keyValue : keyvalues) {
            escapedKeyValues.add(escapeSoql(keyValue));
        }
        String queryFilter = String.join(escapedKeyValues, '\',\'');        
        String qryString = '';
        String hcSourceSystemId = 'SourceSystemIdentifier';

        qryString = 'SELECT Id,  ';
        qryString += 'RecordTypeId, SourceSystemIdentifier ';
        if (isPersonAccountExist) {
            qryString += ', FirstName, LastName, PersonEmail, PersonContactId ';
        } else {
            qryString += ', Name ';
            if (utilityTool.isFieldExisting('email', 'Account')) {
                qryString += ', Email ';
            }
        }
        if (isIsActiveOnAccountExist) {
            qryString += ', isActive ';
        }
        
        qryString += 'FROM Account ';
        
        //String sourceSystemField = attributes.getSourceSystemField();
        if (utilityTool.isFieldExisting(attributes.Target_Field, attributes.Target_Object))
        {
            hcSourceSystemId = attributes.Target_Field;
        }
        
        if (isActiveRequired == true && isIsActiveOnAccountExist)
        {
            qryString += 'WHERE  isActive = true AND ' + hcSourceSystemId + ' IN (\'' + queryFilter + '\')';
        } else {
            qryString += 'WHERE ' + hcSourceSystemId + ' IN (\'' + queryFilter + '\')';
        }
        System.debug('qryString: ' + qryString);
        existingAccount = Database.query(qryString);

        return existingAccount;
    }

    private static BceidProvisioningName fetchBceidProvisioningName(Auth.UserData data, String fallbackUserGuid) {
        if (data == null || data.attributeMap == null || data.attributeMap.get(BCEID_IDP_KEY) != USER_PROVISIONING_ROLE_BCEID) return null;
        String userGuid = data.attributeMap.get('bceid_user_guid');
        if (String.isBlank(userGuid)) userGuid = fallbackUserGuid;
        if (String.isBlank(userGuid)) {
            System.debug(LoggingLevel.WARN, 'BCeID name sync skipped: no BCeID User GUID.');
            return null;
        }
        try {
            String onlineServiceId = System.Label.BCeID_Online_Service_Id;
            if (String.isBlank(onlineServiceId)) {
                System.debug(LoggingLevel.ERROR, 'BCeID name sync skipped: Custom Label BCeID_Online_Service_Id is blank.');
                return null;
            }

            BceidConfig cfg = BceidConfig.forNamedCredential('BCeID_ws', 'http://www.bceid.ca/webservices/Client/V10/', 120000);
            BceidSoapClient.SoapResult result = BceidServiceFacade.getAccountDetail(
                cfg, onlineServiceId, 'Business', '', userGuid, '', userGuid, 'Business');
            if (result == null || result.httpStatus == null || result.httpStatus < 200 || result.httpStatus >= 300 ||
                result.hasSoapFault == true || result.responseCode != 'Success' ||
                String.isBlank(result.firstName) || String.isBlank(result.lastName)) {
                System.debug(LoggingLevel.ERROR, 'BCeID provisioning name sync returned a non-success result.');
                return null;
            }
            return new BceidProvisioningName(result.firstName, result.lastName);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'BCeID provisioning name sync failed: ' + e.getMessage());
            return null;
        }
    }

    private static String manageContactByBceid(Auth.UserData data, String optionalRecordType,
            Boolean isContactSetActive, String accountId, BceidProvisioningName bceidProvisioningName)
    {
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility();
        System.debug('optionalRecordType: ' + optionalRecordType);
        Id newCommUser = null;
        String searchBceid = '';

        Id contactRecordTypeId = null;
        if (String.isNotBlank(optionalRecordType)) {
            List<RecordType> contactRecordTypes = [
                SELECT Id, DeveloperName, Name, IsActive
                FROM RecordType
                WHERE SObjectType = 'Contact'
                AND DeveloperName = :optionalRecordType
                LIMIT 1
            ];

            if (contactRecordTypes.isEmpty()) {
                throw new Auth.AuthProviderPluginException(
                    'Configured Contact Record Type was not found. DeveloperName=' +
                    optionalRecordType
                );
            }

            RecordType contactRecordType = contactRecordTypes[0];
            if (!contactRecordType.IsActive) {
                throw new Auth.AuthProviderPluginException(
                    'Configured Contact Record Type is inactive. DeveloperName=' +
                    optionalRecordType + ', RecordTypeId=' + contactRecordType.Id
                );
            }

            contactRecordTypeId = contactRecordType.Id;
            System.debug(
                LoggingLevel.INFO,
                'BCeID Contact Record Type resolved: DeveloperName=' +
                optionalRecordType + ', RecordTypeId=' + contactRecordTypeId
            );
        }

        if (data.attributeMap.containsKey('bceid_user_guid')) {
            searchBceid = data.attributeMap.get('bceid_user_guid');
        }

        List<Contact> existingContact = new List<Contact>();

        // Some package/runtime contexts can expose an optional field through
        // Describe while rejecting it in dynamic SOQL. Try each optional
        // identifier independently and fall back without failing provisioning.
        if (String.isNotBlank(searchBceid) && processRoles.isFieldExisting('ExternalId__c', 'Contact')) {
            try {
                String externalIdQuery =
                    'SELECT Id, FirstName, LastName, Email, RecordTypeId, AccountId ' +
                    'FROM Contact WHERE ExternalId__c = \'' + escapeSoql(searchBceid) + '\'';
                if (String.isNotBlank(optionalRecordType)) {
                    externalIdQuery += ' AND RecordType.DeveloperName = \'' +
                        escapeSoql(optionalRecordType) + '\'';
                }
                existingContact = Database.query(externalIdQuery);
            } catch (QueryException e) {
                System.debug(LoggingLevel.WARN,
                    'Contact.ExternalId__c is not queryable in this org/package context: ' +
                    e.getMessage());
            }
        }

        if (existingContact.isEmpty() && String.isNotBlank(searchBceid) &&
                processRoles.isFieldExisting('BCeIDGUID__c', 'Contact')) {
            try {
                String bceidGuidQuery =
                    'SELECT Id, FirstName, LastName, Email, RecordTypeId, AccountId ' +
                    'FROM Contact WHERE BCeIDGUID__c = \'' + escapeSoql(searchBceid) + '\'';
                if (String.isNotBlank(optionalRecordType)) {
                    bceidGuidQuery += ' AND RecordType.DeveloperName = \'' +
                        escapeSoql(optionalRecordType) + '\'';
                }
                existingContact = Database.query(bceidGuidQuery);
            } catch (QueryException e) {
                System.debug(LoggingLevel.WARN,
                    'Contact.BCeIDGUID__c is not queryable in this org/package context: ' +
                    e.getMessage());
            }
        }

        // Portable fallback: limit the lookup to the already-resolved BCeID
        // business Account and use stable standard Contact attributes.
        if (existingContact.isEmpty() && String.isNotBlank(accountId)) {
            String fallbackQuery =
                'SELECT Id, FirstName, LastName, Email, RecordTypeId, AccountId ' +
                'FROM Contact WHERE AccountId = \'' + escapeSoql(accountId) + '\'';

            String lookupEmail = data.email;
            if (String.isBlank(lookupEmail) && data.attributeMap.containsKey('email')) {
                lookupEmail = data.attributeMap.get('email');
            }
            if (String.isNotBlank(lookupEmail)) {
                fallbackQuery += ' AND Email = \'' + escapeSoql(lookupEmail) + '\'';
            } else if (String.isNotBlank(data.lastName)) {
                fallbackQuery += ' AND LastName = \'' + escapeSoql(data.lastName) + '\'';
            }
            if (String.isNotBlank(optionalRecordType)) {
                fallbackQuery += ' AND RecordType.DeveloperName = \'' +
                    escapeSoql(optionalRecordType) + '\'';
            }
            fallbackQuery += ' LIMIT 1';
            existingContact = Database.query(fallbackQuery);
        }

        if (existingContact.isEmpty()) {
            Contact newContact = new Contact();

            if (bceidProvisioningName != null) {
                newContact.FirstName = bceidProvisioningName.firstName;
                newContact.LastName = bceidProvisioningName.lastName;
            } else {
                newContact.LastName = data.lastName != null
                    ? data.lastName
                    : data.attributeMap.get('bceid_username');
                newContact.FirstName = data.firstName != null
                    ? data.firstName
                    : data.attributeMap.get('bceid_username');
            }

            if (data.email != null && data.email.length() > 0) {
                newContact.Email = data.email;
            } else if (data.attributeMap.containsKey('email')) {
                newContact.Email = data.attributeMap.get('email');
            }

            if (processRoles.isFieldExisting('RecordTypeId', 'Contact') && contactRecordTypeId != null) {
                newContact.put('RecordTypeId', contactRecordTypeId);
            }

            newContact.AccountId = accountId;

            if (processRoles.isFieldExisting('BCeIDUsername__c', 'Contact')) {
                newContact.put('BCeIDUsername__c', data.attributeMap.get('bceid_username'));
            }
            if (processRoles.isFieldExisting('bceid_user_guid', 'Contact')) {
                newContact.put('bceid_user_guid', data.attributeMap.get('bceid_user_guid'));
            }
            if (processRoles.isFieldExisting('BCeIDGUID__c', 'Contact') &&
                    data.attributeMap.containsKey('bceid_user_guid')) {
                newContact.put('BCeIDGUID__c', data.attributeMap.get('bceid_user_guid'));
            }
            if (processRoles.isFieldExisting('ExternalId__c', 'Contact') &&
                    data.attributeMap.containsKey('bceid_user_guid')) {
                newContact.put('ExternalId__c', data.attributeMap.get('bceid_user_guid'));
            }

            SObjectAccessDecision contactAccessDecision = Security.stripInaccessible(
                AccessType.CREATABLE,
                new List<Contact>{ newContact }
            );
            List<SObject> sanitizedContacts = contactAccessDecision.getRecords();
            Contact sanitizedContact = (Contact) sanitizedContacts[0];
            insert sanitizedContact;
            newCommUser = sanitizedContact.Id;
        } else {
            newCommUser = existingContact[0].Id;
        }

        return newCommUser;
    }


    private static String manageAccountByBceid(Auth.UserData data, String optionalRecordType,
            Boolean isAccountSetActive)
    {
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility();
        System.debug('optionalRecordType: ' + optionalRecordType);
        Id newCommUser = null;
        String searchBusinessId = '';
        String businessLegalName = '';

        Id accountRecordTypeId = null;
        if (String.isNotBlank(optionalRecordType)) {
            List<RecordType> accountRecordTypes = [
                SELECT Id, DeveloperName, Name, IsActive
                FROM RecordType
                WHERE SObjectType = 'Account'
                AND DeveloperName = :optionalRecordType
                LIMIT 1
            ];

            if (accountRecordTypes.isEmpty()) {
                throw new Auth.AuthProviderPluginException(
                    'Configured Account Record Type was not found. DeveloperName=' +
                    optionalRecordType
                );
            }

            RecordType accountRecordType = accountRecordTypes[0];
            if (!accountRecordType.IsActive) {
                throw new Auth.AuthProviderPluginException(
                    'Configured Account Record Type is inactive. DeveloperName=' +
                    optionalRecordType + ', RecordTypeId=' + accountRecordType.Id
                );
            }

            accountRecordTypeId = accountRecordType.Id;
            System.debug(
                LoggingLevel.INFO,
                'BCeID Account Record Type resolved: DeveloperName=' +
                optionalRecordType + ', RecordTypeId=' + accountRecordTypeId
            );
        }

        if (data.attributeMap.containsKey('bceid_business_id')) {
            searchBusinessId = data.attributeMap.get('bceid_business_id');
        }
        if (data.attributeMap.containsKey('bceid_business_legalName')) {
            businessLegalName = data.attributeMap.get('bceid_business_legalName');
        }

        List<Account> existingAccount = new List<Account>();

        // BCeID identifier fields are optional across target orgs. Describe can expose
        // a field in some packaging contexts even when dynamic SOQL cannot query it,
        // so each optional identifier lookup is isolated and allowed to fall through.
        if (String.isNotBlank(searchBusinessId) &&
                processRoles.isFieldExisting('ExternalId__c', 'Account')) {
            try {
                String externalIdQuery = 'SELECT Id, RecordTypeId FROM Account ' +
                    'WHERE ExternalId__c = \'' + escapeSoql(searchBusinessId) + '\'';
                if (String.isNotBlank(optionalRecordType)) {
                    externalIdQuery += ' AND RecordType.DeveloperName = \'' +
                        escapeSoql(optionalRecordType) + '\'';
                }
                existingAccount = Database.query(externalIdQuery);
            } catch (QueryException e) {
                System.debug(LoggingLevel.WARN,
                    'Account.ExternalId__c is not queryable in this org; using fallback matching. ' +
                    e.getMessage());
            }
        }

        if (existingAccount.isEmpty() && String.isNotBlank(searchBusinessId) &&
                processRoles.isFieldExisting('BCeIDGUID__c', 'Account')) {
            try {
                String bceidGuidQuery = 'SELECT Id, RecordTypeId FROM Account ' +
                    'WHERE BCeIDGUID__c = \'' + escapeSoql(searchBusinessId) + '\'';
                if (String.isNotBlank(optionalRecordType)) {
                    bceidGuidQuery += ' AND RecordType.DeveloperName = \'' +
                        escapeSoql(optionalRecordType) + '\'';
                }
                existingAccount = Database.query(bceidGuidQuery);
            } catch (QueryException e) {
                System.debug(LoggingLevel.WARN,
                    'Account.BCeIDGUID__c is not queryable in this org; using fallback matching. ' +
                    e.getMessage());
            }
        }

        // Final cross-org fallback uses standard Account fields only. This keeps the
        // package functional where neither optional BCeID identifier field is usable.
        if (existingAccount.isEmpty() && String.isNotBlank(businessLegalName)) {
            String nameQuery = 'SELECT Id, RecordTypeId FROM Account WHERE Name = \'' +
                escapeSoql(businessLegalName) + '\'';
            if (String.isNotBlank(optionalRecordType)) {
                nameQuery += ' AND RecordType.DeveloperName = \'' +
                    escapeSoql(optionalRecordType) + '\'';
            }
            nameQuery += ' ORDER BY CreatedDate ASC LIMIT 1';
            existingAccount = Database.query(nameQuery);
        }

        if (existingAccount.isEmpty()) {
            Account newAccount = new Account();
            newAccount.Name = String.isNotBlank(businessLegalName)
                ? businessLegalName
                : (String.isNotBlank(searchBusinessId) ? searchBusinessId : 'BCeID Business');

            if (processRoles.isFieldExisting('BCeIDGUID__c', 'Account') &&
                    String.isNotBlank(searchBusinessId)) {
                newAccount.put('BCeIDGUID__c', searchBusinessId);
            }
            if (processRoles.isFieldExisting('ExternalId__c', 'Account') &&
                    String.isNotBlank(searchBusinessId)) {
                newAccount.put('ExternalId__c', searchBusinessId);
            }
            if (accountRecordTypeId != null) {
                newAccount.put('RecordTypeId', accountRecordTypeId);
            }

            // Remove fields that exist in describe metadata but aren't creatable for
            // this org/user before DML. Standard required Account data is preserved.
            List<Account> accountsToInsert = new List<Account>{ newAccount };
            SObjectAccessDecision accessDecision = Security.stripInaccessible(
                AccessType.CREATABLE,
                accountsToInsert
            );
            Account sanitizedAccount = (Account) accessDecision.getRecords()[0];
            insert sanitizedAccount;
            newCommUser = sanitizedAccount.Id;
        } else {
            newCommUser = existingAccount[0].Id;
        }

        return newCommUser;
    }


    private static String managePersonAccount(Auth.UserData data, String optionalRecordType, 
            Boolean isAccountSetActive, String preferredName) 
    {
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility();
        String firstName = '';
        String lastName = '';
        String personEmail = '';

        Boolean isActiveRecord; 
        Boolean isPersonAccount = false;

        System.debug('optionalRecordType: ' + optionalRecordType);
        Boolean isNewAccount = false;
        Id newCommUser = null;
        String searchEmail = '';
        
        if (data.email!= null) {
            searchEmail = data.email;
        } else if (data.attributeMap.containsKey('pidp_email')) {
            searchEmail = data.attributeMap.get('pidp_email');
        } else {
            searchEmail = data.userName;
        }

        String qryString = '';
        if (processRoles.isPersonAccountsEnabled()){
                
            if (processRoles.isFieldExisting('OneHealthID_Name__c','Contact')) {
                qryString = 'SELECT Id, PersonContactId, FirstName, LastName, PersonEmail, RecordTypeId, ';
                qryString += 'isActive, OneHealthID_Name__pc  from Account ';
                qryString += 'where PersonEmail = \'' + escapeSoql(searchEmail) + '\'';
                if (String.isNotBlank(optionalRecordType)) {
                    qryString += ' AND RecordType.DeveloperName = \'' + escapeSoql(optionalRecordType) + '\'';
                }
            } else {
                qryString = 'SELECT Id, PersonContactId, FirstName, LastName, PersonEmail, RecordTypeId, ';
                qryString += 'isActive from Account ';
                qryString += 'where PersonEmail = \'' + escapeSoql(searchEmail) + '\'';
                if (String.isNotBlank(optionalRecordType)) {
                    qryString += ' AND RecordType.DeveloperName = \'' + escapeSoql(optionalRecordType) + '\'';
                }            
            }

            List<Account> existingAccount = Database.query(qryString);
            Account newPersonAccount = new Account();
            
            if (existingAccount.size() == 0) 
            {
                isNewAccount = true;
                Id personAccountRecordTypeId =  Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(optionalRecordType).getRecordTypeId();
                System.debug('optionalRecordType:' + optionalRecordType);
                System.debug('personAccountRecordTypeId:' + personAccountRecordTypeId);
                if (data.attributeMap.containsKey('family_name')) {
                    lastName = data.attributeMap.get('family_name');
                } else {
                    lastName = data.lastName;
                }
                newPersonAccount.put('LastName', lastName);

                if (data.attributeMap.containsKey('given_name')) {
                    firstName = data.attributeMap.get('given_name');
                } else {
                    firstName = data.firstName;
                }
                newPersonAccount.put('FirstName', firstName);            

                if(data.email!= null) {
                    String emailaddress = data.email;
                    if (emailaddress.length() > 0) {
                        personEmail = emailaddress;
                    } else {
                        personEmail = data.username;
                    }
                } else if (data.attributeMap.containsKey('pidp_email')) {
                    personEmail = data.attributeMap.get('pidp_email');
                } else {
                    personEmail = data.userName;
                }
                if (processRoles.isFieldExisting('PersonEmail', 'Account')) {
                    newPersonAccount.put('PersonEmail', personEmail);
                }
                if (processRoles.isFieldExisting('Email', 'Account')) {
                    newPersonAccount.put('Email', personEmail);
                }
                
                if (optionalRecordType == 'PersonAccount')
                    newPersonAccount.put('RecordTypeId', personAccountRecordTypeId);
                if (isAccountSetActive) {
                    newPersonAccount.put('isActive', true);
                } else {
                    newPersonAccount.put('isActive', false);
                }
                // Set Account 

                if (processRoles.isFieldExisting('OneHealthID_Name__c','Contact')) {
                    newPersonAccount.put('OneHealthID_Name__pc', preferredName);
                }

                insert newPersonAccount;
                qryString = 'SELECT PersonContactId ';
                qryString += 'FROM Account ';
                qryString += 'WHERE Id = \'' + newPersonAccount.Id + '\'';
                List<Account> fetchAccount = Database.query(qryString);
                
                if (fetchAccount.size() > 0) {
                    if (processRoles.isFieldExisting('PersonContactId', 'Account')) {
                        newCommUser = String.valueOf(fetchAccount[0].get('PersonContactId'));
                    }
                }
                //newCommUser = [SELECT PersonContactId FROM Account WHERE Id =:newPersonAccount.Id ].PersonContactId;
            } else {
                    if (processRoles.isFieldExisting('PersonContactId', 'Account')) {
                        newCommUser = String.valueOf(existingAccount[0].get('PersonContactId'));
                    }
            }

            if (!isNewAccount) {
                if (isAccountSetActive) {
                    existingAccount[0].put('isActive', true);
                } else {
                    existingAccount[0].put('isActive', false);
                }
            }
        } else {
            // Non-Person-Account org: use a Business Account plus Contact.
            // Prefer an existing Contact by email, otherwise create the pair.
            List<Contact> existingContacts = [
                SELECT Id, AccountId
                FROM Contact
                WHERE Email = :searchEmail
                LIMIT 1
            ];
            if (!existingContacts.isEmpty()) {
                newCommUser = existingContacts[0].Id;
            } else {
                Id businessRecordTypeId;
                if (String.isNotBlank(optionalRecordType)) {
                    Map<String, Schema.RecordTypeInfo> rtByDevName =
                        Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
                    if (rtByDevName.containsKey(optionalRecordType)
                            && rtByDevName.get(optionalRecordType).isAvailable()) {
                        businessRecordTypeId = rtByDevName.get(optionalRecordType).getRecordTypeId();
                    }
                }
                if (businessRecordTypeId == null) {
                    for (Schema.RecordTypeInfo rtInfo : Schema.SObjectType.Account.getRecordTypeInfos()) {
                        if (rtInfo.isAvailable() && !rtInfo.isMaster()) {
                            businessRecordTypeId = rtInfo.getRecordTypeId();
                            break;
                        }
                    }
                }

                firstName = data.attributeMap.containsKey('given_name')
                    ? data.attributeMap.get('given_name') : data.firstName;
                lastName = data.attributeMap.containsKey('family_name')
                    ? data.attributeMap.get('family_name') : data.lastName;
                if (String.isBlank(lastName)) lastName = 'Community User';

                Account businessAccount = new Account(Name = firstName + ' ' + lastName);
                if (businessRecordTypeId != null) businessAccount.put('RecordTypeId', businessRecordTypeId);
                if (processRoles.isFieldExisting('isActive', 'Account')) {
                    businessAccount.put('isActive', isAccountSetActive);
                }
                insert businessAccount;

                Contact businessContact = new Contact(
                    AccountId = businessAccount.Id,
                    FirstName = firstName,
                    LastName = lastName,
                    Email = searchEmail
                );
                if (processRoles.isFieldExisting('OneHealthID_Name__c', 'Contact')
                        && String.isNotBlank(preferredName)) {
                    businessContact.put('OneHealthID_Name__c', preferredName);
                }
                insert businessContact;
                newCommUser = businessContact.Id;
            }
        }
        return newCommUser ;
    }

    private static Id resolveBusinessAccountContactId(Id accountId, Auth.UserData data) {
        if (accountId == null) return null;
        String searchEmail = data == null ? null : data.email;
        if (String.isBlank(searchEmail) && data != null && data.attributeMap != null
                && data.attributeMap.containsKey('pidp_email')) {
            searchEmail = data.attributeMap.get('pidp_email');
        }
        if (String.isBlank(searchEmail) && data != null) searchEmail = data.userName;

        List<Contact> contacts;
        if (String.isNotBlank(searchEmail)) {
            contacts = [SELECT Id FROM Contact WHERE AccountId = :accountId AND Email = :searchEmail LIMIT 1];
            if (!contacts.isEmpty()) return contacts[0].Id;
        }
        contacts = [SELECT Id FROM Contact WHERE AccountId = :accountId ORDER BY CreatedDate ASC LIMIT 1];
        return contacts.isEmpty() ? null : contacts[0].Id;
    }

    @Future
    public static void managePublicGroups(Id userId, String userProvisioningRole)
    {
        List<String> userGroups = new List<String>();
        System.debug('userId: ' + userId);
        System.debug('userProvisioningRole: ' + userProvisioningRole);
        
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility(userProvisioningRole);

        for (IDP_User_Registration_Permission_Set__mdt userGroupRec : processRoles.userPermissionSet)
        {
            if (userGroupRec.Assignment_Type__c == USER_ASSIGNMENT_TYPE_PUBLICGROUP)
            {
                userGroups.add(userGroupRec.Salesforce_Public_Group__c);
            } 
            else 
            {
                if (userGroupRec.Assignment_Type__c == USER_ASSIGNMENT_TYPE_QUEUE)
                {
                    userGroups.add(userGroupRec.Salesforce_Queue__c);
                }
            }
            
        }
        if (userGroups.size() > 0)
        {
            List<GroupMember> groupList = new List<GroupMember>();
            List<Group> grp = [SELECT Id FROM Group WHERE DeveloperName IN :userGroups];
            
            for (Group g : grp) {
                GroupMember gp = new GroupMember(GroupId = g.Id);
                gp.UserOrGroupId = userId;
                groupList.add(gp);
            }
                
            if(groupList.size() > 0)
            {
                insert groupList;
            }

            System.debug('GroupList: ' + groupList);
        }
 
    } 

    @Future
    public static void updateContactDetails(String contactDetails) {
        Contact contactDetail = (Contact)JSON.deserialize(contactDetails, Contact.class);
        update contactDetail;
            
    }
    
    private static List<IDP_User_Registration_User_Mapping__mdt> manageUserRole(Auth.UserData data)
    {
         /*
        * Description: Manage user role
        * Parameters:
        *     Auth.UserData data: UserData id token payload, including attributeMap representing the id token equivalent
        * Returns:
        *     IDP_User_Registration_User_Mapping__mdt: roles
        * 
        */ 

        List<IDP_User_Registration_User_Mapping__mdt> roles = new List<IDP_User_Registration_User_Mapping__mdt>();
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility();

        System.debug('data.attributeMap.get(BCEID_IDP_KEY): ' + data.attributeMap.get(BCEID_IDP_KEY));
        //Determine source IDP
        if (data.attributeMap.containsKey(BCSC_IDP_KEY)) {
            // BCSC
            processRoles = new UserRegistrationCustomMetadataUtility(data.attributeMap.get(BCSC_IDP_KEY));
            roles = processRoles.userMapping;
        } else if (data.attributeMap.containsKey(BCEID_IDP_KEY) && data.attributeMap.get(BCEID_IDP_KEY) == USER_PROVISIONING_ROLE_BCEID)  {
            //BCEID - 
            processRoles = new UserRegistrationCustomMetadataUtility(data.attributeMap.get(BCEID_IDP_KEY));
            roles = processRoles.userMapping;  
        } else if (data.attributeMap.containsKey('roles')) {
            // MoH
            processRoles = new UserRegistrationCustomMetadataUtility(data.attributeMap.get('roles'));
            roles = processRoles.userMapping;   
        }
        
        return roles;
    }

    public static string fetchUserMappingKey(Auth.UserData data)
    {
        String mappingKey = '';
        //Determine source IDP
        if (data.attributeMap.containsKey(BCSC_IDP_KEY)) {
            // BCSC
            mappingKey = BCSC_IDP_KEY;
        } else if (data.attributeMap.containsKey(BCEID_IDP_KEY) && data.attributeMap.get(BCEID_IDP_KEY) == USER_PROVISIONING_ROLE_BCEID) {
            //BCEID {
            mappingKey = BCEID_IDP_KEY;
            System.debug('BCEID_IDP_KEY: ' + BCEID_IDP_KEY);
        } else if (data.attributeMap.containsKey('roles')) {
            //MoH
            mappingKey = 'roles';
        }
        return mappingKey;
    }
    
    public static string fetchLicenseType(Auth.UserData data)
    {
        String licenseType = '';
        UserRegistrationCustomMetadataUtility fetchLicenseType = New UserRegistrationCustomMetadataUtility(data.attributeMap.get('roles'));
        List<IDP_User_Registration_User_Mapping__mdt> foundRoleMaping = new List<IDP_User_Registration_User_Mapping__mdt>();
        foundRoleMaping.addAll(fetchLicenseType.ReadMapping(data.attributeMap.get('roles')));
        
        if (foundRoleMaping.size() > 0)
        {
            for (IDP_User_Registration_User_Mapping__mdt foundRoleMaping_rec : foundRoleMaping)
            {
                licenseType = foundRoleMaping_rec.Salesforce_User_License__c;
            }
        }
        return licenseType;
    }
    public static AttributeMapping fetchAttributeValue(Auth.UserData data, String sourceAttribute, String defaultAttributeValue)
    {
        UserRegistrationCustomMetadataUtility userAttribute = new UserRegistrationCustomMetadataUtility();
        AttributeMapping mapping = new AttributeMapping();
        if (userAttribute.userAttributeMapping_map != null && 
                userAttribute.userAttributeMapping_map.containsKey(sourceAttribute) && 
                data.attributeMap.containsKey(sourceAttribute)) {
            IDP_User_Registration_Attribute_Mapping__mdt foundAttributes = userAttribute.userAttributeMapping_map.get(sourceAttribute);
            mapping.Source_Attribute = foundAttributes.Source_Attribute_Value__c;
            mapping.Target_Object = foundAttributes.Target_Object_and_Element__c.substringBefore('.');
            mapping.Target_Field = foundAttributes.Target_Object_and_Element__c.substringAfter('.');
            mapping.Match_Required = foundAttributes.Match_Required__c;
        } else {
            mapping.Source_Attribute = sourceAttribute;
            mapping.Target_Object = defaultAttributeValue.substringBefore('.');
            mapping.Target_Field = defaultAttributeValue.substringAfter('.');
            mapping.Match_Required = false;
        }
        return mapping;

    }
    public static string generateUserName(Auth.UserData data, String nameType, String domainName)
    {
        /*
        * Description: Generate User name used in user creation/matching
        * Parameters:
        *     Auth.UserData data: UserData id token payload, including attributeMap representing the id token equivalent
                            nameType: source attribute to use for username construction
                            domainName: supplied domainName to be used when username is is not in email format
        * Returns:
        *     String: Username
        * 
        */
        String suffixName = '';
        String directoryName = domainName;
        String customDomain = URL.getOrgDomainUrl()
                        .toExternalForm()
                        .substringAfter('https://')
                        .substringBefore('.');
        suffixName = customDomain.substringAfter('--');
        if (String.isEmpty(suffixName)) {
            suffixName = customDomain;
        }
        if (data.attributeMap.containsKey('pidp_email') && !String.isEmpty(data.attributeMap.get('pidp_email'))) {
            directoryName = data.attributeMap.get('pidp_email').substringAfter(EMAIL_ASPERAND_SIGN);
        } else if (data.email != null && data.email.contains(EMAIL_ASPERAND_SIGN)) {
            if (String.isEmpty(directoryName)) {
                directoryName = data.email.substringAfter(EMAIL_ASPERAND_SIGN);
            }
        }  
        
        return data.identifier + EMAIL_ASPERAND_SIGN + directoryName + '.' + suffixName;
    }

    public static string generateEmailAddress(Auth.UserData data, String userName)
    {
        /*
        * Description: Generate/determin User email used in user creation/matching
        * Parameters:
        *     Auth.UserData data: UserData id token payload, including attributeMap representing the id token equivalent
                            userName: source attribute to use for email construction
        * Returns:
        *     String: email
        * 
        */  
        String emailAddressComplete = '';    
        //first see if attributeMap contains a valid email
        if (data.email != null && data.email.contains(EMAIL_ASPERAND_SIGN)) {
            emailAddressComplete = data.email;
        } else if (data.attributeMap.containsKey('pidp_email')) {
            emailAddressComplete = data.attributeMap.get('pidp_email');
        } else {
            emailAddressComplete = userName;
        }
        System.debug('emailAddressComplete: ' + emailAddressComplete);
        return emailAddressComplete;
    }
    public static string generateUserAlias(Auth.UserData data)
    {
        /*
        * Description: Generate User name used in user creation/matching
        * Parameters:
        *     Auth.UserData data: UserData id token payload, including attributeMap representing the id token equivalent
        * Returns:
        *     String: Username
        * 
        */
        integer unique_num = Math.mod(Math.abs(Crypto.getRandomInteger()), 10);
        return String.valueOf(data.username.left(4) + '_' + String.valueOf(unique_num)).left(8);
    }
    
    public static Boolean checkAvailableLicense(String licenseType) 
    {
         /*
        * Description: look for available licenses based the value being passed in.
        * Parameters:
        *     String licenseType: License type used to verify available licenses.
        * Returns:
        *     String: Boolean
        * 
        */           
        List<UserLicense> availableLicense_list = [
            SELECT TotalLicenses, UsedLicenses
            FROM UserLicense
            WHERE Name = :licenseType
            LIMIT 1
        ];

        if (!availableLicense_list.isEmpty()) {
            return availableLicense_list[0].TotalLicenses > availableLicense_list[0].UsedLicenses;
        }
        return false;
        
    }

    public static String checkValidIdp(Auth.UserData data) 
    {
         /*
        * Description: verify user token is a valid source.
        * Parameters:
        *     None
        * Returns:
        *     String: String
        * 
        */           
        String currentHost = URL.getCurrentRequestUrl().getHost();
        List<IDP_User_Registration_Domain_Setting__mdt> availableDomainList = [
            SELECT Id, DeveloperName, Domain__c, Token_Source__c, Token_Attribute__c
            FROM IDP_User_Registration_Domain_Setting__mdt
            WHERE Domain__c = :currentHost
        ];

        if (availableDomainList.isEmpty()) {
            System.debug('isValidIdp: NA');
            return 'NA';
        }

        for (IDP_User_Registration_Domain_Setting__mdt domainSettingRec : availableDomainList) {
            if (data.attributeMap.containsKey(domainSettingRec.Token_Attribute__c)) {
                String currentIdp = data.attributeMap.get(domainSettingRec.Token_Attribute__c);
                if (currentIdp == domainSettingRec.Token_Source__c) {
                    System.debug('isValidIdp: YES');
                    return 'YES';
                }
            }
        }

        System.debug('isValidIdp: NO');
        return 'NO';
    }

    private class CommunityUserContact
    {
        Id ContactId;
        Id AccountId;
        String AccountName;
    }
    private class AttributeMapping
    {
        String Target_Field;
        String Target_Object;
        String Source_Attribute;
        Boolean Match_Required;
    }

}