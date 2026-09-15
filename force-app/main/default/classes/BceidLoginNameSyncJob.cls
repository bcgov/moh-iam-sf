public without sharing class BceidLoginNameSyncJob implements Queueable, Database.AllowsCallouts {
    private Id userId;
    private String onlineServiceId;
    private String requesterAccountTypeCode;
    private String accountTypeCode;

    public BceidLoginNameSyncJob(
        Id userId,
        String onlineServiceId,
        String requesterAccountTypeCode,
        String accountTypeCode
    ) {
        this.userId = userId;
        this.onlineServiceId = onlineServiceId;
        this.requesterAccountTypeCode = requesterAccountTypeCode;
        this.accountTypeCode = accountTypeCode;
    }

    public void execute(QueueableContext context) {
        if (userId == null) return;

        List<User> users = [
            SELECT Id, ContactId
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];
        if (users.isEmpty() || users[0].ContactId == null) return;

        Id contactId = users[0].ContactId;
        List<Contact> contacts = [
            SELECT Id, BCeIDGUID__c
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
        if (contacts.isEmpty() || String.isBlank(contacts[0].BCeIDGUID__c)) return;

        String bceidUserGuid = contacts[0].BCeIDGUID__c;
        String requesterType = String.isBlank(requesterAccountTypeCode)
            ? 'Business' : requesterAccountTypeCode;
        String targetType = String.isBlank(accountTypeCode)
            ? 'Business' : accountTypeCode;

        try {
            BceidConfig cfg = BceidConfig.forNamedCredential('BCeID_ws');
            BceidSoapClient.SoapResult result = BceidServiceFacade.getAccountDetail(
                cfg,
                onlineServiceId,
                requesterType,
                '',
                bceidUserGuid,
                '',
                bceidUserGuid,
                targetType
            );
            BceidIdentityService.sync(result, userId, contactId);
        } catch (Exception e) {
            // Login-safe asynchronous boundary. A synchronization failure must not affect login.
            System.debug(LoggingLevel.ERROR,
                'BCeID asynchronous name synchronization failed for User ' + userId +
                ': ' + e.getMessage());
        }
    }
}