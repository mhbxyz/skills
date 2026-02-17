# Detailed Guidelines

Extended conventions, patterns, and anti-patterns for elite code.

## Design Principles

### KISS — Keep It Simple

Choose the straightforward solution. Clever code is a liability.

```python
# Bad: clever one-liner
result = {k: v for d in [a, b] for k, v in d.items()}

# Good: obvious
result = {**defaults, **overrides}
```

### YAGNI — You Aren't Gonna Need It

Do not build for hypothetical futures. Solve today's problem.

- No feature flags for features that do not exist
- No abstract base classes with a single implementation
- No configuration for values that never change

### DRY — Don't Repeat Yourself (with nuance)

Duplication is cheaper than the wrong abstraction. Extract only
when you see the **same logic** repeated three or more times with
the **same reason to change**.

```python
# Bad DRY: forced abstraction over superficially similar code
def process_thing(thing, mode):
    if mode == "user":
        # 20 lines of user logic
    elif mode == "admin":
        # 20 lines of admin logic

# Good: two focused functions
def process_user(user): ...
def process_admin(admin): ...
```

## Refactoring Patterns

### Extract Method

When a block of code has a comment explaining what it does,
extract it into a function named after the comment.

```python
# Before
def process_order(order):
    # validate inventory
    for item in order.items:
        stock = get_stock(item.sku)
        if stock < item.quantity:
            raise OutOfStockError(item.sku)
    # calculate totals
    subtotal = sum(i.price * i.quantity for i in order.items)
    tax = subtotal * TAX_RATE
    return subtotal + tax

# After
def process_order(order):
    validate_inventory(order.items)
    return calculate_total(order.items)
```

### Guard Clauses

Replace nested conditionals with early returns.

```python
# Before
def get_pay(employee):
    if employee.is_active:
        if employee.hours > 0:
            if employee.rate > 0:
                return employee.hours * employee.rate
    return 0

# After
def get_pay(employee):
    if not employee.is_active:
        return 0
    if employee.hours <= 0:
        return 0
    if employee.rate <= 0:
        return 0
    return employee.hours * employee.rate
```

### Replace Conditional with Polymorphism

When a function switches on a type to determine behavior,
use polymorphism instead.

```python
# Before
def calculate_area(shape):
    if shape.type == "circle":
        return math.pi * shape.radius ** 2
    elif shape.type == "rectangle":
        return shape.width * shape.height

# After
class Circle:
    def area(self) -> float:
        return math.pi * self.radius ** 2

class Rectangle:
    def area(self) -> float:
        return self.width * self.height
```

## API Design

### REST Conventions

- Use nouns for resources: `/users`, `/orders`
- Use HTTP methods for actions: GET, POST, PUT, DELETE
- Return appropriate status codes:
  - `200` success, `201` created, `204` no content
  - `400` bad request, `401` unauthorized, `404` not found
  - `409` conflict, `422` unprocessable entity
  - `500` internal server error

### Pagination

Always paginate list endpoints. Never return unbounded results.

```python
@app.get("/users")
def list_users(page: int = 1, per_page: int = 20):
    if per_page > 100:
        per_page = 100
    offset = (page - 1) * per_page
    return db.query(User).offset(offset).limit(per_page)
```

### Idempotency

PUT and DELETE must be idempotent. POST should use idempotency
keys for operations that create resources.

## Dependency Management

- **Pin versions**: `requests==2.31.0`, not `requests>=2.0`
- **Audit regularly**: `pip audit` or `safety check`
- **Prefer stdlib**: use `pathlib` over `os.path`, `dataclasses`
  over third-party alternatives when sufficient
- **Minimize dependencies**: every dependency is a liability

## Logging

### Levels

- `DEBUG`: detailed diagnostic info (dev only)
- `INFO`: normal operation milestones
- `WARNING`: unexpected but recoverable situations
- `ERROR`: failures that need attention
- `CRITICAL`: system-level failures

### Best Practices

- Use structured logging (`structlog` or `logging` with JSON)
- Include context: request ID, user ID, operation name
- **Never log sensitive data**: passwords, tokens, PII
- Use lazy formatting: `logger.info("User %s", user_id)`

## Async and Concurrency

- Use `async/await` for I/O-bound work, not CPU-bound
- Always set timeouts on network calls:

```python
async with httpx.AsyncClient(timeout=10.0) as client:
    response = await client.get(url)
```

- Use `asyncio.gather` for concurrent independent calls
- Protect shared state with locks or use immutable data
- Prefer `asyncio.TaskGroup` over bare `create_task`

## Database Patterns

- **Migrations**: use Alembic or equivalent, never raw DDL
- **Indexes**: add indexes for columns used in WHERE/JOIN
- **Transactions**: wrap related writes in a single transaction
- **Connection pooling**: never open a connection per request

```python
# Good: explicit transaction
async with db.begin() as tx:
    await tx.execute(insert_order)
    await tx.execute(update_inventory)
```

## Configuration

### Hierarchy (lowest to highest priority)

1. Hardcoded defaults in code
2. Configuration file (`config.toml`, `settings.yaml`)
3. Environment variables
4. Command-line arguments

### Validation

Validate all configuration at startup. Fail fast with clear
error messages if required values are missing.

```python
@dataclass
class Config:
    db_url: str
    redis_url: str
    debug: bool = False

    def __post_init__(self):
        if not self.db_url:
            raise ValueError("DB_URL is required")
```

## Code Smells

Watch for these and refactor when found:

- **Long parameter list** (more than 3) — use a dataclass
- **God class** — a class that does everything, split it
- **Primitive obsession** — use domain types instead of raw
  strings and ints (`Email` not `str`, `Money` not `float`)
- **Boolean parameters** — split into two functions

```python
# Bad: boolean param
def get_users(include_inactive=False): ...

# Good: explicit functions
def get_active_users(): ...
def get_all_users(): ...
```

- **Feature envy** — a function that uses another object's
  data more than its own, move it to that object
- **Shotgun surgery** — one change requires editing many files,
  consolidate related logic

## Type Safety

- Use type hints for all public function signatures
- Use `Enum` for fixed sets of values, not string constants
- Make illegal states unrepresentable:

```python
# Bad: status can be any string
order.status = "shiped"  # typo, no error

# Good: enum restricts values
class Status(Enum):
    PENDING = "pending"
    SHIPPED = "shipped"
    DELIVERED = "delivered"

order.status = Status.SHIPPED
```

- Use `Optional[X]` explicitly — never let `None` sneak in
- Prefer `dataclass` or `NamedTuple` over raw dicts for
  structured data

## When to Break the Rules

Rules exist to serve the code, not the other way around.
Break a rule when:

1. **Language convention conflicts** — if the ecosystem uses a
   different style (e.g., Go's short variable names), follow
   the ecosystem
2. **The rule increases complexity** — if extracting a function
   makes the code harder to follow, keep it inline
3. **Proven performance need** — if a profiler shows a hotspot,
   optimize there (and comment why)

When breaking a rule, always leave a comment explaining the
reason. Undocumented exceptions become tech debt.
