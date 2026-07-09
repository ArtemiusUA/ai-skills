## Views / API

Views should be thin.

### Responsibilities

* Authentication
* Permissions
* Request parsing
* Serializer validation
* Call services/selectors
* Return responses

Views should contain almost no business logic.

## Serializers / Forms

Responsible only for:

* Validation
* Serialization
* Deserialization

Avoid business workflows inside serializers.
