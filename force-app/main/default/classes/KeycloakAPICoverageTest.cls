@IsTest
private class KeycloakAPICoverageTest {
    private class ResponseMock implements HttpCalloutMock {
        private String expectedMethod;
        private String expectedBody;
        private String expectedHeader;
        private Integer status;
        private Boolean fail;

        ResponseMock(String method, String body, String header, Integer code, Boolean shouldFail) {
            expectedMethod = method;
            expectedBody = body;
            expectedHeader = header;
            status = code;
            fail = shouldFail;
        }

        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('https://example.test/api/accounts', req.getEndpoint());
            System.assertEquals(expectedMethod, req.getMethod());
            System.assertEquals('application/json', req.getHeader('Accept'));
            System.assertEquals('application/json', req.getHeader('Content-Type'));
            System.assertEquals('Bearer testaccesstoken', req.getHeader('Authorization'));
            if (expectedMethod == 'GET') {
                System.assert(String.isBlank(req.getBody()));
            } else {
                System.assertEquals(expectedBody, req.getBody());
            }
            // Apex HttpRequest exposes setTimeout(), but no getTimeout().
            // The service configures the timeout before invoking Http.send().
            if (expectedHeader != null) {
                System.assertEquals(expectedHeader, req.getHeader('X-Correlation-ID'));
            }
            if (fail) throw new CalloutException('Simulated network failure');
            HttpResponse res = new HttpResponse();
            res.setStatusCode(status);
            res.setStatus(status == 200 ? 'OK' : 'Service Unavailable');
            res.setBody('{"status":"ok"}');
            return res;
        }
    }

    private static IDP_User_Registration_API_Endpoint__mdt endpoint(
            String developerName, String site, String url) {
        return new IDP_User_Registration_API_Endpoint__mdt(
            DeveloperName = developerName,
            API_Group__c = 'GATEWAY_PROFILE',
            Site_URL__c = site,
            Endpoint_URL__c = url
        );
    }

    @IsTest
    static void testEndpointSelectionWithHostAndDefault() {
        List<IDP_User_Registration_API_Endpoint__mdt> records =
            new List<IDP_User_Registration_API_Endpoint__mdt>{
                endpoint('DEFAULT', null, 'https://default.example/api/'),
                endpoint('REGIONAL', 'phocs.example.test', 'https://regional.example/api/')
            };
        System.assertEquals('https://regional.example/api/',
            KeycloakAPIService.resolveBaseURL(records, 'phocs.example.test'));
        System.assertEquals('https://regional.example/api/',
            KeycloakAPIService.resolveBaseURL(records, 'PHOCS.EXAMPLE.TEST'));
        System.assertEquals('https://default.example/api/',
            KeycloakAPIService.resolveBaseURL(records, 'unlisted.example.test'));
        System.assertEquals('https://default.example/api/',
            KeycloakAPIService.resolveBaseURL(records, null));
        System.assertEquals(null, KeycloakAPIService.resolveBaseURL(null, null));
        System.assertEquals(null,
            KeycloakAPIService.resolveBaseURL(
                new List<IDP_User_Registration_API_Endpoint__mdt>(), null));
        System.assertEquals(null,
            KeycloakAPIService.resolveBaseURL(
                new List<IDP_User_Registration_API_Endpoint__mdt>{
                    endpoint('REGIONAL', 'phocs.example.test', 'https://regional.example/api/')
                }, 'unknown.example.test'));
    }

    @IsTest
    static void testGetSuccess() {
        Test.setMock(HttpCalloutMock.class,
            new ResponseMock('GET', null, null, 200, false));
        Test.startTest();
        System.assertEquals('{"status":"ok"}',
            KeycloakAPIService.sendRequestToEndpoint(
                'https://example.test/api/accounts', 'GET', '{"ignored":true}', null));
        Test.stopTest();
    }

    @IsTest
    static void testPostSuccessWithHeaders() {
        Test.setMock(HttpCalloutMock.class,
            new ResponseMock('POST', '{"id":"123"}', 'correlation-123', 200, false));
        Test.startTest();
        System.assertEquals('{"status":"ok"}',
            KeycloakAPIService.sendRequestToEndpoint(
                'https://example.test/api/accounts', 'POST', '{"id":"123"}',
                new Map<String, String>{ 'X-Correlation-ID' => 'correlation-123' }));
        Test.stopTest();
    }

    @IsTest
    static void testHttpErrorResponse() {
        Test.setMock(HttpCalloutMock.class,
            new ResponseMock('GET', null, null, 503, false));
        try {
            KeycloakAPIService.sendRequestToEndpoint(
                'https://example.test/api/accounts', 'GET', null,
                new Map<String, String>());
            System.assert(false, 'A non-200 status must fail.');
        } catch (CalloutException expected) {
            System.assert(expected.getMessage().contains('Error from callout'));
        }
    }

    @IsTest
    static void testNetworkError() {
        Test.setMock(HttpCalloutMock.class,
            new ResponseMock('POST', '{}', null, 200, true));
        try {
            KeycloakAPIService.sendRequestToEndpoint(
                'https://example.test/api/accounts', 'POST', '{}', null);
            System.assert(false, 'A transport failure must propagate.');
        } catch (CalloutException expected) {
            System.assert(expected.getMessage().contains('Simulated network failure'));
        }
    }

    @IsTest
    static void testPublicEndpointLookup() {
        // Exercises the SOQL/discovery entry point regardless of whether the
        // target org has matching Custom Metadata installed.
        String endpoint = KeycloakAPIService.getBaseURL();
        System.assert(endpoint == null || endpoint.length() > 0);
    }
}
