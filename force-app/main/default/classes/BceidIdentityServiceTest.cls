@IsTest
private class BceidIdentityServiceTest {
    @TestSetup
    static void setupUser() {
        Profile p = [SELECT Id FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
        String unique = String.valueOf(DateTime.now().getTime());
        insert new User(
            Alias='bceidt',
            Email='bceid.test.' + unique + '@example.com',
            EmailEncodingKey='UTF-8',
            FirstName='Original',
            LastName='User',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId=p.Id,
            TimeZoneSidKey='America/Vancouver',
            Username='bceid.test.' + unique + '@example.com'
        );
        insert new User(
            Alias='bceidm',
            Email='bceid.match.' + unique + '@example.com',
            EmailEncodingKey='UTF-8',
            FirstName='Deepak',
            LastName='Test Operator 1',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId=p.Id,
            TimeZoneSidKey='America/Vancouver',
            Username='bceid.match.' + unique + '@example.com'
        );
    }

    private static User getTestUser() {
        return [SELECT Id, FirstName, LastName FROM User WHERE Alias='bceidt' LIMIT 1];
    }

    private static Contact createContact(String firstName, String lastName) {
        Contact c = new Contact(
            FirstName=firstName,
            LastName=lastName,
            Email='bceid.identity.test@example.com'
        );
        insert c;
        return c;
    }

    private static BceidSoapClient.SoapResult successfulResult() {
        BceidSoapClient.SoapResult r = new BceidSoapClient.SoapResult();
        r.httpStatus = 200;
        r.hasSoapFault = false;
        r.responseCode = 'Success';
        r.failureCode = 'Void';
        r.firstName = 'Deepak';
        r.lastName = 'Test Operator 1';
        r.contactEmail = 'deepak.updated@example.com';
        r.contactTelephone = '6045550123';
        return r;
    }

    @IsTest
    static void testSyncQueuesDifferentNames() {
        User u = getTestUser();
        Contact c = createContact('Original', 'Contact');

        Test.startTest();
        BceidIdentityService.SyncResult sr =
            BceidIdentityService.sync(successfulResult(), u.Id, c.Id);

        // sync() now reports work queued by this invocation. Contact DML is
        // deliberately asynchronous, and a required User update is chained
        // from the Contact job rather than queued directly here.
        System.assertEquals(false, sr.contactUpdated);
        System.assertEquals(true, sr.contactUpdateQueued);
        System.assertEquals(true, sr.userUpdateQueued);
        System.assertNotEquals(null, sr.contactUpdateJobId);
        System.assertEquals(null, sr.userUpdateJobId);
        Test.stopTest();
    }

    @IsTest
    static void testDoesNothingWhenNamesAlreadyMatch() {
        User u = [SELECT Id, FirstName, LastName FROM User WHERE Alias='bceidm' LIMIT 1];
        Contact c = createContact('Deepak', 'Test Operator 1');

        BceidSoapClient.SoapResult namesOnly = successfulResult();
        namesOnly.contactEmail = null;
        namesOnly.contactTelephone = null;
        Test.startTest();
        BceidIdentityService.SyncResult sr =
            BceidIdentityService.sync(namesOnly, u.Id, c.Id);
        Test.stopTest();

        System.assertEquals(false, sr.contactUpdated);
        System.assertEquals(false, sr.contactUpdateQueued);
        System.assertEquals(false, sr.userUpdateQueued);
        System.assertEquals(null, sr.contactUpdateJobId);
        System.assertEquals(null, sr.userUpdateJobId);
    }

    @IsTest
    static void testOnlyUserQueuedWhenContactAlreadyMatches() {
        User u = getTestUser();
        Contact c = createContact('Deepak', 'Test Operator 1');

        BceidSoapClient.SoapResult namesOnly = successfulResult();
        namesOnly.contactEmail = null;
        namesOnly.contactTelephone = null;
        Test.startTest();
        BceidIdentityService.SyncResult sr =
            BceidIdentityService.sync(namesOnly, u.Id, c.Id);
        System.assertEquals(false, sr.contactUpdated);
        System.assertEquals(false, sr.contactUpdateQueued);
        System.assertEquals(true, sr.userUpdateQueued);
        System.assertNotEquals(null, sr.userUpdateJobId);
        Test.stopTest();

        u = [SELECT FirstName, LastName FROM User WHERE Id = :u.Id];
        System.assertEquals('Deepak', u.FirstName);
        System.assertEquals('Test Operator 1', u.LastName);
    }

    @IsTest
    static void testAcceptsPartialNamesWhenAuthorizedContactDataExists() {
        User u = getTestUser();
        Contact c = createContact('Original', 'Contact');
        BceidSoapClient.SoapResult r = successfulResult();
        r.firstName = null;
        r.lastName = null;
        r.contactEmail = 'allowed@example.com';
        r.contactTelephone = '6045550123';

        Test.startTest();
        BceidIdentityService.SyncResult sr = BceidIdentityService.sync(r, u.Id, c.Id);
        Test.stopTest();
        System.assertNotEquals(null, sr.contactUpdateJobId,
            'Authorized email/telephone should be synchronized even when names are not authorized.');
    }
    private static void expectInvalid(BceidSoapClient.SoapResult result, String marker) {
        try {
            BceidIdentityService.sync(result, UserInfo.getUserId(), UserInfo.getUserId());
            System.assert(false, 'Expected BceidIdentityException for ' + marker);
        } catch (BceidIdentityService.BceidIdentityException e) {
            System.assert(e.getMessage().contains(marker), e.getMessage());
        }
    }

    @IsTest
    static void testUnsuccessfulResponseValidation() {
        expectInvalid(null, 'cannot be null');
        BceidSoapClient.SoapResult response = successfulResult();
        response.httpStatus = null;
        expectInvalid(response, 'HTTP status');
        response.httpStatus = 500;
        expectInvalid(response, 'HTTP status');
        response.httpStatus = 300;
        expectInvalid(response, 'HTTP status');
        response.httpStatus = 200;
        response.hasSoapFault = true;
        response.faultString = 'SOAP validation failed';
        expectInvalid(response, 'SOAP fault');
        response.hasSoapFault = false;
        response.responseCode = 'Failure';
        response.failureCode = 'InvalidUser';
        expectInvalid(response, 'not successful');
        response.responseCode = 'Success';
        response.firstName = '';
        response.lastName = '';
        response.contactEmail = null;
        response.contactTelephone = null;
        response.businessGuid = null;
        response.businessLegalName = null;
        response.businessNumber = null;
        response.businessDoingBusinessAs = null;
        response.businessAddressLine1 = null;
        response.businessAddressLine2 = null;
        response.businessCity = null;
        response.businessPostal = null;
        response.businessProvince = null;
        response.businessCountry = null;
        expectInvalid(response, 'authorized person or business fields');
    }


    @IsTest
    static void testRequiredArgumentsAndCurrentUserWithoutContact() {
        BceidSoapClient.SoapResult response = successfulResult();
        try {
            BceidIdentityService.sync(response, null, UserInfo.getUserId());
            System.assert(false, 'Expected missing User Id exception.');
        } catch (BceidIdentityService.BceidIdentityException e) {
            System.assert(e.getMessage().contains('User Id is required'));
        }
        try {
            BceidIdentityService.sync(response, UserInfo.getUserId(), null);
            System.assert(false, 'Expected missing Contact Id exception.');
        } catch (BceidIdentityService.BceidIdentityException e) {
            System.assert(e.getMessage().contains('Contact Id is required'));
        }
        User internalUser = getTestUser();
        System.runAs(internalUser) {
            try {
                BceidIdentityService.syncCurrentUser(response);
                System.assert(false, 'Expected no ContactId exception.');
            } catch (BceidIdentityService.BceidIdentityException e) {
                System.assert(e.getMessage().contains('ContactId'));
            }
        }
    }

}
