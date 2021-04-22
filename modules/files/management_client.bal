// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/xmldata;

# Azure Storage File Service Management Client.
# 
# + httpClient - HTTP Client for Azure Storage File Service
# + azureConfig - Azure file service configuration
@display {label: "Azure Storage File Management Client", iconPath: "AzureStorageFileLogo.png"}
public client class ManagementClient {
    private http:Client httpClient;
    private AzureFileServiceConfiguration azureConfig;

    # Initalize Azure Client using the provided azureConfiguration by user
    #
    # + azureConfig - AzureConfiguration record
    public isolated function init(AzureFileServiceConfiguration azureConfig) returns error? {
        http:ClientSecureSocket? secureSocketConfig = azureConfig?.secureSocketConfig;
        string baseURL = string `https://${azureConfig.accountName}.file.core.windows.net/`;
        self.azureConfig = azureConfig;
        if (secureSocketConfig is http:ClientSecureSocket) {
            self.httpClient = check new (baseURL, {
                http1Settings: {chunking: http:CHUNKING_NEVER},
                secureSocket: secureSocketConfig
            });
        } else {
            self.httpClient = check new (baseURL, {http1Settings: {chunking: http:CHUNKING_NEVER}});
        }
    }

    # Lists all the file shares in the  storage account.
    #
    # + return - If success, returns ShareList record with basic details.  Else returns an error.
    @display {label: "List file shares"}
    remote isolated function listShares(@display {label: "Azure Storage File Client"} ListShareURIParameters 
                                        uriParameters = {}) returns @tainted @display {label: "Share list"} SharesList|
                                        error {
        string? appendedUriParameters = setOptionalURIParametersFromRecord(uriParameters);
        string getListPath = appendedUriParameters is () ? (LIST_SHARE_PATH) : (LIST_SHARE_PATH 
            + appendedUriParameters);
        http:Request request = new;
        if (self.azureConfig.authorizationMethod === ACCESS_KEY) {
            map<string> requiredURIParameters = {};
            requiredURIParameters[COMP] = LIST;
            AuthorizationDetail  authorizationDetail = {
                azureRequest: request,
                azureConfig: self.azureConfig,
                httpVerb: http: HTTP_GET,
                uriParameterRecord: uriParameters,
                requiredURIParameters: requiredURIParameters
            };
            check prepareAuthorizationHeaders(authorizationDetail);     
        } else {
            getListPath = getListPath.concat(AMPERSAND, self.azureConfig.accessKeyOrSAS.substring(1)); 
        }
        map<string> headerMap = populateHeaderMapFromRequest(request);
        http:Response response = <http:Response> check self.httpClient->get(<@untainted>getListPath, headerMap);
        if (response.statusCode === http:STATUS_OK ) {
            xml formattedXML = check removeDoubleQuotesFromXML(check response.getXmlPayload()/<Shares>);
            json jsonValue = check xmldata:toJson(formattedXML);
            if (jsonValue.Shares === EMPTY_STRING) {
                return error NoSharesFoundError(NO_SHARES_FOUND, storageAccountName = self.azureConfig.accountName);
            }
            return <SharesList> check jsonValue.cloneWithType(SharesList);
        } else {
            fail error(check getErrorMessage(response));
        }
    }

    # Gets the File service properties for the storage account.
    #
    # + return - If success, returns FileServicePropertiesList record with details.  Else returns error.
    @display {label: "Get file service properties"}
    remote isolated function getFileServiceProperties() returns @tainted @display {label: "File service properties"} 
            FileServicePropertiesList|error {
        string getListPath = GET_FILE_SERVICE_PROPERTIES;
        map<string> requiredURIParameters = {}; 
        http:Request request = new;
        if (self.azureConfig.authorizationMethod == ACCESS_KEY) {
            requiredURIParameters[RESTYPE] = SERVICE;
            requiredURIParameters[COMP] = PROPERTIES;     
            AuthorizationDetail  authorizationDetail = {
                azureRequest: request,
                azureConfig: self.azureConfig,
                httpVerb: http:HTTP_GET,
                requiredURIParameters: requiredURIParameters
            };
            check prepareAuthorizationHeaders(authorizationDetail);    
        } else {
            getListPath = getListPath.concat(AMPERSAND, self.azureConfig.accessKeyOrSAS.substring(1)); 
        }
        map<string> headerMap = populateHeaderMapFromRequest(request);
        http:Response response = <http:Response> check self.httpClient->get(getListPath, headerMap);
        if (response.statusCode == http:STATUS_OK ) {
            xml responseBody = check response.getXmlPayload();
            xml formattedXML = check removeDoubleQuotesFromXML(responseBody);
            json jsonValue = check xmldata:toJson(formattedXML);
            return <FileServicePropertiesList> check jsonValue.cloneWithType(FileServicePropertiesList);
        } else {
            fail error(check getErrorMessage(response));
        }
    }

    # Sets the File service properties for the storage account.
    #
    # + fileServicePropertiesList - fileServicePropertiesList record with deatil to be set
    # + return - If success, returns true.  Else returns error.
    @display {label: "Set file service properties"}
    remote isolated function setFileServiceProperties(@display {label: "File service properties list"} 
                                                      FileServicePropertiesList fileServicePropertiesList) returns 
                                                      @tainted @display {label: "Status"} boolean|error {
        string requestPath = GET_FILE_SERVICE_PROPERTIES;
        xml requestBody = check convertRecordToXml(fileServicePropertiesList);
        http:Request request = new;
        request.setXmlPayload(<@untainted>requestBody);
        byte[] payload = check request.getBinaryPayload();
        request.setHeader(CONTENT_LENGTH, payload.length().toString());
        request.setHeader(CONTENT_TYPE, APPLICATION_XML);
        if (self.azureConfig.authorizationMethod === ACCESS_KEY) {
            map<string> requiredURIParameters = {}; 
            requiredURIParameters[RESTYPE] = SERVICE;
            requiredURIParameters[COMP] = PROPERTIES;
            AuthorizationDetail  authorizationDetail = {
                azureRequest: request,
                azureConfig: self.azureConfig,
                httpVerb: http:HTTP_PUT,
                requiredURIParameters: requiredURIParameters
            };
            check prepareAuthorizationHeaders(authorizationDetail);        
        } else {
            requestPath = requestPath.concat(AMPERSAND, self.azureConfig.accessKeyOrSAS.substring(1)); 
        }
        http:Response response = <http:Response> check self.httpClient->put(requestPath, request);
        if (response.statusCode === http:STATUS_ACCEPTED) {
            return true;
        } else {
            fail error(check getErrorMessage(response));
        }
    }

    # Creates a new share in a storage account.
    #
    # + fileShareName - Name of the fileshare
    # + createShareHeaders - Optional. Map of the user defined optional headers
    # + return - If success, returns true.  Else returns error.
    @display {label: "Create new share"}
    remote isolated function createShare(@display {label: "File share name"}string fileShareName, 
                                         @display {label: "Map of optional headers"} CreateShareHeaders? 
                                         createShareHeaders = ()) returns @tainted @display {label: "Share created"} 
                                         boolean|error {
        string requestPath = SLASH + fileShareName + QUESTION_MARK + CREATE_GET_DELETE_SHARE;
        http:Request request = new;
        if (createShareHeaders is CreateShareHeaders) {
            setAzureRequestHeaders(request, createShareHeaders);
        }
        if (self.azureConfig.authorizationMethod === ACCESS_KEY) {
            map<string> requiredURIParameters = {};
            requiredURIParameters[RESTYPE] = SHARE;
            AuthorizationDetail  authorizationDetail = {
                azureRequest: request,
                azureConfig: self.azureConfig,
                httpVerb: http:HTTP_PUT,
                requiredURIParameters: requiredURIParameters,
                resourcePath: fileShareName
            };
            check prepareAuthorizationHeaders(authorizationDetail); 
        } else {
            requestPath = requestPath.concat(AMPERSAND, self.azureConfig.accessKeyOrSAS.substring(1)); 
        }
        http:Response response = <http:Response> check self.httpClient->put(<@untainted>requestPath, request);
        if (response.statusCode === http:STATUS_CREATED) {
            return true;
        } else {
            fail error(check getErrorMessage(response));
        }
    }

    # Returns all user-defined metadata and system properties of a share.
    #
    # + fileShareName - Name of the FileShare
    # + return - If success, returns FileServicePropertiesList record with Details.  Else returns error.
    @display {label: "Get share properties"}
    remote isolated function getShareProperties(@display {label: "File share name"} string fileShareName) returns 
                                                @tainted @display {label: "File service properties"} 
                                                FileServicePropertiesList|error {
        string requestPath = SLASH + fileShareName + CREATE_GET_DELETE_SHARE;
        http:Request request = new;
        if (self.azureConfig.authorizationMethod === ACCESS_KEY) {
            map<string> requiredURIParameters = {};
            requiredURIParameters[RESTYPE] = SHARE;
            AuthorizationDetail  authorizationDetail = {
                azureRequest: request,
                azureConfig: self.azureConfig,
                httpVerb: http:HTTP_GET,
                requiredURIParameters: requiredURIParameters,
                resourcePath: fileShareName
            };
            check prepareAuthorizationHeaders(authorizationDetail);       
        } else {
            requestPath = requestPath.concat(AMPERSAND, self.azureConfig.accessKeyOrSAS.substring(1)); 
        }
        map<string> headerMap = populateHeaderMapFromRequest(request);
        http:Response response = <http:Response> check self.httpClient->get(requestPath, headerMap);
        if (response.statusCode === http:STATUS_OK ) {
            xml responseBody = check response.getXmlPayload();
            xml formattedXML = check removeDoubleQuotesFromXML(responseBody);
            json jsonValue = check xmldata:toJson(formattedXML);
            return <FileServicePropertiesList> check jsonValue.cloneWithType(FileServicePropertiesList);
        } else {
            fail error(check getErrorMessage(response));
        }
    }

    # Deletes the share and any files and directories it contains.
    #
    # + fileShareName - Name of the Fileshare
    # + return - If success, returns true.  Else returns error.
    @display {label: "Delete a share"}
    remote isolated function deleteShare(@display {label: "File share name"} string fileShareName) returns @tainted 
                                         @display {label: "File share deleted"} boolean|error {
        string requestPath = SLASH + fileShareName + QUESTION_MARK + CREATE_GET_DELETE_SHARE;
        http:Request request = new;
        if (self.azureConfig.authorizationMethod === ACCESS_KEY) {
            map<string> requiredURIParameters = {};
            requiredURIParameters[RESTYPE] = SHARE;
            AuthorizationDetail  authorizationDetail = {
                azureRequest: request,
                azureConfig: self.azureConfig,
                httpVerb: http:HTTP_DELETE,
                requiredURIParameters: requiredURIParameters,
                resourcePath: fileShareName
            };
            check prepareAuthorizationHeaders(authorizationDetail);        
        } else {
            requestPath = requestPath.concat(AMPERSAND, self.azureConfig.accessKeyOrSAS.substring(1)); 
        }
        http:Response response = <http:Response> check self.httpClient->delete(requestPath, request);
        if (response.statusCode === http:STATUS_ACCEPTED) {
            return true;
        } else {
            fail error(check getErrorMessage(response));
        }
    }
}
