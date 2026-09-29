public with sharing class IDP_ExceptionHandler {
    public IDP_Exception_Handling__mdt exceptionHandlingData { get; private set; }
    public String errorCode { get; private set; }
    public String errorMessage { get; private set; }
    public String contactEmail { get; private set; }
    public String logoutURL { get; private set; }
    public String pageTitle { get; private set; }
    public String customExceptionMessage { get; private set; }
    public String defaultErrorMessage = '1000_UNHANDLED_ERROR';
    
    public IDP_ExceptionHandler() {
        try {
            String baseURL = URL.getCurrentRequestUrl().getHost();
            
            // Get error details from URL parameters
            errorCode = ApexPages.currentPage().getParameters().get('ErrorCode');
            errorMessage = ApexPages.currentPage().getParameters().get('ErrorDescription');
            exceptionHandlingData = new IDP_Exception_Handling__mdt();
            exceptionHandlingData = fetchExceptionHandlingData(baseURL, errorMessage);
            if (exceptionHandlingData == null){
                exceptionHandlingData = new IDP_Exception_Handling__mdt();
            }
            contactEmail = exceptionHandlingData != null ? exceptionHandlingData.Contact_Email__c : '';
            logoutURL = exceptionHandlingData != null ? exceptionHandlingData.Logout_URL__c : '';
            pageTitle = exceptionHandlingData != null ? exceptionHandlingData.Page_Title__c : '';

            // Retrieve custom message based on error code from IDP_Exception_Messages
            if (errorCode != null) {
                IDP_Exception_Messages__mdt customMessage = [
                    SELECT Custom_Message__c
                    FROM IDP_Exception_Messages__mdt
                    WHERE Reference_Code__c = :errorMessage
                    LIMIT 1
                ];
                customExceptionMessage = customMessage != null ? customMessage.Custom_Message__c : '';
            }
        } catch (Exception e) {
            System.debug('Error initializing IDP_ExceptionHandler: ' + e.getMessage());
        }
    }
    
    private IDP_Exception_Handling__mdt fetchExceptionHandlingData(String baseURL, String errorMsg) {
        IDP_Exception_Handling__mdt exceptionHandlingData = new IDP_Exception_Handling__mdt();
        for (IDP_Exception_Handling__mdt exceptionHandling: [SELECT Page_Title__c, Standard_Message_Body__c, Contact_Email__c, Logout_URL__c, Logo_URL__c, Reference_Code__c 
                    FROM IDP_Exception_Handling__mdt 
                    WHERE Base_URL__c = :baseURL 
                    AND Reference_Code__c =: errorMsg
                    LIMIT 1]) {
         	exceptionHandlingData = exceptionHandling;                                                   
        }
        return exceptionHandlingData;
    }
}