@IsTest
public class KeycloakAPIGatewayServiceTest {
    /**
     * test method to verify the functionality of the doCallOut  method in the KeycloakAPIGatewayService class.
     */
    @isTest
    static void testGetPatientInfoFromGatewayApiService() {

    //GIVEN
    // Create a test HD ID
    String testHDId = 'TestHDID123';
    String request = '/v1/hd/' + testHDId + '/gatewayapiservice';
    String requestType = 'GET';
    String requestBody = '';
    
    // Create a mock HTTP response
    HttpResponse mockResponse = new HttpResponse();
    mockResponse.setStatusCode(200);
    mockResponse.setBody('{"result": "Patient Info from Gateway API Service success"}');
    
    //WHEN
    // Create a mock HTTP callout
    Test.setMock(HttpCalloutMock.class, new KeycloakAPIFacadeMock(mockResponse));
    
    // Call the method under test
    String result = new KeycloakAPIGatewayService().doCallout(request, requestType, requestBody, null);

    //THEN
    // Assert the result
    System.assertEquals('{"result": "Patient Info from Gateway API Service success"}', result, 'The result should be {"result": "Patient Info from Gateway API Service success"}');
    }
}
