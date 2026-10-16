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
    static void testBusinessNumberUpdatesCanonicalAccountField() {
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Account.fields.getMap();
        if (supportedGuidField() == null || !fields.containsKey('BCeIDBusinessNumber__c')) return;
        Schema.DescribeFieldResult numberField =
            fields.get('BCeIDBusinessNumber__c').getDescribe();
        if (!numberField.isAccessible() || !numberField.isUpdateable()) return;

        Account account = businessAccount('BUSINESS-NUMBER-GUID', 'Original business');
        BceidBusinessAccountMapper.BusinessData business = data('BUSINESS-NUMBER-GUID');
        business.businessNumber = '123456789';

        Test.startTest();
        BceidBusinessAccountUpdateJob.syncLinkedAccount(account.Id, business);
        Test.stopTest();

        Id accountId = account.Id;
        Account updated = Database.query(
            'SELECT Id, BCeIDBusinessNumber__c FROM Account WHERE Id = :accountId LIMIT 1'
        );
        System.assertEquals('123456789', updated.get('BCeIDBusinessNumber__c'),
            'Account sync must update the spreadsheet-defined BCeID business number field.');
    }

    @IsTest
    static void testExistingAccountStatusBecomesActive() {
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Account.fields.getMap();
        if (supportedGuidField() == null || !fields.containsKey('Status__c')) return;
        Schema.DescribeFieldResult statusDescribe = fields.get('Status__c').getDescribe();
        if (!statusDescribe.isAccessible() || !statusDescribe.isUpdateable()) return;

        Account account = businessAccount('GUID-ACTIVE-TEST', 'Original business');
        Id accountId = account.Id;
        Account initial = Database.query('SELECT Id, Status__c FROM Account WHERE Id = :accountId');
        if (String.valueOf(initial.get('Status__c')) != 'Inactive') {
            Account inactive = new Account(Id = accountId);
            inactive.put('Status__c', 'Inactive');
            update inactive;
        }

        BceidBusinessAccountMapper.BusinessData business = data('GUID-ACTIVE-TEST');
        // Even when the legacy configured flag is false, verified accounts become Active.
        Test.startTest();
        BceidBusinessAccountUpdateJob.syncLinkedAccount(accountId, business, false);
        Test.stopTest();
        Account afterSync = Database.query('SELECT Id, Status__c FROM Account WHERE Id = :accountId');
        System.assertEquals('Active', afterSync.get('Status__c'));

        // A second sync must not change the already Active status.
        BceidBusinessAccountUpdateJob.syncLinkedAccount(accountId, business, false);
        Account again = Database.query('SELECT Id, Status__c FROM Account WHERE Id = :accountId');
        System.assertEquals('Active', again.get('Status__c'));
    }

    @IsTest
    static void testGuidMismatchNeverChangesAccountStatus() {
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Account.fields.getMap();
        if (supportedGuidField() == null || !fields.containsKey('Status__c')) return;
        if (!fields.get('Status__c').getDescribe().isAccessible() ||
                !fields.get('Status__c').getDescribe().isUpdateable()) return;
        Account account = businessAccount('GUID-SAFE', 'Original business');
        Id accountId = account.Id;
        Account inactive = new Account(Id = accountId);
        inactive.put('Status__c', 'Inactive');
        update inactive;

        BceidBusinessAccountUpdateJob.syncLinkedAccount(
            accountId, data('GUID-DIFFERENT'), true);
        Account afterSync = Database.query('SELECT Id, Status__c FROM Account WHERE Id = :accountId');
        System.assertEquals('Inactive', afterSync.get('Status__c'),
            'A GUID mismatch must not activate the Account.');
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

    @IsTest
    static void testPopulatedAddressesUpdateAndBlankAddressesPreserve() {
        if (supportedGuidField() == null) return;
        Account a = businessAccount('GUID-ADDRESS', 'Existing business');
        a.BillingStreet = 'Old Billing Street';
        a.ShippingStreet = 'Old Shipping Street';
        a.BillingCity = 'Old Billing City';
        a.ShippingCity = 'Old Shipping City';
        update a;

        BceidBusinessAccountMapper.BusinessData populated = data('GUID-ADDRESS');
        populated.addressLine1 = '456 Updated Road';
        populated.city = 'Victoria';
        BceidBusinessAccountUpdateJob.syncLinkedAccount(a.Id, populated);
        Account updated = [SELECT BillingStreet, ShippingStreet, BillingCity, ShippingCity
                           FROM Account WHERE Id = :a.Id];
        System.assertEquals('456 Updated Road', updated.BillingStreet);
        System.assertEquals('456 Updated Road', updated.ShippingStreet);
        System.assertEquals('Victoria', updated.BillingCity);
        System.assertEquals('Victoria', updated.ShippingCity);

        BceidBusinessAccountMapper.BusinessData blank = data('GUID-ADDRESS');
        blank.addressLine1 = null;
        blank.addressLine2 = null;
        blank.city = null;
        blank.postal = null;
        blank.province = null;
        blank.country = null;
        BceidBusinessAccountUpdateJob.syncLinkedAccount(a.Id, blank);
        Account preserved = [SELECT BillingStreet, ShippingStreet, BillingCity, ShippingCity
                             FROM Account WHERE Id = :a.Id];
        System.assertEquals(updated.BillingStreet, preserved.BillingStreet);
        System.assertEquals(updated.ShippingStreet, preserved.ShippingStreet);
        System.assertEquals(updated.BillingCity, preserved.BillingCity);
        System.assertEquals(updated.ShippingCity, preserved.ShippingCity);
    }
}
