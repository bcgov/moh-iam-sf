@IsTest
private class BceidConfigTest {
    @IsTest
    static void testConstructors() {
        BceidConfig cfg = new BceidConfig(
            'https://example.com/ws',
            'user',
            'pass'
        );
        System.assertEquals('https://example.com/ws', cfg.endpointUrl);
        System.assertEquals('user', cfg.username);
        System.assertEquals('pass', cfg.password);
        System.assertEquals(
            'http://www.bceid.ca/webservices/Client/V10/',
            cfg.namespace
        );
        System.assertEquals(120000, cfg.timeoutMs);
        System.assertEquals(false, cfg.useNamedCredential);

        BceidConfig custom = new BceidConfig(
            'https://example.com/ws2',
            'u2',
            'p2',
            'urn:test',
            1000
        );
        System.assertEquals('urn:test/', custom.namespace);
        System.assertEquals(1000, custom.timeoutMs);

        BceidConfig named = BceidConfig.forNamedCredential('BCeID_NC');
        System.assertEquals(true, named.useNamedCredential);
        System.assertEquals('BCeID_NC', named.namedCredentialName);
        System.assertEquals(
            'callout:BCeID_NC',
            named.getResolvedEndpoint()
        );
        System.assertEquals(
            'http://www.bceid.ca/webservices/Client/V10/',
            named.namespace
        );
        System.assertEquals(null, named.username);
        System.assertEquals(null, named.password);
    }

    @IsTest
    static void testNamedCredentialCustomNamespaceAndTimeout() {
        BceidConfig cfg = BceidConfig.forNamedCredential(
            'BCeID_NC',
            'http://example.test/soap',
            30000
        );

        System.assertEquals('callout:BCeID_NC', cfg.getResolvedEndpoint());
        System.assertEquals(
            'http://example.test/soap/',
            cfg.namespace
        );
        System.assertEquals(30000, cfg.timeoutMs);
        System.assertEquals(true, cfg.useNamedCredential);
    }

    @IsTest
    static void testNamedCredentialNameRequired() {
        try {
            BceidConfig.forNamedCredential('');
            System.assert(false, 'Expected IllegalArgumentException.');
        } catch (IllegalArgumentException e) {
            System.assert(
                e.getMessage().contains(
                    'Named Credential name cannot be blank'
                )
            );
        }
    }
}