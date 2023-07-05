@isTest
public class KeycloakRegistrationHandlerTest {
  private static final String OAUTH_TOKEN = 'testToken';
  private static final String STATE = 'mocktestState';
  private static final String REFRESH_TOKEN = 'refreshToken';
  private static final String LOGIN_ID = 'testLoginId';
  private static final String USERNAME = 'testUsername';
  private static final String FIRST_NAME = 'testFirstName';
  private static final String LAST_NAME = 'testLastName';
  private static final String EMAIL_ADDRESS = 'testEmailAddress';
  private static final String LOCALE_NAME = 'testLocalName';
  private static final String FULL_NAME = FIRST_NAME + ' ' + LAST_NAME;
  private static final String PROVIDER = 'Concur';
  private static final String REDIRECT_URL = 'http://localhost/services/authcallback/orgId/Concur';
  private static final String KEY = 'testKey';
  private static final String SECRET = 'testSecret';
  private static final String STATE_TO_PROPOGATE = 'testState';
  private static final String ACCESS_TOKEN_URL = 'http://www.dummyhost.com/accessTokenUri';
  private static final String API_USER_VERSION_URL = 'http://www.dummyhost.com/user/20/1';
  private static final String AUTH_URL = 'http://www.dummy.com/authurl';
  private static final String API_USER_URL = 'www.concursolutions.com/user/api';
  private static User RUN_TIME_USER = new User();

  private static Map<String, String> setupAuthProviderConfig() {
      Map<String, String> authProviderConfiguration = new Map<String, String>();
      authProviderConfiguration.put('Key__c', KEY);
      authProviderConfiguration.put('Auth_Url__c', AUTH_URL);
      authProviderConfiguration.put('Secret__c', SECRET);
      authProviderConfiguration.put('Access_Token_Url__c', ACCESS_TOKEN_URL);
      authProviderConfiguration.put('API_User_Url__c', API_USER_URL);
      authProviderConfiguration.put(
        'API_User_Version_Url__c',
        API_USER_VERSION_URL
      );
      authProviderConfiguration.put('Redirect_Url__c', REDIRECT_URL);
      return authProviderConfiguration;
  }

