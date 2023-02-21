/**
 * @description Main rest resource/route to register webhook
 * @author Andi Xie
 */
@RestResource(urlMapping='/webhook/v1/registration/*')
global with sharing class OutboundWebhookApiService {
    @TestVisible
    // Currently max length is the text field length that support SOQL where clause filtering
    // if need to support longer urls, convert field to text area long and implement new checkDuplicate method
    static final Integer URL_MAX_LENGTH = 255;
    @TestVisible
    static final String TEST_BODY_STRING = 'this is a test';
    static final String STATUS_PENDING = 'Pending Confirmation';
    static final String STATUS_ACTIVE = 'Active';
    static final List<String> FIELDS_TO_RETURN = new List<String>{ 'Id', 'Callback_Url__c', 'Status__c', 'Event__c', 'Header__c' };

    @HttpPost
    global static WebhookApiResponse registerWebhook(WebhookRegistrationRequest request) {
        WebhookApiResponse wrappedResponse = new WebhookApiResponse();
        WebhookRegistration reg;
        try {
            checkDuplicate(request);
            testEndpoint(request.url);
            reg = (WebhookRegistration) createRegistration(request, STATUS_ACTIVE);
        }  catch (RegisteredEndpointErrorException endpointException) {
            reg = (WebhookRegistration) createRegistration(request, STATUS_PENDING);
            wrappedResponse.setError(endpointException);
        } catch (CalloutException ce) {
            if (ce.getMessage().startsWith('Unauthorized endpoint')) {
                wrappedResponse.setError(
                    new EndpointNotInRemoteSiteException(
                        'The requested endpoint or domain is not present in Remote Site Setting; please add and try again'
                    )
                );
            } else {
                wrappedResponse.setError(ce);
            }
            RestContext.response.statusCode = Webhook_Constants.HTTP_ERROR_BAD_REQUEST;
            return wrappedResponse;
        } catch (BadRequestException ex){
            wrappedResponse.setError(ex);
            RestContext.response.statusCode = Webhook_Constants.HTTP_ERROR_BAD_REQUEST;
            return wrappedResponse;
        } catch (Exception ex) {
            wrappedResponse.setError(ex);
            RestContext.response.statusCode = Webhook_Constants.HTTP_INTERNAL_SERVER_ERROR;
            return wrappedResponse;
        }
        wrappedResponse.registrationData = reg;
        RestContext.response.statusCode = Webhook_Constants.HTTP_SUCCESS_CREATED;
        return wrappedResponse;
    }

    @HttpPut
    global static WebhookApiResponse updateWebhookRegistration(WebhookRegistrationPutRequest request) {
        RestRequest restRequest = RestContext.request;
        RestResponse response = RestContext.response;
        WebhookApiResponse wrappedResponse = new WebhookApiResponse();
        try {
            Id registrationId = restRequest.requestURI.substring(restRequest.requestURI.lastIndexOf('/') + 1);
            wrappedResponse.registrationData = updateRegistration(request, registrationId);
        } catch (Exception ex) {
            wrappedResponse.setError(ex);
            RestContext.response.statusCode = Webhook_Constants.HTTP_INTERNAL_SERVER_ERROR;
            return wrappedResponse;
        }
        RestContext.response.statusCode = Webhook_Constants.HTTP_SUCCESS_OK;
        return wrappedResponse;
    }

    @HttpGet
    global static WebhookApiResponse getWebhookRegistration() {
        WebhookApiResponse wrappedResponse = new WebhookApiResponse();
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;
        WebhookRegistration registration;
        try {
            Id registrationId = request.requestURI.substring(request.requestURI.lastIndexOf('/') + 1);
            registration = getRegistration(registrationId, FIELDS_TO_RETURN);
        } catch (Exception ex) {
            wrappedResponse.setError(ex);
        }
        RestContext.response.statusCode = Webhook_Constants.HTTP_SUCCESS_OK;
        wrappedResponse.registrationData = registration;
        return wrappedResponse;
    }

    @HttpDelete
    global static WebhookApiResponse deleteRegistration() {
        WebhookApiResponse wrappedResponse = new WebhookApiResponse();

        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;
        try {
            Id registrationId = request.requestURI.substring(request.requestURI.lastIndexOf('/') + 1);
            OutboundWebhookRegistration wrapper = OutboundWebhookRegistration.fromId(registrationId);
            wrapper.deleteRegistration();
        } catch (Exception ex) {
            wrappedResponse.setError(ex);
            response.statusCode = Webhook_Constants.HTTP_INTERNAL_SERVER_ERROR;
            return wrappedResponse;
        }
        response.statusCode = Webhook_Constants.HTTP_SUCCESS_DELETED;
        wrappedResponse.message = 'Registration Deleted';
        return wrappedResponse;
    }

    static WebhookRegistration getRegistration(Id id, List<String> fields) {
        OutboundWebhookRegistration registrationWrapper = OutboundWebhookRegistration.fromIdAndFields(id, fields);
        return new WebhookRegistration(registrationWrapper);
    }

    static void checkDuplicate(WebhookRegistrationRequest wr) {
        try {
            Id id = OutboundWebhookRegistration.checkIfExist(wr.url, wr.event);
            throw new DuplicateRegistrationException('Registration already exist with requested event and callback url; id: ' + id);
        } catch (OutboundWebhookRegistration.RegistrationNotFoundException ex) {
            // do nothing
        }
    }

    static WebhookRegistration updateRegistration(WebhookRegistrationPutRequest wrpr, Id id) {
        OutboundWebhookRegistration wrapper = OutboundWebhookRegistration.fromIdAndFields(id, FIELDS_TO_RETURN);
        Map<String, String> valuesToUpsert = new Map<String, String>();
        if (wrpr.status != null) {
            valuesToUpsert.put('Status__c', wrpr.status);
        }
        if (wrpr.headers != null) {
            valuesToUpsert.put('Header__c', JSON.serialize(wrpr.headers));
        }
        wrapper.upsertRegistration(valuesToUpsert);
        return new WebhookRegistration(wrapper);
    }

    @TestVisible
    static WebhookRegistrationWithSharedSecret createRegistration(WebhookRegistrationRequest wr, String status) {
        String regStatus = status == null ? STATUS_ACTIVE : status;
        if (wr.url.length() > URL_MAX_LENGTH) {
            throw new UrlTooLongException('The webhook Url length is over the maximum allowed length: ' + URL_MAX_LENGTH);
        }
        OutboundWebhookRegistration wrapper = OutboundWebhookRegistration.newRegistration();
        wrapper.upsertRegistration(
            new Map<String, String>{
                'Callback_Url__c' => wr.url,
                'Event__c' => wr.event,
                'Status__c' => regStatus,
                'Header__c' => wr.headers == null ? null : JSON.serialize(wr.headers)
            }
        );
        return new WebhookRegistrationWithSharedSecret(wrapper);
    }

    static void testEndpoint(String url) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setMethod(Webhook_Constants.HTTP_POST);
        request.setEndpoint(url);
        request.setBody(TEST_BODY_STRING);
        HttpResponse response = http.send(request);
        if (response.getStatusCode() > 299) {
            throw new RegisteredEndpointErrorException(
                'Endpoint returned a error status code; if this is expected behavior, update registration status with PUT to active with the id returned'
            );
        }
    }

    abstract class BadRequestException extends Exception{
    }
    class RegisteredEndpointErrorException extends Exception {
    }
    class EndpointNotInRemoteSiteException extends BadRequestException {
    }
    class DuplicateRegistrationException extends BadRequestException {
    }
    class UrlTooLongException extends BadRequestException {
    }

    global class WebhookApiResponse {
        global Boolean hasError = false;
        global String message = 'Success';
        global WebhookRegistration registrationData;

        void setError(Exception ex) {
            this.hasError = true;
            this.message = ex.getMessage();
        }
    }

    global class WebhookRegistrationRequest {
        global String url;
        global String event;
        global Map<String, String> headers;
    }

    global class WebhookRegistrationPutRequest {
        global String status;
        global Map<String, String> headers;
    }

    @TestVisible
    virtual class WebhookRegistration {
        String id;
        String event;
        String callbackUrl;
        String status;
        Map<String, String> headers;

        public WebhookRegistration(OutboundWebhookRegistration reg) {
            this(reg.getSObject());
        }

        public WebhookRegistration(Webhook_Registration__c regSObject) {
            this.id = regSObject.Id;
            this.event = regSObject.Event__c;
            this.status = regSObject.Status__c;
            this.callbackUrl = regSObject.Callback_Url__c;
            if (regSObject.Header__c != null) {
                this.headers = convertDeserializedHeader((Map<String, Object>) JSON.deserializeuntyped(regSObject.Header__c));
            }
        }
        Map<String, String> convertDeserializedHeader(Map<String, Object> untypeHeader) {
            Map<String, String> header = new Map<String, String>();
            for (String headerKey : untypeHeader.keySet()) {
                if (untypeHeader.get(headerKey) instanceof String) {
                    header.put(headerKey, (String) untypeHeader.get(headerKey));
                }
            }
            return header;
        }
    }

    @TestVisible
    class WebhookRegistrationWithSharedSecret extends WebhookRegistration {
        String sharedSecret;
        public WebhookRegistrationWithSharedSecret(OutboundWebhookRegistration wrapper) {
            super(wrapper);
            Webhook_Registration__c regSobject = wrapper.getSObject();
            this.sharedSecret = regSobject.Shared_Secret__c;
        }
    }
}