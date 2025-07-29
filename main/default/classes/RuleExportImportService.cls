/**
 * Rule Export Import Service,
 * used to export and import rules
 * How to use:
 * 
 * 1. Export rules to a content document on source org
 * Use this method by Developer Console:
 *      Id contentDocumentId = RuleExportImportService.exportRulesToContentDocument();
 *      System.debug('### EXPORT - Content document ID: ' + contentDocumentId);
 * 
 * 2. Create a new content document on target org
 * Manually create a new content document on target org and copy the ID
 * 
 * 3. Delete all rules and actions on target org (optional, only if you want to clean up before importing new rules)
 *      Use this method by Developer Console:
 *      RuleExportImportService.deleteAllRules();
 * 
 * 4. Import rules from a content document on target org
 * Use this method by Developer Console:
 *      Id contentDocumentId = '069000000000000AAA'; // A syntactically valid but non-existent ID
 *      RuleExportImportService.importRulesFromContentDocument(contentDocumentId);
 */
public class RuleExportImportService {
    
    // system fields to exclude from export
    public static final Set<String> SYSTEM_FIELDS = new Set<String>{
        'id', 'isdeleted', 'createddate', 'createdbyid', 'lastmodifieddate', 
        'lastmodifiedbyid', 'systemmodstamp', 'lastactivitydate', 'lastvieweddate', 
        'lastreferenceddate', 'ownerid', 'currencyisocode'
    };

    /**
     * Delete all rules and actions,
     * used to clean up before importing new rules or for testing
     */
    public static void deleteAllRules() {
        List<pharos__Rule__c> rules = [SELECT Id FROM pharos__Rule__c];
        List<pharos__Action__c> actions = [SELECT Id FROM pharos__Action__c];
        delete rules;
        delete actions;
    }

    /**
     * Import rules from a content document,
     * used to import rules from a content document
     */
    public static void importRulesFromContentDocument(Id contentDocumentId) {
        String jsonStr = null;
        List<ContentVersion> cv = [
            SELECT VersionData 
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId 
            LIMIT 1
        ];
        if (cv != null && !cv.isEmpty()) {
            jsonStr = cv[0].VersionData.toString();

            List<RuleWrapper> wrappers = deserializeFromJson(jsonStr);
            importRules(wrappers);
        }
        else {
            System.debug('### IMPORT - No content version found for content document ID: ' + contentDocumentId);
        }
    }

    /**
     * Export rules to a content document,
     * used to export rules to a content document
     */
    public static Id exportRulesToContentDocument() {
        
        // get all rules
        List<pharos__Rule__c> rules = [SELECT Id FROM pharos__Rule__c];
        List<Id> ruleIds = new List<Id>();
        for(pharos__Rule__c rule : rules) {
            ruleIds.add(rule.Id);
        }
        List<RuleWrapper> wrappers = exportRules(ruleIds);

        // create content document with rules
        return createContentDocumentWithRules(wrappers);
    }

    public class ActionInfo {
        public pharos__Action__c action;
        public Id originalId;

        public ActionInfo(pharos__Action__c action, Id originalId) {
            this.action = action;
            this.originalId = originalId;
        }
    }

    public class RuleWrapper {
        public pharos__Rule__c rule;
        public List<pharos__RuleAction__c> ruleActions;
        public Map<Id, pharos__Action__c> actions;
        public List<pharos__RuleFilter__c> ruleFilters;

        public RuleWrapper() {
            this.rule = new pharos__Rule__c();
            this.ruleActions = new List<pharos__RuleAction__c>();
            this.actions = new Map<Id, pharos__Action__c>();
            this.ruleFilters = new List<pharos__RuleFilter__c>();
        }

        public RuleWrapper(pharos__Rule__c sourceRule) {
            this();
            if(sourceRule != null) {
                this.rule = sourceRule.clone(false, true);
            }
        }
    }

