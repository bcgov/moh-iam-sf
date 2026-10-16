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
        Map<String, Schema.SObjectField> contactFields =
            Schema.SObjectType.Contact.fields.getMap();
        Schema.SObjectField guidField = contactFields.get('BCeIDGUID__c');
        if (guidField == null || !guidField.getDescribe().isAccessible()) {
            System.debug(LoggingLevel.WARN,
                'BCeID name sync skipped: optional Contact.BCeIDGUID__c is unavailable or unreadable.');
            return;
        }

        String bceidUserGuid;
        try {
            String guidQuery =
                'SELECT Id, BCeIDGUID__c FROM Contact WHERE Id = :contactId LIMIT 1';
            SObject sourceContact = Database.query(guidQuery);
            Object guidValue = sourceContact.get('BCeIDGUID__c');
            bceidUserGuid = guidValue == null ? null : String.valueOf(guidValue);
        } catch (QueryException e) {
            System.debug(LoggingLevel.WARN,
                'BCeID name sync skipped: optional Contact GUID could not be queried. ' + e.getMessage());
            return;
        }
        if (String.isBlank(bceidUserGuid)) return;
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