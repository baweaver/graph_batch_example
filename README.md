# README

Experimental repo to test GraphQL batch loading patterns.

## Stupid Flags

This is intended as a stand-in for any more mature product:

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

The loader will be on when the flag is on.

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