    public static String buildSelectClause(Schema.SObjectType sObjectType) {
        List<String> fields = new List<String>();
        Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();

        for(String fieldName : fieldMap.keySet()) {
            Schema.SObjectField soField = fieldMap.get(fieldName);
            Schema.DescribeFieldResult fieldDescribe = soField.getDescribe();

            // Skip system fields and non-createable fields
            if(!SYSTEM_FIELDS.contains(fieldName.toLowerCase()) && fieldDescribe.isCreateable()) {
                fields.add(fieldName);
            }
        }

        return String.join(fields, ',');
    }

    /**
     * Create a content document with rules,
     * used to create a content document with rules
     */
    public static Id createContentDocumentWithRules(List<RuleWrapper> wrappers) {
        String jsonStr = serializeToJson(wrappers);

        // create content version
        ContentVersion cv = new ContentVersion();
        cv.ContentLocation = 'S';
        cv.PathOnClient = 'Pharos_Rule_Export_' + Datetime.now().format('yyyy-MM-dd') + '.json';
        cv.Title = 'Pharos Rule Export ' + Datetime.now().format('yyyy-MM-dd');
        cv.VersionData = Blob.valueOf(jsonStr);
        insert cv;

        // get content document id
        // The owner of this ContentVersion (the running user) will automatically
        // be linked to the ContentDocument with ShareType 'O'.
        ContentVersion cdData = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        return cdData.ContentDocumentId;
    }

    /**
     * Export rules,
     * used to export rules
     */
    public static List<RuleWrapper> exportRules(List<Id> ruleIds) {
        System.debug('### EXPORT - Starting export for rule IDs: ' + ruleIds);
        if(ruleIds == null || ruleIds.isEmpty()) {
            System.debug('### EXPORT - No rule IDs provided, returning empty list');
            return new List<RuleWrapper>();
        }

        List<RuleWrapper> exportData = new List<RuleWrapper>();

        // Build dynamic queries
        String ruleFields = buildSelectClause(pharos__Rule__c.SObjectType);
        String actionFields = buildSelectClause(pharos__Action__c.SObjectType);
        String ruleActionFields = buildSelectClause(pharos__RuleAction__c.SObjectType);
        String ruleFilterFields = buildSelectClause(pharos__RuleFilter__c.SObjectType);

        // Query Rules and related records
        String ruleQuery = 'SELECT ' + ruleFields + 
                         ', (SELECT ' + ruleActionFields + ' FROM pharos__RuleActions__r)' +
                         ', (SELECT ' + ruleFilterFields + ' FROM pharos__RuleFilters__r)' +
                         ' FROM pharos__Rule__c WHERE Id IN :ruleIds';
        System.debug('### EXPORT - Rule query: ' + ruleQuery);

        List<pharos__Rule__c> rules = Database.query(ruleQuery);
        System.debug('### EXPORT - Found ' + rules.size() + ' rules');

        // Get all Action IDs from RuleActions
        Set<Id> actionIds = new Set<Id>();
        for(pharos__Rule__c rule : rules) {
            System.debug('### EXPORT - Processing rule: ' + rule.pharos__Name__c + ' with ' + 
                (rule.pharos__RuleActions__r != null ? rule.pharos__RuleActions__r.size() : 0) + ' actions');
            if(rule.pharos__RuleActions__r != null) {
                for(pharos__RuleAction__c ra : rule.pharos__RuleActions__r) {
                    if(ra.pharos__Action__c != null) {
                        actionIds.add(ra.pharos__Action__c);
                    }
                }
            }
        }
        System.debug('### EXPORT - Found ' + actionIds.size() + ' unique action IDs');

        // Query Actions
        Map<Id, pharos__Action__c> actionsMap = new Map<Id, pharos__Action__c>();
        if(!actionIds.isEmpty()) {
            String actionQuery = 'SELECT ' + actionFields + ' FROM pharos__Action__c WHERE Id IN :actionIds';
            System.debug('### EXPORT - Action query: ' + actionQuery);
            actionsMap = new Map<Id, pharos__Action__c>((List<pharos__Action__c>)Database.query(actionQuery));
            System.debug('### EXPORT - Retrieved ' + actionsMap.size() + ' actions');
        }

        // Build export wrappers
        for(pharos__Rule__c rule : rules) {
            RuleWrapper wrapper = new RuleWrapper(rule);
            System.debug('### EXPORT - Creating wrapper for rule: ' + rule.pharos__Name__c);

            // Clone RuleActions
            if(rule.pharos__RuleActions__r != null) {
                for(pharos__RuleAction__c ra : rule.pharos__RuleActions__r) {
                    if(ra != null) {
                        pharos__RuleAction__c clonedRa = ra.clone(false, true);
                        wrapper.ruleActions.add(clonedRa);

                        // Store associated Action
                        if(ra.pharos__Action__c != null && actionsMap.containsKey(ra.pharos__Action__c)) {
                            pharos__Action__c clonedAction = actionsMap.get(ra.pharos__Action__c).clone(false, true);
                            wrapper.actions.put(ra.pharos__Action__c, clonedAction);
                        }
                    }
                }
                System.debug('### EXPORT - Added ' + wrapper.ruleActions.size() + ' rule actions and ' + 
                    wrapper.actions.size() + ' actions to wrapper');
            }

            // Clone RuleFilters
            if(rule.pharos__RuleFilters__r != null) {
                for(pharos__RuleFilter__c rf : rule.pharos__RuleFilters__r) {
                    if(rf != null) {
                        wrapper.ruleFilters.add(rf.clone(false, true));
                    }
                }
                System.debug('### EXPORT - Added ' + wrapper.ruleFilters.size() + ' rule filters to wrapper');
            }

            exportData.add(wrapper);
        }

        System.debug('### EXPORT - Completed export with ' + exportData.size() + ' rule wrappers');
        return exportData;
    }

