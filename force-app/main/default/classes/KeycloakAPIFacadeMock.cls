@isTest
public class KeycloakAPIFacadeMock implements HttpCalloutMock {
  private HttpResponse response;
  
  public KeycloakAPIFacadeMock(HttpResponse response) {
    this.response = response;
  }
  
  public HttpResponse respond(HttpRequest request) {
    return this.response;
  }
}
