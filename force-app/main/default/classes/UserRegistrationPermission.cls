public with sharing class UserRegistrationPermission {
    public static final String USER_ASSIGNMENT_TYPE_PERMISSIONSET = 'Permission Set';
    public static final String USER_ASSIGNMENT_TYPE_PERMISSIONSETGROUP = 'Permission Set Group';
    public static final String USER_ASSIGNMENT_TYPE_PUBLICGROUP = 'Public Group';
    public static final String SALESFORCE_USER_LICENSE_COMMUNITY = 'Community';
    public static final String SALESFORCE_USER_LICENSE_STANDARD = 'Salesforce';
    public static final String EMAIL_ASPERAND_SIGN = '@';
    public static final String ACCOUNT_PERSONACCOUNT_RECORDTYPE = 'PersonAccount';
    public static final String BCSC_IDP_KEY = 'idp';
    public static final String MOH_IDP_KEY = 'roles';
    public static final String USER_USERNAME_REFERENCE = 'data.username';
    public static final String EMAIL_ENCODING_KEY = 'UTF-8';
    public static final String TIME_ZONE_SID_KEY = 'America/Vancouver';
    public static final String USER_ASSIGNMENT_TYPE_QUEUE = 'Queue';
    public static final String USER_TITLE_FILTER = 'testuser';
    
    public static void processPermissions(List<User> userList, Map<Id, User> oldUserMap, Boolean isUpdate, Boolean isAfter)
    {
        System.debug('userList: ' + userList);

        List<User> processUserList = new List<User>();
        processUserList.addAll(userList);

        List<IDP_User_Registration_User_Mapping__mdt>  matchingRole_list = new List<IDP_User_Registration_User_Mapping__mdt>();
        IDP_User_Registration_User_Mapping__mdt  matchingRole = new IDP_User_Registration_User_Mapping__mdt();   
        for (User processUser: processUserList) {
            UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility(processUser.User_Provisioning_Role__c);

            matchingRole = processRoles.ReadMapping(processUser.User_Provisioning_Role__c);  
            matchingRole_list.add(matchingRole);  

            String userTitle = processUser.Title != Null ? processUser.Title.toLowerCase(): '';
            system.debug('processUser.Title.toLowerCase()' + userTitle);
            Boolean isTestUser = userTitle == USER_TITLE_FILTER ? true : false;
            Boolean isInactiveUser = false;
            if (isUpdate == true && isAfter == true) {
                if (oldUserMap.containsKey(processUser.Id)) {
                    User oldUserMap_rec = oldUserMap.get(processUser.Id);
                    if (oldUserMap_rec.IsActive == true && processUser.IsActive == false) {
                        isInactiveUser = true;
                        if (!isTestUser)
                        {
                            List<PermissionSetAssignment> removeOtherPerms = new List<PermissionSetAssignment>();
                            for(PermissionSetAssignment existingPSAByUser_rec : [SELECT AssigneeId,Id,PermissionSetId,PermissionSet.Name 
                                                                                    FROM PermissionSetAssignment 
                                                                                    WHERE AssigneeId =: processUser.Id
                                                                                    AND PermissionSet.ProfileId = null  
                                                                                    ORDER BY AssigneeId ASC])
                            {
                                removeOtherPerms.add(existingPSAByUser_rec);
                            } 
                            
                            if(removeOtherPerms.size() > 0) {
                                delete removeOtherPerms;
                            }
                        }
                    }
                }
            }

            if (processUser.User_Provisioning_Role__c != null && (!isInactiveUser)) {
                if (!matchingRole.Requires_Login_Flow__c || 
                        (System.Trigger.isExecuting && 
                        System.Trigger.isUpdate && 
                        matchingRole.Requires_Login_Flow__c) ) {
                    try {
                
                        // add/update any new permission sets
                        managePermissionSet(processUser.Id, processUser.User_Provisioning_Role__c);
                        // add user to Public Group
                        manageGroups(processUser.Id, processUser.User_Provisioning_Role__c);
                        
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
                String userProvisioningRole = processUser.User_Provisioning_Role__c;
                try {
                    // add/update any new permission sets
                    managePermissionSet(processUser.Id, userProvisioningRole);
                    
                    // add user to Public Group
                    //manageGroups(processUser.Id, userProvisioningRole);
                    manageGroups(processUser.Id, userProvisioningRole);
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

        //Boolean isCheckBetauser = checkIsBetaUser(List<User> userId);

        for (IDP_User_Registration_Permission_Set__mdt userPerms : processRoles.userPermissionSet)
        {
            System.debug('userRole.DeveloperName:' + userRole.DeveloperName);
            System.debug('userPerms.QualifiedApiName' + userPerms.QualifiedApiName);

            if (userPerms.Assignment_Type__c == USER_ASSIGNMENT_TYPE_PERMISSIONSET)
            {
                if (userRole.Id == userPerms.External_Provider_User_Mapping__c)
                {
                    if (!userPerms.is_Beta_Only_User__c) 
                    {
                        associatedPermset.add(userPerms.Salesforce_Permission_Set__c);
                    }
                    if (userPerms.is_Beta_Only_User__c ) //&& isCheckBetauser
                    {
                        associatedPermsetGroup.add(userPerms.Salesforce_Permission_Set_Group__c);
                    }                    
                }
            } else if (userPerms.Assignment_Type__c == USER_ASSIGNMENT_TYPE_PERMISSIONSETGROUP)
            {
                if (userRole.Id == userPerms.External_Provider_User_Mapping__c)
                {
                    if (!userPerms.is_Beta_Only_User__c)
                    {
                        associatedPermsetGroup.add(userPerms.Salesforce_Permission_Set_Group__c);
                    }
                    if (userPerms.is_Beta_Only_User__c) // && isCheckBetauser
                    {
                        associatedPermsetGroup.add(userPerms.Salesforce_Permission_Set_Group__c);
                    }
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
                insertPermissionSetAssignment(json_PermissionSetAssign,userId);
            }
        }catch(exception e){
            system.debug('exception caught:' + e);
        }   
    
    }
    
    public static void manageGroups(Id userId, String userProvisioningRole)
    {
        List<String> userGroups = new List<String>();
        Boolean isPublicGroupIgnoreReset = false;
        
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility(userProvisioningRole);

        //is_Ignore_Public_Group_Reset__c
        // 
        List<String> filterPublicGroupByRoleId = new List<String>();
        List<HealthcareFacilityNetwork> hcfn = new List<HealthcareFacilityNetwork>();
        Id accountIdMatch = [SELECT AccountId FROM User WHERE Id =: userId].AccountId;
        Boolean hcfnFieldExisting;
        hcfnFieldExisting = processRoles.isFieldExisting('Clinic_Panel_Group_ID__c','HealthcareFacilityNetwork');

        for (IDP_User_Registration_User_Mapping__mdt userRegistrationRec: processRoles.userMapping)
        {
            if (userRegistrationRec.is_Ignore_Public_Group_Reset__c)
            {
                isPublicGroupIgnoreReset = true;
            }
            if (userRegistrationRec.is_Process_HCFN_Groups__c && hcfnFieldExisting) 
            {
                if (userRegistrationRec.Salesforce_User_License__c == SALESFORCE_USER_LICENSE_COMMUNITY)
                {
                    String qryString = '';
                    qryString = 'select Id, Clinic_Panel_Group_ID__c, Practitioner.Account.Id from HealthcareFacilityNetwork WHERE Clinic_Panel_Group_ID__c <> null And Practitioner.Account.Id = \'' + accountIdMatch + '\'';
                    hcfn = Database.query(qryString);
                }

            }
        }
        List<groupMember> existingGroupList = new List<groupMember>();
        if (!isPublicGroupIgnoreReset) 
        {
            existingGroupList = [SELECT Id from groupMember 
            WHERE UserOrGroupId =: userId];
        }

        if (existingGroupList != null && existingGroupList.size() > 0)
        {
            delete existingGroupList;
        }

        for (IDP_User_Registration_Permission_Set__mdt userGroupRec : processRoles.userPermissionSet)
        {
            if (userGroupRec.Assignment_Type__c == USER_ASSIGNMENT_TYPE_PUBLICGROUP)
            {
                userGroups.add(userGroupRec.Salesforce_Public_Group__c);
            } 
/*                 else 
            {
                if (userPerms.Assignment_Type__c == USER_ASSIGNMENT_TYPE_QUEUE)
                {
                    userGroup.add(userPerms.Salesforce_Queue__c);
                }
            } */
            
        }
        //Add Groups for is_Process_HCFN_Groups__c flag set to true
        if (userGroups.size() > 0)
        {
            list<groupMember> groupList = new list<groupMember>();
            list<Group> grp = [select id from Group where DeveloperName in : userGroups];
            
            for(group g : grp){
                groupMember gp = new groupMember(groupId = g.Id);
                gp.UserOrGroupId = userId;
                groupList.add(gp);
            }
            if (hcfnFieldExisting) 
            {
                for(HealthcareFacilityNetwork hcfn_rec : hcfn) {
                    groupMember gp = new groupMember(groupId = (String)hcfn_rec.get('Clinic_Panel_Group_ID__c'));
                    gp.UserOrGroupId = userId;
                    groupList.add(gp);                
                }
            }
                
            if(groupList.size() > 0)
            {
                insert groupList;
            }

            System.debug('GroupList: ' + groupList);
        }
    }        

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
        try {
            insert permissionSetAssignList;
        } catch (Exception e) {
            system.debug('exception caught:' + e);
        }

    }    
    public static Boolean checkIsBetaUser(List<User> userList) 
    {
         /*
        * Description: look for available licenses based the value being passed in.
        * Parameters:
        *     NA
        * Returns:
        *     Boolean: Boolean
        * 
        */           
        Boolean isBetaUser = false;

        isBetaUser = isSalesforceBetaEnabled(userList);
        System.debug('isBetaUser: ' + isBetaUser);
        return isBetaUser;
        
    }
    public static Boolean isSalesforceBetaEnabled(List<User> userList){
        String responseString = '';
        for (User users: userList)
        {
            if (!Test.isRunningTest())
            {
                responseString =  getPatientInfoFromGatewayApiService(getUserHdId(users.Id));
            } else
            {
                responseString = KeycloakConstants.TEST_HDID_RESPONSE;
            }
            
        }

        System.debug('responseString: ' + responseString);
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseString);
        // Extract the 'resourcePayload' map
        Map<String, Object> resourcePayload = (Map<String, Object>) responseMap.get('resourcePayload');
        // Extract the 'betaFeatures' list
        List<Object> betaFeatures = (List<Object>) resourcePayload.get('betaFeatures');
        //System.debug('betaFeatures: ' + betaFeatures);
        Boolean isSalesforceBetaEnabled = false;
        // Check if 'Salesforce' is present in 'betaFeatures'
         if (betaFeatures != null && !betaFeatures.isEmpty()) {
            for (Object feature : betaFeatures) {
                if (String.valueOf(feature) == KeycloakConstants.HG_SALESFORCE) {
                    isSalesforceBetaEnabled = true;
                    break;
                }
            }
        } 
        System.debug('isSalesforceBetaEnabled: ' + isSalesforceBetaEnabled);
        return isSalesforceBetaEnabled;
    }  
    public static string getUserHdId(String userId){
        String hdId = '';
        Boolean accountHDIDExists = false;
        String hdidField = '';
        String qryString = '';

        UserRegistrationCustomMetadataUtility utilityChecks = new UserRegistrationCustomMetadataUtility();
        if (utilityChecks.isFieldExisting('HDID__c', 'Account'))
        {
            accountHDIDExists = true;
            hdidField = 'HDID__c';
        } else {
            hdidField = 'AccountNumber';
        }
        // if (!Test.isRunningTest())
        // {
            qryString = 'SELECT Id, Account.' + hdidField + ' FROM USER WHERE Id = \'' + userId + '\'';
        // }
        System.debug('qryString: ' + qryString);
        List<User> userList = Database.query(qryString);
        // [SELECT Id, Account.HDID__c FROM USER WHERE Id =: userId];
        //HG_UserSelector.newInstance().getUserById(UserInfo.getUserId());
        String hdidValue = (String)userList[0].Account.get(hdidField);
        System.debug('userList[0].Account.' + qryString + ': ' + hdidValue);
        if(!userList.isEmpty() && String.isNotBlank(hdidValue) ){
          hdId = (String)userList[0].Account.get(hdidField);
        }
  
        return hdId;
    } 
    public static String getPatientInfoFromGatewayApiService(String hdId){
        KeycloakAPIGatewayService gatewayService = new KeycloakAPIGatewayService();
        String requestEndpoint = KeycloakCommonService.getEndpointURL(KeycloakConstants.SERVICE_NAME_GATEWAY_SERVICE);
          requestEndpoint = KeycloakCommonService.replacePlaceholder(requestEndpoint, KeycloakConstants.HDID_PLACEHOLDER, hdId);
          String requestMethod = KeycloakConstants.CALLOUT_TYPE_GET;
          return gatewayService.doCallout(
              requestEndpoint,
              requestMethod,
              null,
              null
          );
      }             
}