    /**
     * Import rules,
     * used to import rules
     */
    public static List<pharos__Rule__c> importRules(List<RuleWrapper> wrappers) {
        System.debug('### IMPORT - Starting import with ' + (wrappers != null ? wrappers.size() : 0) + ' wrappers');
        if(wrappers == null || wrappers.isEmpty()) {
            System.debug('### IMPORT - No wrappers provided, returning empty list');
            return new List<pharos__Rule__c>();
        }

        // Maps to store relationships and prevent duplicates
        Map<String, Id> oldToNewActionIds = new Map<String, Id>();
        Map<String, RuleWrapper> ruleNameToWrapper = new Map<String, RuleWrapper>();
        Map<String, pharos__Action__c> newActionsByKey = new Map<String, pharos__Action__c>();
        //Map<Id, String> actionIdToKey = new Map<Id, String>();

        // Build maps and collect action criteria
        for(RuleWrapper wrapper : wrappers) {
            if(wrapper.rule != null) {
                ruleNameToWrapper.put(wrapper.rule.pharos__Name__c, wrapper);
            }
            if(wrapper.actions != null) {
                for(Id originalActionId : wrapper.actions.keySet()) {
                    pharos__Action__c action = wrapper.actions.get(originalActionId);
                    newActionsByKey.put(originalActionId, action);
                    System.debug('### IMPORT - Added action to process: ' + ' (Original ID: ' + originalActionId + ')');
                }
            }
        }

        // Process actions - only insert if no matching action exists
        List<pharos__Action__c> actionsToInsert = new List<pharos__Action__c>();
        Id recordtypeId = Schema.SObjectType.pharos__Action__c.getRecordTypeInfosByName().get('Monitoring').getRecordtypeId();

        for(String key : newActionsByKey.keySet()) {
            pharos__Action__c actionToProcess = newActionsByKey.get(key).clone(false, true);
            // update RT to local monitoring RT
            actionToProcess.RecordTypeId = recordtypeId;
            // update map with new values 
            newActionsByKey.put(key, actionToProcess);

            System.debug('### IMPORT - Will insert new action: ' + key);
        }

        // Insert new actions
        if(!newActionsByKey.isEmpty()) {
            System.debug('### IMPORT - Inserting ' + newActionsByKey?.values()?.size() + ' new actions');
            insert newActionsByKey.values();

            // Map new action IDs
            for(String key : newActionsByKey.keySet()) {
                oldToNewActionIds.put(key, newActionsByKey.get(key).id);
                System.debug('### IMPORT - Mapped new action: ' + key + ' -> ' + newActionsByKey.get(key).id);
            }
        }

        // Insert Rules
        List<pharos__Rule__c> rulesToInsert = new List<pharos__Rule__c>();

        for(RuleWrapper wrapper : wrappers) {
            if(wrapper.rule != null) {
                pharos__Rule__c newRule = wrapper.rule.clone(false, true);
                rulesToInsert.add(newRule);
            }
        }

        if(!rulesToInsert.isEmpty()) {
            System.debug('### IMPORT - Inserting ' + rulesToInsert.size() + ' rules');
            insert rulesToInsert;

            // Insert RuleFilters and RuleActions
            List<pharos__RuleFilter__c> filtersToInsert = new List<pharos__RuleFilter__c>();
            List<pharos__RuleAction__c> ruleActionsToInsert = new List<pharos__RuleAction__c>();

            // Process rule actions and filters for each inserted rule
            for(pharos__Rule__c rule : rulesToInsert) {
                RuleWrapper wrapper = ruleNameToWrapper.get(rule.pharos__Name__c);
                System.debug('### IMPORT - Processing rule: ' + rule.pharos__Name__c);

                if(wrapper != null) {
                    // Process rule filters
                    if(wrapper.ruleFilters != null) {
                        for(pharos__RuleFilter__c filter : wrapper.ruleFilters) {
                            pharos__RuleFilter__c newFilter = filter.clone(false, true);
                            newFilter.pharos__Rule__c = rule.Id;
                            filtersToInsert.add(newFilter);
                        }
                    }

                    // Process rule actions
                    if(wrapper.ruleActions != null) {
                        for(pharos__RuleAction__c ra : wrapper.ruleActions) {
                            if(ra.pharos__Action__c != null && newActionsByKey.containsKey(ra.pharos__Action__c)) {
                                String oldActionId = ra.pharos__Action__c;
                                Id newActionId = oldToNewActionIds.get(oldActionId);

                                if(newActionId != null && oldActionId != null) {
                                    pharos__RuleAction__c newRa = ra.clone(false, true);
                                    newRa.pharos__Rule__c = rule.Id;
                                    newRa.pharos__Action__c = newActionId;
                                    ruleActionsToInsert.add(newRa);
                                    System.debug('### IMPORT - Created rule action: Rule=' + rule.pharos__Name__c + ', Action=' + oldActionId + ' -> ' + newActionId);
                                }
                            }
                        }
                    }
                }
            }

            // Insert rule filters
            if(!filtersToInsert.isEmpty()) {
                System.debug('### IMPORT - Inserting ' + filtersToInsert.size() + ' rule filters');
                insert filtersToInsert;
            }

            // Insert rule actions
            if(!ruleActionsToInsert.isEmpty()) {
                System.debug('### IMPORT - Inserting ' + ruleActionsToInsert.size() + ' rule actions');
                insert ruleActionsToInsert;
            }
        }

        System.debug('### IMPORT - Import completed successfully');
        return rulesToInsert;
    }

    public static String serializeToJson(List<RuleWrapper> wrappers) {
        return JSON.serialize(wrappers);
    }

    public static List<RuleWrapper> deserializeFromJson(String jsonStr) {
        return (List<RuleWrapper>)JSON.deserialize(jsonStr, List<RuleWrapper>.class);
    }
}