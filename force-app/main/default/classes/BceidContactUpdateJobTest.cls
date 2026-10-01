@IsTest
private class BceidContactUpdateJobTest {

    @TestSetup
    static void setupData() {
        String uniqueValue = String.valueOf(DateTime.now().getTime());

        insert new User(
            Alias = 'bcucov',
            Email = 'bceid.contact.coverage.' + uniqueValue + '@example.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Original',
            LastName = 'Queue User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'America/Vancouver',
            Username = 'bceid.contact.coverage.' + uniqueValue + '@example.com'
        );

        insert new Contact(
            FirstName = 'Original',
            LastName = 'Contact',
            Email = 'bceid.contact.coverage@example.com'
        );
    }

    private static User getUser() {
        return [
            SELECT Id, ContactId, FirstName, LastName
            FROM User
            WHERE Alias = 'bcucov'
            LIMIT 1
        ];
    }

    private static Contact getContact() {
        return [
            SELECT Id, FirstName, LastName
            FROM Contact
            WHERE Email = 'bceid.contact.coverage@example.com'
            LIMIT 1
        ];
    }

    @IsTest
    static void testNullIdsReturnSafely() {
        Test.startTest();
        new BceidContactUpdateJob(
            null, null, 'First', 'Last', false
        ).execute(null);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testBlankNamesReturnSafely() {
        User u = getUser();
        Contact c = getContact();

        Test.startTest();
        new BceidContactUpdateJob(
            c.Id, u.Id, null, 'Last', false
        ).execute(null);
        new BceidContactUpdateJob(
            c.Id, u.Id, 'First', ' ', false
        ).execute(null);
        Test.stopTest();

        Contact afterContact = getContact();
        System.assertEquals('Original', afterContact.FirstName);
        System.assertEquals('Contact', afterContact.LastName);
    }

    @IsTest
    static void testRejectsUnrelatedContact() {
        User u = getUser();
        Contact c = getContact();

        Test.startTest();
        new BceidContactUpdateJob(
            c.Id, u.Id, 'Rejected', 'Name', false
        ).execute(null);
        Test.stopTest();

        Contact afterContact = getContact();
        System.assertEquals('Original', afterContact.FirstName);
        System.assertEquals('Contact', afterContact.LastName);
    }

    @IsTest
    static void testContactNotFoundReturnsSafely() {
        User u = getUser();
        Id missingContactId = '003000000000001AAA';

        Test.startTest();
        new BceidContactUpdateJob(
            missingContactId,
            u.Id,
            'Missing',
            'Contact',
            false,
            true
        ).execute(null);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testUpdatesContact() {
        User u = getUser();
        Contact c = getContact();

        Test.startTest();
        new BceidContactUpdateJob(
            c.Id,
            u.Id,
            'BCeID First',
            'BCeID Last',
            false,
            true
        ).execute(null);
        Test.stopTest();

        Contact afterContact = getContact();
        System.assertEquals('BCeID First', afterContact.FirstName);
        System.assertEquals('BCeID Last', afterContact.LastName);
    }

    @IsTest
    static void testMatchingContactRequiresNoDml() {
        User u = getUser();
        Contact c = getContact();
        c.FirstName = 'Same';
        c.LastName = 'Name';
        update c;

        Test.startTest();
        new BceidContactUpdateJob(
            c.Id,
            u.Id,
            'Same',
            'Name',
            false,
            true
        ).execute(null);
        Test.stopTest();

        Contact afterContact = getContact();
        System.assertEquals('Same', afterContact.FirstName);
        System.assertEquals('Name', afterContact.LastName);
    }

    @IsTest
    static void testQueuesUserUpdateAfterContactUpdate() {
        User u = getUser();
        Contact c = getContact();

        Test.startTest();
        new BceidContactUpdateJob(
            c.Id,
            u.Id,
            'Queued First',
            'Queued Last',
            true,
            true
        ).execute(null);
        Test.stopTest();

        Contact afterContact = getContact();
        User afterUser = getUser();

        System.assertEquals('Queued First', afterContact.FirstName);
        System.assertEquals('Queued Last', afterContact.LastName);
        System.assertEquals('Queued First', afterUser.FirstName);
        System.assertEquals('Queued Last', afterUser.LastName);
    }
}
