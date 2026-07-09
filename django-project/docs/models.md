## Responsibilities

* Database schema
* Relationships
* Constraints
* Small domain behavior
* Business invariants

## Examples

* `Order.mark_paid()`
* `Invoice.total`
* `Cart.is_empty()`

## Boundaries

Models should **not** orchestrate workflows involving multiple systems. That belongs in services.

- Keep Django's ORM as the primary persistence layer.
- Keep models focused on domain behavior, not orchestration.
