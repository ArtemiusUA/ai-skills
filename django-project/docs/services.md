## Use Cases

Services implement business use cases:

* Checkout
* Refund
* Cancel order
* Register user
* Renew subscription

## Responsibilities

Services:

* Coordinate models
* Handle transactions (`transaction.atomic`)
* Call external APIs
* Trigger background jobs
* Invalidate caches
* Enforce business permissions

Business workflows belong here.

Prefer explicit services over implicit signals.
