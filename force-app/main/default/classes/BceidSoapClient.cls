public with sharing class BceidSoapClient {
    private static final String SOAP11_NS =
        'http://schemas.xmlsoap.org/soap/envelope/';

    public class SoapResult {
        public Integer httpStatus;
        public String rawResponse;
        public Boolean hasSoapFault;
        public String faultCode;
        public String faultString;
        public String responseCode;
        public String failureCode;
        public String responseMessage;
        public String firstName;
        public String lastName;
    }

    public static SoapResult invoke(
        BceidConfig cfg,
        String operationName,
        String payloadXml
    ) {
        if (cfg == null) {
            throw new IllegalArgumentException('Config cannot be null.');
        }
        if (String.isBlank(operationName)) {
            throw new IllegalArgumentException('Operation name cannot be blank.');
        }
        if (String.isBlank(cfg.getResolvedEndpoint())) {
            throw new IllegalArgumentException(
                'Endpoint or Named Credential must be configured.'
            );
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(cfg.getResolvedEndpoint());
        req.setMethod('POST');
        req.setTimeout(cfg.timeoutMs);
        req.setHeader('Content-Type', 'text/xml; charset=UTF-8');

        String soapAction = buildSoapAction(cfg.namespace, operationName);
        req.setHeader('SOAPAction', soapAction);

        if (!cfg.useNamedCredential) {
            req.setHeader(
                'Authorization',
                'Basic ' + EncodingUtil.base64Encode(
                    Blob.valueOf(cfg.username + ':' + cfg.password)
                )
            );
        }

        req.setBody(buildEnvelope(cfg.namespace, operationName, payloadXml));

        System.debug('===== BCeID OUTBOUND REQUEST =====');
        System.debug('Endpoint    : ' + req.getEndpoint());
        System.debug('Content-Type: ' + req.getHeader('Content-Type'));
        System.debug('SOAPAction  : ' + req.getHeader('SOAPAction'));
        System.debug('Request Body: ' + req.getBody());
        System.debug('==================================');

        HttpResponse res = new Http().send(req);

        System.debug('===== BCeID INBOUND RESPONSE =====');
        System.debug('HTTP Status : ' + res.getStatusCode());
        System.debug('Content-Type: ' + res.getHeader('Content-Type'));
        System.debug('Response Body: ' + res.getBody());
        System.debug('==================================');

        SoapResult out = new SoapResult();
        out.httpStatus = res.getStatusCode();
        out.rawResponse = res.getBody();
        parseSoapFault(out);
        if (!out.hasSoapFault && out.httpStatus >= 200 && out.httpStatus < 300 &&
            operationName == 'getAccountDetail') {
            parseGetAccountDetailResponse(out, cfg.namespace);
        }
        return out;
    }

    public static String buildSoapAction(String ns, String operationName) {
        if (String.isBlank(ns)) {
            throw new IllegalArgumentException('SOAP namespace cannot be blank.');
        }
        String normalizedNs = ns.endsWith('/') ? ns : ns + '/';
        return '"' + normalizedNs + operationName + '"';
    }

    private static String buildEnvelope(
        String ns,
        String operationName,
        String payloadXml
    ) {
        return '<?xml version="1.0" encoding="utf-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="' + SOAP11_NS +
            '" xmlns:v10="' + escapeXml(ns) + '">' +
            '<soapenv:Header/>' +
            '<soapenv:Body>' +
            '<v10:' + operationName + '>' +
            (payloadXml == null ? '' : payloadXml) +
            '</v10:' + operationName + '>' +
            '</soapenv:Body>' +
            '</soapenv:Envelope>';
    }

    private static void parseSoapFault(SoapResult out) {
        out.hasSoapFault = false;
        if (String.isBlank(out.rawResponse)) return;

        try {
            Dom.Document d = new Dom.Document();
            d.load(out.rawResponse);
            Dom.XmlNode env = d.getRootElement();
            Dom.XmlNode body = env.getChildElement('Body', SOAP11_NS);
            if (body == null) return;

            for (Dom.XmlNode child : body.getChildElements()) {
                if (child.getName() == 'Fault' || child.getName().endsWith(':Fault')) {
                    out.hasSoapFault = true;
                    Dom.XmlNode code = child.getChildElement('faultcode', null);
                    Dom.XmlNode msg = child.getChildElement('faultstring', null);
                    out.faultCode = code == null ? null : code.getText();
                    out.faultString = msg == null ? null : msg.getText();
                    return;
                }
            }
        } catch (Exception e) {
            // Non-XML responses (for example an HTML proxy error) are retained
            // in rawResponse and are not reported as SOAP faults.
        }
    }

    @TestVisible
    private static void parseGetAccountDetailResponse(SoapResult out, String ns) {
        if (out == null || String.isBlank(out.rawResponse)) return;

        try {
            Dom.Document d = new Dom.Document();
            d.load(out.rawResponse);
            Dom.XmlNode env = d.getRootElement();
            Dom.XmlNode body = env.getChildElement('Body', SOAP11_NS);
            if (body == null) return;

            Dom.XmlNode response = body.getChildElement('getAccountDetailResponse', ns);
            if (response == null) return;
            Dom.XmlNode detailResult = response.getChildElement('getAccountDetailResult', ns);
            if (detailResult == null) return;

            out.responseCode = childText(detailResult, 'code', ns);
            out.failureCode = childText(detailResult, 'failureCode', ns);
            out.responseMessage = childText(detailResult, 'message', ns);

            Dom.XmlNode account = detailResult.getChildElement('account', ns);
            if (account == null) return;
            Dom.XmlNode individualIdentity = account.getChildElement('individualIdentity', ns);
            if (individualIdentity == null) return;
            Dom.XmlNode name = individualIdentity.getChildElement('name', ns);
            if (name == null) return;

            out.firstName = bceidStringValue(name, 'firstname', ns);
            out.lastName = bceidStringValue(name, 'surname', ns);
        } catch (Exception e) {
            // Keep the raw response available to the caller if parsing fails.
        }
    }

    private static String childText(Dom.XmlNode parent, String childName, String ns) {
        Dom.XmlNode child = parent == null ? null : parent.getChildElement(childName, ns);
        return child == null ? null : child.getText();
    }

    private static String bceidStringValue(Dom.XmlNode parent, String propertyName, String ns) {
        Dom.XmlNode propertyNode = parent == null ? null : parent.getChildElement(propertyName, ns);
        if (propertyNode == null) return null;
        Dom.XmlNode valueNode = propertyNode.getChildElement('value', ns);
        return valueNode == null ? null : valueNode.getText();
    }

    // BCeID V10 uses elementFormDefault="qualified", so request elements
    // generated by this helper are explicitly qualified with v10:.
    public static String xml(String tagName, String value) {
        if (value == null) return '';
        return '<v10:' + tagName + '>' +
            escapeXml(value) +
            '</v10:' + tagName + '>';
    }

    public static String xmlEmptyAllowed(String tagName, String value) {
        return '<v10:' + tagName + '>' +
            escapeXml(value == null ? '' : value) +
            '</v10:' + tagName + '>';
    }

    public static String xmlInt(String tagName, Integer value) {
        return value == null
            ? ''
            : '<v10:' + tagName + '>' + String.valueOf(value) +
              '</v10:' + tagName + '>';
    }

    public static String xmlBool(String tagName, Boolean value) {
        return value == null
            ? ''
            : '<v10:' + tagName + '>' + String.valueOf(value) +
              '</v10:' + tagName + '>';
    }

    public static String openTag(String tagName) {
        return '<v10:' + tagName + '>';
    }

    public static String closeTag(String tagName) {
        return '</v10:' + tagName + '>';
    }

    public static String escapeXml(String input) {
        if (input == null) return '';
        String s = input;
        s = s.replace('&', '&amp;');
        s = s.replace('<', '&lt;');
        s = s.replace('>', '&gt;');
        s = s.replace('"', '&quot;');
        s = s.replace('\'', '&apos;');
        return s;
    }
}