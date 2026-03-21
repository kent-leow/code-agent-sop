# Jira REST API Reference

Base URL pattern: `https://<your-org>.atlassian.net/rest/api/3`

Authentication: HTTP Basic Auth — `Authorization: Basic <base64(email:token)>`

---

## Create Issue

**POST** `/rest/api/3/issue`

### Headers
```
Content-Type: application/json
Authorization: Basic <base64(JIRA_EMAIL:JIRA_TOKEN)>
```

### Minimal Payload (Story)
```json
{
  "fields": {
    "project": { "key": "PROJ" },
    "summary": "Ticket title here",
    "description": {
      "type": "doc",
      "version": 1,
      "content": [
        {
          "type": "paragraph",
          "content": [{ "type": "text", "text": "Description text here." }]
        }
      ]
    },
    "issuetype": { "name": "Story" },
    "customfield_10016": 3
  }
}
```

### Payload with Sub-task
```json
{
  "fields": {
    "project": { "key": "PROJ" },
    "summary": "Sub-task title",
    "issuetype": { "name": "Sub-task" },
    "parent": { "key": "PROJ-42" },
    "customfield_10016": 1
  }
}
```

### Response (201 Created)
```json
{
  "id": "10001",
  "key": "PROJ-123",
  "self": "https://your-org.atlassian.net/rest/api/3/issue/10001"
}
```

---

## Update Issue Fields (Story Points)

**PUT** `/rest/api/3/issue/{issueKey}`

### Payload
```json
{
  "fields": {
    "customfield_10016": 5
  }
}
```

### Response: `204 No Content` on success.

---

## Discover Custom Fields

**GET** `/rest/api/3/field`

Returns all fields. Filter for story points:
```bash
curl -s -u "$JIRA_EMAIL:$JIRA_TOKEN" \
  "$JIRA_BASE_URL/rest/api/3/field" | \
  python3 -c "
import json, sys
fields = json.load(sys.stdin)
for f in fields:
    name = f.get('name','').lower()
    if 'story' in name or 'point' in name or 'sp' in name:
        print(f['id'], f['name'])
"
```

---

## Common Issue Types

| Type name | Notes |
|---|---|
| `Story` | User story (classic projects) |
| `Task` | Generic task |
| `Bug` | Defect |
| `Sub-task` | Child of another issue (classic) |
| `Child Issue` | Child in next-gen projects |
| `Epic` | Large body of work |

> Issue type names are **case-sensitive** and vary by project configuration.

---

## Notes

- `customfield_10016` is the most common story points field for classic Scrum boards.
- Next-gen (team-managed) projects use `story_points` as the field key.
- The Atlassian Document Format (ADF) is required for `description` in API v3. Use the structure shown above.
- To use plain text, use API v2 (`/rest/api/2/issue`) where `description` is a plain string.
