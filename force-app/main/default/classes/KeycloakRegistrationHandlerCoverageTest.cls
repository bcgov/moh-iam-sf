/** Focused coverage for canCreateUser, independent of org-specific SSO mappings. */
@IsTest
private class KeycloakRegistrationHandlerCoverageTest {
    private static Auth.UserData userData(String username, String bceidUsername) {
        Map<String, String> claims = new Map<String, String>();
        if (bceidUsername != null) claims.put('bceid_username', bceidUsername);
        return new Auth.UserData(
            'test-subject', 'First', 'Last', 'First Last',
            'registration.coverage@example.com', null,
            username, 'en_US', 'Open ID Connect', null, claims
        );
    }

    @IsTest
    static void testMissingFederationIdentifierAllowsCreation() {
        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
        String missing = 'no-match-' + String.valueOf(DateTime.now().getTime());
        System.assertEquals(true, handler.canCreateUser(userData(missing, null)));
        System.assertEquals(true, handler.canCreateUser(userData('unused', missing)));
    }

    @IsTest
    static void testExistingFederationIdentifierBlocksCreation() {
        // Updating the current test user is isolated to the test transaction.
        User current = [
            SELECT Id, FederationIdentifier
            FROM User WHERE Id = :UserInfo.getUserId()
        ];
        current.FederationIdentifier = 'COVERAGE_' + String.valueOf(DateTime.now().getTime());
        update current;
        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
        System.assertEquals(false,
            handler.canCreateUser(userData(current.FederationIdentifier, null)));
        System.assertEquals(false,
            handler.canCreateUser(userData('other-username', current.FederationIdentifier)));
        System.assertEquals(true,
            handler.canCreateUser(userData('other-username', 'not-present-bceid')));
    }
}
