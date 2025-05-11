# README

This repository demonstrates advanced GraphQL patterns in a Ruby on Rails application, focusing on efficient data loading, lookahead optimization, and flexible field definitions.

## Overview

The application models a blogging platform with entities like `Author`, `Post`, `Comment`, `Profile`, and `Like`. It leverages GraphQL-Ruby's dataloader, lookahead features, and custom helpers to optimize query performance and maintain a clean schema design.

### Why Aren't You Using X?

A lot of the existing patterns do not seem to handle dynamic preloads well, or tend
to be very cumbersome to use.

#### Shopify's [GraphQL Batch Loader](https://github.com/Shopify/graphql-batch)

This seems to have predated the Dataloader pattern in the main Ruby GraphQL gem
though was very likely the inspiration for it. I was not fond of some of the
nested nature of association queries:

```ruby
def product_image(id:)
  RecordLoader.for(Product).load(id).then do |product|
    RecordLoader.for(Image).load(product.image_id)
  end
end
```

This felt very manual, especially for deeply nested associations which can
become very common in larger applications. Perhaps I was using it wrong but
given Dataloader being introduced in the interim it made more sense for me to
try something else out.

#### EvilMartian's [ar_lazy_preload](https://github.com/DmitryTsepelev/ar_lazy_preload)

This one I liked a lot more, it got to the point and took care of a lot of
detailts that could reasonably be implied.

```ruby
users = User.lazy_preload(:posts).limit(10)  # => SELECT * FROM users LIMIT 10
users.map(&:first_name)
```

The kicker was this:

```ruby
ArLazyPreload.config.auto_preload = true
```

...which did things automatically. The problem for me was that it monkeypatched
ActiveRecord which meant it would likely be difficult to maintain and upgrade
some time in the future, which is something I'd like to avoid for any sufficiently
large Rails application that's likely to last several more years.

#### GraphQL [DataLoader](https://graphql-ruby.org/dataloader/overview.html)

Rather than promise-based this is fiber-based and is explicitly inspired by
Shopify's gem:

```ruby
field :is_following, Boolean, null: false do
  argument :follower_handle, String
  argument :followed_handle, String
end

def is_following(follower_handle:, followed_handle:)
  follower, followed = dataloader
    .with(Sources::UserByHandle)
    .load_all([follower_handle, followed_handle])

  followed && follower && follower.follows?(followed)
end
```

This got real close to what I was looking for, but I also wanted it to
just figure out some of the associations dynamically and reduce things down
to a single-line if at all possible. It's still the base for what I have here.

#### Where We Are Here

Just this for a nested type:

```ruby
association_field :tags, type: [ Types::TagType ], null: true
```

...or if you need pagination?:

```ruby
association_connection :comments,
  type: Types::CommentType,
  null: false,
  max_page_size: 25,
  scoped: ->(scope, args, ctx) {
    scope.where(spam: false).order(created_at: :desc)
  } do
    argument :not_spam, Boolean, required: false
  end
```

You can still pass arguments and other context, but now the in-place code
required has been reduced to a few lines.

Granted, this is heavily experimental at the current time, and I'm still
exploring a lot more around this domain to see how it can be further refined.

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
