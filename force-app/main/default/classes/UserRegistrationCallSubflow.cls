public class UserRegistrationCallSubflow {
    
    @InvocableMethod(label = 'Call Subflow')
    public static List<ResultVariables> callSubflow(FlowInput[] inputs) {
        Boolean isBetaUser = false;
        Boolean isRegistered = false;
        List<ResultVariables> finalResult = new List<ResultVariables>{new ResultVariables(isBetaUser, isRegistered)};
        for(FlowInput input : inputs) {
            Map<String,Object> inputVariablesMap = (Map<String,Object>)JSON.deserializeUntyped(input.inputVariablesJSON);
            List<ResultVariables> results = startFlow(
                input.flowApiName,
                input.flowNamespace,
                inputVariablesMap
            );
            finalResult = results;
        }
        return new List<ResultVariables>{new ResultVariables(finalResult[0].IsBetaUser, finalResult[0].isRegistered)};
        //return finalResult;
    }

    static List<ResultVariables> startFlow(String flowApiName, String namespace, Map<String,Object> inputVariablesMap) {
        Flow.Interview subflow;
        if(String.isEmpty(namespace)) {
            subflow = Flow.Interview.createInterview(flowApiName, inputVariablesMap);
        } else {
            subflow = Flow.Interview.createInterview(namespace, flowApiName, inputVariablesMap);
        }
        subflow.start();
        Boolean isBetaUser = (Boolean) subflow.getVariableValue('IsBetaUser');
        Boolean isRegistered = (Boolean) subflow.getVariableValue('IsRegistered');
        return new List<ResultVariables>{new ResultVariables(isBetaUser, isRegistered)};
    }

    public class FlowInput {
        @InvocableVariable(label='JSON of Input Variables')
        public String inputVariablesJSON;

        @InvocableVariable(label='Flow API name' description='Make sure the flow is active.')
        public String flowApiName;

        @InvocableVariable(label='Flow Namespace' description='Leave blank if the flow does not have a namespace.')
        public String flowNamespace;
    }
    public class ResultVariables {
        @InvocableVariable
        public Boolean IsBetaUser;
        
        @InvocableVariable
        public Boolean IsRegistered;        

        public ResultVariables(Boolean isBetaUser, Boolean isRegistered) {
            
            this.IsBetaUser = isBetaUser;
            this.IsRegistered = isRegistered;
        }
    }

}