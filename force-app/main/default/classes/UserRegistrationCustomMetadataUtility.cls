/*
* Company: CGI for BC Ministry of Health
* Date: March 31, 2021
* Author: German (Herman) Ovodov, Roy Poystila
* Description: public class UserRegistrationCustomMetadataUtility
*    Generic registration handler service class for an external identity provider (e.g. Keycloak)
*    Attributes:
*         userMapping - [List<IDP_User_Registration_User_Mapping__mdt>] object to store/utilize values found in Custom Metadata
*         userPermissionSet - [List<IDP_User_Registration_Permission_Set__mdt>] object to store/utilize values found in Custom Metadata
*         userMappingByRole_map - [Map<String,IDP_User_Registration_User_Mapping__mdt>] Map used to lookup role that matches inbound payload
*         userPermissionSet_map - [Map<String,IDP_User_Registration_Permission_Set__mdt>] Map used to lookup Permissionset(s) that match inbound payload
*         userExternalProvider - [String userExternalProvider] Assign inbound ExternalProvider to object instance
*    Methods:
*         public IDP_User_Registration_User_Mapping__mdt ReadMapping(String Role): return role metadata based on passed role value (string)
*         public List<IDP_User_Registration_Permission_Set__mdt> ReadPermissionSet(String Role): return permissionset metatdata based on passed role value (string)
*         public UserRegistrationCustomMetadataUtility(String ExternalProvider): Initializes class filtering by ExternalProvider to get subset for provider only.
*
* History:
*     Initial version: March 31, 2021 - GO
*     Updates to codebase: May 1, 2021 - RP
*/

public class UserRegistrationCustomMetadataUtility{
    public UserRegistrationCustomMetadataUtility(){

    }
    
    public List<IDP_User_Registration_User_Mapping__mdt> userMapping;
        
    public List<IDP_User_Registration_Permission_Set__mdt> userPermissionSet;
    
    public Map<String,IDP_User_Registration_User_Mapping__mdt> userMappingByRole_map;
        
    public Map<String,IDP_User_Registration_Permission_Set__mdt> userPermissionSet_map;

    public Map<String,IDP_User_Registration_Permission_Set__mdt> userPermissionSetByName_map;

    public Map<String,IDP_User_Registration_Permission_Set__mdt> userPermissionSetGroupByName_map;

    public Map<String,IDP_User_Registration_Permission_Set__mdt> userPublicGroupIgnoreByName_map;
    
    public List<String> userExternalProvider = new List<String>();
    
    public UserRegistrationCustomMetadataUtility(String ExternalProvider){
        /*
        * Description: Instantiate class with taking external provider parameter to filter specifc provider
        * Parameters:
        *     String ExternalProvider value of the provider used to make call to Salesforce hander
        * Returns:
        *     N/A
        * 
        */
        // Assign inbound ExternalProvider to object instance
        system.debug('ExternalProvider:' + ExternalProvider);
        if (ExternalProvider != null)
        {
            userExternalProvider.addAll(ExternalProvider.remove('[').remove(']').split(','));
        }
        List<String> userRoleFilter = new List<String>();
        for (String userRoleFilterRec: userExternalProvider)
        {
            if (ExternalProvider.contains('[')) {
                userRoleFilter.add('[' + userRoleFilterRec.trim() + ']');
            } else {
                userRoleFilter.add(userRoleFilterRec.trim());
            }
            
        }
        System.debug('userRoleFilter:' + userRoleFilter);
        //Fetch metadata for Role mapping
        userMapping = [SELECT Assurance_Level__c,DeveloperName,External_Provider_Role__c,Id,
                            Identity_Provider__c,Label,Language,MasterLabel,MFA_Flag__c,NamespacePrefix,
                            QualifiedApiName,Salesforce_User_License__c,Salesforce_User_Profile__c, Salesforce_Public_Group__c,
                            Salesforce_User_Role__c,Sequence__c, Default_Domain__c, Payload_Includes_PIdP_Data__c, 
                            Username_Type__c, Non_Regulated_User_Record_Type__c, Account_Record_Type__c, Flow_User__c, 
                            isAccountSetActive__c, Requires_Login_Flow__c, Populate_Role_Filter__c, is_Ignore_Endorser_Data__c,
                            is_Ignore_License_Attribute__c, is_Ignore_Public_Group_Reset__c, is_Process_HCFN_Groups__c,
                            is_Restrict_Beta_User_Only__c
                        FROM IDP_User_Registration_User_Mapping__mdt
                        WHERE External_Provider_Role__c IN: userRoleFilter
                        ORDER BY Sequence__c ASC
                        LIMIT 1
                        ];
        
        // Load Map object for searching values
        userMappingByRole_map = new Map<String,IDP_User_Registration_User_Mapping__mdt>();                     
        for(IDP_User_Registration_User_Mapping__mdt userMapping_rec : userMapping)
        {
            userMappingByRole_map.put(userMapping_rec.External_Provider_Role__c, userMapping_rec);
        }
        
        //Fetch metadata for PermissionSet mapping
        userPermissionSet = [SELECT DeveloperName,External_Provider_User_Mapping__c,Id,Label,Language,MasterLabel,
                                    NamespacePrefix,QualifiedApiName,Salesforce_Permission_Set_Group__c,
                                    Salesforce_Public_Group__c, Salesforce_Permission_Set__c, Assignment_Type__c,
                                    is_Beta_Only_User__c, External_Provider_User_Mapping__r.is_Ignore_Public_Group_Reset__c,
                                    Salesforce_Queue__c
                              FROM IDP_User_Registration_Permission_Set__mdt
                              WHERE External_Provider_User_Mapping__c IN: userMapping];
                              
        // Load Map object for searching values   
        userPermissionSet_map = new Map<String,IDP_User_Registration_Permission_Set__mdt>();
        userPermissionSetByName_map = new Map<String,IDP_User_Registration_Permission_Set__mdt>(); 
        userPermissionSetGroupByName_map = new Map<String,IDP_User_Registration_Permission_Set__mdt>(); 
        userPublicGroupIgnoreByName_map = new Map<String,IDP_User_Registration_Permission_Set__mdt>(); 

        for(IDP_User_Registration_Permission_Set__mdt userPermissionSet_rec : userPermissionSet )
        {
            userPermissionSet_map.put(userPermissionSet_rec.External_Provider_User_Mapping__c, userPermissionSet_rec);
            if (userPermissionSet_rec.Salesforce_Permission_Set__c != null)
            {
                userPermissionSetByName_map.put(userPermissionSet_rec.Salesforce_Permission_Set__c, userPermissionSet_rec);
            }      
            if (userPermissionSet_rec.Salesforce_Permission_Set_Group__c != null)
            {
                userPermissionSetGroupByName_map.put(userPermissionSet_rec.Salesforce_Permission_Set_Group__c, userPermissionSet_rec);
            }   
            if (userPermissionSet_rec.Salesforce_Public_Group__c != null)
            {
                if (userPermissionSet_rec.External_Provider_User_Mapping__r.is_Ignore_Public_Group_Reset__c)
                {
                    userPublicGroupIgnoreByName_map.put(userPermissionSet_rec.Salesforce_Public_Group__c, userPermissionSet_rec);

                }
            }                    
        }
    }
    
