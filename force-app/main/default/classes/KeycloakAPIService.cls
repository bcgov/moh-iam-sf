public inherited sharing abstract class KeycloakAPIService {

    public abstract String doCallout(
        String request,
        String requestType,
        String requestBody,
        Map<String, String> additionalHeaders
    );

    public static String sendRequest(String request, String requestType, String requestBody) {
        return sendRequest(request, requestType, requestBody, new Map<String, String>());
    }

    public static String sendRequest(String request, String requestType, String requestBody,
            Map<String, String> additionalHeaders) {
        String baseUrl = getBaseURL();
        if (String.isBlank(baseUrl)) {
            throw new CalloutException('Keycloak API endpoint configuration is missing for GATEWAY_PROFILE.');
        }
        return sendRequestToEndpoint(baseUrl + request, requestType, requestBody, additionalHeaders);
    }

    // This is the same HTTP implementation used by sendRequest. Separating URL
    // discovery permits deterministic callout tests without assuming a particular
    // Custom Metadata record exists in each target Salesforce org.
    @TestVisible
    private static String sendRequestToEndpoint(String url, String requestType,
            String requestBody, Map<String, String> additionalHeaders) {
        HttpResponse res;
        try {
            KeycloakAPIOAuth oAuth = new KeycloakAPIOAuth();
            String accessToken = Test.isRunningTest() ? 'testaccesstoken' : oAuth.getAccessToken();
            HttpRequest req = new HttpRequest();
            // Do not log access tokens, including in production debug logs.
            req.setEndpoint(url);
            req.setMethod(requestType);
            req.setHeader('Accept', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Content-Type', 'application/json');
            if (additionalHeaders != null) {
                for (String key : additionalHeaders.keySet()) {
                    req.setHeader(key, additionalHeaders.get(key));
                }
            }
            if (requestType != 'GET') {
                req.setBody(requestBody);
            }
            req.setTimeout(60000);
            res = new Http().send(req);
        } catch (Exception e) {
            throw new CalloutException(e.getMessage());
        }
        if (res.getStatusCode() != 200) {
            throw new CalloutException('Error from callout: ' + requestType + ' ' + res);
        }
        return res.getBody();
    }

    public static String getBaseURL() {
        List<IDP_User_Registration_API_Endpoint__mdt> filteredRecords = [
            SELECT Id, DeveloperName, QualifiedApiName, API_Group__c,
                   Endpoint_URL__c, Site_URL__c, Sequence__c
            FROM IDP_User_Registration_API_Endpoint__mdt
            WHERE API_Group__c = 'GATEWAY_PROFILE'
            ORDER BY Sequence__c ASC
        ];
        // In non-HTTP contexts (such as a Queueable), no current request URL exists.
        Url requestUrl = URL.getCurrentRequestUrl();
        return resolveBaseURL(filteredRecords, requestUrl == null ? null : requestUrl.getHost());
    }

    @TestVisible
    private static String resolveBaseURL(
            List<IDP_User_Registration_API_Endpoint__mdt> records, String currentHost) {
        if (records == null || records.isEmpty()) return null;
        String defaultUrl;
        for (IDP_User_Registration_API_Endpoint__mdt item : records) {
            if (String.isNotBlank(currentHost) &&
                    String.isNotBlank(item.Site_URL__c) &&
                    item.Site_URL__c.equalsIgnoreCase(currentHost)) {
                return item.Endpoint_URL__c;
            }
            if (item.DeveloperName == 'DEFAULT' || item.QualifiedApiName == 'DEFAULT') {
                if (defaultUrl == null) defaultUrl = item.Endpoint_URL__c;
            }
        }
        return defaultUrl;
    }
}
