//Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/log;
import ballerina/os;
import ballerina/test;

configurable string accessKeyOrSAS = os:getEnv("ACCESS_KEY_OR_SAS");
configurable string azureStorageAccountName = os:getEnv("ACCOUNT_NAME");

AzureFileServiceConfiguration azureConfig = {
    accessKeyOrSAS: accessKeyOrSAS,
    storageAccountName: azureStorageAccountName,
    authorizationMethod : ACCESS_KEY
};

string testFileShareName = "wso2fileshare";
string baseURL = string `https://${azureConfig.storageAccountName}.file.core.windows.net/`;

FileClient fileClient = check new (azureConfig);
ManagementClient managementClient = check new (azureConfig);

@test:Config {enable: true}
function testGetFileServiceProperties() {
    log:print("GetFileServiceProperties");
    var result = managementClient->getFileServiceProperties();
    if (result is FileServicePropertiesList) {
        test:assertTrue(result.StorageServiceProperties?.MinuteMetrics?.Version == "1.0", 
        msg = "Check the received version");
    } else {
        test:assertFail(msg = result.toString());
    }
}

StorageServicePropertiesType storageServicePropertiesType = {HourMetrics: hourMetrics};
MetricsType minMetrics = {
    Version: "1.0",
    Enabled: true,
    IncludeAPIs: true,
    RetentionPolicy: hourRetentionPolicy
};
MetricsType hourMetrics = {
    Version: "1.0",
    Enabled: false,
    RetentionPolicy: mintRetentionPolicy
};
RetentionPolicyType hourRetentionPolicy = {
    Enabled: "true",
    Days: "7"
};
RetentionPolicyType mintRetentionPolicy = {Enabled: "false"};
ProtocolSettingsType protocolSettingsType = {SMB: smbType};
SMBType smbType = {Multichannel: multichannelType};
MultichannelType multichannelType = {Enabled: "false"};
FileServicePropertiesList fileService = {StorageServiceProperties: storageServicePropertiesType};

@test:Config {enable: true}
function testSetFileServiceProperties() {
    log:print("testSetFileServiceProperties");
    var result = managementClient->setFileServiceProperties(fileService);
    if (result is boolean) {
        test:assertTrue(result, "Operation Failed");
    } else {
        test:assertFail(msg = result.toString());
    }
}

@test:Config {enable: true}
function testCreateShare() {
    log:print("testCreateShare");
    var result = managementClient->createShare(testFileShareName);
    if (result is boolean) {
        test:assertTrue(result, "Operation Failed");
    } else {
        test:assertFail(msg = result.toString());
    }
}

@test:Config {enable: true, dependsOn:[testCreateShare]}
function testListShares() {
    log:print("testListShares with optional URI parameters and headers");
    var result = managementClient ->listShares();
    if (result is SharesList) {
        var list = result.Shares.Share;
        if (list is ShareItem) {
            log:print(list.Name);
        } else {
            log:print(list[1].Name);
        }
    } else if (result is NoSharesFoundError) {
        log:print(result.message());
    } else {
        test:assertFail(msg = result.toString());
    }
}

@test:Config {enable: true, dependsOn:[testCreateShare]}
function testcreateDirectory() {
    log:print("testcreateDirectory");
    var result = fileClient->createDirectory(fileShareName = testFileShareName, 
        newDirectoryName = "wso2DirectoryTest");
    if (result is boolean) {
        test:assertTrue(result, "Operation Failed");
    } else {
        test:assertFail(msg = result.toString());
    }
}

@test:Config {enable: true, dependsOn:[testcreateDirectory]}
function testgetDirectoryList() {
    log:print("testgetDirectoryList");
    var result = fileClient->getDirectoryList(fileShareName = testFileShareName);
    if (result is DirectoryList) {
        test:assertTrue(true, "Operation Failed");
    } else {
        test:assertFail(msg = result.toString());
    }
}

