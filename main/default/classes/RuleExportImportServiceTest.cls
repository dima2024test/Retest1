@IsTest
private class RuleExportImportServiceTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test Actions
        List<pharos__Action__c> actions = new List<pharos__Action__c>{
            new pharos__Action__c(
                pharos__Name__c = 'Test Action 1',
                pharos__Action_Type__c = 'Email Notification',
                pharos__SobjectType__c = 'Monitoring',
                pharos__Description__c = 'Test Action 1 Description'
            ),
            new pharos__Action__c(
                pharos__Name__c = 'Test Action 2',
                pharos__Action_Type__c = 'Slack Notification',
                pharos__SobjectType__c = 'Monitoring',
                pharos__Description__c = 'Test Action 2 Description'
            ),
            new pharos__Action__c(
                pharos__Name__c = 'Test Action 3',
                pharos__Action_Type__c = 'Teams Notification',
                pharos__SobjectType__c = 'Monitoring',
                pharos__Description__c = 'Test Action 3 Description'
            )
        };
        insert actions;
        
        // Create test Rules
        List<pharos__Rule__c> rules = new List<pharos__Rule__c>{
            new pharos__Rule__c(
                pharos__Description__c = 'Test Description 1',
                pharos__Active__c = true,
                pharos__Name__c = 'TEST_RULE_1',
                pharos__Index__c = 1,
                pharos__Type__c = 'Monitoring',
                pharos__SobjectType__c = 'Monitoring'
            ),
            new pharos__Rule__c(
                pharos__Description__c = 'Test Description 2',
                pharos__Active__c = false,
                pharos__Name__c = 'TEST_RULE_2',
                pharos__Index__c = 2,
                pharos__Type__c = 'Monitoring',
                pharos__SobjectType__c = 'Monitoring'
            )
        };
        insert rules;
        
        // Create test RuleFilters
        List<pharos__RuleFilter__c> filters = new List<pharos__RuleFilter__c>{
            new pharos__RuleFilter__c(
                pharos__Rule__c = rules[0].Id,
                pharos__FieldName__c = 'Name',
                pharos__ComparisonOperator__c = 'equals',
                pharos__Value__c = 'Test'
            ),
            new pharos__RuleFilter__c(
                pharos__Rule__c = rules[1].Id,
                pharos__FieldName__c = 'Email',
                pharos__ComparisonOperator__c = 'contains',
                pharos__Value__c = '@test.com'
            )
        };
        insert filters;
        
        // Create test RuleActions
        List<pharos__RuleAction__c> ruleActions = new List<pharos__RuleAction__c>{
            new pharos__RuleAction__c(
                pharos__Rule__c = rules[0].Id,
                pharos__Action__c = actions[0].Id
            ),
            new pharos__RuleAction__c(
                pharos__Rule__c = rules[0].Id,
                pharos__Action__c = actions[1].Id
            ),
            new pharos__RuleAction__c(
                pharos__Rule__c = rules[1].Id,
                pharos__Action__c = actions[2].Id
            )
        };
        insert ruleActions;
    }
    
    @IsTest
    static void testExportRules() {
        Test.startTest();
        Id contentDocumentId = RuleExportImportService.exportRulesToContentDocument();
        Test.stopTest();

        System.assertNotEquals(null, contentDocumentId, 'ContentDocumentId should not be null');

        ContentVersion cv = [
            SELECT VersionData 
            FROM ContentVersion 
            WHERE ContentDocumentId = :contentDocumentId AND IsLatest = true
            LIMIT 1
        ];
        System.assertNotEquals(null, cv, 'ContentVersion record not found');
        System.assertNotEquals(null, cv.VersionData, 'ContentVersion VersionData is null');

        List<RuleExportImportService.RuleWrapper> deserializedWrappers = 
            RuleExportImportService.deserializeFromJson(cv.VersionData.toString());
        
        // Verify results
        System.assertEquals(2, deserializedWrappers.size(), 'Should export 2 rules from ContentVersion');
        
        // Get original data for comparison
        Map<Id, pharos__Action__c> originalActions = new Map<Id, pharos__Action__c>([
            SELECT Id, pharos__Name__c, pharos__Action_Type__c, pharos__SobjectType__c, pharos__Description__c
            FROM pharos__Action__c
        ]);
        
        // Find and Verify first rule (TEST_RULE_1)
        RuleExportImportService.RuleWrapper wrapperForRule1 = null;
        for(RuleExportImportService.RuleWrapper w : deserializedWrappers) {
            if (w.rule != null && 'TEST_RULE_1'.equals(w.rule.pharos__Name__c)) {
                wrapperForRule1 = w;
                break;
            }
        }
        System.assertNotEquals(null, wrapperForRule1, 'Wrapper for TEST_RULE_1 not found in deserialized data');
        
        pharos__Rule__c originalRule1 = [
            SELECT Id, pharos__Description__c, pharos__Active__c, pharos__Name__c, pharos__Index__c, pharos__Type__c, pharos__SobjectType__c,
                   (SELECT Id, pharos__Action__c FROM pharos__RuleActions__r ORDER BY pharos__Action__r.pharos__Name__c), // Order for consistency
                   (SELECT Id, pharos__FieldName__c, pharos__ComparisonOperator__c, pharos__Value__c FROM pharos__RuleFilters__r ORDER BY pharos__FieldName__c) // Order for consistency
            FROM pharos__Rule__c
            WHERE pharos__Name__c = 'TEST_RULE_1'
        ];
        
        // Verify Rule fields
        System.assertEquals(originalRule1.pharos__Description__c, wrapperForRule1.rule.pharos__Description__c, 'Rule description should match');
        System.assertEquals(originalRule1.pharos__Active__c, wrapperForRule1.rule.pharos__Active__c, 'Rule active status should match');
        System.assertEquals(originalRule1.pharos__Name__c, wrapperForRule1.rule.pharos__Name__c, 'Rule name should match');
        System.assertEquals(originalRule1.pharos__Index__c, wrapperForRule1.rule.pharos__Index__c, 'Rule index should match');
        System.assertEquals(originalRule1.pharos__Type__c, wrapperForRule1.rule.pharos__Type__c, 'Rule type should match');
        System.assertEquals(originalRule1.pharos__SobjectType__c, wrapperForRule1.rule.pharos__SobjectType__c, 'Rule sobject type should match');
        
        // Verify RuleActions
        System.assertEquals(originalRule1.pharos__RuleActions__r.size(), wrapperForRule1.ruleActions.size(), 'Rule TEST_RULE_1 should have correct number of rule actions');
        
        // Verify RuleFilters
        System.assertEquals(originalRule1.pharos__RuleFilters__r.size(), wrapperForRule1.ruleFilters.size(), 'Rule TEST_RULE_1 should have correct number of filters');
        if(!originalRule1.pharos__RuleFilters__r.isEmpty() && !wrapperForRule1.ruleFilters.isEmpty()){
            pharos__RuleFilter__c originalFilter1 = originalRule1.pharos__RuleFilters__r[0];
            pharos__RuleFilter__c exportedFilter1 = wrapperForRule1.ruleFilters[0]; // Assumes order is preserved by export/deserialize
            System.assertEquals(originalFilter1.pharos__FieldName__c, exportedFilter1.pharos__FieldName__c, 'Filter field should match');
            System.assertEquals(originalFilter1.pharos__ComparisonOperator__c, exportedFilter1.pharos__ComparisonOperator__c, 'Filter operator should match');
            System.assertEquals(originalFilter1.pharos__Value__c, exportedFilter1.pharos__Value__c, 'Filter value should match');
        }
        
        // Verify Actions in the map for wrapperForRule1
        System.assertEquals(originalRule1.pharos__RuleActions__r.size(), wrapperForRule1.actions.size(), 'Rule TEST_RULE_1 wrapper should have correct number of actions in map');
        Set<Id> originalRule1ActionIds = new Set<Id>();
        for(pharos__RuleAction__c ra : originalRule1.pharos__RuleActions__r) {
            originalRule1ActionIds.add(ra.pharos__Action__c);
        }

        for(Id actionIdInWrapper : wrapperForRule1.actions.keySet()) {
            System.assert(originalRule1ActionIds.contains(actionIdInWrapper), 'Action ID from wrapper map (' + actionIdInWrapper + ') not found in original rule actions for TEST_RULE_1');
            pharos__Action__c originalAction = originalActions.get(actionIdInWrapper);
            pharos__Action__c exportedAction = wrapperForRule1.actions.get(actionIdInWrapper);
            System.assertNotEquals(null, originalAction, 'Original action for ID ' + actionIdInWrapper + ' not found in map');
            System.assertNotEquals(null, exportedAction, 'Exported action for ID ' + actionIdInWrapper + ' not found in wrapper');
            System.assertEquals(originalAction.pharos__Name__c, exportedAction.pharos__Name__c, 'Action name should match');
            System.assertEquals(originalAction.pharos__Action_Type__c, exportedAction.pharos__Action_Type__c, 'Action type should match');
            System.assertEquals(originalAction.pharos__SobjectType__c, exportedAction.pharos__SobjectType__c, 'Action sobject type should match');
            System.assertEquals(originalAction.pharos__Description__c, exportedAction.pharos__Description__c, 'Action description should match');
        }
    }
    
    @IsTest
    static void testImportRules() {
        // Store original data for comparison before any export or deletion
        Map<String, pharos__Rule__c> originalRulesByName = new Map<String, pharos__Rule__c>();
        for(pharos__Rule__c rule : [
            SELECT Id, pharos__Description__c, pharos__Active__c, pharos__Name__c, pharos__Index__c, pharos__Type__c, pharos__SobjectType__c,
                   (SELECT Id, pharos__Action__c, pharos__Action__r.pharos__Name__c, pharos__Action__r.pharos__Action_Type__c, pharos__Action__r.pharos__SobjectType__c, pharos__Action__r.pharos__Description__c FROM pharos__RuleActions__r ORDER BY pharos__Action__r.pharos__Name__c), 
                   (SELECT Id, pharos__FieldName__c, pharos__ComparisonOperator__c, pharos__Value__c FROM pharos__RuleFilters__r ORDER BY pharos__FieldName__c) 
            FROM pharos__Rule__c
            ORDER BY pharos__Name__c // Order rules themselves for predictable originalRulesByName keyset iteration if needed
        ]) {
            originalRulesByName.put(rule.pharos__Name__c, rule);
        }

        Test.startTest();

        // Step 1: Export to Content Document to get an ID for import
        // This uses all rules currently in the org from setupTestData
        Id contentDocumentId = RuleExportImportService.exportRulesToContentDocument();
        System.assertNotEquals(null, contentDocumentId, 'ContentDocumentId for import source should not be null');

        // Step 2: Delete existing data using the service method
        RuleExportImportService.deleteAllRules();

        // Verify deletion before import
        System.assertEquals(0, [SELECT COUNT() FROM pharos__Rule__c], 'All rules should be deleted before import');
        System.assertEquals(0, [SELECT COUNT() FROM pharos__Action__c], 'All actions should be deleted before import');
        System.assertEquals(0, [SELECT COUNT() FROM pharos__RuleAction__c], 'All rule actions should be deleted before import');
        System.assertEquals(0, [SELECT COUNT() FROM pharos__RuleFilter__c], 'All rule filters should be deleted before import');

        // Step 3: Import from Content Document
        RuleExportImportService.importRulesFromContentDocument(contentDocumentId);
        
        Test.stopTest(); 
        
        // Verify imported rules by querying them back from the DB
        List<pharos__Rule__c> importedDbRules = [
            SELECT Id, pharos__Description__c, pharos__Active__c, pharos__Name__c, pharos__Index__c, pharos__Type__c, pharos__SobjectType__c,
                   (SELECT Id, pharos__Action__c, pharos__Action__r.pharos__Name__c, pharos__Action__r.pharos__Action_Type__c, pharos__Action__r.pharos__SobjectType__c, pharos__Action__r.pharos__Description__c FROM pharos__RuleActions__r ORDER BY pharos__Action__r.pharos__Name__c),
                   (SELECT Id, pharos__FieldName__c, pharos__ComparisonOperator__c, pharos__Value__c FROM pharos__RuleFilters__r ORDER BY pharos__FieldName__c)
            FROM pharos__Rule__c
            ORDER BY pharos__Name__c // Order main rules for consistent iteration and comparison
        ];
        
        System.assertEquals(originalRulesByName.size(), importedDbRules.size(), 
            'Should import same number of rules as originally existed. Expected: ' + originalRulesByName.size() + ', Actual: ' + importedDbRules.size());
        
        // Verify each imported rule and its related records
        for(pharos__Rule__c importedRule : importedDbRules) {
            pharos__Rule__c originalRule = originalRulesByName.get(importedRule.pharos__Name__c);
            System.assertNotEquals(null, originalRule, 'Should find original rule for name: ' + importedRule.pharos__Name__c);
            
            // Verify Rule fields
            System.assertEquals(originalRule.pharos__Description__c, importedRule.pharos__Description__c, 'Rule description should match for ' + importedRule.pharos__Name__c);
            System.assertEquals(originalRule.pharos__Active__c, importedRule.pharos__Active__c, 'Rule active status should match for ' + importedRule.pharos__Name__c);
            System.assertEquals(originalRule.pharos__Index__c, importedRule.pharos__Index__c, 'Rule index should match for ' + importedRule.pharos__Name__c);
            System.assertEquals(originalRule.pharos__Type__c, importedRule.pharos__Type__c, 'Rule type should match for ' + importedRule.pharos__Name__c);
            System.assertEquals(originalRule.pharos__SobjectType__c, importedRule.pharos__SobjectType__c, 'Rule sobject type should match for ' + importedRule.pharos__Name__c);
            
            // Verify RuleActions (count and content via Action Name)
            System.assertEquals(originalRule.pharos__RuleActions__r.size(), importedRule.pharos__RuleActions__r.size(), 
                'Rule ' + importedRule.pharos__Name__c + ' should have ' + originalRule.pharos__RuleActions__r.size() + ' actions');
            
            for(Integer i = 0; i < originalRule.pharos__RuleActions__r.size(); i++) {
                pharos__RuleAction__c originalRA = originalRule.pharos__RuleActions__r[i];
                pharos__RuleAction__c importedRA = importedRule.pharos__RuleActions__r[i]; // Relies on ORDER BY Action__r.Name__c
                
                System.assertEquals(originalRA.pharos__Action__r.pharos__Name__c, importedRA.pharos__Action__r.pharos__Name__c, 'Action name for RuleAction should match for rule ' + importedRule.pharos__Name__c);
                // Since actions are recreated by import, compare their details
                System.assertEquals(originalRA.pharos__Action__r.pharos__Action_Type__c, importedRA.pharos__Action__r.pharos__Action_Type__c, 'Action Type should match for action ' + importedRA.pharos__Action__r.pharos__Name__c);
                System.assertEquals(originalRA.pharos__Action__r.pharos__SobjectType__c, importedRA.pharos__Action__r.pharos__SobjectType__c, 'SobjectType should match for action ' + importedRA.pharos__Action__r.pharos__Name__c);
                System.assertEquals(originalRA.pharos__Action__r.pharos__Description__c, importedRA.pharos__Action__r.pharos__Description__c, 'Description should match for action ' + importedRA.pharos__Action__r.pharos__Name__c);
            }
            
            // Verify RuleFilters (count and content)
            System.assertEquals(originalRule.pharos__RuleFilters__r.size(), importedRule.pharos__RuleFilters__r.size(), 
                'Rule ' + importedRule.pharos__Name__c + ' should have same number of filters');
            for(Integer i = 0; i < importedRule.pharos__RuleFilters__r.size(); i++) {
                pharos__RuleFilter__c originalRF = originalRule.pharos__RuleFilters__r[i];
                pharos__RuleFilter__c importedRF = importedRule.pharos__RuleFilters__r[i]; // Relies on ORDER BY FieldName__c

                System.assertEquals(originalRF.pharos__FieldName__c, importedRF.pharos__FieldName__c, 'Filter field should match for ' + importedRule.pharos__Name__c);
                System.assertEquals(originalRF.pharos__ComparisonOperator__c, importedRF.pharos__ComparisonOperator__c, 'Filter operator should match for ' + importedRule.pharos__Name__c);
                System.assertEquals(originalRF.pharos__Value__c, importedRF.pharos__Value__c, 'Filter value should match for ' + importedRule.pharos__Name__c);
            }
        }
    }
    
    @IsTest
    static void testSerializationDeserialization() {
        // Get test Rules
        List<pharos__Rule__c> rules = [SELECT Id FROM pharos__Rule__c];
        List<Id> ruleIds = new List<Id>();
        for(pharos__Rule__c rule : rules) {
            ruleIds.add(rule.Id);
        }
        
        List<RuleExportImportService.RuleWrapper> exportedRules = RuleExportImportService.exportRules(ruleIds);
        
        Test.startTest();
        // Test serialization
        String jsonStr = RuleExportImportService.serializeToJson(exportedRules);
        System.assertNotEquals(null, jsonStr, 'JSON string should not be null');
        
        // Test deserialization
        List<RuleExportImportService.RuleWrapper> deserializedRules = RuleExportImportService.deserializeFromJson(jsonStr);
        Test.stopTest();
        
        // Verify deserialized data
        System.assertEquals(exportedRules.size(), deserializedRules.size(), 'Should have same number of rules after deserialization');
        System.assertEquals(exportedRules[0].rule.pharos__Name__c, deserializedRules[0].rule.pharos__Name__c, 'Rule name should match after deserialization');
    }

    @IsTest
    static void testDeleteAllRules_WithData() {
        // @TestSetup creates data. Verify it's there.
        System.assertNotEquals(0, [SELECT COUNT() FROM pharos__Rule__c], 'Prerequisite: Rules should exist from TestSetup.');
        System.assertNotEquals(0, [SELECT COUNT() FROM pharos__Action__c], 'Prerequisite: Actions should exist from TestSetup.');

        Test.startTest();
        RuleExportImportService.deleteAllRules();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM pharos__Rule__c], 'All rules should be deleted.');
        System.assertEquals(0, [SELECT COUNT() FROM pharos__Action__c], 'All actions should be deleted.');
        System.assertEquals(0, [SELECT COUNT() FROM pharos__RuleAction__c], 'All rule actions should be deleted.');
        System.assertEquals(0, [SELECT COUNT() FROM pharos__RuleFilter__c], 'All rule filters should be deleted.');
    }

    @IsTest
    static void testDeleteAllRules_NoData() {
        // Ensure no data exists before calling
        delete [SELECT Id FROM pharos__RuleAction__c];
        delete [SELECT Id FROM pharos__RuleFilter__c];
        delete [SELECT Id FROM pharos__Action__c];
        delete [SELECT Id FROM pharos__Rule__c];

        Test.startTest();
        RuleExportImportService.deleteAllRules(); // Should run without errors
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM pharos__Rule__c], 'Should remain 0 rules.');
        System.assertEquals(0, [SELECT COUNT() FROM pharos__Action__c], 'Should remain 0 actions.');
    }

    @IsTest
    static void testExportRules_EmptyRuleIds() {
        Test.startTest();
        List<RuleExportImportService.RuleWrapper> wrappers = RuleExportImportService.exportRules(new List<Id>());
        Test.stopTest();

        System.assertNotEquals(null, wrappers, 'Wrapper list should not be null.');
        System.assertEquals(0, wrappers.size(), 'Should return an empty list of wrappers for empty ID list.');
    }

    @IsTest
    static void testImportRules_EmptyWrappers() {
        Test.startTest();
        List<pharos__Rule__c> importedRules = RuleExportImportService.importRules(new List<RuleExportImportService.RuleWrapper>());
        Test.stopTest();

        System.assertNotEquals(null, importedRules, 'Imported rules list should not be null.');
        System.assertEquals(0, importedRules.size(), 'Should return an empty list of rules for empty wrapper list.');
    }

    @IsTest
    static void testImportRulesFromContentDocument_InvalidId() {
        Id nonExistentContentDocumentId = '069000000000000AAA'; // A syntactically valid but non-existent ID

        // Ensure no rules to start (beyond TestSetup, which this test doesn't use directly for its core logic)
        RuleExportImportService.deleteAllRules();
        Integer initialRuleCount = [SELECT COUNT() FROM pharos__Rule__c];


        Test.startTest();
        RuleExportImportService.importRulesFromContentDocument(nonExistentContentDocumentId);
        Test.stopTest();

        System.assertEquals(initialRuleCount, [SELECT COUNT() FROM pharos__Rule__c], 'No rules should be imported for an invalid ContentDocumentId.');
    }
}