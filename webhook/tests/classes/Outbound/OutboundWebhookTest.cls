/**
 * @description test class to fire webhook with tring body
 * @author Andi Xie
 */
@isTest
private class OutboundWebhookTest {
    static List<String> defaultEventTypes = new List<String>{ 'event1', 'event2' };
    static String defaultUrl = 'https://test.com';

    @TestSetup
    static void makeData() {
        List<Webhook_Registration__c> listeners = new List<Webhook_Registration__c>();
        for (String listener : defaultEventTypes) {
            listeners.addAll(WebhookTestFactory.getListeners(1, listener));
        }
        insert listeners;
    }

    /**
     * @description test the number of callout matches the expectation
     * GIVEN: 3 subscription entries but only with 2 distinct endpoints (1 endpoint subscribes to event1 and the other subscribes to both 1 and 2)
     * WHEN: event1 and event2 fires
     * THEN: 3 callouts should be made
     */
    @IsTest
    static void testPubSub() {
        List<Webhook_Registration__c> regs = WebhookTestFactory.getAllExistingListeners(defaultEventTypes[0]);
        insert WebhookTestFactory.getListener(regs[0], defaultEventTypes[0]);
        OutboundWebhookMock mock = new OutboundWebhookMock();
        List<Outbound_Webhook__e> events = WebhookTestFactory.getEvents(1, defaultEventTypes[0], null);
        events.addAll(WebhookTestFactory.getEvents(1, defaultEventTypes[1], null));
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        Eventbus.publish(events);
        Test.getEventBus().deliver();
        Test.stopTest();
        system.assertEquals(3, mock.getCalloutCount());
    }

    /**
     * @description test the outbound webhook event fires with the body of the platform event
     * GIVEN: 2 subscribers (assuming different callback urls), both subscribed to event1
     * WHEN: 2 event1 fire with different bodies,
     * THEN: both listener should receive 2 callouts with correct bodies
     */
    @IsTest
    static void testBodyTargeting() {
        String testEventName = OutboundWebhookTest.defaultEventTypes[0];
        List<String> testBodies = new List<String>{ 'body1', 'body2' };
        Integer noListeners = 0;
        Map<String, Webhook_Registration__c> urlWebhookRegistrationMap = new Map<String, Webhook_Registration__c>();
        // add second listener
        Webhook_Registration__c secondListener = WebhookTestFactory.getListener(testEventName, defaultUrl, null, null);
        insert secondListener;
        List<Webhook_Registration__c> listeners = WebhookTestFactory.getAllExistingListeners();
        for (Webhook_Registration__c listener : listeners) {
            urlWebhookRegistrationMap.put(listener.Callback_Url__c, listener);
        }
        OutboundWebhookMock mock = new OutboundWebhookMock();
        List<Outbound_Webhook__e> events = WebhookTestFactory.getEvents(testBodies.size(), testEventName, testBodies);
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        Eventbus.publish(events);
        Test.getEventBus().deliver();
        Test.stopTest();
        for (Webhook_Registration__c listener : listeners) {
            if (listener.Event__c == testEventName) {
                noListeners++;
                List<OutboundWebhookMock.SerializedStringDataBody> calloutRequests = mock.getCalloutBodies(listener.Callback_Url__c);
                for (Integer i = 0; i < testBodies.size(); i++) {
                    System.assert(
                        testBodies[i] == calloutRequests[i].data,
                        'the outbound webhook body and the fired platform even body should match'
                    );
                }
            }
        }
        // no of events * no of listeners for that event
        Integer expectedCallOuts = testBodies.size() * noListeners;
        System.assertEquals(expectedCallOuts, mock.getCalloutCount());
    }

    /**
     * @description test the signature of data with string body;
     * GIVEN A platform event is fired with an active listener with shared secret
     * WHEN The webhook message fires
     * THEN the body should be signed with the shared secret via the defined hashing function
     */
    @IsTest
    static void testSignatureWithStringData() {
        List<String> testBodies = new List<String>{ 'body1' };
        String testEventName = OutboundWebhookTest.defaultEventTypes[0];
        List<Outbound_Webhook__e> events = WebhookTestFactory.getEvents(testBodies.size(), testEventName, testBodies);
        OutboundWebhookMock mock = new OutboundWebhookMock();
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        Eventbus.publish(events);
        Test.getEventBus().deliver();
        Test.stopTest();
        List<Webhook_Registration__c> listeners = WebhookTestFactory.getAllExistingListeners(testEventName);
        Webhook_Registration__c listener = listeners[0];
        String sharedSecret = listener.Shared_Secret__c;
        OutboundWebhookMock.SerializedStringDataBody outboundWebhookBody = mock.getCalloutBodies(listener.Callback_Url__c)[0];
        String outboundSignature = mock.getCalloutRequests(listener.Callback_Url__c)[0]
            .getHeader(OutboundWebhookWrapper.SIGNATURE_HEADER_KEY);
        String signature = EncodingUtil.base64Encode(
            Crypto.generateMac(
                OutboundWebhookWrapper.SIGNATURE_ALGO,
                Blob.valueOf(JSON.serialize(outboundWebhookBody)),
                EncodingUtil.base64Decode(sharedSecret)
            )
        );
        System.assertEquals(signature, outboundSignature, 'signature should be the same');
    }

    /**
     * @description test callout with a receipient with custom header set
     * GIVEN: Evenet listener with header JSON value
     * WHEN: Applicable event fires
     * THEN: The callout request should contain such custom header
     */
    @IsTest
    static void testCustomSubscriberHeader() {
        String eventName = 'WithHeader';
        Map<String, String> customHeader = new Map<String, String>{ 'header1' => 'value1', 'header2' => 'value2' };
        Webhook_Registration__c listener = WebhookTestFactory.getListener(eventName, defaultUrl, null, customHeader);
        insert listener;
        OutboundWebhookMock mock = new OutboundWebhookMock();
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        List<Outbound_Webhook__e> events = WebhookTestFactory.getEvents(1, eventName, new List<String>{ 'body' });
        Eventbus.publish(events);
        Test.getEventBus().deliver();
        Test.stopTest();
        HttpRequest calloutRequest = mock.getCalloutRequests(defaultUrl)[0];
        for (String key : customHeader.keySet()) {
            System.assertEquals(calloutRequest.getHeader(key), customHeader.get(key));
        }
    }
}
