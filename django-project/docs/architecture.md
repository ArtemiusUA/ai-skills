## Dependency Direction

```
View
   ↓
Serializer/Form
   ↓
Service
   ↓
Model
   ↓
Database
```

For reads:

```
View
   ↓
Selector
   ↓
Database
```

## Transactions

Transactions belong in services.

Views should rarely use `transaction.atomic`.

## General Principles

* Keep Django's ORM as the primary persistence layer.
* Prefer explicit services over implicit signals.
* Keep models focused on domain behavior, not orchestration.
* Centralize complex queries in selectors.
* Cache reads in selectors and invalidate caches in services.
* Keep views thin and focused on HTTP concerns.
* Use repositories only when abstracting external systems or complex persistence, not for simple ORM access.
* Favor clarity over strict adherence to architectural patterns.

## Summary

| Layer             | Responsibility                                               |
| ----------------- | ------------------------------------------------------------ |
| Models            | Data, relationships, invariants, small domain logic          |
| Services          | Business workflows, transactions, permissions, orchestration |
| Selectors         | Read queries, query optimization, read caching               |
| Views             | HTTP handling and delegation                                 |
| Serializers/Forms | Validation and serialization                                 |
| Tasks             | Background work                                              |
| Signals           | Small side effects only                                      |
| Cache             | Reads in selectors, invalidation in services                 |

## Guiding Philosophy

> **Use Django where it excels, introduce structure only where it improves maintainability, and keep every piece of business logic in a predictable location.**

This approach aims to maximize readability, testability, and long-term maintainability while preserving Django's productivity and conventions.
