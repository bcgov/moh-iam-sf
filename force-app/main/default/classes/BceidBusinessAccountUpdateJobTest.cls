@IsTest
private class BceidBusinessAccountUpdateJobTest {
    private static BceidBusinessAccountMapper.BusinessData data(String guid) {
        BceidBusinessAccountMapper.BusinessData business =
            new BceidBusinessAccountMapper.BusinessData();
        business.guid = guid;
        business.legalName = 'BCeID Updated Business';
        business.phone = '604-555-0123';
        business.addressLine1 = '123 Main Street';
        business.city = 'Vancouver';
        business.postal = 'V6B 1A1';
        // Country/state are intentionally omitted: State/Country picklist
        // configuration varies across the orgs using this package.
        return business;
    }

    private static String supportedGuidField() {
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Account.fields.getMap();
        if (fields.containsKey('BCeIDGUID__c')) return 'BCeIDGUID__c';
        if (fields.containsKey('ExternalId__c')) return 'ExternalId__c';
        return null;
    }

    private static Account businessAccount(String guid, String name) {
        Account account = new Account(Name = name);
        Map<String, Schema.RecordTypeInfo> recordTypes =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        if (recordTypes.containsKey('Business_Entity') &&
                recordTypes.get('Business_Entity').isAvailable()) {
            account.RecordTypeId = recordTypes.get('Business_Entity').getRecordTypeId();
        }
        String fieldName = supportedGuidField();
        if (fieldName != null && guid != null) account.put(fieldName, guid);
        insert account;
        return account;
    }

    @IsTest
    static void testGuardClausesAndUnlinkedUser() {
        BceidBusinessAccountMapper.BusinessData valid = data('ABC-123');
        Test.startTest();
        new BceidBusinessAccountUpdateJob(null, valid).execute(null);
        new BceidBusinessAccountUpdateJob(UserInfo.getUserId(), null).execute(null);
        new BceidBusinessAccountUpdateJob(UserInfo.getUserId(),
            new BceidBusinessAccountMapper.BusinessData()).execute(null);
        // An internal test-running user typically has no ContactId.
        new BceidBusinessAccountUpdateJob(UserInfo.getUserId(), valid).execute(null);
        Test.stopTest();
    }

    @IsTest
    static void testUnknownAccountAndMissingIdentifierAreSafe() {
        BceidBusinessAccountMapper.BusinessData business = data('GUID-01');
        Account account = businessAccount(null, 'Original business');
        Test.startTest();
        BceidBusinessAccountUpdateJob.syncLinkedAccount(account.Id, business);
        BceidBusinessAccountUpdateJob.syncLinkedAccount(null, business);
        BceidBusinessAccountUpdateJob.syncLinkedAccount(account.Id, null);
        Test.stopTest();
        Account afterSync = [SELECT Name FROM Account WHERE Id = :account.Id];
        System.assertEquals('Original business', afterSync.Name,
            'An Account with no verified business GUID must not be updated.');
    }

    @IsTest
    static void testGuidMismatchNeverUpdatesAccount() {
        if (supportedGuidField() == null) return;
        Account account = businessAccount('GUID-ONE', 'Original business');
        Test.startTest();
        BceidBusinessAccountUpdateJob.syncLinkedAccount(account.Id, data('GUID-TWO'));
        Test.stopTest();
        System.assertEquals('Original business',
            [SELECT Name FROM Account WHERE Id = :account.Id].Name,
            'A BCeID business GUID mismatch must block updates.');
    }

    @IsTest
    static void testMatchingBusinessUpdatesOnlyDifferentFields() {
        // This package requires a business identifier to trust an Account.
        // Org-specific optional fields may be absent in other package targets.
        if (supportedGuidField() == null) return;
        Account account = businessAccount('GUID-UPDATE', 'Original business');
        Test.startTest();
        BceidBusinessAccountUpdateJob.syncLinkedAccount(
            account.Id, data('GUID-UPDATE'));
        Test.stopTest();
        Account afterSync = [
            SELECT Name, Phone, BillingStreet, ShippingStreet, BillingCity, ShippingCity
            FROM Account WHERE Id = :account.Id
        ];
        System.assertEquals('BCeID Updated Business', afterSync.Name);
        System.assertEquals('6045550123', afterSync.Phone);
        System.assertEquals('123 Main Street', afterSync.BillingStreet);
        System.assertEquals(afterSync.BillingStreet, afterSync.ShippingStreet);
        System.assertEquals('Vancouver', afterSync.BillingCity);
        System.assertEquals(afterSync.BillingCity, afterSync.ShippingCity);
    }

