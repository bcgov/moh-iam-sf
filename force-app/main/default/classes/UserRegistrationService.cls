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
*         public static void updateUsers(List<Id> userId, List<Id> portalId, List<Auth.UserData> data): Mass update existing users 
*         public static void deleteUsers(List<Id> userId, List<Id> portalId, List<Auth.UserData> data): Mass delete (deactivate) existing users 
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
    public static final String SALESFORCE_USER_LICENSE_COMMUNITY = 'Community';
    public static final String SALESFORCE_USER_LICENSE_STANDARD = 'Salesforce';
    public static final String EMAIL_ASPERAND_SIGN = '@';
    public static final String ACCOUNT_PERSONACCOUNT_RECORDTYPE = 'PersonAccount';
    public static final String BCSC_IDP_KEY = 'idp';
    public static final String MOH_IDP_KEY = 'roles';
    public static final String USER_USERNAME_REFERENCE = 'data.username';
    public static final String NON_REGULATED_USER_RECORD_TYPE = 'Non_Regulated_User_Record_Type__c';


    public static void createUsers(List<Id> portalId, List<Auth.UserData> data){
    /*
    * Description: Mass creates new users
    * Parameters:
    *     List<Id> portalId: Ordered list of Id of the portal (community) where the request originated from
    *     List<Auth.UserData> data: Ordered list of UserData id token payload, including attributeMap representing the id token equivalent
    * Returns:
    *     NONE
    * 
    */
        
    }


    public static void updateUsers(List<Id> userId, List<Id> portalId, List<Auth.UserData> data) {
    /*
     * Description: Mass updates existing users
     * Parameters:
     *     List<Id> userId: Ordered list of Id of the existing user
     *     List<Id> portalId: Ordered list of Id of the portal (community) where the request originated from
     *     List<Auth.UserData> data: Ordered list of UserData id token payload, including attributeMap representing the id token equivalent
     * Returns:
     *     NONE
     * 
     */
        List<User> user_list= new List<User>();
        for (User deactivateUser : [Select Id, isActive, FederationIdentifier From User where Id IN : userId]) {
            //deactivateUser.isActive = false;
            user_list.add(deactivateUser);
        }
        Update(user_list);
        
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
        //Verify user data - to be removed prior to completion
        String userdata = JSON.serialize(data.attributeMap);
        String nonRegulatedStaff = '';
        Boolean createUser = true;
        String existingBcscGuid = null;

        String keyLookup = UserRegistrationService.fetchUserMappingKey(data);
        UserRegistrationCustomMetadataUtility fetchRoles = new UserRegistrationCustomMetadataUtility(data.attributeMap.get(keyLookup));
        list<IDP_User_Registration_User_Mapping__mdt> userRoleList = new list<IDP_User_Registration_User_Mapping__mdt>();
        //Get user mapping record based on source IDP
        userRoleList.add(fetchRoles.ReadMapping(data.attributeMap.get(keyLookup)));
     
        system.debug('data:'+ json.serializePretty(data));
        User newUser = new User();
        //Create user
        if (userRoleList.size() > 0)
        {
            for (IDP_User_Registration_User_Mapping__mdt userRoleRec : userRoleList)
            {
                system.debug('userRole_rec:' + userRoleRec );
                String userName = UserRegistrationService.generateUserName(data, userRoleRec.Username_Type__c, userRoleRec.Default_Domain__c);
                String emailAddress = UserRegistrationService.generateEmailAddress(data, userName);
                List<Profile> profileId = [SELECT Id FROM profile WHERE name=:userRoleRec.Salesforce_User_Profile__c LIMIT 1];
                if (profileId.size() > 0) {

                    newUser.username = userName;
                    if (data.attributeMap.containsKey('pidp_email')) {
                        newUser.email = data.attributeMap.get('pidp_email');
                    } else {
                        newUser.email = emailAddress;
                    }  
                    if (data.attributeMap.containsKey('family_name')) {
                        newUser.LastName = data.attributeMap.get('family_name');
                    } else {
                        newUser.lastName = data.lastName;
                    }
                    if (data.attributeMap.containsKey('given_name')) {
                        newUser.firstName = data.attributeMap.get('given_name');
                    } else {
                        newUser.firstName = data.firstName;
                    }
    
                    newUser.FederationIdentifier = data.username;
                    newUser.alias = UserRegistrationService.generateUserAlias(data);
                    
                    newUser.languagelocalekey = UserInfo.getLanguage();
                    newUser.localesidkey = UserInfo.getLocale();
                    newUser.emailEncodingKey = 'UTF-8';
                    newUser.timeZoneSidKey = 'America/Vancouver';
                    newUser.profileId = profileId[0].Id;
                } else {
                    throw new Auth.AuthProviderPluginException('No Match found, Missing Profile Info');
                }
            }
        }
        try {
            /****************************************************************** */
            List<IDP_User_Registration_User_Mapping__mdt>  matchingRole_list = new List<IDP_User_Registration_User_Mapping__mdt>();
                        
            matchingRole_list.add(manageUserRole(data)); 
    
            for (IDP_User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list)
            {
                if (matchingRole_rec.Non_Regulated_User_Record_Type__c == NON_REGULATED_USER_RECORD_TYPE)
                {
                    nonRegulatedStaff = matchingRole_rec.Non_Regulated_User_Record_Type__c;
                }
                else {
                    nonRegulatedStaff = 'PersonAccount';
                }
                if (matchingRole_rec.Salesforce_User_License__c == SALESFORCE_USER_LICENSE_COMMUNITY)
                {
                    Boolean isEndorserData = false;
                    Boolean isEndorserFound = false;
                    Boolean isCpnFound = false;
                    Boolean isBCSCData = false;
                    Boolean isHdidMatch = false;
                    Boolean isCpnData = false;
                    String contactId = null;
                    List<Account> bcscMatch = new List<Account>();
                    List<Account> endorserData = new List<Account>();
                    List<Account> cpnData = new List<Account>();

                    if (data.attributeMap.containsKey('idp') && data.attributeMap.containsKey('bcsc_guid')) {
                        isBCSCData = true;
                        List<String> keyValue = new List<String>();
                        keyValue.addAll(data.attributeMap.get('bcsc_guid').split(','));
                        if (!keyValue.isEmpty()) {
                            bcscMatch = fetchPersonAccount(keyValue);
                        }
                        
                    }
                    //lookup up when endorser_data is available
                    if (data.attributeMap.containsKey('endorser_data')) {
                        isEndorserData = true;
                        List<String> keyValue = new List<String>();
                        keyValue.addAll(data.attributeMap.get('endorser_data').remove('[').remove(']').split(','));
                        System.debug('keyValue:' + keyValue);
                        if (!keyValue.isEmpty()) {
                            endorserData = fetchPersonAccount(keyValue);
                            if (!endorserData.isEmpty()) {
                                isEndorserFound = true;
                            }
                        }
                    }
                    //lookup up when common_provider_number is available
                    if (data.attributeMap.containsKey('common_provider_number')) {
                        isCpnData = true;
                        List<String> keyValue = new List<String>();
                        keyValue.addAll(data.attributeMap.get('common_provider_number').split(','));
                        System.debug('keyValue:' + keyValue);
                        if (!keyValue.isEmpty()) {
                            cpnData = fetchPersonAccount(keyValue);
                            if (!cpnData.isEmpty()) {
                                contactId = cpnData[0].PersonContactId;
                                isCpnFound = true;
                            }
                        }
                    }

                    // Create
                    String searchValue = ''; 
                    Boolean fieldExisting = false;
                    if (data.attributeMap.ContainsKey('hdid')) {
                        fieldExisting = fetchRoles.isFieldExisting('HDID__c','Account');
                        searchValue = data.attributeMap.get('hdid');
                    }
                    
                    if (data.attributeMap.containsKey('idp') && data.attributeMap.containsKey('hdid') 
                            && fieldExisting ) {
                        String qryString = 'select id,PersonContactId from Account where HDID__c = \'' + searchValue + '\'';
                        List<Account> accountList = Database.query(qryString);
                        
                        if(accountList.size() > 0 && String.isNotBlank(accountList[0].PersonContactId)){
                            isHdidMatch = true;
                            contactId = accountList[0].PersonContactId;  
                        } else {
                            isHdidMatch = false;
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
                    if (isEndorserData && !isEndorserFound && !isHdidMatch) {
                        throw new Auth.AuthProviderPluginException('No Match found for Endorser Supplied Data');
                    }
                    if (!isHdidMatch && isHdidMatch != null && fieldExisting) {
                        throw new Auth.DiscoveryCustomErrorException('No Match found for HDID');
                    } else if (isHdidMatch)
                    {
                        newUser.ContactId = contactId;
                    } else if (!isCpnFound) {
                        contactId = managePersonAccount(data, nonRegulatedStaff );
                    }
                        
                    newUser.ContactId = contactId;
                }
            }

            // Update user role & permissionset based on latest payload
            UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility();
            
            for (IDP_User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list)
            {
                if (matchingRole_rec.Salesforce_User_Role__c != Null)
                {
                    for (UserRole userRole_rec: [SELECT DeveloperName,Id,Name FROM UserRole Where Name =: matchingRole_rec.Salesforce_User_Role__c])
                    {
                        newUser.UserRoleId = matchingRole_rec.Id;
                    }
                }       
            }
            List<User> checkUser = [
                SELECT Id 
                FROM User 
                WHERE FederationIdentifier =: data.username ];

            if(checkUser.size() > 0) {
                createUser = false;
                newUser.Id = checkUser[0].Id;
            }        
            if(createUser) {
                insert newUser;
            } else {
                update newUser;
            } 
             // add/update any new permission sets
            managePermissionSet(newUser.Id, data);
            
            // add user to Public Group
            for (IDP_User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list)
            {
                if (matchingRole_rec.Salesforce_Public_Group__c != Null)
                {
                    managePublicGroups(newUser.Id, matchingRole_rec.Salesforce_Public_Group__c);
                }     
            }      
        }
        catch (Exception e) {
            system.debug(e.getMessage());
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
        system.debug('data:'+ json.serializePretty(data));
        //Fetch Salesforce Id
        User existingUser = [SELECT Id, username, email,lastname,firstname,alias,
                                emailEncodingKey,timeZoneSidKey,languagelocaleKey,localesidkey
                             FROM User WHERE Id =: userId];
        
         //Verify user data - to be removed prior to completion

        String l_userdata = JSON.serialize(data.attributeMap);

        if (existingUser.lastName != data.lastName)
        {
            existingUser.lastName = data.lastName;
        }
        if (existingUser.firstName != data.firstName)
        {
            existingUser.firstName = data.firstName;
        }
        existingUser.FederationIdentifier = data.username;
        
        existingUser.alias = UserRegistrationService.generateUserAlias(data);
        
        existingUser.languagelocalekey = UserInfo.getLanguage();
        existingUser.localesidkey = UserInfo.getLocale();
        existingUser.emailEncodingKey = 'UTF-8';
        existingUser.timeZoneSidKey = 'America/Vancouver';
        
        // Update user role & permissionset based on latest payload
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility();

        // add/update any new permission sets
        managePermissionSet(existingUser.Id, data);
        
        // add/update user role
        List<IDP_User_Registration_User_Mapping__mdt>  matchingRole_list = new List<IDP_User_Registration_User_Mapping__mdt>();

        matchingRole_list.add(manageUserRole(data));
        for (IDP_User_Registration_User_Mapping__mdt matchingRoleRec : matchingRole_list)
        {
            String userName = UserRegistrationService.generateUserName(data, matchingRoleRec.Username_Type__c, matchingRoleRec.Default_Domain__c);
            String emailAddress = UserRegistrationService.generateEmailAddress(data, userName);   

            if (existingUser.username != userName)
            {
                existingUser.username = userName;
            }
            if (existingUser.email != emailAddress)
            {
                existingUser.email = emailAddress;
            }
            for (UserRole userRoleRec : [SELECT DeveloperName,Id,Name FROM UserRole Where Name =: matchingRoleRec.Salesforce_User_Role__c])
            {
                existingUser.UserRoleId = userRoleRec.Id;
                existingUser.isActive = true;
            }
        }
        
            // add user to Public Group
            for (IDP_User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list)
            {
                if (matchingRole_rec.Salesforce_Public_Group__c != Null)
                {
                    managePublicGroups(existingUser.Id, matchingRole_rec.Salesforce_Public_Group__c);
                }     
            }         
        try {
            update(existingUser);
        } 
        catch (Exception e) {
            System.debug(e.getMessage());
            throw e;
            //throw new Auth.LoginDiscoveryException(e.getMessage());
        }

        return existingUser;
        
    }

    private static List<Account> fetchPersonAccount(List<String> keyLookup) 
    {
        Boolean isNewAccount = false;
        List<Account> newCommUser = new List<Account>();
        List<String> keyvalues = new List<String>();
        
        if (!keyLookup.isEmpty()) {
            keyvalues.addAll(keyLookup);
        } else {
            return newCommUser;
        }
        
        List<Account> existingAccount = [
            SELECT Id, PersonContactId, FirstName, LastName, PersonEmail, RecordTypeId, SourceSystemIdentifier 
            FROM Account where HealthCloudGA__SourceSystemId__pc IN : keyValues 
            ];
        
        return existingAccount;
    }

    private static String managePersonAccount(Auth.UserData data, String optionalRecordType) 
    {
        Boolean isNewAccount = false;
        Id newCommUser = null;
        String searchEmail = '';
        
        if (data.email!= null) {
            searchEmail = data.email;
        } else {
            searchEmail = data.username;
        }
        
        List<Account> existingAccount = [
            SELECT Id, PersonContactId, FirstName, LastName, PersonEmail, RecordTypeId 
            FROM Account where PersonEmail =: searchEmail 
            ];
        Account newPersonAccount = new Account();
        
        if (existingAccount.size() == 0) 
        {
            isNewAccount = true;
            Id personAccountRecordTypeId =  Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(optionalRecordType).getRecordTypeId();
        
            newPersonAccount.FirstName = data.firstName ;

            newPersonAccount.LastName = data.lastName;

            if(data.email!= null) {
                String emailaddress = data.email;
                if (emailaddress.length() > 0) {
                    newPersonAccount.PersonEmail = emailaddress;
                } else {
                    newPersonAccount.PersonEmail = data.username;
                }
            } else if (data.attributeMap.containsKey('pidp_email')) {
                newPersonAccount.PersonEmail = data.attributeMap.get('pidp_email');
            } else {
                newPersonAccount.PersonEmail = data.userName;
            }


            newPersonAccount.RecordTypeId = personAccountRecordTypeId;
            insert newPersonAccount;

            newCommUser = [SELECT PersonContactId FROM Account WHERE Id =:newPersonAccount.Id ].PersonContactId;
        } else {
            newCommUser = existingAccount[0].PersonContactId;
        }

        if (!isNewAccount) {
            update(existingAccount);
        }
        return newCommUser ;
    }

    @Future
    public static void managePublicGroups(Id userId, String userPublicGroup)
    {

        list<groupMember> groupList = new list<groupMember>();
        list<Group> grp = [select id from Group where DeveloperName in : userPublicGroup.split(',')];
        
        for(group g : grp){
            groupMember gp = new groupMember(groupId = g.Id);
            gp.UserOrGroupId = userId;
            groupList.add(gp);
        }
            
        if(groupList.size() > 0)
        insert groupList;
        System.debug('GroupList: ' + groupList);
    }
    
    private static void managePermissionSet(Id userId, Auth.UserData data)
    {
        /*
        * Description: Manage user permissionset(s)
        * Parameters:
        *     Id userId: Id of the user logging into the system via provider
        *     Auth.UserData data: UserData id token payload, including attributeMap representing the id token equivalent
        * Returns:
        *     None
        * 
        */            
        Set<Id> userIds = new Set<Id>();
        Set<Id> roleIds = new Set<Id>();
        Set<Id> PermIds = new Set<Id>();
        Set<String> availableRoles = new Set<String>();
        
        String keyLookup = UserRegistrationService.fetchUserMappingKey(data);
        //Get user mapping record based on source IDP
        String UserRoleAssign = data.attributeMap.get(keyLookup);
        
        UserRegistrationCustomMetadataUtility processPermissions = new UserRegistrationCustomMetadataUtility();
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility(UserRoleAssign);
       
        IDP_User_Registration_User_Mapping__mdt userRole = new IDP_User_Registration_User_Mapping__mdt();
        // get role metadata
        for (IDP_User_Registration_User_Mapping__mdt userMapping : processRoles.userMapping)
        {
            availableRoles.add(userMapping.DeveloperName);
            
            if (userMapping.External_Provider_Role__c == UserRoleAssign)
            {
                roleIds.add(userMapping.Id);
                userRole = userMapping;
            }
        }
        
        List<PermissionSetAssignment> removeOtherPerms = new List<PermissionSetAssignment>();
        for(PermissionSetAssignment existingPSAByUser_rec : [SELECT AssigneeId,Id,PermissionSetId,PermissionSet.Name 
                                                                FROM PermissionSetAssignment 
                                                                WHERE AssigneeId =: userId
                                                                AND PermissionSet.ProfileId = null  
                                                                ORDER BY AssigneeId ASC])
        {
            if(userRole.DeveloperName != existingPSAByUser_rec.PermissionSet.Name)
            {
                removeOtherPerms.add(existingPSAByUser_rec);
            }
        }        

        // get permission metadata
        Set<String> associatedPermset = new Set<String>();
        Set<String> associatedPermsetGroup= new Set<String>();



        for (IDP_User_Registration_Permission_Set__mdt userPerms : processRoles.userPermissionSet)
        {
            System.debug('userRole.DeveloperName:' + userRole.DeveloperName);
            System.debug('userPerms.QualifiedApiName' + userPerms.QualifiedApiName);

            if (userPerms.Assignment_Type__c == USER_ASSIGNMENT_TYPE_PERMISSIONSET)
            {
                if (userRole.DeveloperName == userPerms.QualifiedApiName)
                {
                    associatedPermset.add(userPerms.Salesforce_Permission_Set__c);
                }
            } else if (userPerms.Assignment_Type__c == USER_ASSIGNMENT_TYPE_PERMISSIONSETGROUP)
            {
                if (userRole.DeveloperName == userPerms.QualifiedApiName)
                {
    
                    associatedPermsetGroup.add(userPerms.Salesforce_Permission_Set_Group__c);
                } 
            }

        }
        //fetch current Assignments
        List<PermissionSetAssignment> existingPermSetAssign = [Select Id, PermissionSetGroupId, PermissionSetId, IsActive from PermissionSetAssignment where AssigneeId =: userId];
        
        List<PermissionSetAssignment> permissionSetAssignList = new List<PermissionSetAssignment>();
        List<PermissionSetAssignment> permissionSetRemoveList = new List<PermissionSetAssignment>();
        Set<Id> genPSAset = new Set<Id>();
        List<PermissionSet> permissionSetList = new List<PermissionSet>();
        // PermissionSet's
        for (PermissionSet perm : [SELECT ID FROM PermissionSet  WHERE  Name IN: associatedPermset])
        { 
            for(PermissionSetAssignment genPSArec : existingPermSetAssign)
            {
                if (genPSArec.PermissionSetGroupId == null)
                {
                    genPSAset.add(genPSArec.Id);
                    PermissionSetAssignment psaRemoverec = new PermissionSetAssignment (Id = genPSArec.Id);
                    permissionSetRemoveList.add(psaRemoverec);  
                }
          
            }
            PermissionSetAssignment psa = new PermissionSetAssignment (PermissionSetId = perm.Id, AssigneeId = userId);
            permissionSetAssignList.add(psa);
        }
        System.debug('associatedPermsetGroup:' + associatedPermsetGroup);
        // PermissionSetGroup's
        for (PermissionSetGroup perm : [SELECT ID FROM PermissionSetGroup  WHERE  DeveloperName IN: associatedPermsetGroup])
        { 
            for(PermissionSetAssignment genPSArec : existingPermSetAssign)
            {
                if (genPSArec.PermissionSetGroupId != null)
                {
                    genPSAset.add(genPSArec.Id);
                    PermissionSetAssignment psaRemoverec = new PermissionSetAssignment (Id = genPSArec.Id);
                    permissionSetRemoveList.add(psaRemoverec);     
                }
            }
            PermissionSetAssignment psa = new PermissionSetAssignment (PermissionSetGroupId = perm.Id, AssigneeId = userId);
            permissionSetAssignList.add(psa);
        }
        System.debug('removeOtherPerms: ' + removeOtherPerms);

        try {
            if(removeOtherPerms.size() > 0)
            {
                delete removeOtherPerms;
            } 
            if(permissionSetAssignList.size() > 0) {
                String json_PermissionSetAssign = JSON.serialize(permissionSetAssignList, true);          
                //insert permissionSetAssignList;
                insertPermissionSetAssignment(json_PermissionSetAssign);
            }
        }catch(exception e){
            system.debug('exception caught:' + e);
        }   
    
    }
    
    @Future
    public static void insertPermissionSetAssignment(String permissionsets) {
        List<PermissionSetAssignment> permissionSetAssignList = (List<PermissionSetAssignment>)JSON.deserialize(permissionsets, List<PermissionSetAssignment>.class);
        
        insert permissionSetAssignList;

    }
    
    private static IDP_User_Registration_User_Mapping__mdt manageUserRole(Auth.UserData data)
    {
         /*
        * Description: Manage user role
        * Parameters:
        *     Auth.UserData data: UserData id token payload, including attributeMap representing the id token equivalent
        * Returns:
        *     IDP_User_Registration_User_Mapping__mdt: roles
        * 
        */ 

        UserRegistrationCustomMetadataUtility processPermissions = new UserRegistrationCustomMetadataUtility();
        IDP_User_Registration_User_Mapping__mdt roles = new IDP_User_Registration_User_Mapping__mdt();
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility();

        //Determine source IDP
        if (data.attributeMap.containsKey('idp')) {
            // BCSC
            processRoles = new UserRegistrationCustomMetadataUtility(data.attributeMap.get('idp'));
            roles = processRoles.ReadMapping(data.attributeMap.get('idp'));
        } else if (data.attributemap.containsKey('roles')) {
            // MoH
            processRoles = new UserRegistrationCustomMetadataUtility(data.attributeMap.get('roles'));
            roles = processRoles.ReadMapping(data.attributeMap.get('roles'));
        }
        
        return roles;
    }

    public static string fetchUserMappingKey(Auth.UserData data)
    {
        String mappingKey = '';
        //Determine source IDP
        if (data.attributeMap.containsKey('idp')) {
            // BCSC
            mappingKey = 'idp';
        } else if (data.attributemap.containsKey('roles')) {
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
        foundRoleMaping.add(fetchLicenseType.ReadMapping(data.attributeMap.get('roles')));
        
        if (foundRoleMaping.size() > 0)
        {
            for (IDP_User_Registration_User_Mapping__mdt foundRoleMaping_rec : foundRoleMaping)
            {
                licenseType = foundRoleMaping_rec.Salesforce_User_License__c;
            }
        }
        Return licenseType;
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
        String customDomain = URL.getSalesforceBaseUrl()
                        .toExternalForm()
                        .substringAfter('https://')
                        .substringBefore('.');
        suffixName = CustomDomain.substringAfter('--');
        if (String.isEmpty(suffixName)) {
            suffixName = customDomain;
        }
        //first see if attributeMap contains a valid email
        if (data.email != null && data.email.contains(EMAIL_ASPERAND_SIGN)) {
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
        return String.valueof(data.username.left(4) + '_' + String.Valueof(unique_num)).left(8);
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
        Boolean isLicenseAvailable = false;
        UserLicense[] availableLicense_list =
            [SELECT CreatedDate,Id,LastModifiedDate,LicenseDefinitionKey,MasterLabel,Name,Status,
                SystemModstamp,TotalLicenses,UsedLicenses,UsedLicensesLastUpdated 
            FROM UserLicense where Name =: licenseType];
            
        if (availableLicense_list.size() > 0)
        {
            for(UserLicense availableLicense_rec : availableLicense_list)
            {
                if (availableLicense_rec.TotalLicenses > availableLicense_rec.UsedLicenses)
                {
                    isLicenseAvailable = true;
                }
            }
            
        }
        return isLicenseAvailable;
        
    }

    private class CommunityUserContact
    {
        Id ContactId;
        Id AccountId;
        String AccountName;
    }

}