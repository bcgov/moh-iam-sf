/**
 * @description       : 
 * @author            : Roy Poystila
 * @group             : 
 * @last modified on  : 09-28-2026
 * @last modified by  : Roy Poystila
**/
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
        String bceidUserGuid = getContactBceidIdentifier(contactId);
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
            System.debug(
                LoggingLevel.ERROR,
                'BCeID asynchronous name synchronization failed for User ' +
                userId + ': ' + e.getMessage()
            );
        }
    }

    /*
     * BCeIDGUID__c and ExternalId__c are optional across target orgs.
     * Do not statically reference either field so unlocked-package compilation
     * does not require them to exist.
     */
    private static String getContactBceidIdentifier(Id contactId) {
        if (contactId == null) return null;

        Map<String, Schema.SObjectField> contactFields =
            Schema.SObjectType.Contact.fields.getMap();

        String identifier = queryOptionalContactField(
            contactId,
            contactFields,
            'bceidguid__c'
        );

        if (String.isBlank(identifier)) {
            identifier = queryOptionalContactField(
                contactId,
                contactFields,
                'externalid__c'
            );
        }

        return identifier;
    }

    private static String queryOptionalContactField(
        Id contactId,
        Map<String, Schema.SObjectField> contactFields,
        String fieldKey
    ) {
        if (contactFields == null || !contactFields.containsKey(fieldKey)) {
            return null;
        }

        String fieldName =
            contactFields.get(fieldKey).getDescribe().getName();

        try {
            List<SObject> contacts = Database.query(
                'SELECT Id, ' + fieldName +
                ' FROM Contact WHERE Id = :contactId LIMIT 1'
            );

            if (contacts.isEmpty()) return null;

            Object value = contacts[0].get(fieldName);
            return value == null ? null : String.valueOf(value);
        } catch (QueryException e) {
            System.debug(
                LoggingLevel.WARN,
                'Optional Contact field ' + fieldName +
                ' is not queryable in this org/package context: ' +
                e.getMessage()
            );
            return null;
        }
    }
}