  @TestSetup
  public static void testSetup() {

    test.startTest();
        verifyTestUser();
    test.stopTest();

    PermissionSetGroup psg = [select Id, Status from PermissionSetGroup where DeveloperName='TESTONLY_DONOTREMOVE'];
    
    // force calculation of the PSG if it is not already Updated
    if (psg.Status != 'Updated') {
      Test.calculatePermissionSetGroup(psg.Id);
    }

    User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
    System.runAs(runtimeUser) {   

        Profile commUserType = [
            SELECT Id, Name, UserType 
            FROM Profile 
            WHERE Name = 'Customer Community Plus Login User' Limit 1];  

        Account newPersonAccount0 = new Account();    
        Account newPersonAccount = new Account();
        List<Account> newPersonAccounts = new List<Account>();
        String setIdentifier = '';

        Id personAccountRecordTypeId =  Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        
        newPersonAccount0.RecordTypeId = personAccountRecordTypeId;
        newPersonAccount0.FirstName = 'TESTONLY_ZERO';
        newPersonAccount0.LastName = 'TESTONLY_LAST';
        newPersonAccount0.PersonEmail = 'TESTONLY0@EMAIL.com';
        newPersonAccount0.SourceSystemIdentifier = 'CPN.TSTP00000.CPSID.GS';
        newPersonAccount0.HealthCloudGA__SourceSystemId__pc = 'CPN.TSTP00000.CPSID.GS';
        //setIdentifier = (String)newPersonAccount0.put('HealthCloudGA__SourceSystemId__pc', 'CPN.TSTP00000.CPSID.GS');
        
        newPersonAccounts.Add(newPersonAccount0);
        
        newPersonAccount.RecordTypeId = personAccountRecordTypeId;
        newPersonAccount.FirstName = 'TESTONLY_FIRST';
        newPersonAccount.LastName = 'TESTONLY_LAST';
        newPersonAccount.PersonEmail = 'TESTONLY@EMAIL.com';
        newPersonAccount.SourceSystemIdentifier = 'CPN.TSTP00015.CPSID.GS';
        newPersonAccount.HealthCloudGA__SourceSystemId__pc = 'CPN.TSTP00015.CPSID.GS';
        //setIdentifier = (String)newPersonAccount.put('HealthCloudGA__SourceSystemId__pc', 'CPN.TSTP00015.CPSID.GS');

        newPersonAccounts.Add(newPersonAccount);
        
        Account newPersonAccount3 = new Account();
        newPersonAccount3.RecordTypeId = personAccountRecordTypeId;
        newPersonAccount3.FirstName = 'TESTONLYBCSC3_FIRST';
        newPersonAccount3.LastName = 'TESTONLYBCSC3_LAST';
        newPersonAccount3.PersonEmail = 'testusername3@me.com';
        newPersonAccount3.SourceSystemIdentifier = 'CPN.TSTP00016.CPSID.GS';
        newPersonAccount3.HealthCloudGA__SourceSystemId__pc = 'CPN.TSTP00016.CPSID.GS';
        //setIdentifier = (String)newPersonAccount3.put('HealthCloudGA__SourceSystemId__pc', 'CPN.TSTP00016.CPSID.GS');
        
        newPersonAccounts.Add(newPersonAccount3);

        Account newPersonAccount2 = new Account();
        newPersonAccount2.RecordTypeId = personAccountRecordTypeId;
        newPersonAccount2.FirstName = 'TESTONLYBCSC2_FIRST';
        newPersonAccount2.LastName = 'TESTONLYBCSC2_LAST';
        newPersonAccount2.PersonEmail = 'TESTONLYBCSC2@EMAIL.com';
        newPersonAccount2.SourceSystemIdentifier = 'GUID01';
        newPersonAccount2.HealthCloudGA__SourceSystemId__pc = 'GUID01';
        //setIdentifier = (String)newPersonAccount2.put('HealthCloudGA__SourceSystemId__pc', 'GUID01');

        newPersonAccounts.Add(newPersonAccount2);        

        Account newPersonAccount4 = new Account();
        newPersonAccount4.RecordTypeId = personAccountRecordTypeId;
        newPersonAccount4.FirstName = 'TESTONLYBCSC4_FIRST';
        newPersonAccount4.LastName = 'TESTONLYBCSC4_LAST';
        newPersonAccount4.PersonEmail = 'TESTONLYBCSC4@EMAIL.com';
        newPersonAccount4.SourceSystemIdentifier = 'GUID02';
        newPersonAccount4.HealthCloudGA__SourceSystemId__pc = 'GUID02';
        //setIdentifier = (String)newPersonAccount4.put('HealthCloudGA__SourceSystemId__pc', 'GUID02');

        newPersonAccounts.Add(newPersonAccount4);  

        Account newPersonAccount5 = new Account();
        newPersonAccount5.RecordTypeId = personAccountRecordTypeId;
        newPersonAccount5.FirstName = 'TESTONLYBCSC5_FIRST';
        newPersonAccount5.LastName = 'TESTONLYBCSC5_LAST';
        newPersonAccount5.PersonEmail = 'TESTONLYBCSC5@EMAIL.com';
        newPersonAccount5.SourceSystemIdentifier = 'BCSC01';
        //setIdentifier = (String)newPersonAccount4.put('HealthCloudGA__SourceSystemId__pc', 'GUID02');

        newPersonAccounts.Add(newPersonAccount5);      

        insert newPersonAccounts;
        
        Account fetchAccount = [
            SELECT Id, PersonContactId 
            FROM Account 
            WHERE PersonEmail = 'TESTONLY0@EMAIL.com'];        

        Group testGroup = new Group();
        testGroup.Name = 'Test_Group';
        insert testGroup;    
    }
  }

  @isTest
    public static void testUpdateCommunityeUser() {
    String uniqueUserName =
        'standarduser' +
        DateTime.now().getTime() +
        '@testorg.com';

    List<UserRole> userRole = [SELECT Id FROM UserRole];
    String userRoleId = userRole[0].Id;
    KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();

    Map<String,String> attribmap = new Map<String,String>();
    attribmap.put('roles', 'BCSC_TESTONLY');

    Auth.UserData sampleData = new Auth.UserData(
        'testId',
        'testFirst',
        'testLast',
        'testFirst testLast',
        'testuser@example.org',
        null,
        'testuserlong',
        'en_US',
        'facebook',
        null,
        attribmap
    );
    System.debug('sampleData:' + sampleData);
        test.startTest();
            verifyTestUser();
        test.stopTest();
        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {

            User u = handler.createUser(null, sampleData);
            System.assertEquals('testLast', u.lastName);
            System.assertEquals('testFirst', u.firstName);
            List<Auth.UserData> users = new List<Auth.UserData>();
            List<Id> ids = new List<Id>(); 
            ids.add(u.Id);
            users.add(sampleData);
            handler.updateUser(u.Id, null, sampleData);
            String uid = u.id;
        }
  
  }

