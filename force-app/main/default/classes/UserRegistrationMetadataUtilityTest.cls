@IsTest
private class UserRegistrationMetadataUtilityTest {
    @IsTest
    static void testOrgSchemaAndSafeSObjectHelpers() {
        UserRegistrationCustomMetadataUtility utility =
            new UserRegistrationCustomMetadataUtility();
        System.assertEquals(true, utility.isFieldExisting('Name', 'Account'));
        System.assertEquals(true, utility.isFieldExisting('name', 'Account'));
        System.assertEquals(false, utility.isFieldExisting('NotARealField__c', 'Account'));
        System.assertEquals(false, utility.isFieldExisting(null, 'Account'));
        System.assertEquals(false, utility.isFieldExisting('Name', 'NotAnObject__c'));
        System.assertNotEquals(null, utility.safeNewSObject('Account'));
        System.assertEquals(null, utility.safeNewSObject('NotAnObject__c'));
        System.assertEquals(1, utility.safeNewSObjectList('Contact').size());
        System.assertEquals(null, utility.safeNewSObjectList('NotAnObject__c'));
        System.assertNotEquals(null, utility.isPersonAccountsEnabled());
        System.assertNotEquals(null, utility.isHealthCloudInstalled());
    }

    @IsTest
    static void testRecordTypeLookupRespectsObjectAndDeveloperName() {
        UserRegistrationCustomMetadataUtility utility =
            new UserRegistrationCustomMetadataUtility();
        System.assertEquals(false, utility.checkForRecordType('Account', null));
        System.assertEquals(false, utility.checkForRecordType('Contact', ''));
        System.assertEquals(false, utility.checkForRecordType('NotAnObject__c', 'X'));
        System.assertEquals(false,
            utility.checkForRecordType('Account', 'A_RECORD_TYPE_THAT_CANNOT_EXIST_123'));
        // Lookups work with installed org metadata, not hard-coded RecordType IDs.
        for (String objectName : new List<String>{'Account', 'Contact'}) {
            Map<String, Schema.RecordTypeInfo> infos = objectName == 'Account'
                ? Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                : Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName();
            for (String developerName : infos.keySet()) {
                System.assertEquals(true,
                    utility.checkForRecordType(objectName, developerName));
                break;
            }
        }
    }

    @IsTest
    static void testRoleLookupHandlesDelimitedAndBracketedRoles() {
        UserRegistrationCustomMetadataUtility utility =
            new UserRegistrationCustomMetadataUtility();
        utility.userMappingByRole_map = new Map<String, IDP_User_Registration_User_Mapping__mdt>{
            'ROLE_ONE' => new IDP_User_Registration_User_Mapping__mdt(
                External_Provider_Role__c = 'ROLE_ONE',
                Salesforce_User_License__c = 'Salesforce'
            ),
            '[ROLE_TWO]' => new IDP_User_Registration_User_Mapping__mdt(
                External_Provider_Role__c = '[ROLE_TWO]'
            )
        };
        System.assertEquals(0, utility.ReadMapping(null).size());
        System.assertEquals(1, utility.ReadMapping('ROLE_ONE').size());
        System.assertEquals(1, utility.ReadMapping('[ROLE_TWO]').size());
        utility.userMappingByRole_map.put('[ROLE_ONE]',
            utility.userMappingByRole_map.get('ROLE_ONE'));
        System.assertEquals(2, utility.ReadMapping('[ROLE_ONE,ROLE_TWO]').size());
        System.assertEquals(0, utility.ReadMapping('ROLE_UNKNOWN').size());
    }

    @IsTest
    static void testPermissionLookupAndEmptyMetadataPaths() {
        UserRegistrationCustomMetadataUtility utility =
            new UserRegistrationCustomMetadataUtility();
        IDP_User_Registration_User_Mapping__mdt role =
            new IDP_User_Registration_User_Mapping__mdt(
                External_Provider_Role__c = 'TEST_ROLE');
        utility.userMappingByRole_map =
            new Map<String, IDP_User_Registration_User_Mapping__mdt>{'TEST_ROLE' => role};
        utility.userPermissionSet = new List<IDP_User_Registration_Permission_Set__mdt>{
            new IDP_User_Registration_Permission_Set__mdt(
                Salesforce_Permission_Set__c = 'ExamplePermission')
        };
        System.assertEquals(1, utility.ReadPermissionSet('TEST_ROLE').size());
        System.assertEquals(0, utility.ReadPermissionSet('MISSING_ROLE').size());
        System.assertEquals(false, utility.isTriggerActive('NeverExisting_Trigger_123'));
    }

    @IsTest
    static void testCustomMetadataConstructorSupportsEmptyAndBracketedRoles() {
        UserRegistrationCustomMetadataUtility blank =
            new UserRegistrationCustomMetadataUtility(null);
        System.assertEquals('', blank.ProvidedExternalProvider);
        System.assertEquals(0, blank.ReadMapping(null).size());
        UserRegistrationCustomMetadataUtility multi =
            new UserRegistrationCustomMetadataUtility('[TESTROLE_ONE,TESTROLE_TWO]');
        System.assertEquals('[TESTROLE_ONE,TESTROLE_TWO]', multi.ProvidedExternalProvider);
        System.assertNotEquals(null, multi.userMappingByRole_map);
        System.assertNotEquals(null, multi.userPermissionSet_map);
        System.assertNotEquals(null, multi.userAttributeMapping_map);
    }
}
