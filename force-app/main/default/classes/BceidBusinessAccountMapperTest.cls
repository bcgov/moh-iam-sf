@IsTest
private class BceidBusinessAccountMapperTest {
    private static final String NS = 'http://www.bceid.ca/webservices/Client/V10/';

    @IsTest
    static void testParseAllowedBusinessFieldsFromSoap() {
        BceidSoapClient.SoapResult result = new BceidSoapClient.SoapResult();
        result.rawResponse =
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body><getAccountDetailResponse xmlns="' + NS + '">' +
            '<getAccountDetailResult><code>Success</code><failureCode>Void</failureCode>' +
            '<account><individualIdentity><name>' +
            '<firstname isAllowed="true"><value>Deepak</value></firstname>' +
            '<surname isAllowed="true"><value>Test Operator 1</value></surname>' +
            '</name></individualIdentity><business>' +
            '<guid isAllowed="true"><value>BUSINESS-GUID</value></guid>' +
            '<legalName isAllowed="true"><value>Accenture Test BCeID</value></legalName>' +
            '<businessNumber isAllowed="true"><value /></businessNumber>' +
            '<doingBusinessAs isAllowed="true"><value>PHOCS Accenture</value></doingBusinessAs>' +
            '<incorporationNumber isAllowed="false"><value>DO_NOT_COPY</value></incorporationNumber>' +
            '<address>' +
            '<addressLine1 isAllowed="true"><value>601 West Broadway</value></addressLine1>' +
            '<addressLine2 isAllowed="true"><value /></addressLine2>' +
            '<city isAllowed="true"><value>Vancouer</value></city>' +
            '<postal isAllowed="true"><value>V5Z 4C2</value></postal>' +
            '<province isAllowed="true"><value>BC</value></province>' +
            '<country isAllowed="true"><value>CA</value></country>' +
            '</address></business></account></getAccountDetailResult>' +
            '</getAccountDetailResponse></soap:Body></soap:Envelope>';

        BceidSoapClient.parseGetAccountDetailResponse(result, NS);
        System.assertEquals('Success', result.responseCode);
        System.assertEquals('Deepak', result.firstName);
        System.assertEquals('Test Operator 1', result.lastName);
        System.assertEquals('BUSINESS-GUID', result.businessGuid);
        System.assertEquals('Accenture Test BCeID', result.businessLegalName);
        System.assertEquals(null, result.businessNumber, 'Empty values are ignored');
        System.assertEquals('PHOCS Accenture', result.businessDoingBusinessAs);
        System.assertEquals('601 West Broadway', result.businessAddressLine1);
        System.assertEquals('Vancouer', result.businessCity);
        System.assertEquals('V5Z 4C2', result.businessPostal);
        System.assertEquals('BC', result.businessProvince);
        System.assertEquals('CA', result.businessCountry);
        System.assertEquals(null, result.businessAddressLine2);

        BceidBusinessAccountMapper.BusinessData business =
            BceidBusinessAccountMapper.fromSoapResult(result);
        Account accountRecord = new Account(Name = 'Previous name');
        System.assert(BceidBusinessAccountMapper.apply(accountRecord, business));
        System.assertEquals('Accenture Test BCeID', accountRecord.Name);
        System.assertEquals('601 West Broadway', accountRecord.BillingStreet);
        System.assertEquals('601 West Broadway', accountRecord.ShippingStreet);
        System.assertEquals('Vancouer', accountRecord.BillingCity);
        System.assertEquals('Vancouer', accountRecord.ShippingCity);
        System.assertEquals('V5Z 4C2', accountRecord.BillingPostalCode);
        System.assertEquals('V5Z 4C2', accountRecord.ShippingPostalCode);
        System.assertEquals(false, BceidBusinessAccountMapper.apply(accountRecord, business),
            'Re-applying identical values should result in no DML');
    }

    @IsTest
    static void testFalseIsAllowedSkipsAddressAndBusinessFields() {
        BceidSoapClient.SoapResult result = new BceidSoapClient.SoapResult();
        result.rawResponse =
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body><getAccountDetailResponse xmlns="' + NS + '">' +
            '<getAccountDetailResult><code>Success</code>' +
            '<account><business>' +
            '<guid isAllowed="true"><value>BUSINESS-GUID</value></guid>' +
            '<legalName isAllowed="false"><value>Forbidden name</value></legalName>' +
            '<address><city isAllowed="false"><value>Private city</value></city>' +
            '<postal isAllowed="true"><value /></postal></address>' +
            '</business></account></getAccountDetailResult></getAccountDetailResponse>' +
            '</soap:Body></soap:Envelope>';
        BceidSoapClient.parseGetAccountDetailResponse(result, NS);
        System.assertEquals(null, result.businessLegalName);
        System.assertEquals(null, result.businessCity);
        System.assertEquals(null, result.businessPostal);
        BceidBusinessAccountMapper.BusinessData data =
            BceidBusinessAccountMapper.fromSoapResult(result);
        Account accountRecord = new Account(Name='Existing', BillingCity='Keep this');
        BceidBusinessAccountMapper.apply(accountRecord, data);
        System.assertEquals('Existing', accountRecord.Name);
        System.assertEquals('Keep this', accountRecord.BillingCity);
    }

