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
    }

    private static User getTestUser() {
        return [
            SELECT Id, FirstName, LastName
            FROM User
            WHERE Alias = 'bceifl'
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
            Email = 'bceid.identity.test@example.com',
            BCeIDGUID__c = guid
        );
        insert c;
        return c;
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
            results[0].errorMessage.contains('BCeIDGUID__c is blank')
        );
    }

    @IsTest
    static void testCalloutUsesGuidFromContactAndSyncsNames() {
        User u = getTestUser();
        Contact c = createContact(
            'Original',
            'Contact',
            '64510436D6CF4EE68B1DFE39111FFE74'
        );

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        List<BceidLoginNameSync.Response> results =
            BceidLoginNameSync.execute(
                new List<BceidLoginNameSync.Request>{
                    request(u.Id, c.Id)
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
        System.assertEquals(true, results[0].contactUpdated);
        System.assertEquals(true, results[0].userUpdateQueued);

        c = [
            SELECT FirstName, LastName
            FROM Contact
            WHERE Id = :c.Id
        ];

        u = [
            SELECT FirstName, LastName
            FROM User
            WHERE Id = :u.Id
        ];

        System.assertEquals('Deepak', c.FirstName);
        System.assertEquals('Test Operator 1', c.LastName);
        System.assertEquals('Deepak', u.FirstName);
        System.assertEquals('Test Operator 1', u.LastName);
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

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        List<BceidLoginNameSync.Response> results =
            BceidLoginNameSync.execute(
                new List<BceidLoginNameSync.Request>{
                    request(u.Id, c.Id)
                }
            );
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertEquals(false, results[0].skipped);
        System.assertEquals(false, results[0].contactUpdated);
        System.assertEquals(false, results[0].userUpdateQueued);
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