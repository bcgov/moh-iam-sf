/**
 * Maps the allowed BCeID V10 business details to standard Salesforce Account
 * address fields and optional identifier / DBA fields, without writing DML.
 * An Account's standard mailing-address equivalent is BillingAddress.
 */
public with sharing class BceidBusinessAccountMapper {
    public class BusinessData {
        public String guid;
        public String legalName;
        public String phone;
        public String businessNumber;
        public String doingBusinessAs;
        public String addressLine1;
        public String addressLine2;
        public String city;
        public String postal;
        public String province;
        public String country;
    }

    public static BusinessData fromSoapResult(BceidSoapClient.SoapResult response) {
        if (response == null) return null;
        BusinessData data = new BusinessData();
        data.guid = response.businessGuid;
        data.legalName = response.businessLegalName;
        data.phone = response.businessContactTelephone;
        data.businessNumber = response.businessNumber;
        data.doingBusinessAs = response.businessDoingBusinessAs;
        data.addressLine1 = response.businessAddressLine1;
        data.addressLine2 = response.businessAddressLine2;
        data.city = response.businessCity;
        data.postal = response.businessPostal;
        data.province = response.businessProvince;
        data.country = response.businessCountry;
        return data;
    }

    /** Updates the in-memory Account; returns true if any field differs. */
    public static Boolean apply(Account record, BusinessData data) {
        if (record == null || data == null) return false;
        Boolean changed = false;
        Map<String, Schema.SObjectField> available = Schema.SObjectType.Account.fields.getMap();

        changed = setIfDifferent(record, available, 'Name', data.legalName) || changed;
        // BCeID <account><contact><telephone> maps to Account.Phone.
        // Blank or unauthorized values never clear an existing phone number.
        // PHOCS Account.Phone validation requires exactly ten digits.
        // Normalize permitted BCeID telephone formats before assigning them.
        // Unsupported lengths must not block the business name/address sync.
        changed = setIfDifferent(record, available, 'Phone',
            normalizeBusinessTelephone(data.phone)) || changed;
        changed = setIfDifferent(record, available, 'BCeIDGUID__c', data.guid) || changed;
        changed = setIfDifferent(record, available, 'ExternalId__c', data.guid) || changed;

        // These additional fields are optional across the orgs using this package.
        // Do not misuse AccountNumber or Description for a government business number/DBA.
        if (available.containsKey('Doing_Business_As__c')) {
            changed = setIfDifferent(record, available, 'Doing_Business_As__c', data.doingBusinessAs) || changed;
        } else {
            changed = setIfDifferent(record, available, 'Tradestyle', data.doingBusinessAs) || changed;
        }
        changed = setIfDifferent(record, available, 'Business_Number__c', data.businessNumber) || changed;

        String street = null;
        if (String.isNotBlank(data.addressLine1)) street = data.addressLine1.trim();
        if (String.isNotBlank(data.addressLine2)) {
            street = (street == null ? '' : street + '\n') + data.addressLine2.trim();
        }

        // Source business address is used for both standard Account address sets.
        // Salesforce standard Account has Billing/Shipping, not Mailing fields.
        for (String prefix : new List<String>{ 'Billing', 'Shipping' }) {
            changed = setIfDifferent(record, available, prefix + 'Street', street) || changed;
            changed = setIfDifferent(record, available, prefix + 'City', data.city) || changed;
            changed = setIfDifferent(record, available, prefix + 'PostalCode', data.postal) || changed;

            // CountryCode/StateCode are supported in State and Country/Territory Picklist orgs.
            String countryField = available.containsKey(prefix + 'CountryCode')
                ? prefix + 'CountryCode' : prefix + 'Country';
            String provinceField = available.containsKey(prefix + 'StateCode')
                ? prefix + 'StateCode' : prefix + 'State';
            changed = setIfDifferent(record, available, countryField, data.country) || changed;
            changed = setIfDifferent(record, available, provinceField, data.province) || changed;
        }
        return changed;
    }

    /**
     * BCeID can return formatted Canadian telephone numbers; the target
     * Account validation rule requires a 10-digit value. Strip formatting,
     * including a leading North American country code of 1. A blank or
     * unsupported number is ignored rather than overwriting Account.Phone.
     */
    private static String normalizeBusinessTelephone(String incoming) {
        if (String.isBlank(incoming)) return null;
        String digits = incoming.replaceAll('[^0-9]', '');
        if (digits.length() == 11 && digits.startsWith('1')) {
            digits = digits.substring(1);
        }
        if (digits.length() != 10) {
            System.debug(LoggingLevel.WARN,
                'BCeID Account telephone skipped: unsupported telephone length.');
            return null;
        }
        return digits;
    }

    // Empty/unavailable XML values never erase existing Salesforce fields.
    private static Boolean setIfDifferent(Account record,
            Map<String, Schema.SObjectField> available, String apiName, String value) {
        if (String.isBlank(value) || !available.containsKey(apiName)) return false;
        String incoming = value.trim();
        Object existingValue = record.get(apiName);
        if (existingValue != null && String.valueOf(existingValue) == incoming) return false;
        record.put(apiName, incoming);
        return true;
    }
}
