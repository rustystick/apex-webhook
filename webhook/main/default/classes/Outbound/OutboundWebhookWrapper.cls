/**
 * @description represents a single outbound webhook
 * @author Andi Xie 
 */
public with sharing class OutboundWebhookWrapper {
    public static String SIGNATURE_HEADER_KEY = 'X-OneBanner-Signature';
    public static String SIGNATURE_ALGO = 'HmacSHA256';
    String endPoint;
    SerializableBody body;
    Map<String, String> headers;

    /**
     * @description signs the payload and set the signature of the payload
     * @param  sharedSecret sharedSecret 
     */ 
    private void sign(String sharedSecret) {
        String serializedBody = JSON.serialize(body);
        Blob signedBlob = Crypto.generateMac(SIGNATURE_ALGO, Blob.valueof(serializedBody), EncodingUtil.base64Decode(sharedSecret));
        String signatureString = EncodingUtil.base64Encode(signedBlob);
        this.headers.put(SIGNATURE_HEADER_KEY, signatureString);
    }

    /**
     * @description sets the callout header 
     * @param  headers callout header
     */
    public void setCalloutHeaders(Map<String, String> headers) {
        for(String header : headers.keySet()){
            this.headers.put(header, headers.get(header));
        }
    }

    private OutboundWebhookWrapper(Object data, String key, String endPoint, String event) {
        this.body = new SerializableBody(data, event);
        this.endPoint = endPoint;
        this.headers = new Map<String, String>{'Content-Type' => 'application/json'};
        sign(key);
    }

    /**
     * @description clones the webhook body with new receipient 
     * @param  key      new receipient's shared secret
     * @param  endPoint new receipient's key
     * @return          return cloned wrapper
     */ 
    public OutboundWebhookWrapper cloneWithNewEndpoint(String key, String endPoint) {
        return new OutboundWebhookWrapper(body.data, key, endPoint, body.event);
    }

    public OutboundWebhookWrapper(Object data, String event) {
        this.body = new SerializableBody(data, event);
    }

    /**
     * @description execute the post request
     * @return   return http response
     */ 
    public HttpResponse post() {
        String jsonBody = JSON.serialize(this.body);
        if (headers == null) {
            headers = new Map<String, String>{ 'Content-Type' => 'application/json' };
        }
        HttpResponse response = callout(endPoint, jsonBody, 'POST', headers);
        return response;
    }

    private HttpResponse callout(String endPoint, String jsonBody, String method, Map<String, String> headers) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setmethod(method);
        request.setBody(jsonBody);
        for (String header : headers.keyset()) {
            request.setheader(header, headers.get(header));
        }
        Long beforeTimeStamp = System.now().getTime();
        HttpResponse response = http.send(request);
        Long afterTimeStamp = System.now().getTime();
        Long responseTime = afterTimeStamp - beforeTimeStamp;
        return response;
    }

    public virtual class SerializableBody {
        String event;
        Object data;

        public SerializableBody(Object data, String event) {
            this.data = data;
            this.event = event;
        }

    }

}