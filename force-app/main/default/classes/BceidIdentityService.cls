public without sharing class BceidIdentityService {
    public class SyncResult {
        public Id userId;
        public Id contactId;
        public String firstName;
        public String lastName;
        public Id contactUpdateJobId;
        public Id userUpdateJobId;
        public Boolean contactUpdated;
        public Boolean contactUpdateQueued;
        public Boolean userUpdateQueued;
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
            SELECT Id, ContactId, FirstName, LastName
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
            SELECT Id, FirstName, LastName
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        Boolean contactNameChanged =
            currentContact.FirstName != result.firstName ||
            currentContact.LastName != result.lastName;

        Boolean userNameChanged =
            currentUser.FirstName != result.firstName ||
            currentUser.LastName != result.lastName;

        Id contactJobId;
        Id userJobId;

        // The Contact update is deliberately moved out of the BCeID callout
        // transaction. If both records require changes, the Contact job chains
        // the User job after the Contact transaction completes.
        if (contactNameChanged) {
            contactJobId = System.enqueueJob(
                new BceidContactUpdateJob(
                    contactId,
                    userId,
                    result.firstName,
                    result.lastName,
                    userNameChanged
                )
            );
        } else if (userNameChanged) {
            userJobId = System.enqueueJob(
                new BceidUserUpdateJob(
                    userId,
                    result.firstName,
                    result.lastName
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

        // These fields describe work performed/queued by this invocation.
        syncResult.contactUpdated = false;
        syncResult.contactUpdateQueued = contactNameChanged;
        syncResult.userUpdateQueued = userNameChanged;

        return syncResult;
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
        if (String.isBlank(result.firstName) || String.isBlank(result.lastName)) {
            throw new BceidIdentityException('BCeID response did not contain both first and last name.');
        }
    }

    public class BceidIdentityException extends Exception {}
}