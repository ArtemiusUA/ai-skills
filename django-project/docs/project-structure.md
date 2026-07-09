## Top-Level Layout

```text
project/
├── config/
├── apps/
│   ├── users/
│   ├── orders/
│   ├── inventory/
│   ├── billing/
│   └── ...
├── common/
└── tests/
```

Each business domain is its own Django app.

## App Structure

```text
orders/
├── models/
├── services/
├── selectors.py
├── cache.py          # optional
├── api/
│   ├── serializers.py
│   ├── views.py
│   └── urls.py
├── admin.py
├── tasks.py
├── permissions.py
├── exceptions.py
└── tests/
```

## App Organization

Group code by business domain.

Good:

```
users/
orders/
billing/
inventory/
notifications/
```

Avoid grouping by technical layers:

```
models/
views/
serializers/
```
