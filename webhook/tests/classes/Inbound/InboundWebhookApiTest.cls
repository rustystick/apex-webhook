/**
 * @description tests for receiving arbitrary webhooks
 */
@isTest
private class InboundWebhookApiTest {
    static final String PATH_TEST_NAME = 'test';
    static final String SIGNATURE_HEADER_NAME = 'signature';
    static final String SHARED_SECRET = 'lpyXhWccim00noKygPea7GJ/OjEt2yi7wyURfuZuV98=';
    static final String BASE_PATH_INCOMING_WEBHOOK = '/webhook/v1/listener/';
    @TestSetup
    static void makeData() {
        User webhookUser = WebhookTestFactory.createUserWithInboundWebhookPS();
    }

    /**
     * @description positive test case where processor publish a platform event with the incoming body
     * GIVEN: Inbound Webhook Setting exist with shared secret configured
     * WHEN: Valid webhook request with signature is sent to the endpoint via POST method
     * THEN: a Inbound_Webhook__e platform event is fired
     */
    @IsTest
    static void testSuccessfulWebhookPublishPlatformEvent() {
        User contextuser = WebhookTestFactory.getWebhookUser();
        RestResponse response = new RestResponse();
        RestRequest request = new RestRequest();
        WebhookTestFactory.createInboundWebhookRegistration(
            PATH_TEST_NAME,
            SIGNATURE_HEADER_NAME,
            SHARED_SECRET,
            Webhook_Constants.HASHING_ALGO_HMAC_SHA256
        );
        Request.requestURI = BASE_PATH_INCOMING_WEBHOOK + PATH_TEST_NAME;
        RestContext.request = request;
        RestContext.response = response;
        TestIncomingWebhookBody body = new TestIncomingWebhookBody('testEvent', 'rejected');
        TestIncomingWebhook webhook = new TestIncomingWebhook(body, request);
        webhook.sign(SHARED_SECRET);
        webhook.updateRequest();
        Test.startTest();
        InboundWebhookService.InboundWebhookResponse callResponse;
        System.runAs(contextuser) {
            callResponse = InboundWebhookService.newEvent();
        }
        Test.stopTest();
        System.assertEquals(Webhook_Constants.HTTP_SUCCESS_CREATED, response.statusCode, 'Response status code should be 201');
        System.assertEquals(
            1,
            InboundWebhook.eventsReceived,
            'Apex platform event listener should received 1 inbound webhook platform event'
        );
    }

    /**
     * @description positive test case where shared secret is configured to be empty
     * GIVEN: Inbound Webhook Setting exist with shared secret configured to be empty
     * WHEN: Webhook request is POST-ed to the endpoint
     * THEN: a Inbound_Webhook__e platform event is fired
     */
    @IsTest
    static void testNullSharedSecret() {
        User contextuser = WebhookTestFactory.getWebhookUser();
        RestResponse response = new RestResponse();
        RestRequest request = new RestRequest();
        WebhookTestFactory.createInboundWebhookRegistration(
            PATH_TEST_NAME,
            SIGNATURE_HEADER_NAME,
            '',
            Webhook_Constants.HASHING_ALGO_HMAC_SHA256
        );
        Request.requestURI = BASE_PATH_INCOMING_WEBHOOK + PATH_TEST_NAME;
        RestContext.request = request;
        RestContext.response = response;
        TestIncomingWebhookBody body = new TestIncomingWebhookBody('testEvent', 'rejected');
        TestIncomingWebhook webhook = new TestIncomingWebhook(body, request);
        webhook.updateRequest();
        Test.startTest();
        InboundWebhookService.InboundWebhookResponse callResponse;
        System.runAs(contextuser) {
            try{
                callResponse = InboundWebhookService.newEvent();
            }catch(Exception ex){
            }
        }
        Test.stopTest();
        System.assertEquals(
            1,
            InboundWebhook.eventsReceived,
            'Apex platform event listener should received 1 inbound webhook platform event'
        );
        System.assertEquals(Webhook_Constants.HTTP_SUCCESS_CREATED, response.statusCode, 'Response status should be 201');
    }

    /**
     * @description negative test case where there is no setting available with the given path
     * GIVEN: Inbound webhook setting does not exist with the intended path parameter
     * WHEN: Endpoint is called
     * THEN: receive error response
     */
    @IsTest
    static void testInvalidPathResponse() {
        User contextuser = WebhookTestFactory.getWebhookUser();
        RestResponse response = new RestResponse();
        RestRequest request = new RestRequest();
        WebhookTestFactory.createInboundWebhookRegistration(
            PATH_TEST_NAME,
            SIGNATURE_HEADER_NAME,
            SHARED_SECRET,
            Webhook_Constants.HASHING_ALGO_HMAC_SHA256
        );
        Request.requestURI = BASE_PATH_INCOMING_WEBHOOK + PATH_TEST_NAME + 'wrongpath';
        RestContext.request = request;
        RestContext.response = response;
        TestIncomingWebhookBody body = new TestIncomingWebhookBody('testEvent', 'rejected');
        TestIncomingWebhook webhook = new TestIncomingWebhook(body, request);
        webhook.sign(SHARED_SECRET);
        webhook.updateRequest();
        Test.startTest();
        InboundWebhookService.InboundWebhookResponse callResponse;
        System.runAs(contextuser) {
            callResponse = InboundWebhookService.newEvent();
        }
        Test.stopTest();
        System.assertEquals(Webhook_Constants.HTTP_ERROR_BAD_REQUEST, response.statusCode, 'Response status should be 400');
        System.assertEquals('InboundWebhookService.InvalidWebhookPathException', InboundWebhookService.exceptionType);
    }

