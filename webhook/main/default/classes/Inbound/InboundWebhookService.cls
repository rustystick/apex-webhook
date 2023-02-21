/**
 * @description this rest resource is meant to be placed in a unauthenticated site (assign Inbound Webhook PS to the system generated Site user)
 * @author Andi Xie
 */
@RestResource(urlMapping='/webhook/v1/listener/*')
global with sharing class InboundWebhookService {
    @testVisible
    private static String exceptionType;
    @HttpPost
    global static InboundWebhookResponse newEvent() {
        String requestURI = RestContext.request.requestURI;
        String webhookPath = requestURI.substring(requestURI.lastIndexOf('/') + 1);
        InboundWebhookRequest inboundRequest;
        InboundWebhookResponse response = new InboundWebhookResponse();
        try {
            inboundRequest = new InboundWebhookRequest(RestContext.request, webhookPath);
            inboundRequest.verifySignature();
            Database.SaveResult sr = inboundRequest.fireEvent();
            response.setCorrelationId(sr);
        } catch (InboundWebhookBadRequestException ex) {
            RestContext.response.statusCode = Webhook_Constants.HTTP_ERROR_BAD_REQUEST;
            response.setError(ex);
            return response;
        } catch (Exception ex) {
            RestContext.response.statusCode = Webhook_Constants.HTTP_INTERNAL_SERVER_ERROR;
            response.setError(ex);
            return response;
        }
        RestContext.response.statusCode = Webhook_Constants.HTTP_SUCCESS_CREATED;
        return response;
    }

    global class InboundWebhookRequest {
        String hashingAlgo;
        String signature;
        String sharedSecret;
        RestRequest inboundHttpRequest;

        global InboundWebhookRequest(RestRequest request, String path) {
            Inbound_Webhook_Setting__mdt inboundSetting;
            try {
                inboundSetting = InboundWebhook.getSetting(path);
            } catch (InboundWebhook.NoInboundWebhookSettingFoundException ex) {
                throw new InvalidWebhookPathException().useDefaultMessage();
            }
            this.hashingAlgo = inboundSetting.Signing_Algorithm__c;
            this.sharedSecret = inboundSetting.Shared_Secret__c;
            String signatureHeaderName = inboundSetting.Signature_header_Name__c;

            if (signatureHeaderName != null) {
                this.signature = request.headers.get(signatureHeaderName);
            }
            this.inboundHttpRequest = request;
        }

        void verifySignature() {
            if (String.isBlank(sharedSecret)) {
                return;
            }
            Blob blobSharedSecret = EncodingUtil.base64Decode(sharedSecret);
            Blob hashedBlob = Crypto.generateMac(hashingAlgo, inboundHttpRequest.requestBody, blobSharedSecret);
            String encodedHash = EncodingUtil.base64Encode(hashedBlob);
            if (signature != encodedhash) {
                throw new InvalidWebhookSignatureException().useDefaultMessage();
            }
        }

        Database.SaveResult fireEvent() {
            String jsonBody = inboundHttpRequest.requestBody.toString();
            Map<String, Object> requestBodyObj = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
            String eventName;
            try {
                eventName = (String) requestBodyObj.get('type');
            } catch (TypeException type) {
                throw new InvalidWebhookBodyException().useDefaultMessage();
            }
            if (String.isEmpty(eventName)) {
                throw new InvalidWebhookBodyException().useDefaultMessage();
            }
            Inbound_Webhook__e event = new Inbound_Webhook__e(Event_Type__c = eventName, Event_Body__c = jsonBody);
            return Eventbus.publish(event);
        }
    }

    global class InboundWebhookResponse {
        @testVisible
        Boolean hasError = false;
        @testVisible
        String message = 'Success';
        @testVisible
        String correlationId;
        public InboundWebhookResponse() {
        }
        public void setError(Exception ex) {
            hasError = true;
            message = ex.getMessage();
            exceptionType = ex.getTypeName();
        }
        void setCorrelationId(Database.SaveResult sr){
            correlationId = EventBus.getOperationId(sr);
        }
    }

    public abstract class InboundWebhookBadRequestException extends Exception {
    }
    public class InvalidWebhookSignatureException extends InboundWebhookBadRequestException {
        public InboundWebhookBadRequestException useDefaultMessage() {
            setMessage('Invalid signature: the signature included in the request header is invalid');
            return this;
        }
    }
    public class InvalidWebhookPathException extends InboundWebhookBadRequestException {
        public InboundWebhookBadRequestException useDefaultMessage() {
            setMessage('Invalid path: please verify the inbound webhook custom metadata setting is configured for the path');
            return this;
        }
    }
    public class InvalidWebhookBodyException extends InboundWebhookBadRequestException {
        public InboundWebhookBadRequestException useDefaultMessage() {
            setMessage('Invalid webhook body: please ensure that the request body has a string "type" attribute');
            return this;
        }
    }
}
