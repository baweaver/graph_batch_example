# README

This repository demonstrates advanced GraphQL patterns in a Ruby on Rails application, focusing on efficient data loading, lookahead optimization, and flexible field definitions.

## Overview

The application models a blogging platform with entities like `Author`, `Post`, `Comment`, `Profile`, and `Like`. It leverages GraphQL-Ruby's dataloader, lookahead features, and custom helpers to optimize query performance and maintain a clean schema design.

## Key GraphQL Patterns

### 1. Association Dataloader with Lookahead

The `AssociationDataloaderWithLookahead` class extends `GraphQL::Dataloader::Source` to batch-load ActiveRecord associations efficiently. It utilizes GraphQL's lookahead feature to determine which nested associations to preload, reducing N+1 query issues.

**Highlights:**

- **Lookahead Usage:** Captures the fields requested in a query to determine necessary preloads.
- **Batch Loading:** Groups records by class and deduplicates them by ID before preloading.
- **Deep Merge:** Combines multiple lookahead trees into a single preload specification.

### 2. Scoped Connection Loader

The `ScopedConnectionLoader` class also extends `GraphQL::Dataloader::Source` and is designed for loading associations with additional scoping, such as filtering or ordering.

**Highlights:**

- **Custom Scoping:** Accepts a `scope_proc` to apply custom scopes to the base ActiveRecord relation.
- **Connection Support:** Returns a `GraphQL::Pagination::Connections::BaseConnection` for pagination support.

### 3. Association Loader Helpers

The `Helpers::AssociationLoader` module provides methods to define GraphQL fields that utilize the custom dataloaders.

**Methods:**

- `association_field`: Defines a field that uses `AssociationDataloaderWithLookahead`.
- `flagged_association_field`: Conditionally uses the dataloader based on a feature flag.
- `association_connection`: Defines a connection field with optional scoping and pagination.

### 4. Feature Flags with StupidFlags

The `StupidFlags` module simulates feature flagging, allowing conditional logic in field definitions.

**Example:**

```ruby
module StupidFlags
  FLAG_STATES = {
    association_loader: true
  }

  def self.enabled?(flag_name)
    FLAG_STATES.fetch(flag_name, false)
  end
end
```

This enables toggling between different data loading strategies without altering the schema.

## Testing and Validation

The `spec/graphql/loaders/association_dataloader_with_lookahead_spec.rb` file contains integration tests that validate the behavior of the custom loaders and helpers. These tests ensure that:

- Nested associations are eagerly loaded based on lookahead.
- Pagination works correctly with connections.
- Spam comments are filtered out appropriately.
- Edge cases, such as posts with no comments or authors without profiles, are handled gracefully.

## Sample Query

Try this out in local [GraphiQL](http://127.0.0.1:3000/graphiql)

### Association Field

Plain data, nothing fancy

```
{
  posts {
    id
    title
    comments {
      id
      body
      author {
        id
        name
        profile {
          id
          bio
        }
      }
      post {
        id
        title
        comments {
          id
          likes {
            id
            user {
              id
              name
            }
          }
        }
      }
    }
    tags {
      id
      name
    }
  }
}
```

With the flag ON:

```
GraphQL query made 7 SELECT queries
Completed 200 OK in 154ms (Views: 2.7ms | ActiveRecord: 0.7ms (7 queries, 0 cached) | GC: 11.1ms)
```

With the flag OFF:

```
GraphQL query made 387 SELECT queries
Completed 200 OK in 331ms (Views: 3.4ms | ActiveRecord: 7.0ms (372 queries, 90 cached) | GC: 47.4ms)
```

### Connections

```
{
  posts {
    id
    title
    commentsConnection(first: 5) {
      edges {
        node {
          id
          body
          spam
          author {
            id
            name
            profile {
              id
              bio
            }
          }
          likes {
            id
            user {
              id
              name
            }
          }
        }
      }
    }
  }
}
```

With the flag ON:

```
GraphQL query made 15 SELECT queries
Completed 200 OK in 72ms (Views: 0.4ms | ActiveRecord: 1.4ms (15 queries, 0 cached) | GC: 2.8ms)
```

With the flag OFF:

```
GraphQL query made 275 SELECT queries
Completed 200 OK in 161ms (Views: 0.3ms | ActiveRecord: 5.4ms (262 queries, 40 cached) | GC: 13.6ms)
```
