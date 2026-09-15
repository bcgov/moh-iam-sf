@IsTest
private class BceidUserUpdateJobTest {
    private static User createUser(String firstName, String lastName) {
        Profile p = [SELECT Id FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
        String unique = String.valueOf(DateTime.now().getTime());
        User u = new User(
            Alias = 'bceidq',
            Email = 'bceid.queue.' + unique + '@example.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = firstName,
            LastName = lastName,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Vancouver',
            Username = 'bceid.queue.' + unique + '@example.com'
        );
        insert u;
        return u;
    }

    @IsTest
    static void testQueueableUpdatesUserNameWhenDifferent() {
        User u = createUser('Original', 'Queue User');
        Test.startTest();
        Id jobId = System.enqueueJob(new BceidUserUpdateJob(u.Id, 'Deepak', 'Test Operator 1'));
        Test.stopTest();

        User updatedUser = [SELECT FirstName, LastName FROM User WHERE Id = :u.Id];
        System.assertEquals('Deepak', updatedUser.FirstName);
        System.assertEquals('Test Operator 1', updatedUser.LastName);
        AsyncApexJob job = [SELECT Status, NumberOfErrors FROM AsyncApexJob WHERE Id = :jobId];
        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
    }

    @IsTest
    static void testQueueableSkipsDmlWhenNameAlreadyMatches() {
        User u = createUser('Deepak', 'Test Operator 1');
        Test.startTest();
        Id jobId = System.enqueueJob(new BceidUserUpdateJob(u.Id, 'Deepak', 'Test Operator 1'));
        Test.stopTest();

        User unchangedUser = [SELECT FirstName, LastName FROM User WHERE Id = :u.Id];
        System.assertEquals('Deepak', unchangedUser.FirstName);
        System.assertEquals('Test Operator 1', unchangedUser.LastName);
        AsyncApexJob job = [SELECT Status, NumberOfErrors FROM AsyncApexJob WHERE Id = :jobId];
        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
    }
}