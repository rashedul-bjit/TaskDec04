global class BatchTaskandProjectManagement implements Database.Batchable<sObject>, Database.Stateful {
    public Integer totalProcessed = 0;
    public Integer totalOverdueTask = 0;
    public Integer totalCostUpdate = 0;
    Map<Id, Decimal> projectCostMap = new Map<Id, Decimal>();
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator('SELECT Id, Task_Status__c, Due_Date__c, Project__c From Task__c');	

    }
    global void execute(Database.BatchableContext BC, List<sObject> scope){
        Map<Id, Decimal> taskCostByProject = new Map<Id, Decimal>();
        
        for(Task__c tsk: (List<Task__c>)scope){
            if(tsk.Task_Status__c != 'Completed' && tsk.Due_Date__c < Date.today()){
                tsk.Task_Status__c = 'Overdue';
                totalOverdueTask += 1;
            }else if(tsk.Task_Status__c == 'Overdue'){
                totalOverdueTask += 1;
            }


            if (tsk.Project__c != null && tsk.Task_Cost__c != null) {
                if (!taskCostByProject.containsKey(tsk.Project__c)) {
                    taskCostByProject.put(tsk.Project__c, 0);   
                }
                taskCostByProject.put(tsk.Project__c, taskCostByProject.get(tsk.Project__c) + tsk.Task_Cost__c);
                totalCostUpdate += 1;
            }
        }

        for (Id projectId : taskCostByProject.keySet()) {
            if (!projectCostMap.containsKey(projectId)) {
                projectCostMap.put(projectId, 0);
            }
            projectCostMap.put(projectId, projectCostMap.get(projectId) + taskCostByProject.get(projectId));
        }
        totalProcessed += scope.size();

        update scope;
    }
    
    global void finish(Database.BatchableContext BC){
        try{
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    
            Profile sys_adm_profile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
            List<User> sys_adm = [SELECT Id, Email FROM User WHERE ProfileId = :sys_adm_profile.Id];

            String[] toAddresses = new String[sys_adm.size()];
            for (Integer i = 0; i < sys_adm.size(); i++) {
                toAddresses[i] = sys_adm[i].Email;
            }
            mail.setToAddresses(toAddresses);
    
            mail.setSubject('Due Date and Total Cost Updated!!!');
            mail.setPlainTextBody('Total number of tasks completed - ' + totalProcessed + ' records updated.\n' + 
            'Total number of overdue tasks - ' + totalOverdueTask 
            + '\nTotal number of cost updated - ' + totalCostUpdate);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            System.debug(totalProcessed+ ' records updated.'+totalOverdueTask+ ' '+totalCostUpdate);
        }catch(Exception e){
            System.debug(e.getMessage());
        }
    }
}