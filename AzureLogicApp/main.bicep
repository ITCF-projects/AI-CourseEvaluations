param namePrefix string = ''
param sharepointSiteUrl string = ''
param sharepointListMainName string = ''
param sharepointListSettingsName string = ''

param location string = resourceGroup().location

resource sharepointApiConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: '${namePrefix}-sharepoint-api-connection'
  location: location
  properties: {
    displayName: 'SharepointOnline connection'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'sharepointonline')
      type: 'Microsoft.Web/locations/managedApis'
    }
  }
}

resource translationService 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: '${namePrefix}-translation-service'
  location: location
  kind: 'TextTranslation'
  sku: {
    name: 'S1'
  }
  properties: {
    apiProperties: {}
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    publicNetworkAccess: 'Enabled'
  }
}

resource languageService 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: '${namePrefix}-language-service'
  location: location
  kind: 'TextAnalytics'
  sku: {
    name: 'S'
  }
  properties: {
    customSubDomainName: '${namePrefix}-language-service'
    apiProperties: {}
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    publicNetworkAccess: 'Enabled'
  }
}

resource contentSafetyService 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: '${namePrefix}-content-safety-service'
  location: location
  kind: 'ContentSafety'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: '${namePrefix}-content-safety-service'
    apiProperties: {}
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    publicNetworkAccess: 'Enabled'
  }
}

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: '${namePrefix}-logic-app'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Disabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/schemas/2016-06-01/Microsoft.Logic.json'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        Every_5_minutes: {
          recurrence: {
            interval: 5
            frequency: 'Minute'
          }
          evaluatedRecurrence: {
            interval: 5
            frequency: 'Minute'
          }
          type: 'Recurrence'
        }
      }
      actions: {
        Get_all_lists: {
          runAfter: {}
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'sharepointonlineconnection\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/datasets/@{encodeURIComponent(encodeURIComponent(\'${sharepointSiteUrl}\'))}/tables'
          }
        }
        Parse_JSON: {
          runAfter: {
            Get_all_lists: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'Get_all_lists\')?[\'value\']'
            schema: {
              items: {
                properties: {
                  Name: {
                    type: 'string'
                  }
                  DisplayName: {
                    type: 'string'
                  }
                  Type: {
                    type: 'string'
                  }
                }
                required: [
                  'Name'
                  'DisplayName'
                ]
                type: 'object'
              }
              type: 'array'
            }
          }
        }
        Filter_array_main_list: {
          runAfter: {
            Parse_JSON: [
              'Succeeded'
            ]
          }
          type: 'Query'
          inputs: {
            from: '@body(\'Parse_JSON\')'
            where: '@equals(item()[\'DisplayName\'],\'${sharepointListMainName}\')'
          }
        }
        Filter_array_setting_list: {
          runAfter: {
            Parse_JSON: [
              'Succeeded'
            ]
          }
          type: 'Query'
          inputs: {
            from: '@body(\'Parse_JSON\')'
            where: '@equals(item()[\'DisplayName\'],\'${sharepointListSettingsName}\')'
          }
        }
        Initialize_variable_MainListId: {
          runAfter: {
            Filter_array_main_list: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'MainListId'
                type: 'string'
                value: '@first(body(\'Filter_array_main_list\'))?[\'Name\']'
              }
            ]
          }
        }
        Initialize_variable_SettingsListId: {
          runAfter: {
            Filter_array_setting_list: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'SettingsListId'
                type: 'string'
                value: '@first(body(\'Filter_array_setting_list\'))?[\'Name\']'
              }
            ]
          }
        }
        Get_items: {
          runAfter: {
            Initialize_variable_MainListId: [
              'Succeeded'
            ]
            Initialize_variable_SettingsListId: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'sharepointonlineconnection\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/datasets/@{encodeURIComponent(encodeURIComponent(\'${sharepointSiteUrl}\'))}/tables/@{encodeURIComponent(encodeURIComponent(variables(\'MainListId\')))}/items'
            queries: {
              '$filter': 'Status eq \'New\''
            }
          }
        }
        Initialize_variable_Text: {
          runAfter: {
            Initialize_variable_Translate: [
              'Succeeded'
            ]
            Initialize_variable_UseContentSafety: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'Text'
                type: 'string'
              }
            ]
          }
        }
        Initialize_variable_Blocked: {
          runAfter: {
            Initialize_variable_Text: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'Blocked'
                type: 'boolean'
                value: false
              }
            ]
          }
        }
        For_each: {
          foreach: '@body(\'Get_items\')?[\'value\']'
          actions: {
            Set_variable_blocked: {
              runAfter: {
                Update_Item_set_status_and_start: [
                  'Succeeded'
                ]
              }
              type: 'SetVariable'
              inputs: {
                name: 'Blocked'
                value: false
              }
            }
            Update_Item_set_status_and_start: {
              type: 'ApiConnection'
              inputs: {
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'sharepointonlineconnection\'][\'connectionId\']'
                  }
                }
                method: 'patch'
                body: {
                  Status: {
                    Value: 'Analyzing'
                  }
                  StartTime: '@utcNow()'
                }
                path: '/datasets/@{encodeURIComponent(encodeURIComponent(\'${sharepointSiteUrl}\'))}/tables/@{encodeURIComponent(encodeURIComponent(variables(\'MainListId\')))}/items/@{encodeURIComponent(items(\'For_each\')?[\'ID\'])}'
              }
            }
            Set_variable_Text: {
              runAfter: {
                Update_Item_set_status_and_start: [
                  'Succeeded'
                ]
              }
              type: 'SetVariable'
              inputs: {
                name: 'Text'
                value: '@item()[\'FreeText_x002d_Incoming\']'
              }
            }
            Translate: {
              actions: {
                Translate_To_English: {
                  type: 'Http'
                  inputs: {
                    uri: '${translationService.properties.endpoint}translate?api-version=3.0&to=en'
                    method: 'POST'
                    headers: {
                      'Ocp-Apim-Subscription-Key': translationService.listKeys().key1
                      'Ocp-Apim-Subscription-Region': location
                      'Content-Type': 'application/json'
                    }
                    body: [
                      {
                        Text: '@variables(\'Text\')'
                      }
                    ]
                  }
                }
                Parse_JSON_Response_from_translation: {
                  runAfter: {
                    Translate_To_English: [
                      'Succeeded'
                    ]
                  }
                  type: 'ParseJson'
                  inputs: {
                    content: '@body(\'Translate_To_English\')'
                    schema: {
                      type: 'array'
                      items: {
                        type: 'object'
                        properties: {
                          detectedLanguage: {
                            type: 'object'
                            properties: {
                              language: {
                                type: 'string'
                              }
                              score: {
                                type: 'number'
                              }
                            }
                          }
                          translations: {
                            type: 'array'
                            items: {
                              type: 'object'
                              properties: {
                                text: {
                                  type: 'string'
                                }
                                to: {
                                  type: 'string'
                                }
                              }
                              required: [
                                'text'
                                'to'
                              ]
                            }
                          }
                        }
                        required: [
                          'detectedLanguage'
                          'translations'
                        ]
                      }
                    }
                  }
                }
                Set_variable_Text_after_Translation: {
                  runAfter: {
                    Parse_JSON_Response_from_translation: [
                      'Succeeded'
                    ]
                  }
                  type: 'SetVariable'
                  inputs: {
                    name: 'Text'
                    value: '@first(\r\nfirst(\r\nbody(\'Parse_Json_Response_from_translation\')\r\n)?[\'translations\'])?[\'text\']'
                  }
                }
              }
              runAfter: {
                Set_variable_Text: [
                  'Succeeded'
                ]
                Set_variable_blocked: [
                  'Succeeded'
                ]
              }
              else: {
                actions: {}
              }
              expression: {
                and: [
                  {
                    equals: [
                      '@variables(\'Translate\')'
                      true
                    ]
                  }
                  {
                    not: {
                      equals: [
                        '@variables(\'UseContentSafety\')'
                        false
                      ]
                    }
                  }
                ]
              }
              type: 'If'
            }
            UseContentSafety: {
              actions: {
                Content_Safety: {
                  type: 'Http'
                  inputs: {
                    uri: '${contentSafetyService.properties.endpoint}contentsafety/text:analyze?api-version=2024-09-01'
                    method: 'POST'
                    headers: {
                      'Ocp-Apim-Subscription-Key': contentSafetyService.listKeys().key1
                      'Ocp-Apim-Subscription-Region': location
                      'Content-Type': 'application/json'
                    }
                    body: {
                      Text: '@variables(\'Text\')'
                      categories: [
                        'Hate'
                        'Sexual'
                        'SelfHarm'
                        'Violence'
                      ]
                      outputType: 'EightSeverityLevels'
                    }
                  }
                }
                Parse_JSON_Response_from_Content_Safety: {
                  runAfter: {
                    Content_Safety: [
                      'Succeeded'
                    ]
                  }
                  type: 'ParseJson'
                  inputs: {
                    content: '@body(\'Content_Safety\')'
                    schema: {
                      type: 'object'
                      properties: {
                        blocklistsMatch: {
                          type: 'array'
                        }
                        categoriesAnalysis: {
                          type: 'array'
                          items: {
                            type: 'object'
                            properties: {
                              category: {
                                type: 'string'
                              }
                              severity: {
                                type: 'integer'
                              }
                            }
                            required: [
                              'category'
                              'severity'
                            ]
                          }
                        }
                      }
                    }
                  }
                }
                Filter_array: {
                  runAfter: {
                    Parse_JSON_Response_from_Content_Safety: [
                      'Succeeded'
                    ]
                  }
                  type: 'Query'
                  inputs: {
                    from: '@body(\'Parse_JSON_Response_from_Content_Safety\')?[\'categoriesAnalysis\']'
                    where: '@equals(item()[\'severity\'],0)'
                  }
                }
                Contains_Warnings: {
                  actions: {
                    Block_or_warn: {
                      actions: {
                        Update_item_set_blocked: {
                          type: 'ApiConnection'
                          inputs: {
                            host: {
                              connection: {
                                name: '@parameters(\'$connections\')[\'sharepointonlineconnection\'][\'connectionId\']'
                              }
                            }
                            method: 'patch'
                            body: {
                              Status: {
                                Value: 'Blocked'
                              }
                              Warning: {
                                Value: 'Warning'
                              }
                              EndTime: '@utcNow()'
                              Sentimentanalysisresult: '@string(body(\'Parse_JSON_Response_from_Content_Safety\'))'
                            }
                            path: '/datasets/@{encodeURIComponent(encodeURIComponent(\'${sharepointSiteUrl}\'))}/tables/@{encodeURIComponent(encodeURIComponent(variables(\'MainListId\')))}/items/@{encodeURIComponent(items(\'for_each\')?[\'ID\'])}'
                          }
                        }
                        Set_variable_blocked_to_true: {
                          type: 'SetVariable'
                          inputs: {
                            name: 'Blocked'
                            value: true
                          }
                        }
                      }
                      else: {
                        actions: {
                          Update_item_set_warning: {
                            type: 'ApiConnection'
                            inputs: {
                              host: {
                                connection: {
                                  name: '@parameters(\'$connections\')[\'sharepointonlineconnection\'][\'connectionId\']'
                                }
                              }
                              method: 'patch'
                              body: {
                                Warning: {
                                  Value: 'Warning'
                                }
                              }
                              path: '/datasets/@{encodeURIComponent(encodeURIComponent(\'${sharepointSiteUrl}\'))}/tables/@{encodeURIComponent(encodeURIComponent(variables(\'MainListId\')))}/items/@{encodeURIComponent(items(\'for_each\')?[\'ID\'])}'
                            }
                          }
                        }
                      }
                      expression: {
                        and: [
                          {
                            equals: [
                              '@toLower(variables(\'UseContentSafety\'))'
                              'block'
                            ]
                          }
                        ]
                      }
                      type: 'If'
                    }
                  }
                  runAfter: {
                    Filter_array: [
                      'Succeeded'
                    ]
                  }
                  else: {
                    actions: {}
                  }
                  expression: {
                    and: [
                      {
                        less: [
                          '@length(body(\'Filter_array\'))'
                          4
                        ]
                      }
                    ]
                  }
                  type: 'If'
                }
              }
              runAfter: {
                Translate: [
                  'Succeeded'
                ]
              }
              else: {
                actions: {}
              }
              expression: {
                and: [
                  {
                    not: {
                      equals: [
                        '@variables(\'UseContentSafety\')'
                        '@\'false\''
                      ]
                    }
                  }
                ]
              }
              type: 'If'
            }
            Is_blocked: {
              actions: {}
              runAfter: {
                UseContentSafety: [
                  'Succeeded'
                ]
              }
              else: {
                actions: {
                  Update_Item_set_analyzing: {
                    type: 'ApiConnection'
                    inputs: {
                      host: {
                        connection: {
                          name: '@parameters(\'$connections\')[\'sharepointonlineconnection\'][\'connectionId\']'
                        }
                      }
                      method: 'patch'
                      body: {
                        Status: {
                          Value: 'Analyzing'
                        }
                      }
                      path: '/datasets/@{encodeURIComponent(encodeURIComponent(\'${sharepointSiteUrl}\'))}/tables/@{encodeURIComponent(encodeURIComponent(variables(\'MainListId\')))}/items/@{encodeURIComponent(items(\'For_each\')?[\'ID\'])}'
                    }
                  }
                  Analyze_Sentiment: {
                    type: 'Http'
                    inputs: {
                      uri: '${languageService.properties.endpoint}language/:analyze-text?api-version=2024-11-01'
                      method: 'POST'
                      headers: {
                        'Ocp-Apim-Subscription-Key': languageService.listKeys().key1
                        'Ocp-Apim-Subscription-Region': location
                        'Content-Type': 'application/json'
                      }
                      body: {
                        Kind: 'SentimentAnalysis'
                        Parameters: {
                          ModelVersion: 'latest'
                        }
                        AnalysisInput: {
                          Documents: [
                            {
                              Id: '1'
                              Text: '@variables(\'Text\')'
                            }
                          ]
                        }
                      }
                    }
                  }
                  Parse_JSON_Response_from_Sentiment_Analysis: {
                    runAfter: {
                      Analyze_Sentiment: ['Succeeded']
                      Update_Item_set_analyzing: ['Succeeded']
                    }
                    type: 'ParseJson'
                    inputs: {
                      content: '@body(\'Analyze_Sentiment\')[\'results\'][\'documents\']'
                      schema: {
                        type: 'array'
                        items: {
                          type: 'object'
                          properties: {
                            id: {
                              type: 'string'
                            }
                            sentiment: {
                              type: 'string'
                            }
                            statistics: {
                              type: 'object'
                              properties: {
                                charactersCount: {
                                  type: 'integer'
                                }
                                transactionsCount: {
                                  type: 'integer'
                                }
                              }
                            }
                            confidenceScores: {
                              type: 'object'
                              properties: {
                                positive: {
                                  type: 'number'
                                }
                                neutral: {
                                  type: 'number'
                                }
                                negative: {
                                  type: 'number'
                                }
                              }
                            }
                            sentences: {
                              type: 'array'
                              items: {
                                type: 'object'
                                properties: {
                                  sentiment: {
                                    type: 'string'
                                  }
                                  confidenceScores: {
                                    type: 'object'
                                    properties: {
                                      positive: {
                                        type: 'number'
                                      }
                                      neutral: {
                                        type: 'number'
                                      }
                                      negative: {
                                        type: 'number'
                                      }
                                    }
                                  }
                                  offset: {
                                    type: 'integer'
                                  }
                                  length: {
                                    type: 'integer'
                                  }
                                  text: {
                                    type: 'string'
                                  }
                                }
                                required: [
                                  'sentiment'
                                  'confidenceScores'
                                  'offset'
                                  'length'
                                  'text'
                                ]
                              }
                            }
                            warnings: {
                              type: 'array'
                            }
                          }
                          required: [
                            'id'
                            'sentiment'
                            'confidenceScores'
                            'sentences'
                            'warnings'
                          ]
                        }
                      }
                    }
                  }
                  Update_Item_analyzing_Result: {
                    type: 'ApiConnection'
                    inputs: {
                      host: {
                        connection: {
                          name: '@parameters(\'$connections\')[\'sharepointonlineconnection\'][\'connectionId\']'
                        }
                      }
                      method: 'patch'
                      body: {
                        Sentiment: '@first(body(\'Parse_JSON_Response_from_Sentiment_Analysis\'))?[\'sentiment\']'
                        Sentiment_x002d_Positive: '@first(body(\'Parse_JSON_Response_from_Sentiment_Analysis\'))?[\'confidenceScores\']?[\'positive\']'
                        Sentiment_x002d_Neutral: '@first(body(\'Parse_JSON_Response_from_Sentiment_Analysis\'))?[\'confidenceScores\']?[\'neutral\']'
                        Sentiment_x002d_Negative: '@first(body(\'Parse_JSON_Response_from_Sentiment_Analysis\'))?[\'confidenceScores\']?[\'negative\']'
                        Sentimentanalysisresult: '@string(body(\'Parse_JSON_Response_from_Sentiment_Analysis\'))'
                        EndTime: '@utcNow()'
                        Status: {
                          Value: 'Done'
                        }
                      }
                      path: '/datasets/@{encodeURIComponent(encodeURIComponent(\'${sharepointSiteUrl}\'))}/tables/@{encodeURIComponent(encodeURIComponent(variables(\'MainListId\')))}/items/@{encodeURIComponent(items(\'For_each\')?[\'ID\'])}'
                    }
                    runAfter: {
                      Parse_JSON_Response_from_Sentiment_Analysis: ['Succeeded']
                    }
                  }
                }
              }
              expression: {
                and: [
                  {
                    equals: [
                      '@variables(\'Blocked\')'
                      '@true'
                    ]
                  }
                ]
              }
              type: 'If'
            }
          }
          runAfter: {
            Initialize_variable_Blocked: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
          runtimeConfiguration: {
            concurrency: {
              repetitions: 1
            }
          }
        }
        EmptyList: {
          actions: {
            Terminate: {
              type: 'Terminate'
              inputs: {
                runStatus: 'Succeeded'
              }
            }
          }
          runAfter: {
            Get_items: ['Succeeded']
          }
          else: {
            actions: {}
          }
          expression: {
            and: [
              {
                equals: [
                  '@length(body(\'Get_items\')?[\'value\'])'
                  0
                ]
              }
            ]
          }
          type: 'If'
        }
        Get_Settings: {
          runAfter: {
            EmptyList: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'sharepointonlineconnection\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/datasets/@{encodeURIComponent(encodeURIComponent(\'${sharepointSiteUrl}\'))}/tables/@{encodeURIComponent(encodeURIComponent(variables(\'SettingsListId\')))}/items'
          }
        }
        Parse_Settings: {
          runAfter: {
            Get_Settings: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'Get_Settings\')?[\'value\']'
            schema: {
              type: 'array'
              items: {
                type: 'object'
                properties: {
                  Title: {
                    type: 'string'
                  }
                  Value: {
                    type: 'string'
                  }
                }
                required: [
                  'Title'
                  'Value'
                ]
              }
            }
          }
        }
        Find_Translate: {
          runAfter: {
            Parse_Settings: [
              'Succeeded'
            ]
          }
          type: 'Query'
          inputs: {
            from: '@body(\'Parse_Settings\')'
            where: '@equals(item()[\'Title\'],\'Translate\')'
          }
        }
        Initialize_variable_Translate: {
          runAfter: {
            Find_Translate: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'Translate'
                type: 'string'
                value: '@toLower(first(body(\'Find_Translate\'))?[\'Value\'])'
              }
            ]
          }
        }
        Find_UseContentSafety: {
          runAfter: {
            Parse_Settings: [
              'Succeeded'
            ]
          }
          type: 'Query'
          inputs: {
            from: '@body(\'Parse_Settings\')'
            where: '@equals(item()[\'Title\'],\'UseContentSafety\')'
          }
        }
        Initialize_variable_UseContentSafety: {
          runAfter: {
            Find_UseContentSafety: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'UseContentSafety'
                type: 'string'
                value: '@toLower(first(body(\'Find_UseContentSafety\'))?[\'Value\'])'
              }
            ]
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          sharepointonlineconnection: {
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'sharepointonline')
            connectionId: sharepointApiConnection.id
            connectionName: sharepointApiConnection.name
          }
        }
      }
    }
  }
}
