/***********************************************************************************************************************
Name:AssignLeadTerritory
Copyright © Align Tech
========================================================================================================================
Purpose:
This class assigns the Lead to assign Owner based on the Zip Code Territory table   
========================================================================================================================
History
VERSION         AUTHOR                          DATE                DETAIL              
1.0                                                                 Initial development
2.0            Akhil Bommadevara                5/2/2021            SF-9880, updated assign lead territory method
3.0            Akhil Bommadevara                24/1/2022           AFS-683, Updated lead before conversion method
4.0            Akhil Bommadevara                27/6/2022           updated lead routing as part of AFS-1419
/********************************************************************************************************************/
public without sharing class AssignLeadTerritory 
{
    public static id iTeroSalesRecordTypeId=Schema.SObjectType.Lead.getRecordTypeInfosByName().get('iTero Sales').getRecordTypeId(); 
    /*constant for us country*/
    public static final String USA='us';
    public PageReference AssignLeadTerritoryAction()
    {
        String leadIds = ApexPages.currentPage().getParameters().get('Leads');
        
        if(leadIds != null && leadIds.trim().length() > 0)
        {
            /*String query = 'SELECT Company, OwnerID, Contact__C,LeadSource, Description, Status, Id,RecordTypeId, Name, FirstName, LastName, Street, ' + 
                'City, State, PostalCode FROM Lead WHERE Id IN (\'' + leadIds + '\')'; */
            //SF-9725 removed singlequotes to avoid SOQL Injection error
            String query = 'SELECT Company, OwnerID, Contact__C,LeadSource, Description, Status, Id,RecordTypeId, Name, FirstName, LastName, Street,City, State, PostalCode FROM Lead WHERE Id =: leadIds';
            List<Lead> listOfLeads = Database.Query(query);
                     
            // Process leads
            processAssignLeadTerritory(listOfLeads, listOfLeads, true, false);
            update listOfLeads;
        }
        
        // Return to list of leads
        PageReference retVal = new PageReference('/00Q/o');
        retVal.setRedirect(true);
        return retVal;
    }
    // Filter out records that don't need processing
    public List<Lead> filterData(List<Lead> triggerNew, Boolean triggerIsInsert, Map<Id, Lead> oldMap, Map<Id, Lead> newMap)
    {
        List<Lead> retVal = new List<Lead>();
        
        for(Lead o : triggerNew)
        {
            if(triggerIsInsert)
            {
                retVal.add(o);
            }
            else if(oldMap.get(o.Id).OwnerId == newMap.get(o.Id).OwnerId) // If owner hasn't changed, process
            {
                retVal.add(o);
            }
        }
        
        return retVal;
    }
 /**
	 * @author : Akhil bommadevara
	 * @date : 14/12/2021
	 * @description : Lead routing redesign
	 * @param triggerNew,triggerOld,triggerIsInsert,triggerIsUpdate
	 */      
public void processAssignLeadTerritory(List<Lead> triggerNew, List<Lead> triggerOld, Boolean triggerIsInsert, Boolean triggerIsUpdate) {
        // Make sure we have records to process
        if(triggerNew!=null && !triggernew.isEmpty()) {
            // Define local variables
            final Set<String>                         zipCodes = new Set<String>(); // Set of Zip Codes from the Leads to be assigned
            Id                                  defaultAdminId; // Used when territory owner is not found
            Boolean                             missingAdmin = true; // Set to false if active user found in custom setting
            String                              zipCode; // The Zip Code, truncated if needed.
            //List<NA_Lead_Record_Types__c> NaRecordTypeList = NA_Lead_Record_Types__c.getall().values();
            final Map<String, NA_Lead_Record_Types__c> nARecordTypeMap = NA_Lead_Record_Types__c.getAll();
            final Map<String,UserTerritory2Association> userTerritory2Map=new Map<String,UserTerritory2Association>();
            final Set<String> nARecordTypeIDSet = new Set<String>();
            list<RuleTerritory2Association> ruleTerritoryData=new List<RuleTerritory2Association>();
            final Set<Id>ruleIdSet=new Set<Id>();
            List<UserTerritory2Association> userTerritoryList =new List<UserTerritory2Association>();
            final Set<String> territorySet=new Set<String>();
            final Map<Id,List<String>> ruleTerritoryMap=new Map<Id,List<String>>();
            String valueCondition='(';
            final list<String> zipCodeList=new list<String>();
            for(String n: nARecordTypeMap.keyset()) {
                nARecordTypeIDSet.add(nARecordTypeMap.get(n).record_type_id__c);
            }
            // Get default system admin id from custom setting
            final List<DefaultSystemAdministrator__c> dsa = DefaultSystemAdministrator__c.getAll().values();
            if(dsa!=null && !dsa.isempty() && [SELECT count() FROM User WHERE Id = :dsa[0].UserId__c AND IsActive = true] == 1) {
                defaultAdminId = dsa[0].UserId__c;
                missingAdmin = false;
            }
            
            // Loop through the Leads populating the Set of relevant Ids
            
            System.debug('Evaluating Leads for assignment.');
            
            for(Lead l : triggerNew) {
                System.debug('Evaluating ' + l);
                //SF-8697-Added iTero BDM Condition by Akhil to skip lead routing, removed iTero BDM condition and added lead ownership condition as part of SF-9880
                if(NARecordTypeIDSet.contains(l.recordtypeid)&&l.Keep_Lead_Ownership__c==false ) {
                    // If the Zip Code is not null then add it
                    System.debug('Evaluating ' + l);
                    if(l.PostalCode != null) {
                        // Put the zip code in a holding variable
                        zipCode = l.PostalCode;
                        
                        // Truncate the zip code if needed, added usa and ca condition as part of AFS-1419
                        if (l.countrycode==USA) {
                            zipCode = zipCode.substring(0,5);
                        } else {  // If this is a Canadian zip code
                            zipCode = zipCode.substring(0,3);
                        }
                        
                        System.debug('Lead ' + l.Id + ' will be processed for Zip Code '+ zipCode + '.');
                        zipCodes.add(zipCode);
                    } // END IF the Zip Code is not null then add it
                }        
            }// END LOOP through the Leads populating the Set of relevant Ids
            
            //adding zip codes to a list and forming dynamic query as part of AFS-1419
            if(zipCodes!=null && !zipCodes.isEmpty()) {
                zipCodeList.addAll(zipCodes);
                for(Integer i=0;i<zipCodeList.size();i++) {
                    valueCondition=valueCondition+ 'value LIKE \'%'+String.escapeSingleQuotes(zipCodeList[i])+'%\'';
                    if(i!=zipCodeList.size()-1) {
                        valueCondition=valueCondition+' OR ';
                    }
                    }
            }
            valueCondition=valueCondition+')';
            //calling object territory 2 assignment rule item as part of AFS-1419
            ObjectTerritory2AssignmentRuleItem[] zipCodeData=new list<ObjectTerritory2AssignmentRuleItem>();
            if(zipCodeList!=null && !zipCodeList.isEmpty()) {
              final String query='select id,Field,Value,RuleId from ObjectTerritory2AssignmentRuleItem where field=\'Account.ShippingPostalCode\' and rule.isactive=true and '+valueCondition;
              zipCodeData=database.query(query);
            }
            if(zipCodeData!=null && !zipCodeData.isempty()) {
                for(ObjectTerritory2AssignmentRuleItem zip:zipCodeData) {
                    ruleIdSet.add(zip.RuleId);
                    }
                } 
                //calling rule territory 2 association as part of AFS-1419
                if(ruleIdSet!=null && !ruleIdSet.isempty()) {
                    ruleTerritoryData=[select id,ruleid,Territory2.developername from RuleTerritory2Association where ruleid in :ruleIdSet and Territory2.Territory2Type.developername in ('Invisalign','iTero') and Territory2.Region__c='NORTH AMERICA'];
                } 
            //forming map between rule and territories as part of AFS-1419   
            if(ruleTerritoryData!=null && !ruleTerritoryData.isempty()) {
                for(RuleTerritory2Association ruleTerritory:ruleTerritoryData) {
                    List<String> territoryList=new List<String>();
                    if(ruleTerritoryMap.get(ruleTerritory.ruleId)!=null) {
                        territoryList= ruleTerritoryMap.get(ruleTerritory.ruleId);
                    }
                    territoryList.add(ruleTerritory.Territory2.developername);
                    ruleTerritoryMap.put(ruleTerritory.ruleId,territoryList);
                    territorySet.add(ruleTerritory.Territory2.developername);
                }
            }
            //getting user in territories as part of AFS-1419
            if(territorySet!=null && !territorySet.isempty()) {
                userTerritoryList=[select ID,userid,territory2.developername,RoleInTerritory2 from UserTerritory2Association where territory2.developername in :territorySet and RoleinTerritory2!='Delegated TM'];        }
            if(userTerritoryList!=null && !userTerritoryList.isempty()) {
                for(UserTerritory2Association userTeriObj :userTerritoryList) {
                    userTerritory2Map.put(userTeriObj.Territory2.DeveloperName,userTeriObj);
                }
            }
            // Loop through the Leads setting the Owner
            for(Lead l : triggerNew) {
                System.debug('Evaluating Lead ' + l.Id + '.');
                 //SF-8697-Added iTero BDM Condition by Akhil to skip lead routing, removed iTero BDM condition and added lead ownership condition as part of SF-9880
                if(NARecordTypeIDSet.contains(l.recordtypeid)&&l.Keep_Lead_Ownership__c==false) {
                    // If the Zip Code is not null then proceed
                    System.debug('Evaluating Lead ' + l.Id + '.');
                    if(l.PostalCode != null) {
                        
                        // Put the zip code in a holding variable
                        Id userid=null;
                        zipCode = l.PostalCode;
                        
                        //getting zipcode from postal and country as part of AFS-1419
                        if (l.countrycode==USA) {
                            zipCode = zipCode.substring(0,5);
                        } else {  // If this is a Canadian zip code
                            zipCode = zipCode.substring(0,3);
                        }
                        //logic to get the user id from the territory
                        if(zipCodeData!=null && !zipCodeData.isempty()) {
                            for(ObjectTerritory2AssignmentRuleItem assignmentRule:zipCodeData) {
                                if(assignmentRule.value!=null && assignmentRule.value.contains(zipCode) && ruleTerritoryMap!=null && ruleTerritoryMap.get(assignmentRule.ruleId)!=null && assignmentRule.ruleId!=null && ruleTerritoryMap!=null && ruleTerritoryMap.get(assignmentRule.ruleId)!=null) {
                                for(String territoryDevName:ruleTerritoryMap.get(assignmentRule.ruleId)) {
                                    if(l.CountryCode==USA) {
                                        //assigning resto TM to lead as part of AFS-1419
                                        if(assignmentRule.value.contains(zipCode) && ruleTerritoryMap.get(assignmentRule.ruleId)!=null  && l.Territory_Assignment_Grouping__c!='Ortho' && (l.Line_of_Business__c!=null && !(l.Line_of_Business__c.contains('Invisalign Go') || l.Line_of_Business__c.contains('Invisalign'))) && userTerritory2Map!=null && userTerritory2Map.get(territoryDevName)!=null && userTerritory2Map.get(territoryDevName).RoleInTerritory2=='Restorative Territory Manager') {
                                            System.debug('Restorative');
                                            userId=userTerritory2Map.get(territoryDevName).userId;
                                            break;
                                        }
                                        if(userId==null) {
                                          //Assigning ortho TM to lead as part of AFS-1419  
                                          if(l.Territory_Assignment_Grouping__c=='Ortho' && assignmentRule.value.contains(zipCode) && ruleTerritoryMap.get(assignmentRule.ruleId)!=null && userTerritory2Map!=null && userTerritory2Map.get(territoryDevName)!=null && userTerritory2Map.get(territoryDevName).RoleInTerritory2=='Ortho Territory Manager') {
                                            System.debug('Ortho');
                                            userId=userTerritory2Map.get(territoryDevName).userId;  
                                          } else if(l.Territory_Assignment_Grouping__c=='GP' && assignmentRule.value.contains(zipCode) && ruleTerritoryMap.get(assignmentRule.ruleId)!=null && userTerritory2Map!=null && userTerritory2Map.get(territoryDevName)!=null && userTerritory2Map.get(territoryDevName).RoleInTerritory2=='Territory Manager') {
                                             
                                             System.debug('iTero GP');
                                             userId=userTerritory2Map.get(territoryDevName).userId;
                                             
                                           }
                                        }
                                    } else {
                                     // assigning tm for CAD as part of AFS-1419
                                     if(l.Territory_Assignment_Grouping__c=='Ortho' && assignmentRule.value.contains(zipCode) && ruleTerritoryMap.get(assignmentRule.ruleId)!=null && userTerritory2Map!=null && userTerritory2Map.get(territoryDevName)!=null &&userTerritory2Map.get(territoryDevName).RoleInTerritory2=='Ortho Territory Manager') {
                                        
                                         userId=userTerritory2Map.get(territoryDevName).userId;
                                         break;
                                         
                                     } else if(l.Territory_Assignment_Grouping__c=='GP' && assignmentRule.value.contains(zipCode) && ruleTerritoryMap.get(assignmentRule.ruleId)!=null && userTerritory2Map!=null && userTerritory2Map.get(territoryDevName)!=null && userTerritory2Map.get(territoryDevName).RoleInTerritory2=='Territory Manager') {
                                        userId=userTerritory2Map.get(territoryDevName).userId;   
                                        break;
                                     }
                                   }
                                }
                            }
                        }
                     }
                     //updating the owner as part of AFS-1419
                     if(userid!=null) {
                        l.ownerid=userid;
                     } 
                        
                    } else {
                        // Assign lead to default system admin, if a good one exists.
                        if(missingAdmin == false && l.leadsource!='snapADDY') {
                            l.OwnerId = defaultAdminId;
                        } 
                    }
                }
            } // END LOOP through the Leads setting the Owner
    
          
        }
    }
    //SF-1877 to populate the account type and account sub type with the values given in lead after lead conversion
    public void leadConversion(List<Lead> newLeads, Boolean isUpdate){
        //Map to store account id and lead record
        Map<Id,Lead> accountMap = new Map<Id,Lead>();
        //list of accounts to be updated
        List<Account> accountsList = new List<Account>();
        // Iterating the leads to create the accountmap
        for(lead leadRec : NewLeads){
            if(leadRec.IsConverted == true && leadRec.ConvertedAccountId != null && leadRec.CountryCode != null){
                accountMap.put(leadRec.ConvertedAccountId,leadRec);
             }
        }
        //Iterating the map when it is not null and mapping the type and sub type fields to account record 
        
        if(accountMap != null){
            for(Account convertedAcc : [select Id,Type,Account_Sub_Type__c from account where id =: accountMap.keySet()]){
                System.debug('Lead Conver******'+convertedAcc);
                //Mapping is only done when the Type and Sub type are null
                if(convertedAcc.Type == null && accountMap.containsKey(convertedAcc.Id)){
                    accountsList.add(new Account(
                                    Id = convertedAcc.Id,
                                    Type = accountMap.get(convertedAcc.Id).Account_Type__c,
                                    Account_Sub_Type__c = accountMap.get(convertedAcc.Id).Account_Sub_Type__c));
                }
            }
        }
        //Updating the account list
        if(accountsList != null){
            database.update(accountsList,false); 
        }
    }
    
    /**
	 * @author : Akhil bommadevara
	 * @date : 14/12/2021
	 * @description : AFS-335 validate lead on conversion
	 * @param leadList
	 */  
    public static void leadTrainingRecords(list<lead> leadList)
    {
     //Changed map to set as part of AFS-683   
     Set<Id> leadContactSet=new Set<Id>();   
     list<account> accountList=new list<account>();   
     List<Contact> contactList=new List<Contact>();   
     Map<Id,Account> accountCreatedMap=new Map<Id,Account>();   
     set<Id> leadAccountSet=new set<Id>();
     Map<Id,Contact> contactStatusMap=new Map<Id,Contact>();   
     Map<Id,AggregateResult> results;
     Id invisalignRecordTypeId  = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Invisalign').getRecordTypeId(); 
     Id iTeroRecordTypeId  = Schema.SObjectType.Account.getRecordTypeInfosByName().get('iTero').getRecordTypeId(); 
   
     for(Lead lead:leadList)
     {
        //Changed map to set as part of AFS-683 
        leadContactSet.add(lead.ConvertedContactId);
        leadAccountSet.add(lead.convertedAccountId);
     }
     //Changed map to set and included account status in account query as part of AFS-683   
     if(leadAccountSet.size()>0)
     {
        accountList=[select id,recordtypeid,Account_Status__c,Line_of_Business__c from account where id in :leadAccountSet];   
     }  
     if(accountList.size()>0)
     {
        for(account account:accountList)
        {
           accountCreatedMap.put(account.id,account);
        }
     }
     if(leadContactSet.size()>0)
     {
         //Getting contact list for set of converted contact id as part of AFS-683 
         contactList=[select id,Contact_Status__c,Status_Reason__c from Contact where id in :leadContactSet];
         results = new Map<id,AggregateResult>([SELECT contactId__c Id,COUNT(Id) ContactCount FROM Training_Records__c where ContactID__c in :leadContactSet and Training_Status__c='Attended' group by ContactID__c]);
     }
     //Forming contact status map as part of AFS-683   
     if(contactList.size()>0)
     {
         for(Contact Contact: contactList)
         {
             contactStatusMap.put(contact.id,contact);
         }
     }
     for(Lead lead: leadList)
     {
         
         if(accountCreatedMap!=null && accountCreatedMap.get(lead.convertedaccountid)!=null && (accountCreatedMap.get(lead.convertedaccountid).recordtypeid==invisalignRecordTypeId ||(accountCreatedMap.get(lead.convertedaccountid).recordtypeid==iTeroRecordTypeId && accountCreatedMap.get(lead.ConvertedAccountId).Line_of_Business__c!=null && (accountCreatedMap.get(lead.ConvertedAccountId).Line_of_Business__c.contains('Invisalign')||accountCreatedMap.get(lead.ConvertedAccountId).Line_of_Business__c.contains('Invisalign Go')))))
         {
            //added line of business condition for iTero records as part of AFS-1553
            if(contactTriggerHandler.contactids!=null && contactTriggerHandler.contactids.contains(lead.convertedcontactid))
            {
                lead.adderror('You cannot create new contacts for accounts that contains invisalign/ invisalign GO as line of business');
                //added continue as part of AFS-642
                continue;
            }
            else if(results==null || results.isempty() || (results !=null && results.get(lead.ConvertedContactId)!=null && results.get(lead.ConvertedContactId).get('ContactCount')==0))
            {
                lead.adderror('No training record exist for the selected contact');
                //added continue as part of AFS-642
                continue;
            }
         }
         //Throwing error before conversion if account status is inactive or contact status is limited as part of AFS-683
         if((accountCreatedMap!=null && accountCreatedMap.get(lead.convertedaccountid)!=null && accountCreatedMap.get(lead.convertedaccountid).Account_Status__c=='Inactive')||(contactStatusMap!=null && contactStatusMap.get(lead.ConvertedContactId)!=null && ((contactStatusMap.get(lead.ConvertedContactId).Contact_Status__c=='Limited' && contactStatusMap.get(lead.ConvertedContactId).Status_Reason__c=='Finance Hold')||contactStatusMap.get(lead.ConvertedContactId).Contact_Status__c=='Inactive')))
         {
             lead.adderror('You cannot convert lead on an inactive Account or limited Contact with status reason Finance Hold or inactive contact');
         }
     }
   
   }
   /**
	 * @author : Akhil bommadevara
	 * @date : 29/12/2021
	 * @description : AFS-541 lead contact update
	 * @param leadset, leadOldMap
	 */   
   public static void leadAccountShare(set<Id> leadSet,Map<Id,lead> leadOldMap,boolean isInsert, boolean isUpdate)
   {
     Map<Id,Id> accountShareMap=new Map<Id,Id>();
     Map<Id,Id> contactIdMap=new Map<Id,Id>();  
     for(Lead lead:[select id,contact__c,isconverted,OwnerId,contact__r.accountId,contact__r.account.ownerid,status from lead where id in :leadSet])
     {
         //assigning account access whenever their is change in lead owner as part of AFS-831
         if(((isInsert && lead.Contact__c!=null && lead.Contact__r.AccountId!=null) || (isUpdate && (leadOldMap.get(lead.id).contact__c != lead.contact__c || leadOldMap.get(lead.id).ownerid!=lead.ownerid) && lead.contact__c!=null && lead.Contact__r.AccountId!=null && lead.status!='Dead' && lead.IsConverted==false)) && lead.Contact__r.account.ownerid!=lead.ownerid)
         {
             accountShareMap.put(lead.Contact__r.AccountId,lead.ownerid);
         }
         if(isUpdate && leadOldMap.get(lead.id).contact__c!=lead.contact__c && leadOldMap.get(lead.id).contact__c!=null)
         {
             contactIdMap.put(leadOldMap.get(lead.id).contact__c,lead.ownerid);
         }
         if(isUpdate && leadOldMap.get(lead.id).status!=lead.status && (lead.isconverted==true || lead.status=='Dead') && lead.contact__c!=null)
         {
             contactIdMap.put(lead.contact__c,lead.ownerid);
         }
         //removing account access to old lead owner as part of AFS-831
         if(isUpdate && leadOldMap.get(lead.id).OwnerId!=lead.OwnerId)
         {
             contactIdMap.put(lead.Contact__c,leadOldMap.get(lead.id).OwnerId);
         }
     }
     if(accountShareMap!=null && !accountShareMap.isempty())
     {
         list<AccountShare> accShareList=new list<AccountShare>();
         Map<String,String> accountShareExistMap=new Map<String,String>();
         AccountShare[] accountExistingShare=[select id,accountid,userorgroupid,accountaccesslevel from accountshare where accountaccesslevel='Edit' and accountid In :accountShareMap.keyset()];
         if(accountExistingShare.size()>0)
         {
             for(AccountShare accountExisting:accountExistingShare)
             {
               accountShareExistMap.put(String.valueof(accountExisting.accountid)+'+'+String.valueof(accountExisting.userorgroupid),accountExisting.accountaccesslevel);  
             }
         }
         System.debug('account share'+accountShareMap+''+accountShareExistMap);
         if(accountShareMap!=null && !accountShareMap.isempty())
         {
             for(Id accountId:accountShareMap.keyset())
             {
                 if(accountShareExistMap==null || (accountShareMap!=null && accountShareExistMap!=null && accountShareMap.get(accountId)!=null && accountShareExistMap.get(accountId+'+'+accountShareMap.get(accountId))==null))
                 {
                     AccountShare accShare=new AccountShare();
                     accShare.AccountId=accountId;
                     accShare.UserOrGroupId=accountShareMap.get(accountId);
                     accShare.AccountAccessLevel='Edit';
                     accShare.OpportunityAccessLevel='None';
                     accShareList.add(accShare);
                 }
             }
         }
         if(accShareList.size()>0)
         {
            database.insert(accShareList,false);
         }
     }
     if(contactIdMap!=null && !contactIdMap.isempty())
     {
        Map<String,Integer> ownerCount=new Map<String,Integer>(); 
        list<Contact> contactList=[select id,accountid from contact where id=:contactIdMap.keySet()]; 
        list<Lead> contactCount =[select contact__c,ownerid from lead where Contact__c in :contactIdMap.keySet() and status!='Dead' and isconverted=false and Contact__c!=null and recordtypeid=:iTeroSalesRecordTypeId];
        Map<Id,Id>accountContactMap=new Map<Id,Id>();
        Set<Id>accountIdSet=new Set<Id>();
        if(contactCount.size()>0)
        {
            for(Lead lead:contactCount)
            {
                if(lead.contact__c!=null && ownerCount.get(lead.contact__c+'+'+lead.ownerid)==null)
                {
                    ownerCount.put(lead.contact__c+'+'+lead.ownerid,1);
                }
                if(lead.contact__c!=null && ownerCount.get(lead.contact__c+'+'+lead.ownerid)!=null)
                {
                    ownerCount.put(lead.contact__c+'+'+lead.ownerid,ownerCount.get(lead.contact__c+'+'+lead.ownerid)+1);
                }
            }
        }
        System.debug('owner count'+ownerCount); 
        System.debug('contact map'+contactIdMap); 
        if(contactList.size()>0)
        {
            for(contact con:contactList)
            {
              if(ownerCount==null ||ownerCount.isempty()|| (ownerCount!=null && contactIdMap!=null && contactIdMap.get(con.id)!=null && (ownerCount.get(con.id+'+'+contactIdMap.get(con.id))==null||ownerCount.get(con.id+'+'+contactIdMap.get(con.id))<1)))
              {
                accountIdSet.add(con.accountid);  
                accountContactMap.put(con.accountid,con.id);  
              }
            }
        }
        list<AccountShare> accountShareList=new list<AccountShare>(); 
        if(accountIdSet.size()>0)
        {
           accountShareList=[select id,UserOrGroupId,AccountId from AccountShare where AccountId in :accountIdSet and RowCause='Manual']; 
        }
        list<AccountShare> accountShareDelete=new list<AccountShare>();
        if(accountShareList.size()>0)
        {
          for(AccountShare accShare:accountShareList)
          {
             if(accountContactMap!=null && accountContactMap.get(accShare.AccountId)!=null && contactIdMap.get(accountContactMap.get(accShare.AccountId))!=null && contactIdMap.get(accountContactMap.get(accShare.AccountId))==accShare.UserOrGroupId)
             {
                accountShareDelete.add(accShare);
             }
          }
        }
        if(accountShareDelete.size()>0)
        {
            database.delete(accountShareDelete,false);
        }
     }
       
   }
   @future
   /**
	 * @author : Akhil bommadevara
	 * @date : 02/05/2022
	 * @description : convert leads if already has existing contact and account
	 * @param leadset, clinicianList, emailList
	 */   
   public static void convertLead(Set<Id> leadSet,List<String> clinicianList,List<String> emailList)
   {
     Map<String,Contact> contactClinMap=new Map<String,Contact>();  
     List<Lead> leadList=[SELECT Id,email,clinician_id__c from lead where id in:leadSet];
     Map<Id,Contact> leadConversionMap=new Map<Id,Contact>();
     List<Lead> leadUpdateList=new List<Lead>();
     List<Contact>contactClinList=new List<Contact>();
     List<contact>contactEmailList=new List<Contact>();
     try
     {
     //get the contacts that has the matching clinid
     if(clinicianList!=null && clinicianList.size()>0) 
     {
        contactClinList=[SELECT ID,Clinician_ID__c,accountId from contact where Clinician_ID__c in :clinicianList and Clinician_ID__c!=null];
     }
     Map<String,List<Contact>> contactEmailMap=new Map<String,List<Contact>>();
     //form a map between clin id and contact
     if(contactClinList.size()>0)
     {
         for(Contact con:contactClinList)
         {
            contactClinMap.put(con.Clinician_ID__c,con);
         }
     }
     //get the contacts with matching emails and sort it in descending order
     if(emailList!=null && emailList.size()>0)
     {
       contactEmailList=[SELECT Id,email,Certification_Date__c,account.line_of_business__c,Contact_Status__c from contact where email in :emailList and account.Promotion_Region__c ='NORTH AMERICA'  order by Certification_Date__c desc];
     }
     //form map between email and list of contacts
     if(contactEmailList.size()>0)
     {
         for(Contact con:contactEmailList)
         {
            if(contactEmailMap.get(con.email)==null)
            {
                list<Contact> contactMapList=new List<Contact>();
                contactMapList.add(con);
                contactEmailMap.put(con.email,contactMapList);
            }
            else 
            {
                list<Contact> contactMapList=contactEmailMap.get(con.email);
                contactMapList.add(con);
                contactEmailMap.put(con.email,contactMapList); 
            }
         }
     }
     for(Lead lead:leadList)
     {
         //if clincian ID exists get the contact
         if(lead.Clinician_ID__c!=null && contactClinMap!=null && contactClinMap.get(lead.Clinician_ID__c)!=null)
         {
            Contact con=contactClinMap.get(lead.Clinician_ID__c);
            leadConversionMap.put(lead.id,con);     
         }
         //if clin id doesn't exist on lead get the contact from email
         else if(lead.Clinician_ID__c==null && contactEmailMap!=null && contactEmailMap.get(lead.email)!=null)
         {
            list<Contact> contactLeadList=contactEmailMap.get(lead.email); 
            //if only one contact exist get the contact
            if(contactLeadList!=null && contactLeadList.size()==1)
            {
                leadConversionMap.put(lead.id,contactLeadList[0]);    
            }
            //if more than one contact exist get the active contact with LOB contains invisalign
            else if(contactLeadList!=null && contactLeadList.size()>1)
            {    
                for(Contact con:contactLeadList)
                {
                    if(con.Certification_Date__c!=null && con.Contact_Status__c=='Active' && con.account.line_of_business__c!=null && con.account.line_of_business__c.contains('Invisalign'))
                    {
                        leadConversionMap.put(lead.id,con);    
                        break;
                    }
                }
            }
         }
     }
     List<Database.LeadConvert> leadConvertList=new List<Database.LeadConvert>();
     //for each lead that contains contact convert it into opportunity
     if(leadConversionMap!=null && leadConversionMap.size()>0)
     {
        for(Id leadId:leadConversionMap.keySet())
        {
            if(leadConversionMap.get(leadId)!=null)
            {
                Database.LeadConvert lc1 = new database.LeadConvert();
                lc1.setLeadId(leadId);
                lc1.setAccountId(leadConversionMap.get(leadId).accountId);
                lc1.setContactId(leadConversionMap.get(leadId).Id);
                lc1.setConvertedStatus('Converted to Opportunity');
                lc1.setDoNotCreateOpportunity(false);
                leadConvertList.add(lc1);
                Lead lead=new Lead();
                lead.id=leadId;
                lead.Address_Validation__c='Validated';
                lead.contact__c=leadConversionMap.get(leadId).Id;
                leadUpdateList.add(lead);
            }
        }   
    }
    //update contact field on lead
     if(leadUpdateList.size()>0)
     {
         update leadUpdateList;
     }
     //convert the lead
     if(leadConvertList.size()>0)
     {
      Database.LeadConvertResult[] leadConvertResult = Database.convertLead(leadConvertList,true);  
     }
   }
     Catch(Exception e)
     {
      UCB_ExceptionService exceptionService = new UCB_ExceptionService(userinfo.getuserid(), 'Automatic Lead Conversion', 'Lead Conversion error', '');
      exceptionService.add(e); 
      exceptionService.publish();  
     }
   }
}