    public IDP_User_Registration_User_Mapping__mdt ReadMapping(String keycloakRole){
        /*
        * Description: ReadMapping method is used to retrieve matching records from custom metadata IDP_User_Registration_User_Mapping__mdt 
        * Parameters:
        *     String Role value of the provider used to make call to Salesforce hander
        * Returns:
        *     IDP_User_Registration_User_Mapping__mdt (foundUserMapping_md) object
        * 
        */        
        //Create single instance of Metadata
        IDP_User_Registration_User_Mapping__mdt foundUserMapping_md = new IDP_User_Registration_User_Mapping__mdt();
        //Find keycloakRole in userMapping
        String searchForRoleRec = keycloakRole;
        List<String> searchForRole = new List<String>();
        List<String> userRoleFilter = new List<String>();
        System.debug('keycloakRole: ' + keycloakRole);
        if (keycloakRole != null && keycloakRole.contains('[')) { 
            searchForRole.addAll(keycloakRole.remove('[').remove(']').split(','));

            for (String userRoleFilterRec: searchForRole)
            {
                userRoleFilter.add('[' + userRoleFilterRec.trim() + ']');
            }           
        } else {
            if (keycloakRole != null )
            {
                searchForRole.addAll(keycloakRole.split(','));

                for (String userRoleFilterRec: searchForRole)
                {
                    userRoleFilter.add(userRoleFilterRec.trim());
                }  
            }

        }
        System.debug('userRoleFilter: ' + userRoleFilter);
        for (String searchKey: userRoleFilter)
        {
    
            if (userMappingByRole_map.containsKey(searchKey))
            {
                foundUserMapping_md = userMappingByRole_map.get(searchKey);
            }
        }

        return foundUserMapping_md;
        
    }
    
    
    public  List<IDP_User_Registration_Permission_Set__mdt> ReadPermissionSet(String keycloakRole){
        /*
        * Description: ReadPermissionSet method is used to retrieve matching records from custom metadata IDP_User_Registration_User_Mapping__mdt 
        * Parameters:
        *     String keycloakRole value of the provider used to make call to Salesforce hander
        * Returns:
        *     List<IDP_User_Registration_Permission_Set__mdt> (foundPermissionSet_list) object
        * 
        */              
        //Create single instance of Metadata
        IDP_User_Registration_User_Mapping__mdt foundUserMapping_md = new IDP_User_Registration_User_Mapping__mdt();
        //Create list of Metadata
        List<IDP_User_Registration_Permission_Set__mdt> foundPermissionSet_list = new List<IDP_User_Registration_Permission_Set__mdt>();
        system.debug('keycloakRole:' + keycloakRole);
        system.debug('userMappingByRole_map:' + userMappingByRole_map);
        //Find role in userMapping
        if (userMappingByRole_map.containsKey(keycloakRole))
        {
            foundUserMapping_md = userMappingByRole_map.get(keycloakRole);

            //Find permission sets for the keycloakRole
            for(IDP_User_Registration_Permission_Set__mdt permissionSet_rec: userPermissionSet)
            {
                if (foundUserMapping_md.Id == permissionSet_rec.External_Provider_User_Mapping__c)
                {
                    foundPermissionSet_list.add(permissionSet_rec);
                }
            }
        }
        system.debug('foundPermissionSet_list:' + foundPermissionSet_list );
        return foundPermissionSet_list;
    }

    public Boolean isFieldExisting(String fieldName, String sObjectName) {
        Boolean isFieldFound = false;

        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (globalDescribe.containsKey(sObjectName)){
            fieldName = fieldName == null ? '' : fieldName.toLowerCase();
            Map<String, sObjectField> objectFields = globalDescribe.get(sObjectName).getDescribe().fields.getMap();
            if(objectFields.containsKey(fieldName))
            {
                isFieldFound = true;
                system.debug('isFieldFound:'+isFieldFound);
            }
         }
         return isFieldFound;
    }
}