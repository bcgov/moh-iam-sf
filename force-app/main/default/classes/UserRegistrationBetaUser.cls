public with sharing class UserRegistrationBetaUser {
    public class UserVariables {
        @InvocableVariable
        public List<User> userIdentifiers;
    }

    public class ResultVariables {
        @InvocableVariable
        public List<String> BetaUsers;
    }

    @InvocableMethod (label='Process Beta Users' description='Process Beta Users')
    public static List<ResultVariables> applyBetaUsers(List<UserVariables> userVariables)
    {
        List<User> userList =  userVariables.get(0).userIdentifiers;
        List<User> updateUserList = new List<User>();
        
        //Savepoint sp_perm = Database.setSavepoint();
        System.debug('userList: ' + userList);
        System.debug('getAuthority(): ' + URL.getCurrentRequestUrl().getHost());
        String currentHost = URL.getCurrentRequestUrl().getHost();
        if (currentHost.toLowerCase().contains('healthgateway') || Test.isRunningTest())
        {
            Boolean checkBetaUser = UserRegistrationPermission.checkIsBetaUser(userList);
            if (checkBetaUser)
            {
                for (User updateUserToBeta: userList)
                {
                    User userUpdate = new User();
                    userUpdate.Id = updateUserToBeta.Id;
                    userUpdate.User_Provisioning_Role__c = 'BETA';
                    updateUserList.add(userUpdate);
                }
                update updateUserList;
            }
        }

        List<String> addedBetaUsers = new List<String>();

        List<ResultVariables> returnVarsList = new List<ResultVariables>();
        ResultVariables returnVars = new ResultVariables();
        returnVars.BetaUsers = addedBetaUsers;
        returnVarsList.add(returnVars);
        return returnVarsList;
    }
}