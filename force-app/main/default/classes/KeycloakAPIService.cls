public inherited sharing abstract class KeycloakAPIService {
           
    public abstract String doCallout(
        String request,
        String requestType,
        String requestBody,
        Map<String, String> additionalHeaders
    );

    public static String sendRequest(String request, String requestType, String requestBody){
        return sendRequest(request, requestType, requestBody, new Map<String, String>());
    }
    
    public static String sendRequest(String request, String requestType, String requestBody, Map<String, String> additionalHeaders){
        String url = getBaseURL() + request;
        HttpResponse res;
        try{
            KeycloakAPIOAuth oAuth = new KeycloakAPIOAuth();
            String accessToken = Test.isRunningTest() ? 'testaccesstoken' : oAuth.getAccessToken();
            HttpRequest req = new HttpRequest();
            System.debug('accesstoken: ' + accesstoken);
            req.setEndpoint(url);
            req.setMethod(requestType);
            req.setHeader('Accept', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Content-Type', 'application/json');
            
            // Add additional headers
            if (additionalHeaders != null) {
                for (String key : additionalHeaders.keySet()) {
                    req.setHeader(key, additionalHeaders.get(key));
                }
            }
            
            if (requestType != 'GET') {
                req.setBody(requestBody);
            }
            req.setTimeout(60000);
            Http http = new Http();
            res = http.send(req);
        }
        catch(Exception e){
            throw new  CalloutException(e.getMessage());
        }
        if(res.getStatusCode() != 200){
            throw new  CalloutException('Error from callout: ' + requestType + ' ' + res); 
        }
        return res.getBody();
    }
    

    public static String getBaseURL(){     
      List<IDP_User_Registration_API_Endpoint__mdt> filteredRecords = [SELECT Id, API_Group__c, Endpoint_URL__c, Site_URL__c, Sequence__c, QualifiedApiName FROM IDP_User_Registration_API_Endpoint__mdt WHERE API_Group__c = 'GATEWAY_PROFILE' Order By Sequence__c ASC];
      if(!filteredRecords.isEmpty()){
          String currentHost = URL.getCurrentRequestUrl().getHost();
          for (IDP_User_Registration_API_Endpoint__mdt filterRec: filteredRecords )
          {
              if (filterRec.Site_URL__c == currentHost || filterRec.QualifiedApiName == 'DEFAULT')
              {
                  return filterRec.Endpoint_URL__c;
              }

          }
      }
      return null;
    }
    
}