## Purpose

Selectors are responsible for read operations.

They:

* Encapsulate ORM queries
* Optimize with `select_related()` and `prefetch_related()`
* Return querysets or DTOs
* Are the preferred location for query caching

Views should never duplicate complex queries.

Centralize complex queries in selectors.
