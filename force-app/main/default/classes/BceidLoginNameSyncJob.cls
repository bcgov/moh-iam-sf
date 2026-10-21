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
        String bceidUserGuid = BceidIdentityService.resolveUserGuid(userId, contactId);
        if (String.isBlank(bceidUserGuid)) {
            System.debug(LoggingLevel.WARN,
                'BCeID synchronization skipped: no readable GUID on Contact or User.');
            return;
        }
        if (String.isBlank(onlineServiceId)) {
            onlineServiceId = System.Label.BCeID_Online_Service_Id;
        }
        if (String.isBlank(onlineServiceId)) {
            System.debug(LoggingLevel.ERROR,
                'BCeID synchronization skipped: Custom Label BCeID_Online_Service_Id is blank.');
            return;
        }
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
                'BCeID asynchronous record synchronization failed for User ' + userId +
                ': ' + e.getMessage());
        }
    }
}