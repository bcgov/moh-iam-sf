public with sharing class BceidLoginNameSyncLauncher {
    public class Request {
        @InvocableVariable(required=true label='User Id')
        public Id userId;

        @InvocableVariable(label='Online Service Id')
        public String onlineServiceId;

        @InvocableVariable(label='Requester Account Type Code')
        public String requesterAccountTypeCode;

        @InvocableVariable(label='Account Type Code')
        public String accountTypeCode;
    }

    public class Response {
        @InvocableVariable(label='Queued')
        public Boolean queued;

        @InvocableVariable(label='Job Id')
        public Id jobId;

        @InvocableVariable(label='Message')
        public String message;
    }

    @InvocableMethod(
        label='Queue BCeID Login Name Synchronization'
        description='Queues BCeID name synchronization in a separate transaction so login does not wait for the BCeID callout.'
    )
    public static List<Response> execute(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null) return responses;

        for (Request request : requests) {
            Response response = new Response();
            response.queued = false;

            if (request == null || request.userId == null) {
                response.message = 'BCeID synchronization was not queued because User Id is missing.';
                responses.add(response);
                continue;
            }

            String serviceId = String.isBlank(request.onlineServiceId)
                ? '9E80-25B6-6297-428E' : request.onlineServiceId;
            String requesterType = String.isBlank(request.requesterAccountTypeCode)
                ? 'Business' : request.requesterAccountTypeCode;
            String targetType = String.isBlank(request.accountTypeCode)
                ? 'Business' : request.accountTypeCode;

            try {
                response.jobId = System.enqueueJob(new BceidLoginNameSyncJob(
                    request.userId,
                    serviceId,
                    requesterType,
                    targetType
                ));
                response.queued = true;
                response.message = 'BCeID synchronization queued.';
            } catch (Exception e) {
                // Do not propagate queueing failures back to the Login Flow.
                response.message = 'BCeID synchronization was not queued: ' + e.getMessage();
            }
            responses.add(response);
        }
        return responses;
    }
}