  @isTest
    public static void testUpdateCommunityNewAccountUser() {
    String uniqueUserName =
        'standarduser' +
        DateTime.now().getTime() +
        '@testorg.com';

    List<UserRole> userRole = [SELECT Id FROM UserRole];
    String userRoleId = userRole[0].Id;
    KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();

    Map<String,String> attribmap = new Map<String,String>();
    attribmap.put('roles', 'BCSC_TESTONLY');

    Auth.UserData sampleData = new Auth.UserData(
        'testIdacct',
        'testFirstacct',
        'testLastacct',
        'testFirstacct testLastacct',
        'testuseracct@example.org',
        null,
        'testuserlongacct',
        'en_US',
        'IDP_USER',
        null,
        attribmap
    );
    System.debug('sampleData:' + sampleData);
        test.startTest();
            verifyTestUser();
        test.stopTest();
        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {

            User u = handler.createUser(null, sampleData);
            System.assertEquals('testLastacct', u.lastName);
            System.assertEquals('testFirstacct', u.firstName);
            List<Auth.UserData> users = new List<Auth.UserData>();
            List<Id> ids = new List<Id>(); 
            ids.add(u.Id);
            users.add(sampleData);
            handler.updateUser(u.Id, null, sampleData);
            String uid = u.id;
        }
  
  }

  @isTest
  public static void testCreateIdirUser() {
        String uniqueUserName =
            'standarduser' +
        DateTime.now().getTime() +
            '@testorg.com';

        List<UserRole> userRole = [SELECT Id FROM UserRole];
        String userRoleId = userRole[0].Id;
        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
        
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'SALESFORCE_TESTONLY');
        attribmap.put('email', 'test.last@gov.bc.ca');
        attribmap.put('family_name', 'TestLast');
        attribmap.put('given_name', 'TestFirst');
        attribmap.put('preferred_username', 'test@idir');
        attribmap.put('name', 'TestFirst TestLast');
        attribmap.put('email_verified', 'false');
        attribmap.put('sub', 'f6aac22a-03bd-4d08-a9de-1a050b0e2c15');

