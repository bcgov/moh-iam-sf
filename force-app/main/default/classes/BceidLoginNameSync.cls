public with sharing class BceidLoginNameSync {

    public class Request {

        @InvocableVariable(label='BCeID User GUID (optional; defaults from Contact)')
        public String bceidUserGuid;

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
        description='Calls BCeID getAccountDetail and synchronizes the returned first and last name to the specified Salesforce User and Contact. Only changed values are updated.'
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

                String requesterAccountTypeCode =
                    String.isBlank(request.requesterAccountTypeCode)
                    ? 'Business'
                    : request.requesterAccountTypeCode;

                String accountTypeCode =
                    String.isBlank(request.accountTypeCode)
                    ? 'Business'
                    : request.accountTypeCode;

                String effectiveGuid = request.bceidUserGuid;
                if (String.isBlank(effectiveGuid)) {
                    Map<String, Schema.SObjectField> contactFields =
                        Schema.SObjectType.Contact.fields.getMap();
                    Schema.SObjectField guidField = contactFields.get('BCeIDGUID__c');

                    // Contact.BCeIDGUID__c is org-specific and optional.
                    // If it is absent/unreadable, the caller must provide the GUID.
                    if (guidField != null && guidField.getDescribe().isAccessible()) {
                        Id contactId = request.contactId;
                        String guidQuery =
                            'SELECT Id, BCeIDGUID__c FROM Contact WHERE Id = :contactId LIMIT 1';
                        SObject sourceContact = Database.query(guidQuery);
                        Object guidValue = sourceContact.get('BCeIDGUID__c');
                        effectiveGuid = guidValue == null ? null : String.valueOf(guidValue);
                    }
                }
                if (String.isBlank(effectiveGuid)) {
                    response.skipped = true;
                    response.errorMessage =
                        'Synchronization skipped: BCeID User GUID was not supplied, and the optional Contact.BCeIDGUID__c field is unavailable, unreadable, or blank.';
                    responses.add(response);
                    continue;
                }

                BceidConfig cfg =
                    BceidConfig.forNamedCredential('BCeID_ws');

                BceidSoapClient.SoapResult result =
                    BceidServiceFacade.getAccountDetail(
                        cfg,
                        request.onlineServiceId,
                        requesterAccountTypeCode,
                        '',
                        effectiveGuid,
                        '',
                        effectiveGuid,
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
                response.success = false;
                response.errorMessage = e.getMessage();
            }

            responses.add(response);
        }

        return responses;
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
