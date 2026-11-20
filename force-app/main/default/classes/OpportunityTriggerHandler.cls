public class OpportunityTriggerHandler {
    
    public static void createReservationRequest(
        List<Opportunity> newList,
        Map<Id, Opportunity> oldMap
    ){
        
        List<Reservation_Request__c> reservationList = new List<Reservation_Request__c>();
        
        for(Opportunity opp : newList){
            
            Opportunity oldOpp = oldMap.get(opp.Id);
            
            // Create only when stage changes to Closed Won
            if(
                opp.StageName == 'Closed Won' &&
                oldOpp.StageName != 'Closed Won'
            ){
                
                Reservation_Request__c rr = new Reservation_Request__c();
                
                // Basic Details
               // rr.Name = opp.Name + ' - Reservation';
                rr.Opportunity__c = opp.Id;
                rr.Account__c = opp.AccountId;
                rr.Status__c = 'Pending';
                
                // Tour Details
                rr.Tour_Name__c = opp.Tour__c;
                rr.Tour_Start_Date__c = opp.Tour_Start_Date__c;
                rr.Tour_End_Date__c = opp.Tour_End_Date__c;
                rr.Destination_Country__c = opp.Destination__c;
                
                // PAX & Hotel
                rr.No_of_PAX__c = opp.Number_of_Pax__c;
                rr.Hotel_Tier__c = opp.Hotel_Tier__c;
                
                // Financial
                rr.Accepted_Amount__c = opp.Amount;
                rr.Agreed_Amount__c = opp.Amount;
                //rr.Balance_Amount__c = opp.Balance_Outstanding__c;
                
                // Group Leader
                rr.Group_Leader__c = opp.ContactId;
                
                // Dates
                rr.Request_Sent_Date__c = Date.today();
                //rr.Response_Deadline__c = Date.today().addDays(3);
                rr.Full_Payment_Due_Date__c = opp.CloseDate;
                
                // Status
              //  rr.Status__c = 'Requested';
                
                // Notes
                rr.Notes__c = opp.Description;
                
                reservationList.add(rr);
            }
        }
        
        if(!reservationList.isEmpty()){
            insert reservationList;
        }
    }
}