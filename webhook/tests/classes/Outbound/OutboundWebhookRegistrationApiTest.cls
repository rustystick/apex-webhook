/**
 * @description tests webhook registration api
 * @author Andi Xie
 */
@isTest
private class OutboundWebhookRegistrationApiTest {
    static String urlMapping = '/services/apexrest/webhook/v1/registration';
    static String endPoint = URL.getSalesforceBaseUrl() + urlMapping;
    static final List<String> DEFAULT_TEST_EVENT_TYPE = new List<String>{ 'event1', 'event2' };
    static final Map<String, String> DEFAULT_TEST_HEADER = new Map<String, String>{ 'Content-Type' => 'application/json' };
    static final String DEFAULT_TEST_SUBSCRIBER_URLS = WebhookTestFactory.TEST_BASE_URL;
    static final string STATUS_PENDING_CONFIRMATION = 'Pending Confirmation';
    static final Integer URL_MAX_LENGTH = OutboundWebhookApiService.URL_MAX_LENGTH;

    @TestSetup
    static void makeData() {
        User webhookUser = WebhookTestFactory.createUserWithWebhookPS();
        System.runAs(webhookUser) {
            List<Webhook_Registration__c> listeners = WebhookTestFactory.getListeners(1, DEFAULT_TEST_EVENT_TYPE[0]);
            insert listeners;
        }
    }

