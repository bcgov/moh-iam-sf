/** Pure helper branches, without requiring Health Cloud or Person Accounts. */
@IsTest
private class UserRegistrationServiceCoverageTest {
    private static Auth.UserData data(String identifier, String username,
            String email, Map<String, String> claims) {
        return new Auth.UserData(
            identifier, 'First', 'Last', 'First Last', email, null,
            username, 'en_US', 'Open ID Connect', null, claims
        );
    }

    private static String businessRecordTypeName() {
        Map<String, Schema.RecordTypeInfo> recordTypes =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        if (recordTypes.containsKey('Business_Entity') &&
                recordTypes.get('Business_Entity').isAvailable()) {
            return 'Business_Entity';
        }
        return null;
    }

    private static void assignBusinessRecordType(Account record) {
        String name = businessRecordTypeName();
        if (name != null) {
            record.RecordTypeId = Schema.SObjectType.Account
                .getRecordTypeInfosByDeveloperName().get(name).getRecordTypeId();
        }
    }

    @IsTest
    static void testIdpKeySelectionAndPrecedence() {
        System.assertEquals('idp', UserRegistrationService.fetchUserMappingKey(
            data('sub', 'user', null, new Map<String, String>{'idp'=>'BCSC'})));
        System.assertEquals('identity_provider', UserRegistrationService.fetchUserMappingKey(
            data('sub', 'user', null, new Map<String, String>{
                'identity_provider'=>'bceid_business'})));
        System.assertEquals('roles', UserRegistrationService.fetchUserMappingKey(
            data('sub', 'user', null, new Map<String, String>{'roles'=>'TEST_ROLE'})));
        System.assertEquals('', UserRegistrationService.fetchUserMappingKey(
            data('sub', 'user', null, new Map<String, String>())));
        System.assertEquals('idp', UserRegistrationService.fetchUserMappingKey(
            data('sub', 'user', null, new Map<String, String>{
                'idp'=>'BCSC', 'roles'=>'TEST_ROLE',
                'identity_provider'=>'bceid_business'})));
    }

    @IsTest
    static void testEmailFallbacksAndAlias() {
        Auth.UserData source = data('sub', 'exampleuser',
            'preferred@example.org', new Map<String, String>{
                'pidp_email'=>'pidp@example.ca'});
        System.assertEquals('preferred@example.org',
            UserRegistrationService.generateEmailAddress(source, 'other@example.com'));
        Auth.UserData noEmail = data('sub', 'exampleuser',
            null, new Map<String, String>{'pidp_email'=>'pidp@example.ca'});
        System.assertEquals('pidp@example.ca',
            UserRegistrationService.generateEmailAddress(noEmail, 'fallback@example.com'));
        System.assertEquals('fallback@example.com',
            UserRegistrationService.generateEmailAddress(
                data('sub', 'exampleuser', null, new Map<String, String>()),
                'fallback@example.com'));
        String alias = UserRegistrationService.generateUserAlias(source);
        System.assert(alias.startsWith('exam_'), alias);
        System.assert(alias.length() <= 8);
    }

    @IsTest
    static void testGeneratedUsernamesWithDifferentDomains() {
        Auth.UserData pidp = data('my-subject', 'someuser',
            'source@example.com', new Map<String, String>{
                'pidp_email'=>'person@pidp.example'});
        String result = UserRegistrationService.generateUserName(
            pidp, 'data.username', 'ignored.example');
        System.assert(result.startsWith('my-subject@pidp.example.'), result);
        Auth.UserData userEmail = data('my-subject', 'someuser',
            'source@example.com', new Map<String, String>());
        result = UserRegistrationService.generateUserName(userEmail,
            'data.username', null);
        System.assert(result.startsWith('my-subject@example.com.'), result);
        result = UserRegistrationService.generateUserName(userEmail,
            'data.username', 'configured.example');
        System.assert(result.startsWith('my-subject@configured.example.'), result);
        result = UserRegistrationService.generateUserName(
            data('my-subject', 'someuser', null, new Map<String, String>()),
            'data.username', 'default.example');
        System.assert(result.startsWith('my-subject@default.example.'), result);
    }

    @IsTest
    static void testMissingRoleAndLicenseHandling() {
        Auth.UserData source = data('sub', 'unknown-user', null,
            new Map<String, String>{'roles'=>'NO_CONFIGURED_ROLE_12345'});
        System.assertEquals('', UserRegistrationService.fetchLicenseType(source));
        System.assertEquals(false,
            UserRegistrationService.checkAvailableLicense('NONEXISTENT_LICENSE_12345'));
    }

    @IsTest
    static void testBusinessAccountCreatedAndMatchedByGuid() {
        String guid = 'COVERAGE-BUSINESS-' + String.valueOf(DateTime.now().getTime());
        Map<String, String> claims = new Map<String, String>{
            'bceid_business_id' => guid,
            'bceid_business_legalName' => 'Coverage BCeID Business'
        };
        Auth.UserData source = data('sub', 'bceidusername',
            'business@example.org', claims);
        Test.startTest();
        String createdId = UserRegistrationService.testManageBceidAccount(
            source, businessRecordTypeName());
        System.assertNotEquals(null, createdId);
        String matchingId = UserRegistrationService.testManageBceidAccount(
            source, businessRecordTypeName());
        System.assertEquals(createdId, matchingId,
            'Existing business GUID must reuse the same Account.');
        Test.stopTest();
        System.assertEquals('Coverage BCeID Business',
            [SELECT Name FROM Account WHERE Id = :createdId].Name);
    }