    @IsTest
    static void testExistingAccountStatusFollowsConfiguration() {
        Map<String, Schema.SObjectField> accountFields =
            Schema.SObjectType.Account.fields.getMap();
        if (supportedGuidField() == null || !accountFields.containsKey('isActive')) return;
        Schema.DescribeFieldResult statusField = accountFields.get('isActive').getDescribe();
        if (!statusField.isAccessible() || !statusField.isUpdateable()) return;

        Account account = businessAccount('GUID-ACTIVE-TEST', 'Original business');
        BceidBusinessAccountMapper.BusinessData business = data('GUID-ACTIVE-TEST');
        // First transition is chosen as the opposite of the current value,
        // so this test exercises an actual status-only change on every org.
        Account stored = Database.query('SELECT Id, isActive FROM Account WHERE Id = :account.Id');
        Boolean initialActive = (Boolean) stored.get('isActive');
        Boolean firstDesired = initialActive != true;
        Test.startTest();
        BceidBusinessAccountUpdateJob.syncLinkedAccount(account.Id, business, firstDesired);
        Test.stopTest();
        Account afterFirst = Database.query('SELECT Id, isActive FROM Account WHERE Id = :account.Id');
        System.assertEquals(firstDesired, afterFirst.get('isActive'),
            'BCeID business Account must follow configured status.');

        // A second invocation updates only the status while SOAP business
        // attributes are unchanged and verified GUID identity still matches.
        BceidBusinessAccountUpdateJob.syncLinkedAccount(account.Id, business, !firstDesired);
        Account afterSecond = Database.query('SELECT Id, isActive FROM Account WHERE Id = :account.Id');
        System.assertEquals(!firstDesired, afterSecond.get('isActive'),
            'A subsequent BCeID login must apply a changed configured status.');
    }

    @IsTest
    static void testGuidMismatchNeverChangesAccountStatus() {
        Map<String, Schema.SObjectField> accountFields =
            Schema.SObjectType.Account.fields.getMap();
        if (supportedGuidField() == null || !accountFields.containsKey('isActive')) return;
        if (!accountFields.get('isActive').getDescribe().isAccessible()) return;
        Account account = businessAccount('GUID-SAFE', 'Original business');
        Account beforeSync = Database.query('SELECT Id, isActive FROM Account WHERE Id = :account.Id');
        Boolean previous = (Boolean) beforeSync.get('isActive');
        BceidBusinessAccountUpdateJob.syncLinkedAccount(
            account.Id, data('GUID-DIFFERENT'), previous != true);
        Account afterSync = Database.query('SELECT Id, isActive FROM Account WHERE Id = :account.Id');
        System.assertEquals(previous, afterSync.get('isActive'),
            'Unverified BCeID business identities cannot change Account status.');
    }

    @IsTest
    static void testAlreadyMatchingBusinessDoesNotPerformDml() {
        if (supportedGuidField() == null) return;
        Account account = businessAccount('GUID-SAME', 'BCeID Updated Business');
        BceidBusinessAccountMapper.BusinessData business = data('GUID-SAME');
        account.Phone = '6045550123'; // DEV2 PhoneDigitsValidation accepts digits only
        // Both BCeID identifiers must match to make this a true no-change test.
        if (Schema.SObjectType.Account.fields.getMap().containsKey('ExternalId__c')) {
            account.put('ExternalId__c', business.guid);
        }
        account.BillingStreet = business.addressLine1;
        account.ShippingStreet = business.addressLine1;
        account.BillingCity = business.city;
        account.ShippingCity = business.city;
        account.BillingPostalCode = business.postal;
        account.ShippingPostalCode = business.postal;
        update account;

        Test.startTest();
        Integer beforeDml = Limits.getDmlStatements();
        BceidBusinessAccountUpdateJob.syncLinkedAccount(account.Id, business);
        Integer afterDml = Limits.getDmlStatements();
        System.assertEquals(beforeDml, afterDml,
            'Identical BCeID values should not write an Account.');
        Test.stopTest();
    }
}