    /**
     * @description test POST method on webhook registration endpoint
     * GIVEN: conforming request with no duplicate records in db; test callout was successful
     * WHEN: POST method is called
     * THEN: should not have any error and webhook registration record should be created
     */
    @IsTest
    static void testPostWebhookRegistration() {
        OutboundWebhookApiService.WebhookRegistrationRequest request = new OutboundWebhookApiService.WebhookRegistrationRequest();
        request.event = DEFAULT_TEST_EVENT_TYPE[1];
        request.url = DEFAULT_TEST_SUBSCRIBER_URLS;
        request.headers = DEFAULT_TEST_HEADER;
        User webhookUser = WebhookTestFactory.getWebhookUser();
        RestContext.request = new RestRequest();
        RestContext.request.httpMethod = Webhook_Constants.HTTP_POST;
        RestContext.response = new RestResponse();
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new OutboundWebhookMock(Webhook_Constants.HTTP_SUCCESS_OK));
        System.runAs(webhookUser) {
            OutboundWebhookApiService.WebhookApiResponse response = OutboundWebhookApiService.registerWebhook(request);
            system.assert(response.hasError == false, 'should not have error');
        }
        Test.stopTest();
        List<Webhook_Registration__c> regs = WebhookTestFactory.getAllExistingListeners(request.event);
        system.assert(regs.size() > 0, 'registration should be created');
    }

    /**
     * @description test the POST method on webhook registration endpoint when test callout receive a error status code
     * GIVEN: conforming request with no duplicate records in db; test callout received Webhook_Constants.HTTP_ERROR_NOT_FOUND error code
     * WHEN: POST method is called
     * THEN: registration should be created but with pending status. Registration data is returned to caller, and should include info message in the response
     */ 
    @IsTest
    static void testPostWebhookRegistrationCallOutReturnErrorStatus() {
        OutboundWebhookApiService.WebhookRegistrationRequest request = new OutboundWebhookApiService.WebhookRegistrationRequest();
        request.event = DEFAULT_TEST_EVENT_TYPE[1];
        request.url = DEFAULT_TEST_SUBSCRIBER_URLS;
        request.headers = DEFAULT_TEST_HEADER;
        User webhookUser = WebhookTestFactory.getWebhookUser();
        RestContext.request = new RestRequest();
        RestContext.request.httpMethod = Webhook_Constants.HTTP_POST;
        RestContext.response = new RestResponse();
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new OutboundWebhookMock(Webhook_Constants.HTTP_ERROR_NOT_FOUND));
        System.runAs(webhookUser) {
            OutboundWebhookApiService.WebhookApiResponse response = OutboundWebhookApiService.registerWebhook(request);
            system.assert(response.hasError == true, 'should have error since server returned error messages');
            system.assertEquals(Webhook_Constants.HTTP_SUCCESS_CREATED,RestContext.response.statusCode,'should receive 201 created http status');
        }
        Test.stopTest();
        List<Webhook_Registration__c> regs = WebhookTestFactory.getAllExistingListeners(request.event);
        system.assert(regs.size() > 0, 'registration should be created');
    }
    
    /*
    * @description test the POST method on webhook registration endpoint where another registration already exist with same callback url and event
    * GIVEN: registration exist with same callout url and event
    * WHEN: POST method is called
    * THEN: no new registration record should be created, no registration data should be returned, and error message should be returned to caller
    */
    @IsTest
    static void testPostWebhookRegistrationDuplicate() {
        OutboundWebhookApiService.WebhookRegistrationRequest request = new OutboundWebhookApiService.WebhookRegistrationRequest();
        request.event = DEFAULT_TEST_EVENT_TYPE[0];
        request.url = DEFAULT_TEST_SUBSCRIBER_URLS;
        request.headers = DEFAULT_TEST_HEADER;
        User webhookUser = WebhookTestFactory.getWebhookUser();
        RestContext.request = new RestRequest();
        RestContext.request.httpMethod = Webhook_Constants.HTTP_POST;
        RestContext.response = new RestResponse();
        Test.startTest();
        System.runAs(webhookUser) {
            OutboundWebhookApiService.WebhookApiResponse response = OutboundWebhookApiService.registerWebhook(request);
            system.assert(response.hasError == true, 'should have error since server returned error status code');
            system.assert(response.registrationData == null, 'should not return any registration data');
            system.assertEquals(Webhook_Constants.HTTP_ERROR_BAD_REQUEST,RestContext.response.statusCode, 'Server should return 400 status code');
        }
        Test.stopTest();
        List<Webhook_Registration__c> regs = WebhookTestFactory.getAllExistingListeners(request.event);
        system.assert(regs.size() == 1, 'no new registration should be created');
    }

    /**
    * @description test the POST method on webhook registration endpoint when request url is too long
    * GIVEN: request body with url length > max length
    * WHEN: POST method is called
    * THEN: no new registration record should be created, length too long error should be returned to caller
    */
    @IsTest
    static void testPostWebhookRegistrationUrlTooLong() {
        OutboundWebhookApiService.WebhookRegistrationRequest request = new OutboundWebhookApiService.WebhookRegistrationRequest();
        request.event = DEFAULT_TEST_EVENT_TYPE[1];
        request.url = 'http://' + makeLongString(URL_MAX_LENGTH);
        request.headers = DEFAULT_TEST_HEADER;
        User webhookUser = WebhookTestFactory.getWebhookUser();
        RestContext.request = new RestRequest();
        RestContext.request.httpMethod = Webhook_Constants.HTTP_POST;
        RestContext.response = new RestResponse();
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new OutboundWebhookMock(Webhook_Constants.HTTP_SUCCESS_OK));
        System.runAs(webhookUser) {
            OutboundWebhookApiService.WebhookApiResponse response = OutboundWebhookApiService.registerWebhook(request);
            system.assert(response.hasError == true, 'should have error since server returned error status');
            system.debug(response);
            system.assertEquals(Webhook_Constants.HTTP_ERROR_BAD_REQUEST, RestContext.response.statusCode, 'should receive 400 status code');
        }
        Test.stopTest();
        List<Webhook_Registration__c> regs = WebhookTestFactory.getAllExistingListeners(request.event);
        system.assertEquals(regs.size(), 0, 'no new registration should be created');
    }

    /**
     * @description test the DELETE method on webhook registration endpoint 
     * GIVEN: registration exist in db, caller has id in path parameter
     * WHEN: DELETE is called
     * THEN: record should be deleted and no error should be returned
     */ 
    @IsTest
    static void testDeleteRegistration() {
        Webhook_Registration__c listener = WebhookTestFactory.getAllExistingListeners(DEFAULT_TEST_EVENT_TYPE[0])[0];
        User webhookUser = WebhookTestFactory.getWebhookUser();
        RestContext.request = new RestRequest();
        RestContext.request.httpMethod = Webhook_Constants.HTTP_DELETE;
        RestContext.request.requestURI = urlMapping + '/' + listener.Id;
        RestContext.response = new RestResponse();
        Test.startTest();
        System.runAs(webhookUser) {
            OutboundWebhookApiService.WebhookApiResponse response = OutboundWebhookApiService.deleteRegistration();
            system.assert(response.hasError == false, 'should not have error since server returned error status code');
            system.assert(response.registrationData == null, 'should not return any registration data');
        }
        Test.stopTest();
        List<Webhook_Registration__c> regs = WebhookTestFactory.getAllExistingListeners(DEFAULT_TEST_EVENT_TYPE[0]);
        system.assert(regs.size() == 0, 'registration should be deleted');
        system.assertEquals(Webhook_Constants.HTTP_SUCCESS_DELETED,RestContext.response.statusCode, 'should receive 204 status code for successful delete request');
    }

    /**
     * @description test the GET method on webhook registration endpoint 
     * GIVEN: registration exist in db, caller has id in path parameter
     * WHEN: GET is called
     * THEN: record should be returned
     */ 
    @IsTest
    static void testGetRegistration() {
        Webhook_Registration__c listener = WebhookTestFactory.getAllExistingListeners(DEFAULT_TEST_EVENT_TYPE[0])[0];
        User webhookUser = WebhookTestFactory.getWebhookUser();
        RestContext.request = new RestRequest();
        RestContext.request.httpMethod = Webhook_Constants.HTTP_GET;
        RestContext.request.requestURI = urlMapping + '/' + listener.Id;
        RestContext.response = new RestResponse();
        Test.startTest();
        System.runAs(webhookUser) {
            OutboundWebhookApiService.WebhookApiResponse response = OutboundWebhookApiService.getWebhookRegistration();
            system.assert(response.hasError == false, 'should not have error since server returned error status code');
            system.assert(response.registrationData != null, 'should return registration data');
            system.assertEquals(Webhook_Constants.HTTP_SUCCESS_OK, RestContext.response.statusCode, 'should receive 200 status code');
        }
        Test.stopTest();
    }

    /**
     * @description test the PUT method on webhook registration endpoint 
     * GIVEN: registration exist in db, caller has id in path parameter, body contains the status and header to update
     * WHEN: PUT is called
     * THEN: record should be returned with those 2 fields updated
     */ 
    @IsTest
    static void testUpdateRegistration() {
        Webhook_Registration__c listener = WebhookTestFactory.getAllExistingListeners(DEFAULT_TEST_EVENT_TYPE[0])[0];
        User webhookUser = WebhookTestFactory.getWebhookUser();
        Map<String, String> headerToUpdate = new Map<String, String>{ 'testKey' => 'testValue' };
        String statusToUpdate = STATUS_PENDING_CONFIRMATION;
        RestContext.request = new RestRequest();
        RestContext.request.httpMethod = Webhook_Constants.HTTP_PUT;
        RestContext.request.requestURI = urlMapping + '/' + listener.Id;
        RestContext.response = new RestResponse();
        OutboundWebhookApiService.WebhookRegistrationPutRequest updateRequest = new OutboundWebhookApiService.WebhookRegistrationPutRequest();
        updateRequest.status = statusToUpdate;
        updateRequest.headers = headerToUpdate;
        Test.startTest();
        System.runAs(webhookUser) {
            OutboundWebhookApiService.WebhookApiResponse response = OutboundWebhookApiService.updateWebhookRegistration(updateRequest);
            system.assert(response.hasError == false, 'should not have error since server returned error status code');
            system.assert(response.registrationData != null, 'should return registration data');
        }
        Test.stopTest();
        listener = WebhookTestFactory.getAllExistingListeners(DEFAULT_TEST_EVENT_TYPE[0])[0];
        system.assertEquals(statusToUpdate, listener.Status__c);
        system.assertEquals(JSON.serialize(headerToUpdate), listener.Header__c);
    }

    static String makeLongString(Integer length) {
        String s = '';
        for (integer i = 0; i < length; i++) {
            s += 's';
        }
        return s;
    }
}