        Auth.UserData sampleData = new Auth.UserData(
            'f6aac22a-03bd-4d08-a9de-1a050b0e2c15',
            'TestFirst',
            'TestLast',
            'TestFirst TestLast',
            'test.last@gov.bc.ca',
            null,
            'test@idir',
            'en_CA',
            'Open ID Connect',
            null,
            attribmap
        );
        System.debug('sampleData:' + sampleData);

        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {

            User u = handler.createUser(null, sampleData);
            System.assertEquals('TestLast', u.lastName);
            System.assertEquals('TestFirst', u.firstName);
        }
  }

  @isTest
    public static void testCreatCPNUser() {
        String uniqueUserName =
            'standarduser' +
        DateTime.now().getTime() +
            '@testorg.com';
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        List<UserRole> userRole = [SELECT Id FROM UserRole];
        String userRoleId = userRole[0].Id;

        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();

        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'BCSC_TESTONLY');
        attribmap.put('pidp_email', 'testonly@bcsc.ca');
        attribmap.put('family_name', 'TestOnlyLast');
        attribmap.put('given_name', 'TestOnlyGiven');
        attribmap.put('common_provider_number', 'GUID01');
        attribmap.put('preferred_username', 'pidp.fifteen@bcprovidertest.onmicrosoft.com@bcp');
        attribmap.put('name', 'TestOnlyGiven TestOnlyLast');

        Auth.UserData sampleData = new Auth.UserData(
            'testIdComm',
            'testFirst',
            'testLast',
            'testFirst testLast',
            'testuserComm@example.org',
            null,
            'testonly@bcsc.ca',
            'en_US',
            'Open ID Connect',
            null,
            attribmap
        );
        System.debug('sampleData:' + sampleData);

        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {        
            User u = handler.createUser(null, sampleData);
            System.assertEquals('TestOnlyLast', u.lastName);
            System.assertEquals('TestOnlyGiven', u.firstName);
        }

  }

  @isTest
    public static void testCreateBCSCUser() {
        String uniqueUserName =
            'standarduser' +
            DateTime.now().getTime() +
            '@testorg.com';
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        List<UserRole> userRole = [SELECT Id FROM UserRole];
        String userRoleId = userRole[0].Id;
        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
        
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'BCSC_TESTONLY');
        attribmap.put('pidp_email', 'testonly@bcsc.ca');
        attribmap.put('family_name', 'TestOnlyLast');
        attribmap.put('given_name', 'TestOnlyGiven');
        attribmap.put('hdid','BCSC01');
        attribmap.put('idp','BCSC_TESTONLY');

        Auth.UserData sampleData = new Auth.UserData(
            'testIdComm',
            'testFirst',
            'testLast',
            'testFirst testLast',
            'testuserComm@example.org',
            null,
            'testusername@me.com',
            'en_US',
            'facebook',
            null,
            attribmap
        );
        System.debug('sampleData:' + sampleData);
        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {
            User u = handler.createUser(null, sampleData);
            System.assertEquals('TestOnlyLast', u.lastName);
            System.assertEquals('TestOnlyGiven', u.firstName);
        }

  }

  @isTest
    public static void testCreateProviderUser() {
        String uniqueUserName =
            'standarduser' +
        DateTime.now().getTime() +
            '@testorg.com';
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        List<UserRole> userRole = [SELECT Id FROM UserRole];
        String userRoleId = userRole[0].Id;
        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
      
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'BCSC_TESTONLY');
        attribmap.put('pidp_email', 'TESTONLYBCSC4@EMAIL.com');
        attribmap.put('family_name', 'TestOnlyLast');
        attribmap.put('given_name', 'TestOnlyGiven');
        attribmap.put('bcsc_guid','GUID02');
        attribmap.put('idp','BCSC_TESTONLY');

        Auth.UserData sampleData = new Auth.UserData(
            'testIdComm',
            'testFirst',
            'testLast',
            'testFirst testLast',
            'TESTONLYBCSC4@EMAIL.com',
            null,
            'TESTONLYBCSC4@EMAIL.com',
            'en_US',
            'facebook',
            null,
            attribmap
        );
        System.debug('sampleData:' + sampleData);

        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {
            User u = handler.createUser(null, sampleData);
            System.assertEquals('TestOnlyLast', u.lastName);
            System.assertEquals('TestOnlyGiven', u.firstName);
        }
  }

  @isTest
    public static void testCreateMOAEndorsereUser() {
        String uniqueUserName = 
            'standarduser' +
            DateTime.now().getTime() +
            '@testorg.com';
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        List<UserRole> userRole = [SELECT Id FROM UserRole];
        String userRoleId = userRole[0].Id;
        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
      
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'BCSC_TESTONLY');
        attribmap.put('pidp_email', 'testusername3@me.com');
        attribmap.put('family_name', 'TestOnlyLast');
        attribmap.put('given_name', 'TestOnlyGiven');
        attribmap.put('endorser_data','CPN.TSTP00016.CPSID.GS');
        attribmap.put('preferred_username', 'pidp.fifteen@bcprovidertest.onmicrosoft.com@bcp');
        attribmap.put('name', 'TestOnlyGiven TestOnlyLast');

        Auth.UserData sampleData = new Auth.UserData(
            'testIdComm',
            'testFirst',
            'testLast',
            'testFirst testLast',
            'testusername3@me.com',
            null,
            'testusername3@me.com',
            'en_US',
            'Open ID Connect',
            null,
            attribmap
        );
        System.debug('sampleData:' + sampleData);

        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {
            User u = handler.createUser(null, sampleData);
            System.assertEquals('TestOnlyLast', u.lastName);
            System.assertEquals('TestOnlyGiven', u.firstName);
        }

  }

    @isTest
    static void testCanCreateUser() {
    
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'SALESFORCE_TESTONLY');
        
        Auth.UserData sampleData = new Auth.UserData(
            'testId',
            'testFirst',
            'testLast',
            'testFirst testLast',
            null,
            null,
            null,
            'en_US',
            'facebook',
            null,
            attribmap
        );
        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {
            KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
            Boolean canCreate = handler.canCreateUser(sampleData);
            System.assert(!canCreate);
        }
    }

    @isTest
    static void testCreateUserExcep() {
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'SALESFORCE_TESTONLY');
    
        Auth.UserData sampleData = new Auth.UserData(
            'testId',
            'testFirst',
            'testLast',
            'testFirst testLast',
            'testuser@example.org',
            null,
            'testuserlong',
            'en_US',
            'facebook',
            null,
            null
        );

        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
        Boolean exceptionThrown = false;

        try {
            test.startTest();
                verifyTestUser();
            test.stopTest();

            User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
            System.runAs(runtimeUser) {
                handler.createUser(null, sampleData);
            }
        } catch(Exception e) {
            exceptionThrown = true;
        }

        System.assert(exceptionThrown);
    }
    
    @isTest
    static void testDoNotCreateUser() {
        Boolean exceptionThrown = false;
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'FAIL');
    
        Auth.UserData sampleData = new Auth.UserData(
            'testId',
            'testFirst',
            'testLast',
            'testFirst testLast',
            'testuser@example.org',
            'Someone',
            'Someoneelse',
            'en_US',
            'facebook',
            null,
            attribmap
        );

        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {
            KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
            try {
                User user = handler.createUser(null, sampleData);
            } catch(Exception e) {
                exceptionThrown = true;
            }
            
            System.assert(exceptionThrown);
        }
    }
    
    @isTest
    static void testCreateUserExistingUser() {
        User currentUser = [Select Id, LastName, FirstName From User Where Id = :UserInfo.getUserId()];
        String testID = 'TEST_IDENTIFIER_1';
        update currentUser;
        
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'SALESFORCE_TESTONLY');

        Auth.UserData sampleData = new Auth.UserData(
            testID,
            'testFirst',
            'testLast',
            'testFirst testLast',
            'testuser@example.org',
            'Someone',
            'Someoneelse',
            'en_US',
            'facebook',
            null,
            attribmap
        );

        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {        
            KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
            User user = handler.createUser(null, sampleData);
            
            System.assert(user.Id != null);
        }
    }
    
    @isTest
    static void testUpdateUser() {
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'SALESFORCE_TESTONLY');
    
        Auth.UserData sampleData = new Auth.UserData(
            'testId',
            'testFirst',
            'testLast',
            'testFirst testLast',
            'testuser@example.org',
            'Someone',
            'Someoneelse',
            'en_US',
            'facebook',
            null,
            attribmap
        );

        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {
            KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
            handler.updateUser(UserInfo.getUserId(), null, sampleData);
            
            User user = [Select Id, LastName, FirstName From User Where Id = :UserInfo.getUserId()];
            System.assert(user.LastName == sampleData.lastName);
            System.assert(user.FirstName == sampleData.firstName);
        }
    }
    
    @isTest
    static void testUpdateUserExcep() {
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'SALESFORCE_TESTONLY');
    
        Auth.UserData sampleData = new Auth.UserData(
            'testId',
            'testFirst',
            'testLast',
            'testFirst testLast',
            'testuser@example.org',
            'Someone',
            'Someoneelse',
            'en_US',
            'facebook',
            null,
            attribmap
        );

        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {
            KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
            Boolean exceptionThrown = false;

            try {
                handler.updateUser(null, null, sampleData);
            } catch(Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }
    
    @isTest
    static void testFetchUserMappingData() {
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility();
        UserRegistrationCustomMetadataUtility loadRoles = new UserRegistrationCustomMetadataUtility('SALESFORCE_TESTONLY');

        List<IDP_User_Registration_Permission_Set__mdt> fetchRoles = loadRoles.ReadPermissionSet('SALESFORCE_TESTONLY');
        system.assert(fetchRoles != null);
    }
    
    @isTest
    static void testCheckAvailableLicense() {
        
        Boolean currentLicense = UserRegistrationService.checkAvailableLicense('Salesforce');
        
        system.assert(currentLicense == true);
    }
    
    @isTest
    static void testFetchlicenseType() {
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'SALESFORCE_TESTONLY');
    
        Auth.UserData sampleData = new Auth.UserData(
        'testId',
        'testFirst',
        'testLast',
        'testFirst testLast',
        'testuser@example.org',
        'Someone',
        'Someoneelse',
        'en_US',
        'facebook',
        null,
        attribmap
        );

        String currentLicense = UserRegistrationService.fetchLicenseType(sampleData);
        
        system.assert(currentLicense == 'Salesforce');
    }
    @Future
    public static void verifyTestUser() {

        if (RUN_TIME_USER.Id == null) {
            UserRole userRole = new UserRole(Name='TestRoleOnly');
            Insert userRole;
            //runningUser.UserRoleId = userRole.Id;

            String uniqueUserName =
            'standarduser' +
            DateTime.now().getTime() +
            '@testorg.com';
    
            Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];

            User runningUser = new User(
                Alias = 'standt',
                Email = 'systemuser@testorg.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Testing',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_CA',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = uniqueUserName,
                UserRoleId = userRole.Id
            );

            Insert runningUser;
            RUN_TIME_USER = runningUser;
        }
        
    }
}