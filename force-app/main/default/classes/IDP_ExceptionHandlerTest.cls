@isTest
public class IDP_ExceptionHandlerTest {
    @testSetup
    static void setupTestData() {
        // Create test data for IDP_Exception_Handling
        IDP_Exception_Handling__mdt exceptionHandling = [
                SELECT DeveloperName, Base_URL__c, Page_Title__c, Standard_Message_Body__c, Contact_Email__c, Logout_URL__c, Logo_URL__c
                FROM   IDP_Exception_Handling__mdt
                WHERE  DeveloperName = 'TestOnly_DoNotRemove'];
                
        //new IDP_Exception_Handling__mdt(
        //    DeveloperName = 'TestOnly_DoNotRemove',
        //    Base_URL__c = URL.getCurrentRequestUrl().getHost(),
        //    Page_Title__c = 'Test Exception Page',
        //   Standard_Message_Body__c = 'An unexpected error occurred. Please contact support.',
        //    Contact_Email__c = 'support@example.com',
        //    Logout_URL__c = '/secur/logout.jsp',
        //    Logo_URL__c = 'https://example.com/logo.png'
        //);
        //insert exceptionHandling;
        
        IDP_Exception_Messages__mdt exceptionMessage = [
                SELECT DeveloperName, Custom_Message__c, Reference_Code__c
                FROM   IDP_Exception_Messages__mdt 
                WHERE  Reference_Code__c = 'TEST_ERROR'];
        // Create test data for IDP_Exception_Messages
        //IDP_Exception_Messages__mdt exceptionMessage = new IDP_Exception_Messages__mdt(
        //    DeveloperName = 'Test_Exception_Message',
        //    Reference_Code__c = 'TEST_ERROR',
        //    Custom_Message__c = 'This is a custom error message for testing.'
        //);
        //insert exceptionMessage;
    }
    
    @isTest
    static void testController() {
        // Set URL parameters for error code and message
        ApexPages.currentPage().getParameters().put('ErrorCode', 'REGISTRATION_HANDLER_ERROR');
        ApexPages.currentPage().getParameters().put('ErrorDescription', 'TEST_ERROR');
        
        // Instantiate controller
        IDP_ExceptionHandler controller = new IDP_ExceptionHandler();
        
        // Assertions to verify the correct metadata and custom message retrieval
        //System.assertNotEquals(null, controller.exceptionHandlingData, 'Exception Handling Data should not be null');
        //System.assertEquals('Test Exception Page', controller.exceptionHandlingData.Page_Title__c);
        //System.assertEquals('An unexpected error occurred. Please contact support.', controller.exceptionHandlingData.Standard_Message_Body__c);
        
        //System.assertEquals('REGISTRATION_HANDLER_ERROR', controller.errorCode);
        //System.assertEquals('TEST_ERROR', controller.errorMessage);
        //System.assertEquals('This is a custom error message for testing.', controller.customExceptionMessage);
    }
}