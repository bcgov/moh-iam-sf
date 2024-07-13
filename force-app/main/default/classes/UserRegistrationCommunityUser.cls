public with sharing class UserRegistrationCommunityUser {
    public class UserVariables {
        @InvocableVariable
        public List<User> userIdentifiers;
    }

    public class ResultVariables {
        @InvocableVariable
        public String currentUrl;

        public ResultVariables(String currentUrl) {
            
            this.currentUrl = currentUrl;
        }
    }

    @InvocableMethod (label='Process Community Users' description='Process Community Users')
    public static List<ResultVariables> fetchURL(List<UserVariables> userVariables)
    {
        List<User> userList =  userVariables.get(0).userIdentifiers;
        String currentURL = '';
        List<ResultVariables> results = new List<ResultVariables>();
        List<ResultVariables> result = new List<ResultVariables>();

        System.debug('userList: ' + userList);
        System.debug('getAuthority(): ' + URL.getCurrentRequestUrl().getHost());
        String currentHost = URL.getCurrentRequestUrl().getHost();
        if (currentHost.toLowerCase().contains('healthgateway')) {
            currentURL = 'healthgateway';
        } else {
            currentURL = 'other';
        }

        List<String> addedBetaUsers = new List<String>();
        return new List<ResultVariables>{new ResultVariables(currentURL)};

    }
}