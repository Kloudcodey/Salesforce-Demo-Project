trigger OpportunityInvoiceEmailTrigger on Opportunity (after update, after insert) {

    // ── 1. Stage-change email logic ──────────────────────────────────────────
    List<Id> stageChangedIds = new List<Id>();

    for (Opportunity opp : Trigger.new) {
        // On insert, oldMap is null — treat as a stage "change" only if needed
        Boolean stageChanged = (Trigger.isInsert)
            ? false  // adjust to 'true' if you want inserts to trigger emails
            : opp.StageName != Trigger.oldMap.get(opp.Id).StageName;

        if (stageChanged) {
            stageChangedIds.add(opp.Id);
        }
    }

    if (!stageChangedIds.isEmpty()) {
        OpportunityInvoiceEmailHandler.sendEmailFuture(stageChangedIds);
    }

    // ── 2. Closed Won → create Reservation Requests ──────────────────────────
    //    Only valid on AFTER UPDATE (records must exist; oldMap must be available)
    if (Trigger.isUpdate) {
        List<Id> closedWonIds = new List<Id>();

        for (Opportunity opp : Trigger.new) {
            Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
            if (opp.StageName == 'Closed Won' && oldOpp.StageName != 'Closed Won') {
                closedWonIds.add(opp.Id);
            }
        }

        if (!closedWonIds.isEmpty()) {
              OpportunityTriggerHandler.createReservationRequest(
            Trigger.new,
            Trigger.oldMap
        );
            
        }
    }
}