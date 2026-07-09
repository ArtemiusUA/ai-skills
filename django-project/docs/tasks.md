## Purpose

Background execution only.
Prefer using Celery.

### Examples

* Send email
* Generate reports
* Resize images
* Sync external systems

Tasks should not own business logic/rules.
Treat tasks mostly as ssync shortcuts for business logic located in services.
