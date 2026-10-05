import QtQuick

ApiStrategy {
    property bool isReasoning: false
    property string pendingToolName: ""
    property string pendingToolId: ""
    property string pendingToolArguments: ""
    
    function buildEndpoint(model: AiModel): string {
        // console.log("[AI] Endpoint: " + model.endpoint);
        return model.endpoint;
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        let baseData = {
            "model": model.model,
            "messages": [
                {role: "system", content: systemPrompt},
                ...messages.map(message => {
                    const hasFunctionCall = message.functionCall != undefined && message.functionName.length > 0
                    let messageData = {
                        "role": message.role,
                        "content": message.rawContent,
                    }
                    if (message.functionResponse?.length > 0 && message.functionName.length > 0) {
                        messageData.role = "tool";
                        messageData.content = message.functionResponse;
                        messageData.tool_call_id = message.functionCall?.id;
                    } else if (hasFunctionCall) {
                        messageData.tool_calls = [{
                            id: message.functionCall.id,
                            type: "function",
                            function: {
                                name: message.functionName,
                                arguments: JSON.stringify(message.functionCall.args ?? {})
                            }
                        }];
                    }
                    return messageData
                }),
            ],
            "stream": true,
            "temperature": temperature,
            "tools": tools,
        };
        // console.log("[AI] Request data: ", JSON.stringify(baseData, null, 2));
        return model.extraParams ? Object.assign({}, baseData, model.extraParams) : baseData;
    }

    function buildAuthorizationHeader(apiKeyEnvVarName: string): string {
        return `-H "Authorization: Bearer \$\{${apiKeyEnvVarName}\}"`;
    }

    function parseResponseLine(line, message) {
        // Remove 'data: ' prefix if present and trim whitespace
        let cleanData = line.trim();
        if (cleanData.startsWith("data:")) {
            cleanData = cleanData.slice(5).trim();
        }
        
        // Handle special cases
        if (!cleanData || cleanData.startsWith(":")) return {};
        if (cleanData === "[DONE]") {
            return { finished: true };
        }
        
        // Real stuff
        try {
            const dataJson = JSON.parse(cleanData);

            // Error response handling
            if (dataJson.error) {
                const errorMsg = `**Error**: ${dataJson.error.message || JSON.stringify(dataJson.error)}`;
                message.rawContent += errorMsg;
                message.content += errorMsg;
                return { finished: true };
            }

            let newContent = "";

            const responseContent = dataJson.choices[0]?.delta?.content || dataJson.message?.content;
            const responseReasoning = dataJson.choices[0]?.delta?.reasoning || dataJson.choices[0]?.delta?.reasoning_content;

            // Function call
            if (dataJson.choices[0]?.delta?.tool_calls) {
                const functionCall = dataJson.choices[0].delta.tool_calls[0];
                pendingToolName += functionCall.function?.name ?? "";
                pendingToolId += functionCall.id ?? "";
                pendingToolArguments += functionCall.function?.arguments ?? "";
            }
            if (dataJson.choices[0]?.finish_reason === "tool_calls" && pendingToolName) {
                const args = JSON.parse(pendingToolArguments || "{}");
                const call = { name: pendingToolName, args, id: pendingToolId };
                message.functionName = pendingToolName;
                message.content += "\n\n### Tool call · " + pendingToolName
                    + "\n\n```json\n" + JSON.stringify(args, null, 2) + "\n```";
                pendingToolName = "";
                pendingToolId = "";
                pendingToolArguments = "";
                return { functionCall: call };
            }

            // Thinking?
            if (responseContent && responseContent.length > 0) {
                if (isReasoning) {
                    isReasoning = false;
                    const endBlock = "\n\n</think>\n\n";
                    message.content += endBlock;
                    message.rawContent += endBlock;
                }
                newContent = responseContent;
            } else if (responseReasoning && responseReasoning.length > 0) {
                if (!isReasoning) {
                    isReasoning = true;
                    const startBlock = "\n\n<think>\n\n";
                    message.rawContent += startBlock;
                    message.content += startBlock;
                }
                newContent = responseReasoning;
            }

            // Text
            message.content += newContent;
            message.rawContent += newContent;

            // Usage metadata
            if (dataJson.usage) {
                return {
                    tokenUsage: {
                        input: dataJson.usage.prompt_tokens ?? -1,
                        output: dataJson.usage.completion_tokens ?? -1,
                        total: dataJson.usage.total_tokens ?? -1
                    }
                };
            }

            if (`dataJson`.done) {
                return { finished: true };
            }
            
        } catch (e) {
            console.log("[AI] Mistral: Could not parse line: ", e);
            message.rawContent += line;
            message.content += line;
        }
        
        return {};
    }
    
    function onRequestFinished(message) {
        return {};
    }
    
    function reset() {
        isReasoning = false;
        pendingToolName = "";
        pendingToolId = "";
        pendingToolArguments = "";
    }

}
