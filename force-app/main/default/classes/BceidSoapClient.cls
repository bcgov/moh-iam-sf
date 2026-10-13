/**
 * @description       : 
 * @author            : Roy Poystila
 * @group             : 
 * @last modified on  : 10-06-2026
 * @last modified by  : Roy Poystila
**/
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
        // BCeID V10 <business> details, populated only when isAllowed="true".
        // BCeID V10 <account><contact><telephone>, subject to isAllowed.
        public String businessContactTelephone;
        public String businessGuid;
        public String businessLegalName;
        public String businessNumber;
        public String businessDoingBusinessAs;
        public String businessAddressLine1;
        public String businessAddressLine2;
        public String businessCity;
        public String businessPostal;
        public String businessProvince;
        public String businessCountry;
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
        System.debug('Request body length (bytes approximate): ' + req.getBody().length());
        System.debug('==================================');

        HttpResponse res = new Http().send(req);

        System.debug('===== BCeID INBOUND RESPONSE =====');
        System.debug('HTTP Status : ' + res.getStatusCode());
        System.debug('Content-Type: ' + res.getHeader('Content-Type'));
        System.debug('Response body length (chars): ' + (res.getBody() == null ? 0 : res.getBody().length()));
        System.debug('==================================');

        // TEMPORARY DIAGNOSTIC OUTPUT: full SOAP responses may include PII,
        // including values for which BCeID returned isAllowed="false".
        // Only visible with an Apex Code = FINEST trace flag. Remove after use.
        String responseContentType = res.getHeader('Content-Type');
        if (!String.isBlank(res.getBody()) &&
            !String.isBlank(responseContentType) &&
            responseContentType.toLowerCase().contains('xml')) {
            System.debug(
                LoggingLevel.FINEST,
                '===== BCeID FORMATTED SOAP RESPONSE =====\n' +
                formatSoapXml(res.getBody()) +
                '\n===== END BCeID FORMATTED SOAP RESPONSE ====='
            );
        }

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

    /**
     * Pretty-print diagnostic XML without modifying the SOAP payload.
     * This is a lightweight formatter, not a full XML serializer; callers
     * must continue using the original HttpResponse.getBody() for parsing.
     */
    @TestVisible
    private static String formatSoapXml(String xml) {
        if (String.isBlank(xml)) return '';

        // Typical compact SOAP puts adjacent tags next to one another.
        // Do not use this formatted representation for further processing.
        String normalized = xml.replace('><', '>\n<');
        List<String> formatted = new List<String>();
        Integer depth = 0;

        for (String part : normalized.split('\n')) {
            String line = part.trim();
            if (String.isBlank(line)) continue;

            if (line.startsWith('</') && depth > 0) depth--;

            String indent = '';
            for (Integer i = 0; i < depth; i++) {
                indent += '  ';
            }
            formatted.add(indent + line);

            if (line.startsWith('<') &&
                !line.startsWith('</') &&
                !line.startsWith('<?') &&
                !line.startsWith('<!') &&
                !line.endsWith('/>') &&
                !line.contains('</')) {
                depth++;
            }
        }
        return String.join(formatted, '\n');
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

            // Telephone is under <account><contact>, not <business>.
            // Ignore fields that BCeID did not authorize or left empty.
            Dom.XmlNode contact = account.getChildElement('contact', ns);
            out.businessContactTelephone = bceidAllowedValue(contact, 'telephone', ns);

            Dom.XmlNode business = account.getChildElement('business', ns);
            if (business != null) {
                out.businessGuid = bceidAllowedValue(business, 'guid', ns);
                out.businessLegalName = bceidAllowedValue(business, 'legalName', ns);
                out.businessNumber = bceidAllowedValue(business, 'businessNumber', ns);
                out.businessDoingBusinessAs = bceidAllowedValue(business, 'doingBusinessAs', ns);
                Dom.XmlNode address = business.getChildElement('address', ns);
                if (address != null) {
                    out.businessAddressLine1 = bceidAllowedValue(address, 'addressLine1', ns);
                    out.businessAddressLine2 = bceidAllowedValue(address, 'addressLine2', ns);
                    out.businessCity = bceidAllowedValue(address, 'city', ns);
                    out.businessPostal = bceidAllowedValue(address, 'postal', ns);
                    out.businessProvince = bceidAllowedValue(address, 'province', ns);
                    out.businessCountry = bceidAllowedValue(address, 'country', ns);
                }
            }
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

    // Authorization on BCeID properties is per-field, not just per response.
    // Do not expose / copy values with isAllowed=false, and never clear on blank.
    private static String bceidAllowedValue(Dom.XmlNode parent, String propertyName, String ns) {
        Dom.XmlNode property = parent == null ? null : parent.getChildElement(propertyName, ns);
        if (property == null || property.getAttribute('isAllowed', null) != 'true') return null;
        Dom.XmlNode value = property.getChildElement('value', ns);
        String text = value == null ? null : value.getText();
        return String.isBlank(text) ? null : text.trim();
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