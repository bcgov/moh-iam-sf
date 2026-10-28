/*
 * Execute Anonymous - BCeID V10 getAccountDetail
 *
 * Named Credential BCeID_ws URL:
 * https://ws.test.bceid.ca/webservices/client/V10/BCeIDService.asmx
 *
 * SOAP namespace / SOAPAction are taken from the BCeID V10 WSDL.
 */

System.debug('======================================================');
System.debug('Starting BCeID getAccountDetail callout');
System.debug('======================================================');

BceidConfig cfg = BceidConfig.forNamedCredential(
    'BCeID_ws',
    'http://www.bceid.ca/webservices/Client/V10/',
    120000
);

System.assertEquals('callout:BCeID_ws', cfg.getResolvedEndpoint());
System.assertEquals(true, cfg.useNamedCredential);
System.assertEquals(
    'http://www.bceid.ca/webservices/Client/V10/',
    cfg.namespace
);

String onlineServiceId = '9E80-25B6-6297-428E';
String requesterAccountTypeCode = 'Business';
String requesterUserId = '';
String requesterUserGuid = '64510436D6CF4EE68B1DFE39111FFE74';
String userId = '';
String userGuid = '64510436D6CF4EE68B1DFE39111FFE74';
String accountTypeCode = 'Business';

System.debug('Resolved Endpoint: ' + cfg.getResolvedEndpoint());
System.debug('SOAP Namespace: ' + cfg.namespace);
System.debug(
    'Expected SOAPAction: ' +
    BceidSoapClient.buildSoapAction(
        cfg.namespace,
        'getAccountDetail'
    )
);

BceidSoapClient.SoapResult result =
    BceidServiceFacade.getAccountDetail(
        cfg,
        onlineServiceId,
        requesterAccountTypeCode,
        requesterUserId,
        requesterUserGuid,
        userId,
        userGuid,
        accountTypeCode
    );

System.debug('======================================================');
System.debug('BCeID SOAP Response');
System.debug('======================================================');
System.debug('HTTP Status: ' + result.httpStatus);
System.debug('Has SOAP Fault: ' + result.hasSoapFault);
System.debug('Fault Code: ' + result.faultCode);
System.debug('Fault String: ' + result.faultString);
System.debug('Raw Response: ' + result.rawResponse);

if (result.hasSoapFault) {
    System.debug(
        LoggingLevel.ERROR,
        'BCeID SOAP Fault: ' + result.faultString
    );
} else if (result.httpStatus >= 200 && result.httpStatus < 300) {
    System.debug(
        LoggingLevel.INFO,
        'BCeID getAccountDetail completed successfully.'
    );
} else {
    System.debug(
        LoggingLevel.ERROR,
        'BCeID returned HTTP status ' + result.httpStatus
    );
}

System.debug('======================================================');
System.debug('BCeID getAccountDetail callout completed');
System.debug('======================================================');