    @IsTest
    static void testNewBceidBusinessAccountStatusFromRoleMapping() {
        Map<String, Schema.SObjectField> accountFields =
            Schema.SObjectType.Account.fields.getMap();
        if (!accountFields.containsKey('isActive')) return;
        Schema.DescribeFieldResult statusField = accountFields.get('isActive').getDescribe();
        if (!statusField.isAccessible() || !statusField.isCreateable()) return;

        String suffix = String.valueOf(DateTime.now().getTime());
        for (Boolean desiredStatus : new List<Boolean>{ true, false }) {
            String guid = 'BCeID-STATUS-' + suffix + '-' + String.valueOf(desiredStatus);
            Auth.UserData source = data('sub', 'bcestatus',
                'business@example.org', new Map<String, String>{
                    'bceid_business_id' => guid,
                    'bceid_business_legalName' => 'BCeID Status ' + guid
                });
            Id accountId = (Id) UserRegistrationService.testManageBceidAccountWithActive(
                source, businessRecordTypeName(), desiredStatus);
            Account created = Database.query(
                'SELECT Id, isActive FROM Account WHERE Id = :accountId');
            System.assertEquals(desiredStatus, created.get('isActive'),
                'New BCeID business Accounts must use the configured Active value.');
        }
    }

    @IsTest
    static void testBusinessAccountMatchingByLegalName() {
        Account existing = new Account(Name = 'BCeID Fallback Coverage Business');
        assignBusinessRecordType(existing);
        insert existing;
        Auth.UserData source = data('sub', 'bceidusername',
            'business@example.org', new Map<String, String>{
                'bceid_business_legalName'=>'BCeID Fallback Coverage Business'
            });
        Test.startTest();
        String matchedId = UserRegistrationService.testManageBceidAccount(
            source, businessRecordTypeName());
        Test.stopTest();
        System.assertEquals(existing.Id, matchedId);
    }

    @IsTest
    static void testMissingConfiguredRecordTypesRaiseClearErrors() {
        Auth.UserData source = data('sub', 'bceidusername',
            'business@example.org', new Map<String, String>{
                'bceid_business_legalName'=>'Coverage Missing Record Type'
            });
        try {
            UserRegistrationService.testManageBceidAccount(source,
                'UNAVAILABLE_RECORDTYPE_COVERAGE_TEST');
            System.assert(false, 'Expected missing Account RecordType failure.');
        } catch (Auth.AuthProviderPluginException expected) {
            System.assert(expected.getMessage().contains('Account Record Type was not found'));
        }
        try {
            UserRegistrationService.testManageBceidContact(source,
                'UNAVAILABLE_RECORDTYPE_COVERAGE_TEST', UserInfo.getUserId());
            System.assert(false, 'Expected missing Contact RecordType failure.');
        } catch (Auth.AuthProviderPluginException expected) {
            System.assert(expected.getMessage().contains('Contact Record Type was not found'));
        }
    }

    // Read back the identifier via the same SOQL capabilities available to
    // the registration implementation. Describe alone is insufficient because
    // a field can be present while FLS prevents querying or persisting it.
    private static Boolean contactHasPersistedBceidGuid(Id contactId, String guid) {
        Map<String, Schema.SObjectField> contactFields =
            Schema.SObjectType.Contact.fields.getMap();
        for (String apiName : new List<String>{ 'ExternalId__c', 'BCeIDGUID__c' }) {
            if (!contactFields.containsKey(apiName) ||
                    !contactFields.get(apiName).getDescribe().isAccessible()) {
                continue;
            }
            try {
                SObject saved = Database.query(
                    'SELECT ' + apiName + ' FROM Contact WHERE Id = :contactId LIMIT 1');
                if (String.valueOf(saved.get(apiName)) == guid) {
                    return true;
                }
            } catch (QueryException e) {
                System.debug(LoggingLevel.WARN,
                    'Contact identity field not queryable in package org: ' +
                    apiName + ': ' + e.getMessage());
            }
        }
        return false;
    }

    @IsTest
    static void testBusinessContactCreationAndMatching() {
        Account businessAccount = new Account(Name='Coverage Contact Business');
        assignBusinessRecordType(businessAccount);
        insert businessAccount;
        String bceidGuid = 'CONTACTGUID-' + String.valueOf(DateTime.now().getTime());
        Auth.UserData source = data('sub', 'coverage-contact',
            'coverage.contact@example.org', new Map<String, String>{
                'bceid_user_guid'=>bceidGuid,
                'bceid_username'=>'CoverageContact'
            });
        Test.startTest();
        String createdContactId = UserRegistrationService.testManageBceidContact(
            source, null, businessAccount.Id);
        System.assertNotEquals(null, createdContactId);
        // BCeID identifiers are optional Account/Contact fields across target
        // orgs. The package-version test org may not contain a queryable and
        // creatable Contact GUID field. Only exercise the second lookup when
        // the first insert actually persisted its stable identifier; otherwise
        // a second insert will correctly be rejected by the duplicate rule.
        if (contactHasPersistedBceidGuid((Id) createdContactId, bceidGuid)) {
            String matchedContactId = UserRegistrationService.testManageBceidContact(
                source, null, businessAccount.Id);
            System.assertEquals(createdContactId, matchedContactId,
                'A persisted BCeID GUID must always resolve to the same Contact.');
        } else {
            System.debug(LoggingLevel.WARN,
                'BCeID Contact GUID not accessible/persisted in this package ' +
                'test org. Contact identity re-matching was not exercised. ' +
                'Do not use email-only matching as an identity fallback.');
        }
        Test.stopTest();
        Contact created = [SELECT AccountId, FirstName, LastName, Email
            FROM Contact WHERE Id = :createdContactId];
        System.assertEquals(businessAccount.Id, created.AccountId);
        System.assertEquals('First', created.FirstName);
        System.assertEquals('Last', created.LastName);
        System.assertEquals('coverage.contact@example.org', created.Email);
    }
}
