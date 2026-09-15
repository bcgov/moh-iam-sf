@IsTest
private class BceidServiceFacadeTest {
    private static List<HTTPRequest> requests =
        new List<HTTPRequest>();
    private static List<String> responseBodies =
        new List<String>();

    private class MockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            requests.add(req);

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader(
                'Content-Type',
                'text/xml; charset=UTF-8'
            );
            res.setBody(
                responseBodies.isEmpty()
                ? '<soapenv:Envelope xmlns:soapenv="' +
                  'http://schemas.xmlsoap.org/soap/envelope/">' +
                  '<soapenv:Body><ok/></soapenv:Body>' +
                  '</soapenv:Envelope>'
                : responseBodies.remove(0)
            );
            return res;
        }
    }

    private static void resetMockState() {
        requests.clear();
        responseBodies.clear();
    }

    private static BceidConfig cfg() {
        return BceidConfig.forNamedCredential(
            'BCeID_NC',
            'http://www.bceid.ca/webservices/Client/V10/',
            30000
        );
    }

    @IsTest
    static void testGetAccountDetailMatchesSoapUiAndWsdlStructure() {
        resetMockState();
        Test.setMock(HttpCalloutMock.class, new MockResponse());

        BceidSoapClient.SoapResult result =
            BceidServiceFacade.getAccountDetail(
                cfg(),
                'os1',
                'Business',
                '',
                'REQUESTER-GUID',
                '',
                'TARGET-GUID',
                'Business'
            );

        System.assertEquals(false, result.hasSoapFault);
        System.assertEquals(1, requests.size());

        HttpRequest req = requests[0];
        String body = req.getBody();

        System.assertEquals(
            '"http://www.bceid.ca/webservices/Client/V10/' +
            'getAccountDetail"',
            req.getHeader('SOAPAction')
        );

        System.assert(
            body.contains('<v10:getAccountDetail>')
        );
        System.assert(
            body.contains('<v10:accountDetailRequest>')
        );
        System.assert(
            body.contains(
                '<v10:onlineServiceId>os1</v10:onlineServiceId>'
            )
        );
        System.assert(
            body.contains(
                '<v10:requesterAccountTypeCode>Business' +
                '</v10:requesterAccountTypeCode>'
            )
        );
        System.assert(
            body.contains(
                '<v10:requesterUserId></v10:requesterUserId>'
            )
        );
        System.assert(
            body.contains(
                '<v10:requesterUserGuid>REQUESTER-GUID' +
                '</v10:requesterUserGuid>'
            )
        );
        System.assert(
            body.contains('<v10:userId></v10:userId>')
        );
        System.assert(
            body.contains(
                '<v10:userGuid>TARGET-GUID</v10:userGuid>'
            )
        );
        System.assert(
            body.contains(
                '<v10:accountTypeCode>Business' +
                '</v10:accountTypeCode>'
            )
        );

        System.assert(
            body.indexOf('<v10:requesterUserId>') <
            body.indexOf('<v10:requesterUserGuid>')
        );
        System.assert(
            body.indexOf('<v10:userId>') <
            body.indexOf('<v10:userGuid>')
        );
    }

    @IsTest
    static void testCompatibilityGetAccountDetailOverload() {
        resetMockState();
        Test.setMock(HttpCalloutMock.class, new MockResponse());

        BceidServiceFacade.getAccountDetail(
            cfg(),
            'os1',
            'Business',
            'REQUESTER-GUID',
            'TARGET-GUID',
            '',
            'Business'
        );

        String body = requests[0].getBody();

        System.assert(
            body.contains(
                '<v10:requesterUserId></v10:requesterUserId>'
            )
        );
        System.assert(
            body.contains(
                '<v10:userGuid>TARGET-GUID</v10:userGuid>'
            )
        );
    }

    @IsTest
    static void testOtherFacadeMethodsInvokeExpectedOperations() {
        resetMockState();
        Test.setMock(HttpCalloutMock.class, new MockResponse());

        BceidSoapClient.SoapResult r1 =
            BceidServiceFacade.getSubscriptionCodeList(
                cfg(),
                'os1',
                'UG1'
            );

        BceidSoapClient.SoapResult r2 =
            BceidServiceFacade.searchInternalAccount(
                cfg(),
                'os1',
                'Internal',
                'UG1',
                'Ascending',
                'UserId',
                50,
                1,
                'cservant',
                'StartsWith'
            );

        BceidRequestBuilders.AccountDetailItem item =
            new BceidRequestBuilders.AccountDetailItem();
        item.userGuid = 'UG3';
        item.accountTypeCode = 'Business';
        item.clientKey = 'k1';

        BceidSoapClient.SoapResult r3 =
            BceidServiceFacade.getAccountDetailList(
                cfg(),
                'os1',
                'Business',
                'UG1',
                new List<BceidRequestBuilders.AccountDetailItem>{
                    item
                }
            );

        BceidRequestBuilders.GroupMatch gm =
            new BceidRequestBuilders.GroupMatch();
        gm.groupName = 'MY_GROUP';

        BceidSoapClient.SoapResult r4 =
            BceidServiceFacade.getInternalUserGroupInfo(
                cfg(),
                'os1',
                'Internal',
                'UG1',
                'UG2',
                new List<BceidRequestBuilders.GroupMatch>{ gm }
            );

        BceidRequestBuilders.SubscriptionItem s =
            new BceidRequestBuilders.SubscriptionItem();
        s.osKey = 'os1';
        s.codeType = 'Regular';
        s.scope = 'Individual';
        s.question = 'Q';
        s.answer = 'A';
        s.accountTypeCode = 'Business';
        s.initialActivationPeriod = 90;

        BceidSoapClient.SoapResult r5 =
            BceidServiceFacade.createSubscriptionBatch(
                cfg(),
                'os1',
                'Business',
                'UG1',
                'Batch 1',
                'Regular',
                new List<BceidRequestBuilders.SubscriptionItem>{ s }
            );

        BceidSoapClient.SoapResult r6 =
            BceidServiceFacade.searchBceIDAccount(
                cfg(),
                'os1',
                'Business',
                'UG1',
                'Ascending',
                'UserId',
                500,
                1,
                'Business',
                'abc',
                'StartsWith',
                'Smith',
                'Exact'
            );

        System.assertEquals(false, r1.hasSoapFault);
        System.assertEquals(false, r2.hasSoapFault);
        System.assertEquals(false, r3.hasSoapFault);
        System.assertEquals(false, r4.hasSoapFault);
        System.assertEquals(false, r5.hasSoapFault);
        System.assertEquals(false, r6.hasSoapFault);
        System.assertEquals(6, requests.size());

        List<String> bodies = new List<String>();
        for (HTTPRequest req : requests) {
            bodies.add(req.getBody());
            System.assertEquals(
                'callout:BCeID_NC',
                req.getEndpoint()
            );
        }

        System.assert(
            bodies[0].contains('<v10:getSubscriptionCodeList>')
        );
        System.assert(
            bodies[1].contains('<v10:searchInternalAccount>')
        );
        System.assert(
            bodies[2].contains('<v10:getAccountDetailList>')
        );
        System.assert(
            bodies[3].contains('<v10:getInternalUserGroupInfo>')
        );
        System.assert(
            bodies[4].contains('<v10:createSubscriptionBatch>')
        );
        System.assert(
            bodies[5].contains('<v10:searchBCeIDAccount>')
        );
    }
}