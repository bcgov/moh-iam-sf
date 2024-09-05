/*
 Class Name: HG_CommonService
 Purpose: Common service class to be used by other apex classes.
 Created By: Numaan Mohammad
 Created Date: 2024-03-25
*/
public inherited sharing class KeycloakCommonService {
    
      //Method to get the endpoint URL from the Custom Metadata Type.
      public static String getEndpointURL(String serviceName){

        List<IDP_User_Registration_API_Endpoint__mdt> filteredRecords = [SELECT Id, API_Group__c, Endpoint_URL__c, Service_Path__c, Site_URL__c, Sequence__c, DeveloperName FROM IDP_User_Registration_API_Endpoint__mdt WHERE API_Group__c = 'GATEWAY_PROFILE' Order By Sequence__c ASC];
        if(!filteredRecords.isEmpty()){
            String currentHost = URL.getCurrentRequestUrl().getHost();
            for (IDP_User_Registration_API_Endpoint__mdt filterRec: filteredRecords )
            {
                if (filterRec.Site_URL__c == currentHost || filterRec.DeveloperName == 'DEFAULT')
                {
                    return filterRec.Service_Path__c;
                }

            }
        }
        return null;
      }
      //Method to replace the placeholder with the value in the endpoint URL.
      public static String replacePlaceholder(String endpoint, String placeholder, String value){
          return endpoint.replace(placeholder, value);
      }
  }
  