@test:Config {enable: true, dependsOn:[testCreateShare]}
function testCreateFile() {
    log:print("testCreateFile");
    var result = fileClient->createFile(fileShareName = testFileShareName, azureFileName = "test.txt", 
    fileSizeInByte = 8);
    if (result is boolean) {
        test:assertTrue(result, "Operation Failed");
    } else {
        test:assertFail(msg = result.toString());
    }
}

@test:Config {enable: true, dependsOn:[testCreateFile]}
function testgetFileList() {
    log:print("testgetFileList");
    var result = fileClient->getFileList(fileShareName = testFileShareName);
    if (result is FileList) {
        test:assertTrue(true, "Operation Failed");
    } else {
        test:assertFail(msg = result.toString());
    }
}

@test:Config {enable: true, dependsOn:[testCreateFile]}
function testPutRange() {
    log:print("testPutRange");
    var result = fileClient->putRange(fileShareName = testFileShareName, 
    localFilePath = "modules/files/tests/resources/test.txt", azureFileName = "test.txt");
    if (result is boolean) {
        test:assertTrue(result, "Uploading Failure");
    } else {
        test:assertFail(msg = result.toString());
    }
}

@test:Config {enable: true,  dependsOn:[testCreateShare]}
function testDirectUpload() {
    log:print("testDirectUpload");
    var result = fileClient->directUpload(fileShareName = testFileShareName, localFilePath 
        = "modules/files/tests/resources/test.txt", azureFileName = "test2.txt");
    if (result is boolean) {
        test:assertTrue(result, "Operation Failed");
    } else {
        test:assertFail(msg = result.toString());
    }
}

@test:Config {enable: true,  dependsOn:[testPutRange]}
function testListRange() {
    log:print("testListRange");
    var result = fileClient->listRange(fileShareName = testFileShareName, fileName = "test.txt");
    if (result is RangeList) {
        test:assertTrue(true, "Operation Failed");
    } else {
        test:assertFail(msg = result.toString());
    }
}

@test:Config {enable: true, dependsOn:[testPutRange]}
function testgetFile() {
    log:print("testgetFile");
    var result = fileClient->getFile(fileShareName = testFileShareName, fileName = "test.txt", 
    localFilePath = "modules/files/tests/resources/test_download.txt");
    if (result is boolean) {
        test:assertTrue(result, "Operation Failed");
    } else {
        test:assertFail(msg = result.toString());
    }
}

@test:Config {enable: true, dependsOn:[testCreateShare, testcreateDirectory, testCreateFile, testPutRange]}
function testCopyFile() {
    log:print("testCopyFile");
    var result = fileClient->copyFile(fileShareName = testFileShareName, destFileName = "copied.txt", destDirectoryPath
         = "wso2DirectoryTest", sourceURL = baseURL + testFileShareName + SLASH + "test.txt");
    if (result is boolean) {
        test:assertTrue(result, "Operation Failed");
    } else {
        test:assertFail(msg = result.toString());
    }
}

@test:Config {enable: true, dependsOn:[testCopyFile, testListRange, testgetFile]}
function testDeleteFile() {
    log:print("testDeleteFile");
    var result = fileClient->deleteFile(fileShareName = testFileShareName, fileName = "test.txt");
    if (result is boolean) {
        test:assertTrue(result, "Operation Failed");
    } else {
        test:assertFail(msg = result.toString());
    }
}

@test:Config {enable: true, dependsOn:[testDeleteFile, testgetDirectoryList]}
function testDeleteDirectory() {
    log:print("testDeleteDirectory");
    var deleteCopied = fileClient->deleteFile(fileShareName = testFileShareName, fileName = "copied.txt", 
        azureDirectoryPath = "wso2DirectoryTest");
    var result = fileClient->deleteDirectory(fileShareName = testFileShareName, directoryName = "wso2DirectoryTest");
    if (result is boolean) {
        test:assertTrue(result, "Operation Failed");
    } else {
        test:assertFail(msg = result.toString());
    }
}

@test:AfterSuite {}
function testDeleteShare() {
    log:print("testDeleteShare");
    var result = managementClient->deleteShare(testFileShareName);
    if (result is boolean) {
        test:assertTrue(result, "Operation Failed");
    } else {
        test:assertFail(msg = result.toString());
    }
}