public without sharing class BceidIdentityService {
    public class SyncResult {
        public Id userId;
        public Id contactId;
        public String firstName;
        public String lastName;
        public Id contactUpdateJobId;
        public Id userUpdateJobId;
        public Id accountUpdateJobId;
        public Boolean contactUpdated;
        public Boolean contactUpdateQueued;
        public Boolean userUpdateQueued;
        public Boolean accountUpdateQueued;
    }

    public static SyncResult syncCurrentUser(BceidSoapClient.SoapResult result) {
        validateSuccessfulResult(result);

        User currentUser = [
            SELECT Id, ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (currentUser.ContactId == null) {
            throw new BceidIdentityException(
                'The current user is not associated with a Contact through ContactId.'
            );
        }

        return sync(result, currentUser.Id, currentUser.ContactId);
    }

    public static SyncResult sync(
        BceidSoapClient.SoapResult result,
        Id userId,
        Id contactId
    ) {
        validateSuccessfulResult(result);
        if (userId == null) throw new BceidIdentityException('User Id is required.');
        if (contactId == null) throw new BceidIdentityException('Contact Id is required.');

        User currentUser = [
            SELECT Id, ContactId, FirstName, LastName, Email, MobilePhone
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];

        if (currentUser.ContactId != null && currentUser.ContactId != contactId) {
            throw new BceidIdentityException(
                'The specified Contact is not associated with the specified User.'
            );
        }

        Contact currentContact = [
            SELECT Id, AccountId, FirstName, LastName, Email, MobilePhone
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        BceidPersonData person = BceidPersonData.fromSoapResult(result);
        Contact contactCandidate = new Contact(
            Id = currentContact.Id,
            FirstName = currentContact.FirstName,
            LastName = currentContact.LastName,
            Email = currentContact.Email,
            MobilePhone = currentContact.MobilePhone
        );
        Boolean contactChanged = BceidContactMapper.apply(contactCandidate, person);

        User userCandidate = new User(
            Id = currentUser.Id,
            FirstName = currentUser.FirstName,
            LastName = currentUser.LastName,
            Email = currentUser.Email,
            MobilePhone = currentUser.MobilePhone
        );
        Boolean userChanged = BceidUserMapper.apply(userCandidate, person);

        BceidBusinessAccountMapper.BusinessData business =
            BceidBusinessAccountMapper.fromSoapResult(result);
        Boolean hasVerifiedBusinessPayload = business != null && String.isNotBlank(business.guid);
        if (!hasVerifiedBusinessPayload) business = null;

        Id contactJobId;
        Id userJobId;
        Id accountJobId;
        // ContactUpdateJob is the coordinator whenever Contact or Account DML is
        // required. It publishes User DML separately (mixed-DML safety) and chains
        // the Account update after validating User -> Contact -> Account.
        if (contactChanged || hasVerifiedBusinessPayload) {
            contactJobId = System.enqueueJob(
                new BceidContactUpdateJob(
                    contactId,
                    userId,
                    person.firstName,
                    person.lastName,
                    person.email,
                    person.mobile,
                    userChanged,
                    business
                )
            );
            if (hasVerifiedBusinessPayload) accountJobId = null; // chained by ContactUpdateJob
        } else if (userChanged) {
            // If Contact and Account don't need DML, update the User in its own
            // Queueable rather than requiring an unrelated Contact relationship
            // to succeed in the coordinator job.
            userJobId = System.enqueueJob(
                new BceidUserUpdateJob(
                    userId, person.firstName, person.lastName,
                    person.email, person.mobile
                )
            );
        }

        SyncResult syncResult = new SyncResult();
        syncResult.userId = userId;
        syncResult.contactId = contactId;
        syncResult.firstName = result.firstName;
        syncResult.lastName = result.lastName;
        syncResult.contactUpdateJobId = contactJobId;
        syncResult.userUpdateJobId = userJobId;
        syncResult.accountUpdateJobId = accountJobId;
        syncResult.contactUpdated = false;
        syncResult.contactUpdateQueued = contactChanged;
        syncResult.userUpdateQueued = userChanged;
        syncResult.accountUpdateQueued = hasVerifiedBusinessPayload;

        return syncResult;
    }

    /**
     * Resolve the BCeID user GUID without making Contact.BCeIDGUID__c mandatory.
     * The package may run in orgs where the optional custom field is absent;
     * ExternalId__c is populated by registration and is the supported fallback.
     */
    public static String resolveUserGuid(Id userId, Id contactId) {
        String resolved = readFirstIdentifier(
            Schema.SObjectType.Contact.fields.getMap(), contactId,
            new List<String>{ 'BCeIDGUID__c', 'ExternalId__c', 'BCeID_User_GUID__c' },
            'Contact'
        );
        if (String.isNotBlank(resolved)) return resolved;
        return readFirstIdentifier(
            Schema.SObjectType.User.fields.getMap(), userId,
            new List<String>{ 'BCeIDGUID__c', 'ExternalId__c', 'BCeID_User_GUID__c' },
            'User'
        );
    }

    private static String readFirstIdentifier(
        Map<String, Schema.SObjectField> fields, Id recordId,
        List<String> candidateFields, String objectName
    ) {
        if (recordId == null) return null;
        List<String> selected = new List<String>();
        for (String apiName : candidateFields) {
            if (fields.containsKey(apiName) && fields.get(apiName).getDescribe().isAccessible()) {
                selected.add(apiName);
            }
        }
        if (selected.isEmpty()) return null;
        try {
            SObject record = Database.query(
                'SELECT ' + String.join(selected, ',') + ' FROM ' + objectName +
                ' WHERE Id = :recordId LIMIT 1'
            );
            for (String apiName : selected) {
                Object value = record.get(apiName);
                if (value != null && String.isNotBlank(String.valueOf(value))) {
                    return String.valueOf(value);
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'Unable to resolve optional BCeID identifier from ' + objectName + '.');
        }
        return null;
    }

    private static void validateSuccessfulResult(BceidSoapClient.SoapResult result) {
        if (result == null) throw new BceidIdentityException('BCeID result cannot be null.');
        if (result.httpStatus == null || result.httpStatus < 200 || result.httpStatus >= 300) {
            throw new BceidIdentityException('BCeID callout did not return a successful HTTP status.');
        }
        if (result.hasSoapFault == true) {
            throw new BceidIdentityException('BCeID returned a SOAP fault: ' + result.faultString);
        }
        if (result.responseCode != 'Success') {
            throw new BceidIdentityException(
                'BCeID response was not successful. Code=' + result.responseCode +
                ', failureCode=' + result.failureCode
            );
        }
        Boolean hasPersonValues = String.isNotBlank(result.firstName) ||
            String.isNotBlank(result.lastName) || String.isNotBlank(result.contactEmail) ||
            String.isNotBlank(result.contactTelephone);
        Boolean hasBusinessValues = String.isNotBlank(result.businessGuid) ||
            String.isNotBlank(result.businessLegalName) || String.isNotBlank(result.businessNumber) ||
            String.isNotBlank(result.businessDoingBusinessAs) ||
            String.isNotBlank(result.businessAddressLine1) || String.isNotBlank(result.businessAddressLine2) ||
            String.isNotBlank(result.businessCity) || String.isNotBlank(result.businessPostal) ||
            String.isNotBlank(result.businessProvince) || String.isNotBlank(result.businessCountry);
        if (!hasPersonValues && !hasBusinessValues) {
            throw new BceidIdentityException(
                'BCeID response did not contain any authorized person or business fields.'
            );
        }
    }

    public class BceidIdentityException extends Exception {}
}