public with sharing class UserRegistrationPermission {
    public static final String USER_ASSIGNMENT_TYPE_PERMISSIONSET = 'Permission Set';
    public static final String USER_ASSIGNMENT_TYPE_PERMISSIONSETGROUP = 'Permission Set Group';
    public static final String SALESFORCE_USER_LICENSE_COMMUNITY = 'Community';
    public static final String SALESFORCE_USER_LICENSE_STANDARD = 'Salesforce';
    public static final String EMAIL_ASPERAND_SIGN = '@';
    public static final String ACCOUNT_PERSONACCOUNT_RECORDTYPE = 'PersonAccount';
    public static final String BCSC_IDP_KEY = 'idp';
    public static final String MOH_IDP_KEY = 'roles';
    public static final String USER_USERNAME_REFERENCE = 'data.username';
    public static final String EMAIL_ENCODING_KEY = 'UTF-8';
    public static final String TIME_ZONE_SID_KEY = 'America/Vancouver';
    
    public static void processPermissions(List<User> userList)
    {
        //Savepoint sp_perm = Database.setSavepoint();
        System.debug('userList: ' + userList);
        //UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility();
        List<IDP_User_Registration_User_Mapping__mdt>  matchingRole_list = new List<IDP_User_Registration_User_Mapping__mdt>();
        IDP_User_Registration_User_Mapping__mdt  matchingRole = new IDP_User_Registration_User_Mapping__mdt();   
        for (User processUser: userList) {
            UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility(processUser.User_Provisioning_Role__c);

            matchingRole = processRoles.ReadMapping(processUser.User_Provisioning_Role__c);  
            matchingRole_list.add(matchingRole);  

            if (processUser.User_Provisioning_Role__c != null) {
                if (!matchingRole.Requires_Login_Flow__c) {
                    try {
                
                        // add/update any new permission sets
                    managePermissionSet(processUser.Id, processUser.User_Provisioning_Role__c);
                    
                    // add user to Public Group
                    for (IDP_User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list)
                    {
                        if (matchingRole_rec.Salesforce_Public_Group__c != Null)
                        {
                            managePublicGroups(processUser.Id, matchingRole_rec.Salesforce_Public_Group__c);
                        }     
                    } 
                    } catch (Exception e) {
                        system.debug('exception caught:' + e);
                    }
                }
            }

        }
    }
    
        public class InputVariables {
            @InvocableVariable
            public  List<User> userPerms;
        }
        public class ReturnVariables {
            @InvocableVariable 
            public List<String> permissionsAdded;
        }
    
        @InvocableMethod (label='Process User Permissions' description='Process user Permissions')
        public static List<ReturnVariables> applyPermissions(List<InputVariables> inputVariables)
        {
            List<User> userList =  inputVariables.get(0).userPerms;
            //Savepoint sp_perm = Database.setSavepoint();
            System.debug('userList: ' + userList);
            //UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility();
            List<IDP_User_Registration_User_Mapping__mdt>  matchingRole_list = new List<IDP_User_Registration_User_Mapping__mdt>();
            IDP_User_Registration_User_Mapping__mdt  matchingRole = new IDP_User_Registration_User_Mapping__mdt();   
            for (User processUser: userList) {
                if (processUser.User_Provisioning_Role__c != null) {
                    try {
                        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility(processUser.User_Provisioning_Role__c);
    
                        matchingRole = processRoles.ReadMapping(processUser.User_Provisioning_Role__c);  
                        matchingRole_list.add(matchingRole);                 
                        // add/update any new permission sets
                    managePermissionSet(processUser.Id, processUser.User_Provisioning_Role__c);
                    
                    // add user to Public Group
                    for (IDP_User_Registration_User_Mapping__mdt matchingRole_rec : matchingRole_list)
                    {
                        if (matchingRole_rec.Salesforce_Public_Group__c != Null)
                        {
                            managePublicGroups(processUser.Id, matchingRole_rec.Salesforce_Public_Group__c);
                        }     
                    } 
                    } catch (Exception e) {
                        system.debug('exception caught:' + e);
                    }
                }
    
            }
            List<String> addedPermissions = new List<String>();
    
            List<ReturnVariables> returnVarsList = new List<ReturnVariables>();
            ReturnVariables returnVars = new ReturnVariables();
            returnVars.permissionsAdded = addedPermissions;
            returnVarsList.add(returnVars);
            return returnVarsList;
        } 

        private static void managePermissionSet(Id userId, String keyCloakRole)
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
            
            //String keyLookup = UserRegistrationService.fetchUserMappingKey(data);
            //Get user mapping record based on source IDP
            String UserRoleAssign = keyCloakRole;//data.attributeMap.get(keyLookup);
            
            //UserRegistrationCustomMetadataUtility processPermissions = new UserRegistrationCustomMetadataUtility();
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
                    if (userRole.Id == userPerms.External_Provider_User_Mapping__c)
                    {
                        associatedPermset.add(userPerms.Salesforce_Permission_Set__c);
                    }
                } else if (userPerms.Assignment_Type__c == USER_ASSIGNMENT_TYPE_PERMISSIONSETGROUP)
                {
                    if (userRole.Id == userPerms.External_Provider_User_Mapping__c)
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
                    //uow_perms.registerDeleted(removeOtherPerms);
                    //uow_perms.commitWork();
                    delete removeOtherPerms;
                } 
                if(permissionSetAssignList.size() > 0) {
                    String json_PermissionSetAssign = JSON.serialize(permissionSetAssignList, true);
                    //insert permissionSetAssignList;
                    insertPermissionSetAssignment(json_PermissionSetAssign,userId);
                }
            }catch(exception e){
                system.debug('exception caught:' + e);
            }   
        
        }
        //@Future
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
            
            //uow_perms.registerNew(groupList);
            //uow_perms.registerUpsert(groupList);
            //uow_perms.commitWork();
            insert groupList;
            System.debug('GroupList: ' + groupList);
        }        
        //@Future
        private static void insertPermissionSetAssignment(String permissionsets, Id userId) {

            List<PermissionSetAssignment> permissionSetAssignList = (List<PermissionSetAssignment>)JSON.deserialize(permissionsets, List<PermissionSetAssignment>.class);
            List<PermissionSetAssignment> removeOtherPerms = new List<PermissionSetAssignment>();

            for(PermissionSetAssignment existingPSAByUser_rec : [SELECT AssigneeId,Id,PermissionSetId,PermissionSet.Name 
                    FROM PermissionSetAssignment 
                    WHERE AssigneeId =: userId
                    AND PermissionSet.ProfileId = null  
                    ORDER BY AssigneeId ASC])
            {
                removeOtherPerms.add(existingPSAByUser_rec);
            }   
            if (removeOtherPerms.size() > 0) {
                delete removeOtherPerms;
            }     
            //uow_perms.registerNew(permissionSetAssignList);
            //uow_perms.registerUpsert(permissionSetAssignList);
            //uow_perms.commitWork();
            try {
                insert permissionSetAssignList;
            } catch (Exception e) {
                system.debug('exception caught:' + e);
            }

        }    
    }