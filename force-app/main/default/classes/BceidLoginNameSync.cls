public with sharing class BceidLoginNameSync {

    public class Request {

        @InvocableVariable(required=true label='User Id')
        public Id userId;

        @InvocableVariable(required=true label='Contact Id')
        public Id contactId;

        @InvocableVariable(required=true label='Online Service Id')
        public String onlineServiceId;

        @InvocableVariable(label='Requester Account Type Code')
        public String requesterAccountTypeCode;

        @InvocableVariable(label='Account Type Code')
        public String accountTypeCode;
    }

    public class Response {

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Skipped')
        public Boolean skipped;

        @InvocableVariable(label='HTTP Status')
        public Integer httpStatus;

        @InvocableVariable(label='BCeID Response Code')
        public String responseCode;

        @InvocableVariable(label='BCeID Failure Code')
        public String failureCode;

        @InvocableVariable(label='First Name')
        public String firstName;

        @InvocableVariable(label='Last Name')
        public String lastName;

        @InvocableVariable(label='Contact Updated')
        public Boolean contactUpdated;

        @InvocableVariable(label='User Update Queued')
        public Boolean userUpdateQueued;

        @InvocableVariable(label='User Update Job Id')
        public Id userUpdateJobId;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='BCeID Update User and Contact Name'
        description='Retrieves the BCeID GUID from the Contact, calls BCeID getAccountDetail, and synchronizes returned names. Missing Contact/GUID or errors are returned without throwing to Flow.'
        callout=true
    )
    public static List<Response> execute(List<Request> requests) {
        List<Response> responses = new List<Response>();

        if (requests == null) {
            return responses;
        }

        for (Request request : requests) {
            Response response = new Response();
            response.success = false;
            response.skipped = false;
            response.contactUpdated = false;
            response.userUpdateQueued = false;

            try {
                validateRequest(request);

                GuidLookupResult guidLookup = getBceidGuid(request.contactId);

                if (!guidLookup.contactFound) {
                    response.skipped = true;
                    response.errorMessage = 'BCeID name synchronization skipped: Contact was not found.';
                    responses.add(response);
                    continue;
                }

                if (!guidLookup.fieldAvailable) {
                    response.skipped = true;
                    response.errorMessage = 'BCeID name synchronization skipped: Contact BCeIDGUID__c is not available in this org.';
                    responses.add(response);
                    continue;
                }

                String bceidUserGuid = guidLookup.guid;

                if (String.isBlank(bceidUserGuid)) {
                    response.skipped = true;
                    response.errorMessage = 'BCeID name synchronization skipped: Contact BCeIDGUID__c is blank.';
                    responses.add(response);
                    continue;
                }

                String requesterAccountTypeCode =
                    String.isBlank(request.requesterAccountTypeCode)
                    ? 'Business'
                    : request.requesterAccountTypeCode;

                String accountTypeCode =
                    String.isBlank(request.accountTypeCode)
                    ? 'Business'
                    : request.accountTypeCode;

                BceidConfig cfg =
                    BceidConfig.forNamedCredential('BCeID_ws');

                BceidSoapClient.SoapResult result =
                    BceidServiceFacade.getAccountDetail(
                        cfg,
                        request.onlineServiceId,
                        requesterAccountTypeCode,
                        '',
                        bceidUserGuid,
                        '',
                        bceidUserGuid,
                        accountTypeCode
                    );

                response.httpStatus = result.httpStatus;
                response.responseCode = result.responseCode;
                response.failureCode = result.failureCode;
                response.firstName = result.firstName;
                response.lastName = result.lastName;

                BceidIdentityService.SyncResult syncResult =
                    BceidIdentityService.sync(
                        result,
                        request.userId,
                        request.contactId
                    );

                response.success = true;
                response.contactUpdated = syncResult.contactUpdated;
                response.userUpdateQueued = syncResult.userUpdateQueued;
                response.userUpdateJobId = syncResult.userUpdateJobId;

            } catch (Exception e) {
                // Login-safe boundary: never rethrow a BCeID synchronization error to Flow.
                response.success = false;
                response.errorMessage = e.getMessage();
            }

            responses.add(response);
        }

        return responses;
    }

    private class GuidLookupResult {
        Boolean contactFound = false;
        Boolean fieldAvailable = false;
        String guid;
    }

    private static GuidLookupResult getBceidGuid(Id contactId) {
        GuidLookupResult result = new GuidLookupResult();
        Map<String, Schema.SObjectField> contactFields =
            Schema.SObjectType.Contact.fields.getMap();

        String guidFieldName;
        for (String fieldName : contactFields.keySet()) {
            if ('BCeIDGUID__c'.equalsIgnoreCase(fieldName)) {
                guidFieldName = contactFields.get(fieldName).getDescribe().getName();
                break;
            }
        }

        result.fieldAvailable = guidFieldName != null;

        String queryText = 'SELECT Id';
        if (result.fieldAvailable) {
            queryText += ', ' + guidFieldName;
        }
        queryText += ' FROM Contact WHERE Id = :contactId LIMIT 1';

        List<SObject> contacts = Database.query(queryText);
        if (contacts.isEmpty()) {
            return result;
        }

        result.contactFound = true;
        if (result.fieldAvailable) {
            result.guid = (String) contacts[0].get(guidFieldName);
        }
        return result;
    }

    private static void validateRequest(Request request) {
        if (request == null) {
            throw new BceidIdentityService.BceidIdentityException(
                'Request cannot be null.'
            );
        }

        if (request.userId == null) {
            throw new BceidIdentityService.BceidIdentityException(
                'User Id is required.'
            );
        }

        if (request.contactId == null) {
            throw new BceidIdentityService.BceidIdentityException(
                'Contact Id is required.'
            );
        }

        if (String.isBlank(request.onlineServiceId)) {
            throw new BceidIdentityService.BceidIdentityException(
                'Online Service Id is required.'
            );
        }
    }
}
