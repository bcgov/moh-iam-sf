@IsTest
private class BceidSoapClientTest {
    private static List<HTTPRequest> requests = new List<HTTPRequest>();
    private static List<String> responseBodies = new List<String>();
    private static Integer statusCode = 200;
    private static String responseContentType = 'text/xml; charset=UTF-8';

    private static void resetMockState() {
        requests.clear();
        responseBodies.clear();
        statusCode = 200;
        responseContentType = 'text/xml; charset=UTF-8';
    }

    private class MockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            BceidSoapClientTest.requests.add(req);

            HttpResponse res = new HttpResponse();
            res.setStatusCode(BceidSoapClientTest.statusCode);
            res.setHeader(
                'Content-Type',
                BceidSoapClientTest.responseContentType
            );
            res.setBody(
                BceidSoapClientTest.responseBodies.isEmpty()
                ? '<soapenv:Envelope xmlns:soapenv="' +
                  'http://schemas.xmlsoap.org/soap/envelope/">' +
                  '<soapenv:Body><ok/></soapenv:Body></soapenv:Envelope>'
                : BceidSoapClientTest.responseBodies.remove(0)
            );
            return res;
        }
    }

    @IsTest
    static void testEscapeAndQualifiedXmlHelpers() {
        System.assertEquals(
            'A&amp;B&lt;C&gt;&quot;&apos;',
            BceidSoapClient.escapeXml('A&B<C>"\'')
        );

        System.assertEquals(
            '<v10:tag>value</v10:tag>',
            BceidSoapClient.xml('tag', 'value')
        );
        System.assertEquals('', BceidSoapClient.xml('tag', null));

        System.assertEquals(
            '<v10:tag></v10:tag>',
            BceidSoapClient.xmlEmptyAllowed('tag', null)
        );

        System.assertEquals(
            '<v10:n>42</v10:n>',
            BceidSoapClient.xmlInt('n', 42)
        );
        System.assertEquals('', BceidSoapClient.xmlInt('n', null));

        System.assertEquals(
            '<v10:flag>true</v10:flag>',
            BceidSoapClient.xmlBool('flag', true)
        );

        System.assertEquals(
            '<v10:test>',
            BceidSoapClient.openTag('test')
        );
        System.assertEquals(
            '</v10:test>',
            BceidSoapClient.closeTag('test')
        );
    }

    @IsTest
    static void testBuildSoapAction() {
        System.assertEquals(
            '"http://www.bceid.ca/webservices/Client/V10/getAccountDetail"',
            BceidSoapClient.buildSoapAction(
                'http://www.bceid.ca/webservices/Client/V10/',
                'getAccountDetail'
            )
        );

        System.assertEquals(
            '"http://example.test/ns/getAccountDetail"',
            BceidSoapClient.buildSoapAction(
                'http://example.test/ns',
                'getAccountDetail'
            )
        );
    }

    @IsTest
    static void testInvokeSuccessBuildsQualifiedEnvelopeAndHeaders() {
        resetMockState();
        responseBodies.add(
            '<soapenv:Envelope xmlns:soapenv="' +
            'http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body><getAccountDetailResponse/>' +
            '</soapenv:Body></soapenv:Envelope>'
        );
        Test.setMock(HttpCalloutMock.class, new MockResponse());

        BceidConfig cfg = new BceidConfig(
            'https://example.com/bceid',
            'alice',
            'secret',
            'http://www.bceid.ca/webservices/Client/V10/',
            30000
        );

        String payload =
            BceidSoapClient.openTag('accountDetailRequest') +
            BceidSoapClient.xml('userId', 'abc') +
            BceidSoapClient.closeTag('accountDetailRequest');

        BceidSoapClient.SoapResult result =
            BceidSoapClient.invoke(
                cfg,
                'getAccountDetail',
                payload
            );

        System.assertEquals(200, result.httpStatus);
        System.assertEquals(false, result.hasSoapFault);
        System.assertEquals(1, requests.size());

        HttpRequest req = requests[0];
        System.assertEquals(
            'https://example.com/bceid',
            req.getEndpoint()
        );
        System.assertEquals('POST', req.getMethod());
        System.assertEquals(
            'text/xml; charset=UTF-8',
            req.getHeader('Content-Type')
        );
        System.assertEquals(
            '"http://www.bceid.ca/webservices/Client/V10/getAccountDetail"',
            req.getHeader('SOAPAction')
        );
        System.assert(req.getHeader('Authorization').startsWith('Basic '));

        String body = req.getBody();
        System.assert(body.contains('<soapenv:Header/>'));
        System.assert(body.contains('<v10:getAccountDetail>'));
        System.assert(
            body.contains(
                '<v10:accountDetailRequest>' +
                '<v10:userId>abc</v10:userId>' +
                '</v10:accountDetailRequest>'
            )
        );
        System.assert(
            body.contains(
                'xmlns:v10="http://www.bceid.ca/webservices/Client/V10/"'
            )
        );
    }

    @IsTest
    static void testInvokeParsesGetAccountDetailNames() {
        resetMockState();
        responseBodies.add(
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<getAccountDetailResponse xmlns="http://www.bceid.ca/webservices/Client/V10/">' +
            '<getAccountDetailResult>' +
            '<code>Success</code><failureCode>Void</failureCode><message />' +
            '<account><individualIdentity><name>' +
            '<firstname isAllowed="true"><value>Deepak</value></firstname>' +
            '<surname isAllowed="true"><value>Test Operator 1</value></surname>' +
            '</name></individualIdentity></account>' +
            '</getAccountDetailResult></getAccountDetailResponse>' +
            '</soap:Body></soap:Envelope>'
        );
        Test.setMock(HttpCalloutMock.class, new MockResponse());

        BceidConfig cfg = BceidConfig.forNamedCredential('BCeID_NC');
        BceidSoapClient.SoapResult result = BceidSoapClient.invoke(
            cfg, 'getAccountDetail', '<v10:accountDetailRequest/>'
        );

        System.assertEquals(200, result.httpStatus);
        System.assertEquals('Success', result.responseCode);
        System.assertEquals('Void', result.failureCode);
        System.assertEquals('Deepak', result.firstName);
        System.assertEquals('Test Operator 1', result.lastName);
    }

    @IsTest
    static void testInvokeWithNamedCredentialSkipsAuthorizationHeader() {
        resetMockState();
        Test.setMock(HttpCalloutMock.class, new MockResponse());

        BceidConfig cfg = BceidConfig.forNamedCredential(
            'BCeID_NC',
            'http://www.bceid.ca/webservices/Client/V10/',
            30000
        );

        String payload =
            BceidSoapClient.openTag('subscriptionCodeListRequest') +
            BceidSoapClient.xml('userGuid', 'abc') +
            BceidSoapClient.closeTag('subscriptionCodeListRequest');

        BceidSoapClient.SoapResult result =
            BceidSoapClient.invoke(
                cfg,
                'getSubscriptionCodeList',
                payload
            );

        System.assertEquals(200, result.httpStatus);
        System.assertEquals(1, requests.size());

        HttpRequest req = requests[0];
        System.assertEquals('callout:BCeID_NC', req.getEndpoint());
        System.assertEquals(null, req.getHeader('Authorization'));
        System.assertEquals(
            '"http://www.bceid.ca/webservices/Client/V10/' +
            'getSubscriptionCodeList"',
            req.getHeader('SOAPAction')
        );
    }

    @IsTest
    static void testInvokeParsesSoapFault() {
        resetMockState();
        responseBodies.add(
            '<soapenv:Envelope xmlns:soapenv="' +
            'http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body>' +
            '<soapenv:Fault>' +
            '<faultcode>soapenv:Client</faultcode>' +
            '<faultstring>Invalid request</faultstring>' +
            '</soapenv:Fault>' +
            '</soapenv:Body>' +
            '</soapenv:Envelope>'
        );
        statusCode = 500;
        Test.setMock(HttpCalloutMock.class, new MockResponse());

        BceidConfig cfg = new BceidConfig(
            'https://example.com/bceid',
            'alice',
            'secret'
        );

        BceidSoapClient.SoapResult result =
            BceidSoapClient.invoke(
                cfg,
                'getSubscriptionCodeList',
                '<v10:subscriptionCodeListRequest/>'
            );

        System.assertEquals(500, result.httpStatus);
        System.assertEquals(true, result.hasSoapFault);
        System.assertEquals('soapenv:Client', result.faultCode);
        System.assertEquals('Invalid request', result.faultString);
    }

    @IsTest
    static void testInvokeRetainsNonXmlErrorResponse() {
        resetMockState();
        statusCode = 500;
        responseContentType = 'text/html; charset=iso-8859-1';
        responseBodies.add(
            '<!DOCTYPE HTML><html><body>' +
            'Internal Server Error</body></html>'
        );
        Test.setMock(HttpCalloutMock.class, new MockResponse());

        BceidConfig cfg = BceidConfig.forNamedCredential('BCeID_NC');

        BceidSoapClient.SoapResult result =
            BceidSoapClient.invoke(
                cfg,
                'getAccountDetail',
                '<v10:accountDetailRequest/>'
            );

        System.assertEquals(500, result.httpStatus);
        System.assertEquals(false, result.hasSoapFault);
        System.assert(
            result.rawResponse.contains('Internal Server Error')
        );
    }
}