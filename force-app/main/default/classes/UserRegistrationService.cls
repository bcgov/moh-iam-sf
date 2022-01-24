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


public class UserRegistrationService{

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
            deactivateUser.isActive = false;
            user_list.add(deactivateUser);
        }
        Update(user_list);
        
    }
    
    public static void deleteUsers(List<Id> userId, List<Id> portalId, List<Auth.UserData> data) {

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
        System.debug('UserRegistrationService.createUser');
        String userdata = JSON.serialize(data.attributeMap);
        System.debug('data:' + data);
        System.debug('userdata:' + userdata);
        
        //Create user
        String l_username = UserRegistrationService.generateUserName(data);
        
        UserRegistrationCustomMetadataUtility fetchRoles = new UserRegistrationCustomMetadataUtility(data.attributeMap.get('roles'));
        list<User_Registration_User_Mapping__mdt> userRole_list = new list<User_Registration_User_Mapping__mdt>();
        userRole_list.add(fetchRoles.ReadMapping(data.attributeMap.get('roles')));
        
        User newUser = new User();
        if (userRole_list.size() > 0)
        {
            for (User_Registration_User_Mapping__mdt userRole_rec : userRole_list)
            {
                Profile p = [SELECT Id FROM profile WHERE name=:userRole_rec.Salesforce_User_Profile__c];
        
                newUser.username = l_username;
                newUser.email = data.email;
                newUser.lastName = data.lastName;
                newUser.firstName = data.firstName;
                newUser.FederationIdentifier = data.username;
                newUser.alias = UserRegistrationService.generateUserAlias(data);
                
                System.debug('UserInfo.getLanguage();' + UserInfo.getLanguage());
                System.debug('UserInfo.getLocale();' + UserInfo.getLocale());
                newUser.languagelocalekey = UserInfo.getLanguage();
                newUser.localesidkey = UserInfo.getLocale();
                newUser.emailEncodingKey = 'UTF-8';
                newUser.timeZoneSidKey = 'America/Los_Angeles';
                newUser.profileId = p.Id;
            }
        }
        insert newUser;
         // Update user role & permissionset based on latest payload
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility();
        
        System.debug('newUser:' + newUser);
        // add/update any new permission sets
        managePermissionSet(newUser.Id, data);
        
        // add/update user role
        List<User_Registration_User_Mapping__mdt>  matchingRole_list = new List<User_Registration_User_Mapping__mdt>();
        
        System.debug('matchingRole_list:' + matchingRole_list);
        
        matchingRole_list.add(manageUserRole(newUser.Id, data));
        for (User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list)
        {
            System.debug('matchingRole_rec:' + matchingRole_rec);
            for (UserRole userRole_rec: [SELECT DeveloperName,Id,Name FROM UserRole Where Name =: matchingRole_rec.Salesforce_User_Role__c])
            {
                newUser.UserRoleId = userRole_rec.Id;
            }
        }       
        
        update newUser;
        return newUser;
    }
    
    public static void updateUser(Id userId, Id portalId, Auth.UserData data) {
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
        //Fetch Salesforce Id
        User existingUser = [Select Id, username, email,lastname,firstname,alias,
                                emailEncodingKey,timeZoneSidKey,languagelocaleKey,localesidkey
                             From User where Id =: userId];
        
         //Verify user data - to be removed prior to completion
        System.debug('UserRegistrationService.updateUser');
        String l_userdata = JSON.serialize(data.attributeMap);
        String l_username = UserRegistrationService.generateUserName(data);
        
        System.debug('l_userdata:' + l_userdata);
        System.debug('l_username:' + l_username);       

        if (existingUser.username != l_username)
        {
            existingUser.username = l_username;
        }
        if (existingUser.email != data.email)
        {
            existingUser.email = data.email;
        }
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
        existingUser.timeZoneSidKey = 'America/Los_Angeles';
        
        // Update user role & permissionset based on latest payload
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility();

        // add/update any new permission sets
        managePermissionSet(existingUser.Id, data);
        
        // add/update user role
        List<User_Registration_User_Mapping__mdt>  matchingRole_list = new List<User_Registration_User_Mapping__mdt>();

        matchingRole_list.add(manageUserRole(existingUser.Id, data));
        for (User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list)
        {
            for (UserRole userRole_rec: [SELECT DeveloperName,Id,Name FROM UserRole Where Name =: matchingRole_rec.Salesforce_User_Role__c])
            {
                existingUser.UserRoleId = userRole_rec.Id;
                existingUser.isActive = true;
            }
        }
        
        update(existingUser);
        
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
        
        String UserRoleAssign = data.attributeMap.get('roles');
        
        UserRegistrationCustomMetadataUtility processPermissions = new UserRegistrationCustomMetadataUtility();
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility(UserRoleAssign);
        System.debug('data.attributeMap.get(roles):' + UserRoleAssign);
       
        User_Registration_User_Mapping__mdt userRole = new User_Registration_User_Mapping__mdt();
        // get role metadata
        for (User_Registration_User_Mapping__mdt userMapping : processRoles.userMapping)
        {
            system.debug('userMapping:' + userMapping);
            availableRoles.add(userMapping.DeveloperName);
            
            if (userMapping.External_Provider_Role__c == UserRoleAssign)
            {
                roleIds.add(userMapping.Id);
               userRole = userMapping;
            }
        }
        
        system.debug('userRole:' +userRole);
        List<PermissionSetAssignment> removeOtherPerms = new List<PermissionSetAssignment>();
        for(PermissionSetAssignment existingPSAByUser_rec : [SELECT AssigneeId,Id,PermissionSetId,PermissionSet.Name 
                                                                FROM PermissionSetAssignment 
                                                                WHERE AssigneeId =: userId
                                                                AND PermissionSet.Name IN:availableRoles  
                                                                ORDER BY AssigneeId ASC])
        {
            system.debug('existingPSAByUser_rec:' + existingPSAByUser_rec.PermissionSet.Name);
            system.debug('userRole.DeveloperName:' + userRole.DeveloperName);
            if(userRole.DeveloperName != existingPSAByUser_rec.PermissionSet.Name)
            {
                removeOtherPerms.add(existingPSAByUser_rec);
            }
        }        
        system.debug('removeOtherPerms:'+removeOtherPerms);
        // get permission metadata
        Set<String> associatedPermset = new Set<String>();
        for (User_Registration_Permission_Set__mdt userPerms : processRoles.userPermissionSet)
        {
            if (userRole.DeveloperName == userPerms.Salesforce_Permission_Set__c)
            {
                System.debug('userPerms :' + userPerms );
                associatedPermset.add(userPerms.Salesforce_Permission_Set__c);
            }
        
        }
        
        System.debug('UserData:' + data);
        //System.debug('UserData.attributeMap: ' + UserData.attributeMap);
        System.debug('UserData.attributeMap: ' + Data.attributeMap);
        
        List<PermissionSetAssignment> permissionSetAssignList = new List<PermissionSetAssignment>();
        List<PermissionSetAssignment> permissionSetRemoveList = new List<PermissionSetAssignment>();
        Set<Id> genPSA_set = new Set<Id>();
        List<PermissionSet> permissionSetList = new List<PermissionSet>();
        for (PermissionSet perm : [SELECT ID FROM PermissionSet  WHERE  Name IN: associatedPermset])
        { 
            List<PermissionSetAssignment> existingPermSetAssign = [Select Id from PermissionSetAssignment where PermissionSetId =: perm.Id and AssigneeId =: userId];
            for(PermissionSetAssignment genPSA_rec : existingPermSetAssign)
            {
                genPSA_set.add(genPSA_rec.Id);
                PermissionSetAssignment psaRemove_rec = new PermissionSetAssignment (Id = genPSA_rec.Id, PermissionSetId = perm.Id, AssigneeId = userId);
                permissionSetRemoveList.add(psaRemove_rec);
                System.debug('permissionSetRemoveList:' + permissionSetRemoveList);                
            }
            System.debug('existingPermSetAssign.size():' + existingPermSetAssign.size());
            if(existingPermSetAssign.size() > 0)
            {

            } else
            {
                PermissionSetAssignment psa = new PermissionSetAssignment (PermissionSetId = perm.Id, AssigneeId = userId);
                permissionSetAssignList.add(psa);
                System.debug('permissionSetAssignList:' + permissionSetAssignList);
            }
            
        }
        try{
            //List<PermissionSetAssignment> removeOtherPerms = [Select Id 
            //                                                    from PermissionSetAssignment 
            //                                                    where  Id in: permissionSetRemoveList and AssigneeId =: userId]; //Id in: permissionSetRemoveList and
            if(removeOtherPerms.size() > 0)
            {
                delete removeOtherPerms;
            }            
            upsert permissionSetAssignList;
            
            
        }catch(exception e){
            system.debug('exception caught:' + e);
        }   
    
    }
    
    private static User_Registration_User_Mapping__mdt manageUserRole(Id userId, Auth.UserData data)
    {
         /*
        * Description: Manage user role
        * Parameters:
        *     Id userId: Id of the user logging into the system via provider
        *     Auth.UserData data: UserData id token payload, including attributeMap representing the id token equivalent
        * Returns:
        *     User_Registration_User_Mapping__mdt: roles
        * 
        */           
        UserRegistrationCustomMetadataUtility processPermissions = new UserRegistrationCustomMetadataUtility();
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility(data.attributeMap.get('roles'));

        User_Registration_User_Mapping__mdt roles = processRoles.ReadMapping(data.attributeMap.get('roles'));
        
        System.debug('roles:'+ roles);
        
        return roles;
    }
    
    private static string fetchLicenseType(Auth.UserData data)
    {
        String licenseType = '';
        UserRegistrationCustomMetadataUtility fetchLicenseType = New UserRegistrationCustomMetadataUtility(data.attributeMap.get('roles'));
        List<User_Registration_User_Mapping__mdt> foundRoleMaping = new List<User_Registration_User_Mapping__mdt>();
        foundRoleMaping.add(fetchLicenseType.ReadMapping(data.attributeMap.get('roles')));
        
        if (foundRoleMaping.size() > 0)
        {
            for (User_Registration_User_Mapping__mdt foundRoleMaping_rec : foundRoleMaping)
            {
                licenseType = foundRoleMaping_rec.Salesforce_User_License__c;
            }
        }
        Return licenseType;
    }
    
    public static string generateUserName(Auth.UserData data)
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
        return data.identifier + '@MoH.com';
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
        return String.valueof(data.username.left(4) + '' + String.Valueof(unique_num)).left(8);
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
        
    public static void deleteUser(Id userId, Id portalId, Auth.UserData data) {
        
        //Verify user
        
        
        //Remove user
        
    }
    
    public Static void manageKeycloakUsers() {
        String clientId = 'MAID-CASE-MANAGEMENT-1';
        String clientSecret = '1212c064-53c0-41a1-826a-d932403aab11';
        String refreshToken = '';
        String authUrl = 'https://common-logon-dev.hlth.gov.bc.ca/auth/realms/moh_applications/protocol/openid-connect/token';
        //cfUrl = myobIntg.Company_File_URL__c;
        DateTime lastSync = System.now();
        Map<String, String> authJson = new Map<String, String>();
        // Get the Access Token using the Refresh Token.
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(authUrl);
        request.setMethod('POST');    
        request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        String payload = 'client_id='+EncodingUtil.urlEncode(clientId,'UTF-8')+'&client_secret='+EncodingUtil.urlEncode(clientSecret,'UTF-8')+'&grant_type=client_credentials';
        String auth_token='';
        String user_fed = 'rpoystil@idir';
        System.debug(payload);
        System.debug(request);
        
        request.setBody(payload);
        HttpResponse response = http.send(request);
        Map<String, Object> result = New Map<String, Object>();
        // Parse the JSON response
        if (response.getStatusCode() != 200) {
          System.debug('The status code returned was not expected: ' + response.getStatusCode() + ' ' + response.getStatus());
        } else {
          System.debug(response.getBody());
          result = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
          System.debug(result);
          System.debug(result.get('access_token'));
          auth_token=(String)result.get('access_token');
        }
        // Get the user info using authorization Token.
        String reqUrl = 'https://user-management-dev.api.hlth.gov.bc.ca/users/afaeb84e-8a34-4719-92c7-8001152da88c'; 
        http = new Http();
        request = new HttpRequest();
        request.setEndpoint(reqUrl);
        request.setMethod('GET');    
        request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        request.setHeader('Authorization','Bearer '+EncodingUtil.urlEncode(auth_token,'UTF-8'));
        //payload = 'Authorization: Bearer '+EncodingUtil.urlEncode(auth_token,'UTF-8');
        System.debug(request);
        
        //request.setBody(payload);
        HttpResponse response2 = http.send(request);
        //List<User> list_user = new List<User>();
        List<Id> usersDeactivate = new List<Id>();
        List<Id> portalIds = new List<Id>();
        List<Auth.UserData> data = new List<Auth.UserData>();
        if(response.getStatusCode() == 200) {
            for (user updateUser : [select Id, isActive from User where FederationIdentifier =: user_fed])
            {
                usersDeactivate.add(updateUser.Id);
                //updateUser.isActive = false;
                //list_user.add(updateUser);
            }
            if (usersDeactivate.size() > 0) {
                
                UserRegistrationService.updateUsers(usersDeactivate,portalIds,data);
            }
    
            //update list_user;
            
        }    
    }
    
    
}