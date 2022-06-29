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
    public static String USER_ASSIGNMENT_TYPE_PERMISSIONSET = 'Permission Set';
    public static String USER_ASSIGNMENT_TYPE_PERMISSIONSETGROUP = 'Permission Set Group';


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
        String userdata = JSON.serialize(data.attributeMap);

        //Create user
        String l_username = UserRegistrationService.generateUserName(data);
        
        UserRegistrationCustomMetadataUtility fetchRoles = new UserRegistrationCustomMetadataUtility(data.attributeMap.get('roles'));
        list<User_Registration_User_Mapping__mdt> userRole_list = new list<User_Registration_User_Mapping__mdt>();
        userRole_list.add(fetchRoles.ReadMapping(data.attributeMap.get('roles')));
        system.debug('data:'+ json.serializePretty(data));
        User newUser = new User();
        if (userRole_list.size() > 0)
        {
            for (User_Registration_User_Mapping__mdt userRole_rec : userRole_list)
            {
            system.debug('userRole_rec:' + userRole_rec );
                Profile p = [SELECT Id FROM profile WHERE name='MoH Standard User']; //:userRole_rec.Salesforce_User_Profile__c];
        
                newUser.username = l_username;
                newUser.email = data.email;
                newUser.lastName = data.lastName;
                newUser.firstName = data.firstName;
                newUser.FederationIdentifier = data.username;
                newUser.alias = UserRegistrationService.generateUserAlias(data);
                
                newUser.languagelocalekey = UserInfo.getLanguage();
                newUser.localesidkey = UserInfo.getLocale();
                newUser.emailEncodingKey = 'UTF-8';
                newUser.timeZoneSidKey = 'America/Los_Angeles';
                newUser.profileId = p.Id;
            }
        }
        try {


            insert newUser;
            // Update user role & permissionset based on latest payload
            UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility();
            
            // add/update any new permission sets
            managePermissionSet(newUser.Id, data);
            
            // add/update user role
            List<User_Registration_User_Mapping__mdt>  matchingRole_list = new List<User_Registration_User_Mapping__mdt>();
            
            matchingRole_list.add(manageUserRole(newUser.Id, data));
            for (User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list)
            {
                for (UserRole userRole_rec: [SELECT DeveloperName,Id,Name FROM UserRole Where Name =: matchingRole_rec.Salesforce_User_Role__c])
                {
                    newUser.UserRoleId = userRole_rec.Id;
                }
            }       
            
            update newUser;
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
        User existingUser = [Select Id, username, email,lastname,firstname,alias,
                                emailEncodingKey,timeZoneSidKey,languagelocaleKey,localesidkey
                             From User where Id =: userId];
        
         //Verify user data - to be removed prior to completion

        String l_userdata = JSON.serialize(data.attributeMap);
        String l_username = UserRegistrationService.generateUserName(data);    

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
       
        User_Registration_User_Mapping__mdt userRole = new User_Registration_User_Mapping__mdt();
        // get role metadata
        for (User_Registration_User_Mapping__mdt userMapping : processRoles.userMapping)
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
        for (User_Registration_Permission_Set__mdt userPerms : processRoles.userPermissionSet)
        {
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

        try {
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
        String suffixName = '';
        String customDomain = URL.getSalesforceBaseUrl()
                        .toExternalForm()
                        .substringAfter('https://')
                        .substringBefore('.');
        suffixName = CustomDomain.substringAfter('--');
        if (String.isEmpty(suffixName)) {
            suffixName = customDomain;
        }
        
        return data.identifier + '@MoH.com.' + suffixName;
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

}