    /**
     * @description negative test case where signature is invalid for an incoming webhook request
     * GIVEN: setting exist for the intended path parameter with shared secret configured
     * WHEN: endpoint called with an invalid signature
     * THEN: receive error response
     */
    @IsTest
    static void testBadSignature() {
        User contextuser = WebhookTestFactory.getWebhookUser();
        RestResponse response = new RestResponse();
        RestRequest request = new RestRequest();
        WebhookTestFactory.createInboundWebhookRegistration(
            PATH_TEST_NAME,
            SIGNATURE_HEADER_NAME,
            SHARED_SECRET,
            Webhook_Constants.HASHING_ALGO_HMAC_SHA256
        );
        Request.requestURI = BASE_PATH_INCOMING_WEBHOOK + PATH_TEST_NAME;
        RestContext.request = request;
        RestContext.response = response;
        TestIncomingWebhookBody body = new TestIncomingWebhookBody('testEvent', 'rejected');
        TestIncomingWebhook webhook = new TestIncomingWebhook(body, request);
        webhook.sign(SHARED_SECRET + 'bad');
        webhook.updateRequest();
        Test.startTest();
        InboundWebhookService.InboundWebhookResponse callResponse;
        System.runAs(contextuser) {
            callResponse = InboundWebhookService.newEvent();
        }
        Test.stopTest();
        System.assertEquals(Webhook_Constants.HTTP_ERROR_BAD_REQUEST, response.statusCode, 'Response status should be 400');
        System.assertEquals('InboundWebhookService.InvalidWebhookSignatureException', InboundWebhookService.exceptionType);
    }

    /**
     * @description negative test case where the request body contains an empty 'event' string attribute
     * GIVEN: setting exist for the intended path parameter with shared secret configured
     * WHEN: endpoint called with a body with an empty 'event' attribute
     * THEN: receive error response
     */
    @IsTest
    static void testEmptyEventName() {
        User contextuser = WebhookTestFactory.getWebhookUser();
        RestResponse response = new RestResponse();
        RestRequest request = new RestRequest();
        WebhookTestFactory.createInboundWebhookRegistration(
            PATH_TEST_NAME,
            SIGNATURE_HEADER_NAME,
            SHARED_SECRET,
            Webhook_Constants.HASHING_ALGO_HMAC_SHA256
        );
        Request.requestURI = BASE_PATH_INCOMING_WEBHOOK + PATH_TEST_NAME;
        RestContext.request = request;
        RestContext.response = response;
        TestIncomingWebhookBody body = new TestIncomingWebhookBody('', 'rejected');
        TestIncomingWebhook webhook = new TestIncomingWebhook(body, request);
        webhook.sign(SHARED_SECRET);
        webhook.updateRequest();
        Test.startTest();
        InboundWebhookService.InboundWebhookResponse callResponse;
        System.runAs(contextuser) {
            callResponse = InboundWebhookService.newEvent();
        }
        Test.stopTest();
        System.assertEquals(Webhook_Constants.HTTP_ERROR_BAD_REQUEST, response.statusCode, 'Response status should be 400');
        System.assertEquals('InboundWebhookService.InvalidWebhookBodyException', InboundWebhookService.exceptionType);
    }

    /**
     * @description negative test case where the request body contains a 'event' attribute but it's not string type
     * GIVEN: setting exist for the intended path parameter with shared secret configured
     * WHEN: endpoint called with a body with an 'event' attribute that is object type
     * THEN: receive error response
     */
    @IsTest
    static void testBadEventAttributeType() {
        User contextuser = WebhookTestFactory.getWebhookUser();
        RestResponse response = new RestResponse();
        RestRequest request = new RestRequest();
        WebhookTestFactory.createInboundWebhookRegistration(
            PATH_TEST_NAME,
            SIGNATURE_HEADER_NAME,
            SHARED_SECRET,
            Webhook_Constants.HASHING_ALGO_HMAC_SHA256
        );
        Request.requestURI = BASE_PATH_INCOMING_WEBHOOK + PATH_TEST_NAME;
        RestContext.request = request;
        RestContext.response = response;
        Map<String, Object> body = new Map<String, Object>();
        Map<String, String> eventObj = new Map<String, String>{ 'attribute 1' => 'value1' };
        body.put('type', eventObj);
        TestIncomingWebhook webhook = new TestIncomingWebhook(body, request);
        webhook.sign(SHARED_SECRET);
        webhook.updateRequest();
        Test.startTest();
        InboundWebhookService.InboundWebhookResponse callResponse;
        System.runAs(contextuser) {
            callResponse = InboundWebhookService.newEvent();
        }
        Test.stopTest();
        System.assertEquals(Webhook_Constants.HTTP_ERROR_BAD_REQUEST, response.statusCode, 'Response status should be 400');
        System.assertEquals('InboundWebhookService.InvalidWebhookBodyException', InboundWebhookService.exceptionType);
    }

    class TestIncomingWebhook {
        Blob body;
        String signature;
        RestRequest request;
        public TestIncomingWebhook(Object body, RestRequest request) {
            this.body = Blob.valueOf(JSON.serialize(body));
            this.request = request;
        }
        void sign(String sharedSecret) {
            Blob signedBlob = Crypto.generateMac(Webhook_Constants.HASHING_ALGO_HMAC_SHA256, body, EncodingUtil.base64Decode(sharedSecret));
            signature = EncodingUtil.base64Encode(signedBlob);
        }
        void updateRequest() {
            request.httpMethod = Webhook_Constants.HTTP_POST;
            request.requestBody = body;
            request.headers.put(SIGNATURE_HEADER_NAME, signature == null ? '' : signature);
        }
    }

    class TestIncomingWebhookBody {
        String type;
        String disposition;
        public TestIncomingWebhookBody(String type, String disposition) {
            this.type = type;
            this.disposition = disposition;
        }
    }
}
