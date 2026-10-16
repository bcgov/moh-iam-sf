/** Authorized BCeID V10 person fields shared by Contact and User mapping. */
public with sharing class BceidPersonData {
    public String firstName;
    public String lastName;
    public String email;
    public String mobile;

    public BceidPersonData(String firstName, String lastName,
            String email, String mobile) {
        this.firstName = firstName;
        this.lastName = lastName;
        this.email = email;
        this.mobile = mobile;
    }

    public static BceidPersonData fromSoapResult(BceidSoapClient.SoapResult result) {
        if (result == null) return null;
        // The SOAP parser sets these properties only for authorized values.
        return new BceidPersonData(result.firstName, result.lastName,
            result.contactEmail, result.contactTelephone);
    }

    /** Return a PHOCS-compatible 10-digit North American telephone number. */
    public static String normalizedMobile(String incoming) {
        if (String.isBlank(incoming)) return null;
        String digits = incoming.replaceAll('[^0-9]', '');
        if (digits.length() == 11 && digits.startsWith('1')) {
            digits = digits.substring(1);
        }
        // Don't write ambiguous or invalid numbers; never clear existing data.
        return digits.length() == 10 ? digits : null;
    }
}
