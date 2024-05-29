public inherited sharing class KeycloakAPIOAuth {

    public final String cachePartitionName = 'local.HealthGatewayAccessToken.accessToken';
    public final String authProviderName = 'BC_Services_Card_Login';

    /**
     * Stores the user token in the cache.
     * 
     * @param tokenValue The value of the user token to be stored.
     */
    public void storeUserToken(String tokenValue) {
        // Store the user-based token in the cache.
        //Cache.Session.put(cachePartitionName, tokenValue);
    }

    /**
     * Retrieves the access token for the user.
     * If a cached token exists, it checks if it has expired.
     * If the token has expired, it retrieves a new refresh token and stores it.
     * If no cached token exists, it retrieves a new refresh token and stores it.
     * @return The access token for the user.
     */
    public String getAccessToken() {
        // Object cachedToken = Cache.Session.get(cachePartitionName);
        // if (cachedToken != null) {
        //      if(isTokenExpired((String)cachedToken)){
        //          String refreshToken = getRefreshAccessToken();
        //          storeUserToken(refreshToken);
        //          return refreshToken;
        //      }
        //     return (String)cachedToken;

        // } else {
            String refreshToken = getRefreshAccessToken();
            //storeUserToken(refreshToken);
            return refreshToken;
        //}
    }

    /**
     * Checks if a JWT token is expired.
     * 
     * @param jwtToken The JWT token to check.
     * @return True if the token is expired, false otherwise.
     */
    public Boolean isTokenExpired(String jwtToken){
        Map<String, Object> payload = (Map<String, Object>)JSON.deserializeUntyped(EncodingUtil.base64Decode(jwtToken.split('\\.')[1]).toString());
        Long exp = (Long)payload.get('exp');
        DateTime expDateTime = DateTime.newInstance(exp * 1000);
        //decrease the expiration time by 20 seconds to avoid any timing issues
        expDateTime = expDateTime.addSeconds(-20);
        return expDateTime < DateTime.now();
    }

    /**
     * Returns the refresh access token.
     * This method retrieves the access token using the specified OpenID Connect ID,
     * and then refreshes the access token using the retrieved access token.
     * The refreshed access token is returned.
     *
     * @return The refresh access token.
     */
    public String getRefreshAccessToken() {
        String openIdConnectId = getAuthProviderIdByDevName(authProviderName);
        System.debug('UserInfo: ' + UserInfo.getUserName());
        System.debug('openIdConnectId: ' + openIdConnectId);

        String accessToken = Auth.AuthToken.getAccessToken(openIdConnectId, 'Open ID Connect'); // 'Open ID Connect'
        //System.debug('accessToken: ' + accessToken);
        Map<String, String> responseMap = Auth.AuthToken.refreshAccessToken(openIdConnectId, 'Open ID Connect', accessToken); //'Open ID Connect'
        String refreshToken = responseMap.get('AccessToken');
        System.debug('refreshToken: ' + refreshToken);
        return refreshToken;
    }

    public Id getAuthProviderIdByDevName(String authProviderName) {
        List<AuthProvider> authProviders = [SELECT Id, FriendlyName, DeveloperName FROM AuthProvider where DeveloperName = :authProviderName LIMIT 1];
        
        if (!authProviders.isEmpty()) {
            return authProviders[0].Id;
        } else {
            return null; 
        }
    }
}
