@IsTest
private class BceidIdentityServiceTest {
    @TestSetup static void setupUser() {
        Profile p = [SELECT Id FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
        String unique = String.valueOf(DateTime.now().getTime());
        insert new User(Alias='bceidt', Email='bceid.test.'+unique+'@example.com', EmailEncodingKey='UTF-8', FirstName='Original', LastName='User', LanguageLocaleKey='en_US', LocaleSidKey='en_US', ProfileId=p.Id, TimeZoneSidKey='America/Vancouver', Username='bceid.test.'+unique+'@example.com');
    }
    private static User getTestUser(){ return [SELECT Id,FirstName,LastName FROM User WHERE Alias='bceidt' LIMIT 1]; }
    private static Contact createContact(String firstName,String lastName){ Contact c=new Contact(FirstName=firstName,LastName=lastName,
            Email = 'bceid.identity.test@example.com'); insert c; return c; }
    private static BceidSoapClient.SoapResult successfulResult(){ BceidSoapClient.SoapResult r=new BceidSoapClient.SoapResult(); r.httpStatus=200; r.hasSoapFault=false; r.responseCode='Success'; r.failureCode='Void'; r.firstName='Deepak'; r.lastName='Test Operator 1'; return r; }

    @IsTest static void testSyncUpdatesDifferentNames(){
        User u=getTestUser(); Contact c=createContact('Original','Contact');
        Test.startTest(); BceidIdentityService.SyncResult sr=BceidIdentityService.sync(successfulResult(),u.Id,c.Id); Test.stopTest();
        c=[SELECT FirstName,LastName FROM Contact WHERE Id=:c.Id]; u=[SELECT FirstName,LastName FROM User WHERE Id=:u.Id];
        System.assertEquals('Deepak',c.FirstName); System.assertEquals('Test Operator 1',c.LastName);
        System.assertEquals('Deepak',u.FirstName); System.assertEquals('Test Operator 1',u.LastName);
        System.assertEquals(true,sr.contactUpdated); System.assertEquals(true,sr.userUpdateQueued); System.assertNotEquals(null,sr.userUpdateJobId);
    }
    @IsTest static void testDoesNothingWhenNamesAlreadyMatch(){
        User u=getTestUser(); u.FirstName='Deepak'; u.LastName='Test Operator 1'; update u;
        Contact c=createContact('Deepak','Test Operator 1');
        Test.startTest(); BceidIdentityService.SyncResult sr=BceidIdentityService.sync(successfulResult(),u.Id,c.Id); Test.stopTest();
        System.assertEquals(false,sr.contactUpdated); System.assertEquals(false,sr.userUpdateQueued); System.assertEquals(null,sr.userUpdateJobId);
    }
    @IsTest static void testOnlyUserQueuedWhenContactAlreadyMatches(){
        User u=getTestUser(); Contact c=createContact('Deepak','Test Operator 1');
        Test.startTest(); BceidIdentityService.SyncResult sr=BceidIdentityService.sync(successfulResult(),u.Id,c.Id); Test.stopTest();
        System.assertEquals(false,sr.contactUpdated); System.assertEquals(true,sr.userUpdateQueued);
    }
    @IsTest static void testRejectsMissingNames(){
        User u=getTestUser(); Contact c=createContact('Original','Contact'); BceidSoapClient.SoapResult r=successfulResult(); r.firstName=null;
        try { BceidIdentityService.sync(r,u.Id,c.Id); System.assert(false); } catch(BceidIdentityService.BceidIdentityException e){ System.assert(e.getMessage().contains('first and last name')); }
    }
}