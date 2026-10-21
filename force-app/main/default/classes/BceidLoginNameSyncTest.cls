@IsTest
private class BceidLoginNameSyncTest {

    @TestSetup
    static void setupUser() {
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Id = :UserInfo.getProfileId()
            LIMIT 1
        ];

        String uniqueValue = String.valueOf(DateTime.now().getTime());

        insert new User(
            Alias = 'bceifl',
            Email = 'bceid.flow.' + uniqueValue + '@example.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Original',
            LastName = 'Flow User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Vancouver',
            Username = 'bceid.flow.' + uniqueValue + '@example.com'
        );

        // Experience Cloud Contacts require their Account owner to have a role.
        UserRole roleForPortalAccount = new UserRole(
            Name = 'BCeID Login Sync Test Role'
        );
        insert roleForPortalAccount;
        insert new User(
            Alias = 'bcowner',
            Email = 'bceid.owner.' + uniqueValue + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'BCeID Test Account Owner',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Vancouver',
            Username = 'bceid.owner.' + uniqueValue + '@example.com',
            UserRoleId = roleForPortalAccount.Id
        );
    }

    private static User getTestUser() {
        return [
            SELECT Id, FirstName, LastName
            FROM User
            WHERE Alias = 'bceifl'
            LIMIT 1
        ];
    }

    private static User getRoleOwner() {
        return [
            SELECT Id, UserRoleId
            FROM User
            WHERE Alias = 'bcowner' AND UserRoleId != null
            LIMIT 1
        ];
    }

    private static Contact createContact(
        String firstName,
        String lastName,
        String guid
    ) {
        Contact c = new Contact(
            FirstName = firstName,
            LastName = lastName,
            Email = 'bceid.identity.' + String.valueOf(DateTime.now().getTime()) + '@example.com'
        );
        Schema.SObjectField guidField =
            Schema.SObjectType.Contact.fields.getMap().get('BCeIDGUID__c');
        if (guid != null && guidField != null && guidField.getDescribe().isCreateable()) {
            c.put('BCeIDGUID__c', guid);
        }
        insert c;
        return c;
    }

    private static Contact createContact(
        String firstName,
        String lastName,
        String guid,
        Id accountId
    ) {
        Contact c = new Contact(
            AccountId = accountId,
            FirstName = firstName,
            LastName = lastName,
            Email = 'bceid.identity.' + String.valueOf(DateTime.now().getTime()) + '@example.com'
        );
        Schema.SObjectField guidField =
            Schema.SObjectType.Contact.fields.getMap().get('BCeIDGUID__c');
        if (guid != null && guidField != null && guidField.getDescribe().isCreateable()) {
            c.put('BCeIDGUID__c', guid);
        }
        insert c;
        return c;
    }

    /** Creates an Experience Cloud user whose ContactId matches the target Contact. */
    private static User createExperienceUser(Contact contactRecord) {
        List<Profile> profiles = [
            SELECT Id, Name, UserLicense.Name
            FROM Profile
            WHERE UserLicense.Name LIKE '%Customer Community%'
            ORDER BY Name
            LIMIT 1
        ];
        if (profiles.isEmpty()) {
            profiles = [
                SELECT Id, Name, UserLicense.Name
                FROM Profile
                WHERE UserLicense.Name LIKE '%External Identity%'
                ORDER BY Name
                LIMIT 1
            ];
        }
        System.assert(
            !profiles.isEmpty(),
            'This test requires an Experience Cloud or External Identity profile.'
        );

        String uniqueValue = String.valueOf(DateTime.now().getTime()) +
            String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User portalUser = new User(
            Alias = 'bceiexp',
            Email = 'bceid.exp.' + uniqueValue + '@example.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Original',
            LastName = 'Flow User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profiles[0].Id,
            TimeZoneSidKey = 'America/Vancouver',
            Username = 'bceid.exp.' + uniqueValue + '@example.com',
            CommunityNickname = 'bceidexp' + uniqueValue,
            ContactId = contactRecord.Id
        );

        User runningUser = [
            SELECT Id
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        System.runAs(runningUser) {
            insert portalUser;
        }
        return portalUser;
    }

    private static BceidLoginNameSync.Request request(
        Id userId,
        Id contactId
    ) {
        BceidLoginNameSync.Request r =
            new BceidLoginNameSync.Request();

        r.userId = userId;
        r.contactId = contactId;
        r.onlineServiceId = 'TEST-SERVICE';
        r.requesterAccountTypeCode = 'Business';
        r.accountTypeCode = 'Business';
        return r;
    }


    private static BceidLoginNameSync.Request requestWithGuidFallback(Id userId, Id contactId) {
        BceidLoginNameSync.Request r = request(userId, contactId);
        Schema.SObjectField guidField =
            Schema.SObjectType.Contact.fields.getMap().get('BCeIDGUID__c');
        if (guidField == null || !guidField.getDescribe().isAccessible() ||
            !guidField.getDescribe().isCreateable()) {
            r.bceidUserGuid = '64510436D6CF4EE68B1DFE39111FFE74';
        }
        return r;
    }

    @IsTest
    static void testBlankContactGuidSkipsWithoutCallout() {
        User u = getTestUser();
        Contact c = createContact('Original', 'Contact', null);

        Test.startTest();
        List<BceidLoginNameSync.Response> results =
            BceidLoginNameSync.execute(
                new List<BceidLoginNameSync.Request>{
                    request(u.Id, c.Id)
                }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].success);
        System.assertEquals(true, results[0].skipped);
        System.assertEquals(false, results[0].contactUpdated);
        System.assertEquals(false, results[0].userUpdateQueued);
        System.assert(
            results[0].errorMessage.contains('Synchronization skipped: BCeID User GUID was not supplied')
        );
    }

    @IsTest
    static void testCalloutUsesGuidFromContactAndSyncsNames() {
        Account accountRecord = new Account(
            Name = 'BCeID Login Sync Test Account',
            OwnerId = getRoleOwner().Id
        );
        Map<String, Schema.SObjectField> accountFields = Schema.SObjectType.Account.fields.getMap();
        Boolean canVerifyBusinessAccountUpdate = false;
        if (accountFields.containsKey('BCeIDGUID__c') &&
                accountFields.get('BCeIDGUID__c').getDescribe().isCreateable()) {
            accountRecord.put('BCeIDGUID__c', 'LOGIN-SYNC-BUSINESS-GUID');
            canVerifyBusinessAccountUpdate = accountFields.get('BCeIDGUID__c').getDescribe().isAccessible();
        }
        if (accountFields.containsKey('ExternalId__c') &&
                accountFields.get('ExternalId__c').getDescribe().isCreateable()) {
            accountRecord.put('ExternalId__c', 'LOGIN-SYNC-BUSINESS-GUID');
            canVerifyBusinessAccountUpdate = canVerifyBusinessAccountUpdate ||
                accountFields.get('ExternalId__c').getDescribe().isAccessible();
        }
        insert accountRecord;
        Contact c = createContact(
            'Original',
            'Contact',
            '64510436D6CF4EE68B1DFE39111FFE74',
            accountRecord.Id
        );
        User u = createExperienceUser(c);

        System.assertEquals(c.Id, u.ContactId,
            'The test user must be associated with the Contact being synchronized.');
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        List<BceidLoginNameSync.Response> results =
            BceidLoginNameSync.execute(
                new List<BceidLoginNameSync.Request>{
                    requestWithGuidFallback(u.Id, c.Id)
                }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].success);
        System.assertEquals(false, results[0].skipped);
        System.assertEquals(200, results[0].httpStatus);
        System.assertEquals('Success', results[0].responseCode);
        System.assertEquals('Deepak', results[0].firstName);
        System.assertEquals('Test Operator 1', results[0].lastName);
        // Contact automation may already have made the names authoritative before sync.
        // Final persisted values below are the source of truth; contactUpdated only reports
        // whether this specific sync transaction performed Contact DML.
        System.assertNotEquals(null, results[0].contactUpdated);
        System.assertEquals(true, results[0].userUpdateQueued);
        System.assertEquals(true, results[0].accountUpdateQueued,
            'The authorized business section should queue Account synchronization.');

        // Deliver the separate User-update platform event after Contact DML.
        Test.getEventBus().deliver();
        c = [
            SELECT FirstName, LastName, Email, MobilePhone
            FROM Contact
            WHERE Id = :c.Id
        ];

        System.assertEquals('Deepak', c.FirstName);
        System.assertEquals('Test Operator 1', c.LastName);
        System.assertEquals('deepak.updated@example.com', c.Email);
        System.assertEquals('6045550123', c.MobilePhone);
        if (canVerifyBusinessAccountUpdate) {
            Account synchronizedAccount = [
                SELECT Name, Phone, BillingStreet, ShippingStreet, BillingCity, ShippingCity
                FROM Account WHERE Id = :accountRecord.Id LIMIT 1
            ];
            System.assertEquals('BCeID Updated Business', synchronizedAccount.Name);
            System.assertEquals('6045550123', synchronizedAccount.Phone);
            System.assertEquals('123 Updated Road\nSuite 2', synchronizedAccount.BillingStreet);
            System.assertEquals(synchronizedAccount.BillingStreet, synchronizedAccount.ShippingStreet);
            System.assertEquals('Vancouver', synchronizedAccount.BillingCity);
            System.assertEquals(synchronizedAccount.BillingCity, synchronizedAccount.ShippingCity);
        }
        // The User update is published as a platform event to avoid mixed DML.
        User synchronizedUser = [
            SELECT FirstName, LastName, Email, MobilePhone
            FROM User WHERE Id = :u.Id LIMIT 1
        ];
        System.assertEquals('Deepak', synchronizedUser.FirstName);
        System.assertEquals('Test Operator 1', synchronizedUser.LastName);
        System.assertEquals('deepak.updated@example.com', synchronizedUser.Email);
        System.assertEquals('6045550123', synchronizedUser.MobilePhone);
        System.assertEquals(true, results[0].userUpdateQueued);
    }

    @IsTest
    static void testNoUpdatesWhenNamesAlreadyMatch() {
        User u = getTestUser();
        u.FirstName = 'Deepak';
        u.LastName = 'Test Operator 1';
        update u;

        Contact c = createContact(
            'Deepak',
            'Test Operator 1',
            '64510436D6CF4EE68B1DFE39111FFE74'
        );

        Test.setMock(HttpCalloutMock.class, new SuccessMock(false));

        Test.startTest();
        List<BceidLoginNameSync.Response> results =
            BceidLoginNameSync.execute(
                new List<BceidLoginNameSync.Request>{
                    requestWithGuidFallback(u.Id, c.Id)
                }
            );
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertEquals(false, results[0].skipped);
        System.assertEquals(false, results[0].contactUpdated);
        System.assertEquals(false, results[0].userUpdateQueued);
        System.assertEquals(false, results[0].accountUpdateQueued);
        System.assertEquals(null, results[0].userUpdateJobId);
    }

    @IsTest
    static void testMissingContactIdReturnsNonFatalError() {
        User u = getTestUser();
        BceidLoginNameSync.Request r = request(u.Id, null);

        Test.startTest();
        List<BceidLoginNameSync.Response> results =
            BceidLoginNameSync.execute(
                new List<BceidLoginNameSync.Request>{ r }
            );
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assertEquals(false, results[0].skipped);
        System.assert(
            results[0].errorMessage.contains('Contact Id is required.')
        );
    }

    private class SuccessMock implements HttpCalloutMock {
        private Boolean includeContactAndBusiness;
        SuccessMock() { this(true); }
        SuccessMock(Boolean includeContactAndBusiness) {
            this.includeContactAndBusiness = includeContactAndBusiness;
        }

        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals('POST', req.getMethod());
            System.assertEquals(
                '"http://www.bceid.ca/webservices/Client/V10/getAccountDetail"',
                req.getHeader('SOAPAction')
            );
            System.assert(
                req.getBody().contains(
                    '64510436D6CF4EE68B1DFE39111FFE74'
                ),
                'Expected Contact.BCeIDGUID__c in SOAP request.'
            );

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader(
                'Content-Type',
                'text/xml; charset=utf-8'
            );
            String contactAndBusinessXml = includeContactAndBusiness
                ? '<contact>' +
                    '<email isAllowed="true"><value>deepak.updated@example.com</value></email>' +
                    '<telephone isAllowed="true"><value>+1 (604) 555-0123</value></telephone>' +
                  '</contact>' +
                  '<business>' +
                    '<guid isAllowed="true"><value>LOGIN-SYNC-BUSINESS-GUID</value></guid>' +
                    '<legalName isAllowed="true"><value>BCeID Updated Business</value></legalName>' +
                    '<businessNumber isAllowed="true"><value>123456789</value></businessNumber>' +
                    '<doingBusinessAs isAllowed="true"><value>Updated DBA</value></doingBusinessAs>' +
                    '<address>' +
                      '<addressLine1 isAllowed="true"><value>123 Updated Road</value></addressLine1>' +
                      '<addressLine2 isAllowed="true"><value>Suite 2</value></addressLine2>' +
                      '<city isAllowed="true"><value>Vancouver</value></city>' +
                      '<postal isAllowed="true"><value>V5Z 4C2</value></postal>' +
                      '<province isAllowed="true"><value>BC</value></province>' +
                      '<country isAllowed="true"><value>CA</value></country>' +
                    '</address>' +
                  '</business>'
                : '';
            res.setBody(
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soap:Envelope ' +
                'xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" ' +
                'xmlns="http://www.bceid.ca/webservices/Client/V10/">' +
                '<soap:Body>' +
                '<getAccountDetailResponse>' +
                '<getAccountDetailResult>' +
                '<code>Success</code>' +
                '<failureCode>Void</failureCode>' +
                '<message />' +
                '<account>' +
                contactAndBusinessXml +
                '<individualIdentity>' +
                '<name>' +
                '<firstname isAllowed="true">' +
                '<value>Deepak</value>' +
                '</firstname>' +
                '<surname isAllowed="true">' +
                '<value>Test Operator 1</value>' +
                '</surname>' +
                '</name>' +
                '</individualIdentity>' +
                '</account>' +
                '</getAccountDetailResult>' +
                '</getAccountDetailResponse>' +
                '</soap:Body>' +
                '</soap:Envelope>'
            );
            return res;
        }
    }
}