    @IsTest
    static void testAuthorizedTelephoneMapsToAccountPhone() {
        BceidSoapClient.SoapResult result = new BceidSoapClient.SoapResult();
        result.rawResponse =
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body><getAccountDetailResponse xmlns="' + NS + '">' +
            '<getAccountDetailResult><code>Success</code><account>' +
            '<contact><telephone isAllowed="true"><value>250-555-0134</value></telephone></contact>' +
            '<business><guid isAllowed="true"><value>BUSINESS-GUID</value></guid></business>' +
            '</account></getAccountDetailResult></getAccountDetailResponse>' +
            '</soap:Body></soap:Envelope>';

        BceidSoapClient.parseGetAccountDetailResponse(result, NS);
        System.assertEquals('250-555-0134', result.businessContactTelephone);
        BceidBusinessAccountMapper.BusinessData business =
            BceidBusinessAccountMapper.fromSoapResult(result);
        System.assertEquals('250-555-0134', business.phone);

        Account existing = new Account(Name = 'Business', Phone = '2505559999');
        System.assertEquals(true, BceidBusinessAccountMapper.apply(existing, business));
        System.assertEquals('2505550134', existing.Phone);
        System.assertEquals(false, BceidBusinessAccountMapper.apply(existing, business),
            'Identical BCeID phone values must not trigger an update');
    }

    @IsTest
    static void testUnauthorizedOrBlankTelephonePreservesExistingPhone() {
        for (String phoneProperty : new List<String>{
            '<telephone isAllowed="false"><value>250-555-0000</value></telephone>',
            '<telephone isAllowed="true"><value /></telephone>'
        }) {
            BceidSoapClient.SoapResult result = new BceidSoapClient.SoapResult();
            result.rawResponse =
                '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soap:Body><getAccountDetailResponse xmlns="' + NS + '">' +
                '<getAccountDetailResult><code>Success</code><account>' +
                '<contact>' + phoneProperty + '</contact>' +
                '<business><guid isAllowed="true"><value>BUSINESS-GUID</value></guid></business>' +
                '</account></getAccountDetailResult></getAccountDetailResponse>' +
                '</soap:Body></soap:Envelope>';
            BceidSoapClient.parseGetAccountDetailResponse(result, NS);
            System.assertEquals(null, result.businessContactTelephone,
                'Blank and unauthorized telephone values must be ignored');
            Account existing = new Account(Name = 'Business', Phone = '604-555-0199');
            BceidBusinessAccountMapper.BusinessData business =
                BceidBusinessAccountMapper.fromSoapResult(result);
            BceidBusinessAccountMapper.apply(existing, business);
            System.assertEquals('604-555-0199', existing.Phone,
                'Existing Account phone must remain unchanged');
        }
    }

    @IsTest
    static void testPhoneNormalizationIsIdempotentAndInvalidValuesAreSkipped() {
        BceidBusinessAccountMapper.BusinessData business =
            new BceidBusinessAccountMapper.BusinessData();
        Account accountRecord = new Account(Name='Existing', Phone='6045550123');

        business.phone = '+1 (604) 555-0123';
        System.assertEquals(false, BceidBusinessAccountMapper.apply(accountRecord, business),
            'Same number with country code and formatting must not cause a DML change');
        System.assertEquals('6045550123', accountRecord.Phone);

        business.phone = '604-555-0199';
        System.assertEquals(true, BceidBusinessAccountMapper.apply(accountRecord, business));
        System.assertEquals('6045550199', accountRecord.Phone);

        business.phone = '604-555-0199 extension 123';
        System.assertEquals(false, BceidBusinessAccountMapper.apply(accountRecord, business),
            'Unsupported length with extension must not overwrite an existing phone');
        System.assertEquals('6045550199', accountRecord.Phone);

        business.phone = ' '; 
        System.assertEquals(false, BceidBusinessAccountMapper.apply(accountRecord, business));
        System.assertEquals('6045550199', accountRecord.Phone);
    }


