@IsTest
private class UserRegistrationCrmContentTest {
    @IsTest
    static void testNewUserCrmContentSetting() {
        User candidate = new User();
        Schema.SObjectField field = Schema.SObjectType.User.fields.getMap()
            .get('UserPermissionsSFContentUser');

        // The provisioning service must tolerate orgs without this feature.
        UserRegistrationService.applyCrmContentUserSetting(candidate, true, false);
        if (field != null && field.getDescribe().isCreateable()) {
            System.assertEquals(true,
                (Boolean) candidate.get('UserPermissionsSFContentUser'),
                'An enabled mapping should set CRM Content User during creation.');
            UserRegistrationService.applyCrmContentUserSetting(candidate, false, false);
            System.assertEquals(false,
                (Boolean) candidate.get('UserPermissionsSFContentUser'),
                'A disabled mapping should clear CRM Content User.');
            UserRegistrationService.applyCrmContentUserSetting(candidate, null, false);
            System.assertEquals(false,
                (Boolean) candidate.get('UserPermissionsSFContentUser'),
                'An unspecified setting must not grant CRM Content access.');
        }
    }

    @IsTest
    static void testExistingUserCrmContentSetting() {
        User candidate = new User();
        Schema.SObjectField field = Schema.SObjectType.User.fields.getMap()
            .get('UserPermissionsSFContentUser');

        UserRegistrationService.applyCrmContentUserSetting(candidate, true, true);
        if (field != null && field.getDescribe().isUpdateable()) {
            System.assertEquals(true,
                (Boolean) candidate.get('UserPermissionsSFContentUser'),
                'An enabled role should enable CRM Content on an existing User.');
            UserRegistrationService.applyCrmContentUserSetting(candidate, false, true);
            System.assertEquals(false,
                (Boolean) candidate.get('UserPermissionsSFContentUser'),
                'A disabled role should remove the CRM Content flag.');
        }
        // Null User should always be safe, independent of org field availability.
        UserRegistrationService.applyCrmContentUserSetting(null, true, true);
    }

    @IsTest
    static void testMappingMetadataContainsCrmContentCheckbox() {
        System.assertEquals(true,
            Schema.SObjectType.IDP_User_Registration_User_Mapping__mdt.fields
                .getMap().containsKey('CRM_Content_User__c'),
            'The CRM_Content_User__c field must be included in the package.');
        IDP_User_Registration_User_Mapping__mdt mapping =
            new IDP_User_Registration_User_Mapping__mdt(
                CRM_Content_User__c = true
            );
        System.assertEquals(true, mapping.CRM_Content_User__c);
    }
}
