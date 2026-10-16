/** Map authorized BCeID person details without executing DML. */
public with sharing class BceidContactMapper {
    /** Return true only if one or more supplied fields differ. */
    public static Boolean apply(Contact record, BceidPersonData data) {
        if (record == null || data == null) return false;
        Boolean changed = false;
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Contact.fields.getMap();
        changed = setDifferent(record, fields, 'FirstName', data.firstName) || changed;
        changed = setDifferent(record, fields, 'LastName', data.lastName) || changed;
        changed = setDifferent(record, fields, 'Email', data.email) || changed;
        changed = setDifferent(record, fields, 'MobilePhone',
            BceidPersonData.normalizedMobile(data.mobile)) || changed;
        return changed;
    }

    // Blank/unavailable values never overwrite target fields.
    private static Boolean setDifferent(SObject record,
            Map<String, Schema.SObjectField> fields, String apiName, String incoming) {
        if (String.isBlank(incoming) || !fields.containsKey(apiName)) return false;
        String cleaned = incoming.trim();
        Object existing = record.get(apiName);
        if (existing != null && String.valueOf(existing) == cleaned) return false;
        record.put(apiName, cleaned);
        return true;
    }
}
