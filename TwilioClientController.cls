/***********************************************************************************************************************************************************************
Class Used: TwilioClientController

References to :TwilioClick2DialPage

Created Date : 16 May 2017  

Description : Call to twilio api and get App Id and call id in response then reesend Dial Xml to Twilio

******************************/
public class TwilioClientController {
    
        public  String LeadId{ get; set; }
        public  String emailBody { get; set; }
        public  String emailSubject { get; set; }
        public  String comments { get; set; }
        private TwilioCapability capability;
        public  String uname {get; set;}
        public  string selectedValue { get;set; }
        public  string typeSelectedValue { get;set; }
        public  date dueDate{get; set;}
        public  string taskComment{get; set;}
        public  list<Custom_Lead__c> leadObj { get;set; }
        public  string voicemailErrorMsg { get;set; }
        
        
        //Initalizer - Set up Twilio Capability Token - requires ApplicationSid__c to be set
        public TwilioClientController() {
            capability = TwilioAPI.createCapability();
            capability.allowClientOutgoing(TwilioAPI.getTwilioConfig().ApplicationSid__c,null);
            capability.allowClientIncoming('salesforce_agent');
        }
        
        //{!Token} method returns a string based capability token
        public String getToken() { return capability.generateToken(); }
        
        public TwilioConfig__c getTwilioConfig(){
        	return TwilioAPI.getTwilioConfig();
        }
        
        //Pass in a parameter PhoneNumber - and this will Dial the phone number
        public String getDial() {
        	
            String callerid;
            String recordingCallbackUrl = TwilioAPI.getTwilioConfig().Recording_Callback_Url__c;
                    
            //Phone number,Id,UserId will be passed as http query parameter
            String PhoneNumber = System.currentPageReference().getParameters().get('PhoneNumber');
            String Id = System.currentPageReference().getParameters().get('Id');
            String UserId = System.currentPageReference().getParameters().get('UserId');
            
            leadObj = [Select id,Country__c from Custom_Lead__c where id=:Id];
            if(String.isNotBlank(leadObj.get(0).Country__c) && leadObj.get(0).Country__c.equalsIgnoreCase('UK')){
            	callerid = TwilioAPI.getTwilioConfig().CallerIdUk__c;
            }else if(String.isNotBlank(leadObj.get(0).Country__c) 
            	&& (leadObj.get(0).Country__c.equalsIgnoreCase('Hong Kong')
            		|| leadObj.get(0).Country__c.equalsIgnoreCase('China')
            		|| leadObj.get(0).Country__c.equalsIgnoreCase('Macau')
            	)){
            	
            	callerid = TwilioAPI.getTwilioConfig().CallerIdHongKong__c;
            }else{
            	callerid = TwilioAPI.getTwilioConfig().CallerId__c;
            }
            
            
            
            TwilioTwiML.Response res = new TwilioTwiML.Response();
            
            TwilioTwiML.Dial d = new TwilioTwiML.Dial();
            d.setCallerId(callerid);
            d.setRecord(true);      
            d.setRecordingStatusCallback(recordingCallbackUrl+Id+'-'+UserId); 
            
            TwilioTwiML.PhoneNumber dialnumber = new TwilioTwiML.PhoneNumber(PhoneNumber);
           	
           	d.append(dialnumber);
          	
            res.append(d);
            
            return res.toXML();
        }
        
        public List<SelectOption> getvoicemailOptions() {
            List<SelectOption> options = new List<SelectOption>();
            set<Id> contentversionIdSet = new set<Id>();
            for(ContentWorkspaceDoc cwd : [Select id,
            										ContentDocument.Title,
            										ContentDocument.LatestPublishedVersionId 
            										from ContentWorkspaceDoc 
            										where ContentWorkspace.name = 'Voicemail Audio Files']){
            	contentversionIdSet.add(cwd.ContentDocument.LatestPublishedVersionId);
            }
            
            for(ContentDistribution conDistObj: [Select id,
					            					ContentVersion.PathOnClient,
					            					ContentVersion.title,
					            					ContentVersionId,
					            					DistributionPublicUrl
					            					from ContentDistribution 
					            					where ContentVersionId In: contentversionIdSet]){
				String endUrl = conDistObj.DistributionPublicUrl.split('/a/',2)[1];		   
				String host = URL.getSalesforceBaseUrl().toExternalForm();
        		String downUrl = host+'/sfc/dist/version/download?ids='+conDistObj.ContentVersionId+'&oid='+UserInfo.getOrganizationId()+'&d=/a/'+endUrl;         						
				options.add(new SelectOption(downUrl,conDistObj.ContentVersion.title));	
			}
            
            return options;
        }
        
        
        public List<SelectOption> gettypeOptions() {
            List<SelectOption> options = new List<SelectOption>();
            Schema.DescribeFieldResult typeFieldDescription = Task.Type.getDescribe();
            
            
            for (Schema.Picklistentry picklistEntry : typeFieldDescription.getPicklistValues()){
                options.add(new SelectOption(pickListEntry.getValue(),pickListEntry.getLabel()));
            }
            return options;
        }
        
        
        public PageReference LeadDetail(){
            leadObj = [Select id,First_Name__c,Last_Name__c,Email__c,Phone__c,Country__c from Custom_Lead__c where id=:LeadId];
            return null;     
        }
        
        //Sending Email to lead email and creating related task
        public void sendEmail() {
            try{
                If(String.isBlank(leadObj.get(0).Email__c) || String.isBlank(emailSubject) || String.isBlank(emailBody)){
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, 'Email address or subject or body can not be blank.')); 
                    return;
                }
                List<String> emails = new List<String>(); 
                emails.add(leadObj.get(0).Email__c);
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(emails);
                mail.setSubject(emailSubject);
                mail.setHtmlBody(emailBody);
                mail.setsaveasActivity(true);
                mail.setWhatId(LeadId);
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] {mail});
                
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, ' Email sent successfully.')); 
                return;
            }catch(Exception e){
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info,e.getmessage())); 
                return;
            }
        
        }

        //Create a task with task comments
        public  void createTask() {
            try{
                If(String.isBlank(LeadId) || String.isBlank(taskComment) || String.isBlank(typeSelectedValue)){
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, 'Parent or task comment or type can not be blank.')); 
                    return;
                }
                
                Task newTask = new Task(Description = taskComment, 
                                        ActivityDate = dueDate, 
                                        WhatId = LeadId,
                                        Type = typeSelectedValue);             
                insert newTask;  
                
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, ' Task is created successfully.')); 
                return;
            }catch(Exception e){
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info,e.getmessage())); 
                return;
            }
                  
        }
        
        //Updating status of  lead
        public  void updateLead() {
            try{
                If(String.isBlank(selectedValue) || leadObj == null || leadObj.isEmpty()){
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, 'Lead Comment or Lead Details can not be blank')); 
                    return;
                }
                leadObj.get(0).Comments__c = comments;
                
                update leadObj;
                
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, ' Lead Comment is updated successfully.')); 
                return;  
            }catch(Exception e){
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info,e.getmessage())); 
                return;
            }
        }
        
        
    }
