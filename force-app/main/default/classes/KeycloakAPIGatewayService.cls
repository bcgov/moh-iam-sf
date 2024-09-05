/**
 *KeycloakApiService extension of the KeycloakGatewayService
 */
public inherited sharing class KeycloakAPIGatewayService extends KeycloakAPIService {

    /**
     * @description : Execute the callout
     * @param: request: API Request
     * @param: requestType: GET/POST etc.
     * @param: requestBody: Data to be sent with request
     * @param: additionalHeaders: Headers to be sent with request
     * @return: String : Response of the callout
     */
    public override String doCallout(
      String request,
      String requestType,
      String requestBody,
      Map<String, String> additionalHeaders
    ) {
      String response = sendRequest(request, requestType, requestBody, additionalHeaders);
      return response;
    }
  }