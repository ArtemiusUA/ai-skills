## Read cache

Place caching inside selectors.

```
Selector
    ↓
Cache
    ↓
Database
```

## Cache invalidation

Services invalidate cache after modifying data.

```
Service
    ↓
Save
    ↓
Invalidate cache
```

## External API cache

Cache inside API clients or repositories that communicate with external services.

## Optional cache module

Each app may contain:

```text
cache.py
```

to centralize:

* cache keys
* invalidation helpers
* reusable cache utilities
