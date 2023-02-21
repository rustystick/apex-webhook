/**
 * @description provide constants that are used across NTFH modules
 * @author Andi Xie
 */

public with sharing class Webhook_Constants {
    public static final Integer HTTP_ERROR_NOT_FOUND = 404;
    public static final Integer HTTP_ERROR_BAD_REQUEST = 400;
    public static final Integer HTTP_SUCCESS_CREATED = 201;
    public static final Integer HTTP_SUCCESS_OK = 200;
    public static final Integer HTTP_SUCCESS_DELETED = 204;
    public static final Integer HTTP_INTERNAL_SERVER_ERROR = 500;
    public static final String HTTP_POST = 'POST';
    public static final String HTTP_GET = 'GET';
    public static final String HTTP_DELETE = 'DELETE';
    public static final String HTTP_PUT = 'PUT';
    public static final String CONTENT_TYPE_APPLICATION_JSON = 'application/json';
    public static final String CONTENT_TYPE_APPLICATION_FORM_URL_ENCODED = 'application/x-www-form-urlencoded';
    public static final String STATUS_ACTIVE = 'Active';
    public static final String SF_BASE_URL = Url.getSalesforceBaseUrl().toExternalForm();
    public static final String SF_ORG_ID = UserInfo.getOrganizationId();
    public static final String HASHING_ALGO_HMAC_SHA256 = 'hmacSHA256';
}