/**
 * @description test inbound webhook processing
 */
@isTest
public class InboundWebhookTest {
    static Boolean mockHandlerRan = false;
    static Boolean mockHandler2Ran = false;
    static Boolean mockHandlerThrowException = false;
    static final String MOCK_EVENT_NAME = 'mockEvent';

    /**
     * @description test the event handler execution logic
     * GIVEN: An event handler apex class exist within the org Extending the InboundWebhookEventHandler class
     * WHEN: A event is fired with the event type matching the event handler
     * THEN: the event handler's handleEvent methods should run for that particular event
     */
    @IsTest
    static void testEventHandlerExecution() {
        MockInboundWebhookHandler mockHandler = new MockInboundWebhookHandler();
        InboundWebhook.setHandler(mockHandler.getClassName());
        Inbound_Webhook__e event = new Inbound_Webhook__e(
            Event_Type__c = mockHandler.getEventTypeName(),
            Event_Body__c = 'dummyBody'
        );
        Test.startTest();
        EventBus.publish(event);
        Test.getEventBus().deliver();
        Test.stopTest();
        System.assertEquals(true, mockHandlerRan);
    }

    /**
     * @description test the chaining logic when there are multiple Webhook Handlers present within the org
     * GIVEN: There are 2 webhook handler classes within an org
     * WHEN: Inbound webhook event is fired
     * THEN: handleEvent method from both classes should execute 
     */ 
    @IsTest
    static void testChaining() {
        startWebhookProcessorSynchronously();
        MockInboundWebhookHandler mockHandler = new MockInboundWebhookHandler();
        MockInboundWebhookHandler2 mockHandler2 = new MockInboundWebhookHandler2();
        InboundWebhook.setHandler(new List<String>{ mockHandler.getClassName(), mockHandler2.getClassName() });
        Inbound_Webhook__e event = new Inbound_Webhook__e(
            Event_Type__c = mockHandler.getEventTypeName(),
            Event_Body__c = 'dummyBody'
        );
        Test.startTest();
        Eventbus.publish(event);
        Test.getEventBus().deliver();
        Test.stopTest();

        System.assertEquals(true, mockHandlerRan);
        System.assertEquals(true, mockHandler2Ran);
    }

    @IsTest
    static void testSObjectToInsertIfException(){
        startWebhookProcessorSynchronously();
        mockHandlerThrowException = true;
        MockInboundWebhookHandler mockHandler = new MockInboundWebhookHandler();
        MockInboundWebhookHandler2 mockHandler2 = new MockInboundWebhookHandler2();
        InboundWebhook.setHandler(new List<String>{ mockHandler.getClassName(), mockHandler2.getClassName() });
        Inbound_Webhook__e event = new Inbound_Webhook__e(
            Event_Type__c = mockHandler.getEventTypeName(),
            Event_Body__c = 'dummyBody'
        );
        Test.startTest();
        Eventbus.publish(event);
        Test.getEventBus().deliver();
        Test.stopTest();

        System.assertEquals(true, mockHandlerRan);
        System.assertEquals(true, mockHandler2Ran);
        System.assertEquals(1, [SELECT Id FROM Webhook_Registration__c].size());
        
    }

    public class MockInboundWebhookHandler extends InboundWebhookEventHandler {
        String getClassName() {
            return 'InboundWebhookTest.MockInboundWebhookHandler';
        }
        String getEventTypeName() {
            return MOCK_EVENT_NAME;
        }

        String getRelatedSObjectName() {
            return 'Webhook_Registration__c';
        }

        void handleEvent() {
            getRelatedSObjectName();
            getEvents();
            setItemToInsertIfError(new Webhook_Registration__c(Event__c = 'a'));
            mockHandlerRan = true;
            if(mockHandlerThrowException) {
                throw new MockException(); 
            }
            
        }
    }
    public class MockInboundWebhookHandler2 extends InboundWebhookEventHandler {
        String getClassName() {
            return 'InboundWebhookTest.MockInboundWebhookHandler2';
        }
        String getEventTypeName() {
            return MOCK_EVENT_NAME;
        }
        void handleEvent() {
            mockHandler2Ran = true;
        }
    }

    public static void startWebhookProcessorSynchronously() {
        InboundWebhookEventHandler.startHandlerSynchronously = true;
        InboundWebhook.startHandlerSynchronously = true;
    }

    public class MockException extends Exception {}
}
