public with sharing class BceidConfig {
    public static final String DEFAULT_SOAP_NAMESPACE =
        'http://www.bceid.ca/webservices/Client/V10/';
    public static final Integer DEFAULT_TIMEOUT_MS = 120000;

    public String endpointUrl { get; private set; }
    public String namedCredentialName { get; private set; }
    public String username { get; private set; }
    public String password { get; private set; }
    public String namespace { get; private set; }
    public Integer timeoutMs { get; private set; }
    public Boolean useNamedCredential { get; private set; }

    public BceidConfig(String endpointUrl, String username, String password) {
        this(endpointUrl, username, password, DEFAULT_SOAP_NAMESPACE, DEFAULT_TIMEOUT_MS);
    }

    public BceidConfig(
        String endpointUrl,
        String username,
        String password,
        String soapNamespace,
        Integer timeoutMs
    ) {
        this.endpointUrl = endpointUrl;
        this.username = username;
        this.password = password;
        this.namespace = normalizeNamespace(soapNamespace);
        this.timeoutMs = timeoutMs == null ? DEFAULT_TIMEOUT_MS : timeoutMs;
        this.useNamedCredential = false;
        this.namedCredentialName = null;
    }

    public static BceidConfig forNamedCredential(String namedCredentialName) {
        return forNamedCredential(
            namedCredentialName,
            DEFAULT_SOAP_NAMESPACE,
            DEFAULT_TIMEOUT_MS
        );
    }

    public static BceidConfig forNamedCredential(
        String namedCredentialName,
        String soapNamespace,
        Integer timeoutMs
    ) {
        if (String.isBlank(namedCredentialName)) {
            throw new IllegalArgumentException('Named Credential name cannot be blank.');
        }

        BceidConfig cfg = new BceidConfig();
        cfg.namedCredentialName = namedCredentialName;
        cfg.namespace = normalizeNamespace(soapNamespace);
        cfg.timeoutMs = timeoutMs == null ? DEFAULT_TIMEOUT_MS : timeoutMs;
        cfg.useNamedCredential = true;
        cfg.endpointUrl = null;
        cfg.username = null;
        cfg.password = null;
        return cfg;
    }

    private BceidConfig() {
    }

    private static String normalizeNamespace(String soapNamespace) {
        String ns = String.isBlank(soapNamespace)
            ? DEFAULT_SOAP_NAMESPACE
            : soapNamespace.trim();
        return ns.endsWith('/') ? ns : ns + '/';
    }

    public String getResolvedEndpoint() {
        return useNamedCredential ? 'callout:' + namedCredentialName : endpointUrl;
    }
}