    @IsTest
    static void testSpreadsheetTargetsFromAllowedSoap() {
        // Synthetic fixture reproduces the structure of the supplied V10 SOAP
        // example, using nonblank business number / phone for mapping coverage.
        BceidSoapClient.SoapResult result = new BceidSoapClient.SoapResult();
        result.rawResponse =
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body><getAccountDetailResponse xmlns="' + NS + '">' +
            '<getAccountDetailResult><code>Success</code><account>' +
            '<contact><telephone isAllowed="true"><value>604-555-0199</value></telephone></contact>' +
            '<business>' +
            '<guid isAllowed="true"><value>BUSINESS-MAPPING-123</value></guid>' +
            '<legalName isAllowed="true"><value>Example Business Incorporated</value></legalName>' +
            '<businessNumber isAllowed="true"><value>123456789</value></businessNumber>' +
            '<address>' +
            '<addressLine1 isAllowed="true"><value>100 Example Street</value></addressLine1>' +
            '<addressLine2 isAllowed="true"><value>Unit 200</value></addressLine2>' +
            '<city isAllowed="true"><value>Vancouver</value></city>' +
            '<postal isAllowed="true"><value>V6B 1A1</value></postal>' +
            // Country/province are omitted in this portable test because
            // State/Country picklist configuration differs between target orgs.
            '</address></business></account></getAccountDetailResult>' +
            '</getAccountDetailResponse></soap:Body></soap:Envelope>';

        BceidSoapClient.parseGetAccountDetailResponse(result, NS);
        BceidBusinessAccountMapper.BusinessData data =
            BceidBusinessAccountMapper.fromSoapResult(result);
        System.assertEquals('123456789', data.businessNumber,
            'The V10 parser must read allowed business/businessNumber/value.');

        Account created = new Account(Name = 'Pending BCeID business');
        System.assertEquals(true, BceidBusinessAccountMapper.apply(created, data));
        System.assertEquals('Example Business Incorporated', created.Name);
        System.assertEquals('6045550199', created.Phone);
        System.assertEquals('100 Example Street\nUnit 200', created.BillingStreet);
        System.assertEquals(created.BillingStreet, created.ShippingStreet);
        System.assertEquals('Vancouver', created.BillingCity);
        System.assertEquals(created.BillingCity, created.ShippingCity);
        System.assertEquals('V6B 1A1', created.BillingPostalCode);
        System.assertEquals(created.BillingPostalCode, created.ShippingPostalCode);

        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Account.fields.getMap();
        if (fields.containsKey('BCeIDGUID__c')) {
            System.assertEquals(data.guid, created.get('BCeIDGUID__c'));
        }
        if (fields.containsKey('ExternalId__c')) {
            System.assertEquals(data.guid, created.get('ExternalId__c'));
        }
        if (fields.containsKey('BCeIDBusinessNumber__c')) {
            System.assertEquals('123456789', created.get('BCeIDBusinessNumber__c'),
                'The spreadsheet requires the canonical BCeIDBusinessNumber__c target.');
        }
        System.assertEquals(false, BceidBusinessAccountMapper.apply(created, data),
            'Reapplying identical BCeID values must not cause an update.');

        // Updating the already-mapped record uses exactly the same field mapping.
        data.businessNumber = '987654321';
        Boolean expectsBusinessNumberChange = fields.containsKey('BCeIDBusinessNumber__c');
        System.assertEquals(expectsBusinessNumberChange,
            BceidBusinessAccountMapper.apply(created, data));
        if (expectsBusinessNumberChange) {
            System.assertEquals('987654321', created.get('BCeIDBusinessNumber__c'));
        }
    }

    @IsTest
    static void testUnauthorizedBusinessNumberNeverOverwritesExistingValue() {
        BceidSoapClient.SoapResult result = new BceidSoapClient.SoapResult();
        result.rawResponse =
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body><getAccountDetailResponse xmlns="' + NS + '">' +
            '<getAccountDetailResult><code>Success</code><account><business>' +
            '<businessNumber isAllowed="false"><value>999999999</value></businessNumber>' +
            '</business></account></getAccountDetailResult></getAccountDetailResponse>' +
            '</soap:Body></soap:Envelope>';
        BceidSoapClient.parseGetAccountDetailResponse(result, NS);
        System.assertEquals(null, result.businessNumber,
            'Unauthorized BCeID fields must not be mapped.');
        BceidBusinessAccountMapper.BusinessData data =
            BceidBusinessAccountMapper.fromSoapResult(result);
        Account existing = new Account(Name = 'Existing business');
        if (Schema.SObjectType.Account.fields.getMap().containsKey('BCeIDBusinessNumber__c')) {
            existing.put('BCeIDBusinessNumber__c', '111111111');
            System.assertEquals(false, BceidBusinessAccountMapper.apply(existing, data));
            System.assertEquals('111111111', existing.get('BCeIDBusinessNumber__c'));
        }
    }

    @IsTest
    static void testTwoLineStreetAndUnchangedValues() {
        BceidBusinessAccountMapper.BusinessData data =
            new BceidBusinessAccountMapper.BusinessData();
        data.addressLine1 = '123 Example Road';
        data.addressLine2 = 'Suite 400';
        data.city = 'Vancouver';
        Account accountRecord = new Account(Name='Existing');
        System.assertEquals(true, BceidBusinessAccountMapper.apply(accountRecord, data));
        System.assertEquals('123 Example Road\nSuite 400', accountRecord.BillingStreet);
        System.assertEquals(accountRecord.BillingStreet, accountRecord.ShippingStreet);
        System.assertEquals(false, BceidBusinessAccountMapper.apply(accountRecord, data));
        System.assertEquals(false, BceidBusinessAccountMapper.apply(null, data));
        System.assertEquals(false, BceidBusinessAccountMapper.apply(accountRecord, null));
    }
}
