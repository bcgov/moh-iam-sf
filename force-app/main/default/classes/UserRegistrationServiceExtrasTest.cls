@IsTest
private class UserRegistrationServiceExtrasTest {
    private static Auth.UserData token(String identifier, String username, String firstName,
            String lastName, String email, Map<String, String> claims) {
        return new Auth.UserData(identifier, firstName, lastName,
            'Example Name', email, null, username, 'en_US',
            'Open ID Connect', null, claims);
    }

    private static void applyBusinessRT(Account account) {
        Map<String, Schema.RecordTypeInfo> infos =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        if (infos.containsKey('Business_Entity') &&
                infos.get('Business_Entity').isAvailable()) {
            account.RecordTypeId = infos.get('Business_Entity').getRecordTypeId();
        }
    }

    @IsTest
    static void testResolveLinkedBusinessContacts() {
        Account account = new Account(Name = 'BCeID Contact Resolution Coverage');
        applyBusinessRT(account);
        insert account;
        System.assertEquals(null,
            UserRegistrationService.resolveBusinessAccountContactId(account.Id, null),
            'An Account without Contacts has no linked Contact.');

        Contact first = new Contact(AccountId = account.Id, LastName = 'First',
            Email = 'first@example.org');
        insert first;
        Auth.UserData exact = token('id', 'fallback@example.org', 'First', 'Last',
            'first@example.org', new Map<String, String>());
        System.assertEquals(first.Id,
            UserRegistrationService.resolveBusinessAccountContactId(account.Id, exact));

        Auth.UserData pidpFallback = token('id', 'fallback@example.org', 'First', 'Last',
            null, new Map<String, String>{'pidp_email' => 'first@example.org'});
        System.assertEquals(first.Id,
            UserRegistrationService.resolveBusinessAccountContactId(account.Id, pidpFallback));

        Auth.UserData usernameFallback = token('id', 'first@example.org', 'First', 'Last',
            null, new Map<String, String>());
        System.assertEquals(first.Id,
            UserRegistrationService.resolveBusinessAccountContactId(account.Id, usernameFallback));

        Auth.UserData missingEmail = token('id', 'unmatched@example.org', 'First', 'Last',
            null, new Map<String, String>());
        System.assertEquals(first.Id,
            UserRegistrationService.resolveBusinessAccountContactId(account.Id, missingEmail),
            'When an exact email does not match, fall back to earliest Contact.');
        System.assertEquals(null,
            UserRegistrationService.resolveBusinessAccountContactId(null, exact));
    }

    @IsTest
    static void testBusinessAccountIdentifierAndDefaultName() {
        String guid = 'BCID-COV-' + String.valueOf(DateTime.now().getTime());
        Auth.UserData byGuid = token('id', 'business-user', 'First', 'Last',
            'account@example.org', new Map<String, String>{'bceid_business_id' => guid});
        String accountId = UserRegistrationService.testManageBceidAccount(byGuid, null);
        Account inserted = [SELECT Id, Name FROM Account WHERE Id = :accountId];
        System.assertEquals(guid, inserted.Name,
            'When legalName is absent, prefer the stable BCeID business identifier.');
        System.assertEquals(accountId,
            UserRegistrationService.testManageBceidAccount(byGuid, null),
            'The BCeID GUID should reuse the same Account.');

        Auth.UserData noName = token('id', 'business-user-2', 'First', 'Last',
            'account@example.org', new Map<String, String>());
        String fallbackId = UserRegistrationService.testManageBceidAccount(noName, null);
        System.assertEquals('BCeID Business',
            [SELECT Name FROM Account WHERE Id = :fallbackId].Name);
    }

    @IsTest
    static void testBusinessContactUsesTokenFieldsWhenUserDataBlank() {
        Account account = new Account(Name = 'BCeID Token Contact Coverage');
        applyBusinessRT(account);
        insert account;
        Map<String, String> claims = new Map<String, String>{
            'bceid_username' => 'TokenBceidUser',
            'email' => 'token.contact@example.org'
        };
        Auth.UserData source = token('contact', 'token-user', null, null, null, claims);
        String contactId = UserRegistrationService.testManageBceidContact(
            source, null, account.Id);
        Contact result = [SELECT FirstName, LastName, Email, AccountId
                          FROM Contact WHERE Id = :contactId];
        System.assertEquals('TokenBceidUser', result.FirstName);
        System.assertEquals('TokenBceidUser', result.LastName);
        System.assertEquals('token.contact@example.org', result.Email);
        System.assertEquals(account.Id, result.AccountId);
    }

    @IsTest
    static void testRoleSourceBranchesAndNoEndorsers() {
        Auth.UserData bcsc = token('id', 'user', 'First', 'Last', null,
            new Map<String, String>{'idp' => 'NOT_CONFIGURED_ROLE_987654'});
        Auth.UserData bceid = token('id', 'user', 'First', 'Last', null,
            new Map<String, String>{'identity_provider' => 'bceid_business'});
        Auth.UserData moh = token('id', 'user', 'First', 'Last', null,
            new Map<String, String>{'roles' => 'NOT_CONFIGURED_ROLE_987654'});
        Auth.UserData unknown = token('id', 'user', 'First', 'Last', null,
            new Map<String, String>());
        System.assertNotEquals(null, UserRegistrationService.manageUserRole(bcsc));
        System.assertNotEquals(null, UserRegistrationService.manageUserRole(bceid));
        System.assertNotEquals(null, UserRegistrationService.manageUserRole(moh));
        System.assertEquals(0, UserRegistrationService.manageUserRole(unknown).size());

        System.assertEquals(0, UserRegistrationService.fetchPersonAccount(
            new List<String>(), false, unknown, 'endorser_data').size());
    }

    @IsTest
    static void testPersonAccountLookupWithUnknownExternalKeys() {
        // Exercise the dynamically constructed Account query without relying on
        // an org-wide Person Account fixture or pre-existing Salesforce data.
        Auth.UserData source = token('id', 'user', 'First', 'Last', null,
            new Map<String, String>());
        List<String> neverExisting = new List<String>{
            'NOT-A-REAL-PROVIDER-ID-987654321'
        };
        System.assertEquals(0,
            UserRegistrationService.fetchPersonAccount(
                neverExisting, false, source, 'endorser_data').size());
        System.assertEquals(0,
            UserRegistrationService.fetchPersonAccount(
                neverExisting, true, source, 'endorser_data').size());
    }

    @IsTest
    static void testNoPermissionGroupsForUnknownRole() {
        Test.startTest();
        UserRegistrationService.managePublicGroups(UserInfo.getUserId(),
            'NO_PERMISSION_GROUP_COVERAGE_987654');
        Test.stopTest();
    }
}
